import Foundation

public enum AnalysisStage: String, Sendable, CaseIterable {
    case analyzing = "Analyzing every photo & prompt"
    case ranking = "Ranking conversation targets"
    case writing = "Writing 12+ openers"
    case critiquing = "Critiquing & choosing the strongest"
}

public enum EngineError: Error, LocalizedError, Equatable {
    case emptyProfile

    public var errorDescription: String? {
        switch self {
        case .emptyProfile: "No prompts or photos were found in these screenshots."
        }
    }
}

/// Orchestrates the full decision: compatibility, target ranking, candidate generation, critique.
/// AI providers supply raw judgments; this engine validates and decides deterministically.
public struct WingmanEngine: Sendable {
    public let router: ProviderRouter
    /// Your personal on-device ranking model.
    public var model: OpenerModel

    public init(router: ProviderRouter = ProviderRouter(), model: OpenerModel = OpenerModel()) {
        self.router = router
        self.model = model
    }

    // MARK: - Full analysis

    public func analyze(profile: DatingProfile, photos: [ProviderImage], preferences: UserPreferences, dna: MessageDNA,
                        progress: @escaping @Sendable (AnalysisStage) -> Void = { _ in }) async throws -> CompleteProfileAnalysis {
        guard !profile.prompts.isEmpty || !profile.photos.isEmpty else { throw EngineError.emptyProfile }
        progress(.analyzing)

        let safety = SafetyAssessment.assess(profile)
        let localTone = FlirtCalibrator.tone(of: profile)
        let local = ProfileHeuristicAnalyzer.analyze(profile, preferences: preferences, dna: dna)
        let localCompat = CompatibilityScorer.score(profile, preferences: preferences)

        let preliminaryFlirt = FlirtCalibrator.target(setting: preferences.flirtSetting, tone: localTone, dna: dna, preferences: preferences, safety: safety)
        let request = AnalysisRequest(profile: profile, photos: photos, preferences: preferences, dna: dna,
                                      flirtTarget: preliminaryFlirt, spicyAllowed: preferences.spicyAllowed && !safety.possibleMinor, tone: localTone)

        var providerResult: Routed<ProviderAnalysis>?
        do { providerResult = try await router.analyze(request) } catch is CancellationError { throw CancellationError() } catch { providerResult = nil }
        let provided = providerResult.map { sanitize($0.value, profile: profile) } ?? ProviderAnalysis()

        // Tone: trust the model's read only toward *less* escalation unless the text itself shows it.
        var tone = localTone
        if let pt = provided.tone, pt.baseFlirtLevel <= localTone.baseFlirtLevel || localTone == .neutral { tone = pt == .suggestive && localTone != .suggestive ? .bold : pt }
        let flirt = FlirtCalibrator.target(setting: preferences.flirtSetting, tone: tone, dna: dna, preferences: preferences, safety: safety)

        progress(.ranking)
        let signals = InteractionRanker.blend(local: local.targets, provider: provided.targets)
        let ranked = InteractionRanker.rank(signals, profile: profile)
        let photoAnalyses = merge(local.photos, provided.photoAnalyses, key: \.index)
        let promptAnalyses = merge(local.prompts, provided.promptAnalyses, key: \.index)

        let compat = CompatibilityScorer.blend(local: localCompat, provider: provided.compatibility)
        let recommendation = CompatibilityScorer.recommendation(for: compat, safety: safety)

        var best: RecommendedInteraction?
        var report = providerResult?.report
        if !safety.possibleMinor, let top = ranked.first {
            progress(.writing)
            let ctx = Context(profile: profile, photos: photos, preferences: preferences, dna: dna, tone: tone, flirt: flirt,
                              safety: safety, photoAnalyses: photoAnalyses, promptAnalyses: promptAnalyses)
            let (comments, candReport) = await writeComments(for: top, ctx: ctx, seed: provided.candidates, direction: nil, baseMessage: nil, avoid: [])
            progress(.critiquing)
            if report == nil { report = candReport }
            best = RecommendedInteraction(
                target: top,
                why: WingmanEngine.explain(target: top, comment: comments.first, profile: profile),
                comment: comments.first, alternatives: Array(comments.dropFirst().prefix(5)), flirtIntensity: flirt)
        }

        let confidence = min(0.97, compat.confidence * 0.6 + profile.ocrConfidence * 0.2 + (providerResult == nil ? 0.08 : 0.17))
        return CompleteProfileAnalysis(
            profile: profile, overallCompatibility: compat.score, confidence: confidence, recommendation: recommendation,
            compatibility: compat, tone: tone, photoAnalyses: photoAnalyses, promptAnalyses: promptAnalyses,
            rankedInteractionTargets: ranked, bestInteraction: best, safetyNotes: safety.notes, providerReport: report)
    }

    // MARK: - Rewrites & alternatives

    /// Build Doc §19: rewrites the current suggestion in a direction. Returns the updated analysis.
    public func rewrite(_ analysis: CompleteProfileAnalysis, direction: RewriteDirection, photos: [ProviderImage], preferences: UserPreferences, dna: MessageDNA) async -> CompleteProfileAnalysis {
        guard let best = analysis.bestInteraction else { return analysis }
        let safety = SafetyAssessment.assess(analysis.profile)
        var level = best.flirtIntensity.rawValue + direction.flirtDelta
        if direction == .moreSuggestive && !preferences.spicyAllowed { level = min(level, FlirtIntensity.bold.rawValue) }
        let cap = FlirtCalibrator.maxAllowed(tone: direction == .moreSuggestive && preferences.spicyAllowed ? .suggestive : analysis.tone, preferences: preferences)
        let flirt = safety.possibleMinor ? .friendly : min(FlirtIntensity(clamping: level), cap)

        let ctx = Context(profile: analysis.profile, photos: photos, preferences: preferences, dna: dna, tone: analysis.tone, flirt: flirt,
                          safety: safety, photoAnalyses: analysis.photoAnalyses, promptAnalyses: analysis.promptAnalyses)
        let shown = ([best.comment].compactMap { $0 } + best.alternatives).map(\.text)
        let (comments, report) = await writeComments(for: best.target, ctx: ctx, seed: [], direction: direction, baseMessage: best.comment?.text, avoid: shown)
        var updated = analysis
        guard !comments.isEmpty else { return analysis }
        updated.bestInteraction = RecommendedInteraction(
            target: best.target, why: best.why, comment: comments.first,
            alternatives: Array(comments.dropFirst().prefix(5)), flirtIntensity: flirt)
        if let report { updated.providerReport = report }
        return updated
    }

    /// Fresh set of options for the current target ("MORE OPTIONS").
    public func moreOptions(_ analysis: CompleteProfileAnalysis, photos: [ProviderImage], preferences: UserPreferences, dna: MessageDNA) async -> CompleteProfileAnalysis {
        guard let best = analysis.bestInteraction else { return analysis }
        return await retarget(analysis, to: best.target.ref, photos: photos, preferences: preferences, dna: dna,
                              avoid: ([best.comment].compactMap { $0 } + best.alternatives).map(\.text))
    }

    /// Lets the user pick a different photo/prompt from the ranking and get openers for it.
    public func retarget(_ analysis: CompleteProfileAnalysis, to ref: TargetRef, photos: [ProviderImage], preferences: UserPreferences, dna: MessageDNA, avoid: [String] = []) async -> CompleteProfileAnalysis {
        guard let target = analysis.rankedInteractionTargets.first(where: { $0.ref == ref }) else { return analysis }
        let safety = SafetyAssessment.assess(analysis.profile)
        guard !safety.possibleMinor else { return analysis }
        let flirt = analysis.bestInteraction?.flirtIntensity ?? FlirtCalibrator.target(setting: preferences.flirtSetting, tone: analysis.tone, dna: dna, preferences: preferences, safety: safety)
        let ctx = Context(profile: analysis.profile, photos: photos, preferences: preferences, dna: dna, tone: analysis.tone, flirt: flirt,
                          safety: safety, photoAnalyses: analysis.photoAnalyses, promptAnalyses: analysis.promptAnalyses)
        let (comments, report) = await writeComments(for: target, ctx: ctx, seed: [], direction: nil, baseMessage: nil, avoid: avoid)
        var updated = analysis
        updated.bestInteraction = RecommendedInteraction(
            target: target, why: WingmanEngine.explain(target: target, comment: comments.first, profile: analysis.profile),
            comment: comments.first, alternatives: Array(comments.dropFirst().prefix(5)), flirtIntensity: flirt)
        if let report { updated.providerReport = report }
        return updated
    }

    // MARK: - Comment writing

    struct Context {
        var profile: DatingProfile
        var photos: [ProviderImage]
        var preferences: UserPreferences
        var dna: MessageDNA
        var tone: ProfileTone
        var flirt: FlirtIntensity
        var safety: SafetyAssessment
        var photoAnalyses: [PhotoAnalysis]
        var promptAnalyses: [PromptAnalysis]
    }

    /// Generates >= 12 candidates, critiques them and returns the accepted ones, best first.
    func writeComments(for target: InteractionTarget, ctx: Context, seed: [CommentCandidate], direction: RewriteDirection?, baseMessage: String?, avoid: [String]) async -> ([ScoredCandidate], ProviderReport?) {
        let hooks = WingmanEngine.hooks(for: target.ref, photos: ctx.photoAnalyses, prompts: ctx.promptAnalyses)
        let critique = CritiqueContext(profile: ctx.profile, target: target.ref, targetText: target.context, hooks: hooks,
                                       flirtTarget: ctx.flirt, spicyAllowed: ctx.preferences.spicyAllowed && !ctx.safety.possibleMinor,
                                       possibleMinor: ctx.safety.possibleMinor, dna: ctx.dna)
        let preferred = direction?.preferredStyles ?? []
        let targetPhotos = ctx.photos.filter { target.type == .photo ? $0.photoIndex == target.profileIndex : false }
        var request = CandidateRequest(profile: ctx.profile, target: target.ref, targetContext: target.context, hooks: hooks, photos: targetPhotos,
                                       preferences: ctx.preferences, dna: ctx.dna, flirtTarget: ctx.flirt,
                                       spicyAllowed: critique.spicyAllowed, tone: ctx.tone, direction: direction,
                                       baseMessage: baseMessage, avoid: avoid)
        let avoidKeys = Set(avoid.map(TextFeatures.normalize))

        let category = target.type == .prompt ? ctx.profile.prompt(target.profileIndex)?.category : nil
        func score(_ pool: [CommentCandidate]) -> [ScoredCandidate] {
            pool.filter { $0.target == target.ref }
                .map { c -> CommentCandidate in var c = c; c.text = StyleApplier.apply(c.text, dna: ctx.dna, style: c.style); return c }
                .filter { !avoidKeys.contains(TextFeatures.normalize($0.text)) }
                .map { c -> ScoredCandidate in
                    var s = CommentCritic.evaluate(c, context: critique)
                    s.features = OpenerFeatures.vector(for: s, category: category)
                    return s
                }
        }

        var report: ProviderReport?
        var pool = seed.filter { $0.target == target.ref }
        if pool.count < 12 {
            request.count = max(12, 12 - pool.count)
            if let routed = try? await router.generateCandidates(request) {
                pool += routed.value
                report = routed.report
            }
        }
        var scored = score(pool)
        var ranked = CandidateRanker.rank(scored, preferredStyles: preferred, model: model)

        // Regenerate once with the critic's feedback if too few survived.
        if ranked.count < 3 {
            request.critique = Array(Set(scored.flatMap(\.rejectionReasons))).sorted()
            request.avoid = avoid + scored.map(\.text)
            if let routed = try? await router.generateCandidates(request) {
                scored += score(routed.value)
                report = report ?? routed.report
            }
            ranked = CandidateRanker.rank(scored, preferredStyles: preferred, model: model)
        }
        // Final safety net: the offline generator always produces something specific.
        if ranked.isEmpty {
            scored += score(LocalCommentGenerator.generate(request))
            ranked = CandidateRanker.rank(scored, preferredStyles: preferred, model: model)
        }
        if direction == .shorter {
            let short = ranked.filter { $0.text.count <= 70 }
            ranked = short.sorted { $0.text.count < $1.text.count } + ranked.filter { $0.text.count > 70 }
        }
        return (ranked, report)
    }

    // MARK: - Helpers

    static func hooks(for ref: TargetRef, photos: [PhotoAnalysis], prompts: [PromptAnalysis]) -> [String] {
        switch ref.type {
        case .prompt: prompts.first { $0.index == ref.index }.map { $0.hooks + [$0.question] } ?? []
        case .photo: photos.first { $0.index == ref.index }.map { $0.conversationHooks + $0.visibleContext } ?? []
        }
    }

    /// "WHY THIS ONE?" copy.
    public static func explain(target: InteractionTarget, comment: ScoredCandidate?, profile: DatingProfile) -> String {
        var parts: [String] = [target.rationale]
        if target.type == .prompt || target.profileIndex != 1, !profile.photos.isEmpty, target.ref != TargetRef(.photo, 1) {
            parts.insert("Don't use the first photo.", at: 0)
        }
        if let c = comment {
            var traits: [String] = []
            if c.scores.specificityRating >= 4 { traits.append("specific") }
            if c.scores.humor >= 50 { traits.append("playful") }
            if c.scores.replyProbability >= 60 { traits.append("gives them an easy reply") }
            if c.scores.styleMatch >= 55 { traits.append("matches how you normally talk") }
            if !traits.isEmpty { parts.append("The line is " + naturalList(traits) + ".") }
        }
        return parts.joined(separator: " ")
    }

    static func naturalList(_ items: [String]) -> String {
        switch items.count {
        case 0: ""
        case 1: items[0]
        case 2: "\(items[0]) and \(items[1])"
        default: items.dropLast().joined(separator: ", ") + ", and " + items.last!
        }
    }

    /// Drops provider output that points at photos/prompts that don't exist (hallucination guard).
    func sanitize(_ a: ProviderAnalysis, profile: DatingProfile) -> ProviderAnalysis {
        func exists(_ ref: TargetRef) -> Bool { ref.type == .prompt ? profile.prompt(ref.index) != nil : profile.photo(ref.index) != nil }
        var out = a
        out.targets = a.targets.filter { exists($0.ref) }
        out.candidates = a.candidates.filter { exists($0.target) && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        out.photoAnalyses = a.photoAnalyses.filter { profile.photo($0.index) != nil }
        out.promptAnalyses = a.promptAnalyses.filter { profile.prompt($0.index) != nil }
        return out
    }

    func merge<T>(_ local: [T], _ provided: [T], key: KeyPath<T, Int>) -> [T] {
        let byKey = Dictionary(provided.map { ($0[keyPath: key], $0) }, uniquingKeysWith: { a, _ in a })
        return local.map { byKey[$0[keyPath: key]] ?? $0 }
    }
}
