import Foundation

/// Safety checks on the profile itself (Build Doc §12, §26).
public struct SafetyAssessment: Codable, Hashable, Sendable {
    /// Any sign the person may be under 18. Disables all flirting and the recommendation.
    public var possibleMinor: Bool
    public var notes: [String]

    public static func assess(_ profile: DatingProfile) -> SafetyAssessment {
        var notes: [String] = []
        var minor = false
        if let age = profile.age, age < 18 {
            minor = true
            notes.append("The profile shows an age under 18.")
        }
        let text = profile.allText
        if TextFeatures.containsAny(text, TextFeatures.minorSignals) {
            minor = true
            notes.append("The profile mentions something that suggests the person may be under 18.")
        }
        if minor { notes.append("Dating Assist won't suggest flirting or a like for this profile.") }
        return SafetyAssessment(possibleMinor: minor, notes: notes)
    }
}

/// Build Doc §10-11: AUTO infers the profile's written tone and matches or slightly exceeds it.
/// Escalation is driven only by the profile's own words — never by how photos look.
public enum FlirtCalibrator {
    public static func tone(of profile: DatingProfile) -> ProfileTone {
        let text = profile.authoredText
        let words = TextFeatures.words(text)
        let suggestive = TextFeatures.countAny(text, TextFeatures.suggestiveProfileMarkers)
        let bold = TextFeatures.countAny(text, TextFeatures.boldProfileMarkers)
        let teasing = TextFeatures.countAny(text, TextFeatures.teasingMarkers) + TextFeatures.countAny(text, TextFeatures.opinionMarkers)
        let wholesome = TextFeatures.countAny(text, TextFeatures.wholesomeProfileMarkers)
        let humor = TextFeatures.countAny(text, TextFeatures.humorMarkers) + TextFeatures.emojiCount(text)
        let avgAnswer = profile.prompts.isEmpty ? 0 : Double(profile.prompts.map { TextFeatures.words($0.answer).count }.reduce(0, +)) / Double(profile.prompts.count)

        if suggestive >= 2 { return .suggestive }
        if bold >= 2 || (bold >= 1 && suggestive >= 1) { return .bold }
        if teasing >= 2 { return .teasing }
        if wholesome >= 2 && suggestive == 0 && teasing == 0 { return .wholesome }
        if humor >= 2 || teasing >= 1 || suggestive >= 1 || bold >= 1 { return .playful }
        if words.count < 12 || avgAnswer < 4 { return .reserved }
        if wholesome >= 1 { return .wholesome }
        return .neutral
    }

    /// The flirt level to aim for.
    public static func target(setting: FlirtSetting, tone: ProfileTone, dna: MessageDNA, preferences: UserPreferences, safety: SafetyAssessment) -> FlirtIntensity {
        if safety.possibleMinor { return .friendly }
        let cap = maxAllowed(tone: tone, preferences: preferences)
        switch setting {
        case .fixed(let level):
            return min(level, cap)
        case .auto:
            // Match the profile, step up by one, then let the user's own habits nudge it.
            let level = tone.baseFlirtLevel + 1 + dna.flirtBias
            return min(FlirtIntensity(clamping: level), cap)
        }
    }

    /// Spicy (5) only with Spicy Suggestions on, adult confirmed, and a profile whose own words invite it.
    public static func maxAllowed(tone: ProfileTone, preferences: UserPreferences) -> FlirtIntensity {
        if preferences.spicyAllowed && tone == .suggestive { return .spicy }
        return .bold
    }
}

/// Local compatibility estimate from the user's five preferences. Dealbreakers and age range are
/// hard rules the AI can't override.
public enum CompatibilityScorer {
    static let synonyms: [String: [String]] = [
        "hiking": ["hike", "hiking", "trail", "trails", "mountain", "mountains", "outdoors", "camping", "summit"],
        "travel": ["travel", "traveling", "travelling", "trip", "trips", "abroad", "passport", "flight", "country", "countries"],
        "dogs": ["dog", "dogs", "puppy", "pup", "doggo"],
        "cats": ["cat", "cats", "kitten"],
        "music": ["music", "concert", "concerts", "festival", "guitar", "piano", "band", "vinyl", "playlist", "karaoke"],
        "food": ["food", "cooking", "cook", "restaurant", "restaurants", "brunch", "pizza", "tacos", "sushi", "ramen", "foodie", "chef"],
        "coffee": ["coffee", "espresso", "latte", "cafe", "matcha"],
        "fitness": ["gym", "fitness", "workout", "lifting", "run", "running", "marathon", "yoga", "pilates", "climbing"],
        "reading": ["book", "books", "reading", "read", "novel", "library", "bookstore"],
        "gaming": ["game", "games", "gaming", "mario", "zelda", "nintendo", "playstation", "xbox", "switch", "catan"],
        "movies": ["movie", "movies", "film", "films", "cinema", "letterboxd"],
        "art": ["art", "museum", "museums", "gallery", "painting", "pottery", "drawing"],
        "beach": ["beach", "ocean", "surf", "surfing", "sea", "coast"],
        "comedy": ["comedy", "stand-up", "standup", "funny", "jokes", "memes"],
    ]

    static let dealbreakerSynonyms: [String: [String]] = [
        "smoking": ["smoke", "smoker", "smoking", "cigarette", "cigarettes", "cigs", "vape", "vaping", "smokes: yes"],
        "kids": ["have children", "my kids", "my son", "my daughter", "single mom", "single dad", "mom of", "dad of"],
        "no kids": ["don't want children", "dont want children", "no kids ever", "childfree", "child-free"],
        "drugs": ["drugs", "420", "stoner", "weed", "cannabis", "edibles"],
        "heavy drinking": ["drunk", "blackout", "wasted", "shots shots", "party every"],
        "long distance": ["long distance", "moving to", "relocating", "only here until", "visiting"],
        "hookups": ["short-term fun", "nothing serious", "just for fun", "hookup", "fwb"],
        "no pets": ["no pets"],
        "cats": ["cat", "cats", "kitten"],
        "dogs": ["dog", "dogs", "puppy"],
    ]

    public static func score(_ profile: DatingProfile, preferences prefs: UserPreferences) -> CompatibilityAssessment {
        let text = profile.allText.lowercased()
        let textWords = Set(TextFeatures.words(text).map(TextFeatures.stem))
        var score = 58.0
        var reasons: [String] = []
        var concerns: [String] = []
        var dealbreakersHit: [String] = []
        var evidence = 0

        // Interests.
        var matched: [String] = []
        for interest in prefs.interests {
            let key = interest.lowercased().trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            let terms = synonyms[key] ?? synonyms.first(where: { $0.value.contains(key) })?.value ?? [key]
            if terms.contains(where: { text.contains($0) || textWords.contains(TextFeatures.stem($0)) }) { matched.append(interest) }
        }
        if !matched.isEmpty {
            score += min(24, Double(matched.count) * 8)
            reasons.append("Shares your interest in \(matched.prefix(3).joined(separator: ", ")).")
            evidence += matched.count
        }

        // Green flags.
        let flags = prefs.greenFlags.filter { flag in
            let k = flag.lowercased().trimmingCharacters(in: .whitespaces)
            return !k.isEmpty && (text.contains(k) || TextFeatures.contentStems(k).isSubset(of: textWords))
        }
        if !flags.isEmpty {
            score += min(12, Double(flags.count) * 6)
            reasons.append("Shows green flags you care about: \(flags.prefix(2).joined(separator: ", ")).")
            evidence += flags.count
        }

        // Dating intentions.
        if let theirGoal = RelationshipGoal.detect(in: text) {
            let a = prefs.goal.alignment(with: theirGoal)
            score += (a - 0.6) * 22
            if a >= 0.85 { reasons.append("Looking for the same thing (\(theirGoal.label.lowercased())).") }
            else if a < 0.5 { concerns.append("Different dating intentions: \(theirGoal.label.lowercased()).") }
            evidence += 1
        }

        // Age range.
        if let age = profile.age {
            if age < prefs.ageMin || age > prefs.ageMax {
                score -= 28
                concerns.append("Age \(age) is outside your \(prefs.ageMin)-\(prefs.ageMax) range.")
            } else {
                score += 3
            }
            evidence += 1
        }

        // Dealbreakers (hard rule).
        for breaker in prefs.dealbreakers {
            let key = breaker.lowercased().trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            let terms = dealbreakerSynonyms[key] ?? [key]
            for term in terms where text.contains(term) && !isNegated(term, in: text) {
                dealbreakersHit.append(breaker)
                break
            }
        }
        if !dealbreakersHit.isEmpty {
            score = min(score - 40, 35)
            concerns.append("Hits your dealbreaker: \(dealbreakersHit.joined(separator: ", ")).")
        }

        // Profile effort: more prompts and photos = easier conversation, more confidence.
        if profile.prompts.count >= 3 { score += 3 }
        if profile.prompts.isEmpty { concerns.append("No written prompts to go on.") }

        let confidence = min(0.95, 0.35 + Double(evidence) * 0.08 + Double(profile.prompts.count) * 0.06 + Double(profile.photos.count) * 0.02 + profile.ocrConfidence * 0.1)
        if reasons.isEmpty && dealbreakersHit.isEmpty { reasons.append("Nothing conflicts with your preferences.") }
        return CompatibilityAssessment(score: Int(score.rounded()), confidence: confidence, reasons: reasons, concerns: concerns, dealbreakersHit: dealbreakersHit)
    }

    static func isNegated(_ term: String, in text: String) -> Bool {
        guard let range = text.range(of: term) else { return false }
        let before = text[text.startIndex..<range.lowerBound].suffix(14)
        return ["no ", "never ", "don't ", "dont ", "not ", "non-", "doesn't "].contains { before.hasSuffix($0) || before.contains($0) }
    }

    /// Combines the local estimate with a provider's. Hard rules (dealbreakers, age) always win.
    public static func blend(local: CompatibilityAssessment, provider: CompatibilityAssessment?) -> CompatibilityAssessment {
        guard let provider else { return local }
        var merged = local
        let blended = Double(local.score) * 0.45 + Double(provider.score) * 0.55
        merged.score = Int(blended.rounded()).clamped(0, 100)
        if !local.dealbreakersHit.isEmpty { merged.score = min(merged.score, 35) }
        if local.concerns.contains(where: { $0.hasPrefix("Age ") }) { merged.score = min(merged.score, 55) }
        merged.confidence = max(local.confidence, provider.confidence * 0.9)
        merged.reasons = (provider.reasons + local.reasons.filter { $0 != "Nothing conflicts with your preferences." }).uniqued().prefixArray(4)
        merged.concerns = (local.concerns + provider.concerns).uniqued().prefixArray(4)
        return merged
    }

    public static func recommendation(for c: CompatibilityAssessment, safety: SafetyAssessment) -> MatchRecommendation {
        if safety.possibleMinor || !c.dealbreakersHit.isEmpty { return .skip }
        if c.score >= 70 { return .like }
        if c.score >= 52 { return .consider }
        return .skip
    }
}

/// Build Doc §7 weighted interaction score and unified ranking.
public enum InteractionRanker {
    public struct Weights: Sendable {
        public var reply = 0.30, specificity = 0.25, humor = 0.15, flirt = 0.15, originality = 0.10, style = 0.05
        public init() {}
    }

    public static func score(_ s: TargetSignals, weights w: Weights = Weights()) -> Int {
        let v = Double(s.replyPotential) * w.reply
            + Double(s.specificity) * w.specificity
            + Double(s.humorPotential) * w.humor
            + Double(s.flirtPotential) * w.flirt
            + Double(s.originalityPotential) * w.originality
            + Double(s.styleCompatibility) * w.style
        return Int(v.rounded()).clamped(0, 100)
    }

    /// Ranks every target. Ties break toward prompts (more specific) then profile order, so the
    /// same input always gives the same ranking.
    public static func rank(_ signals: [TargetSignals], profile: DatingProfile) -> [InteractionTarget] {
        signals
            .filter { s in s.ref.type == .prompt ? profile.prompt(s.ref.index) != nil : profile.photo(s.ref.index) != nil }
            .map { s -> InteractionTarget in
                let context: String
                switch s.ref.type {
                case .prompt:
                    let p = profile.prompt(s.ref.index)!
                    context = "\(p.question) — \(p.answer)"
                case .photo:
                    let ph = profile.photo(s.ref.index)!
                    let parts = ph.visibleContext.prefix(3).joined(separator: ", ")
                    context = [ph.caption.map { "“\($0)”" }, parts.isEmpty ? nil : parts].compactMap { $0 }.joined(separator: " · ").ifEmpty("Photo with no readable context")
                }
                return InteractionTarget(
                    id: deterministicID(s.ref), type: s.ref.type, profileIndex: s.ref.index, context: context,
                    conversationPotential: (s.replyPotential + s.humorPotential) / 2,
                    personalizationPotential: s.specificity, flirtPotential: s.flirtPotential, humorPotential: s.humorPotential,
                    replyPotential: s.replyPotential, originalityPotential: s.originalityPotential,
                    styleCompatibility: s.styleCompatibility, overallInteractionScore: score(s), rationale: s.rationale)
            }
            .sorted { a, b in
                if a.overallInteractionScore != b.overallInteractionScore { return a.overallInteractionScore > b.overallInteractionScore }
                if a.type != b.type { return a.type == .prompt }
                return a.profileIndex < b.profileIndex
            }
    }

    static func deterministicID(_ ref: TargetRef) -> UUID {
        let n = (ref.type == .prompt ? 0x1000 : 0x2000) + ref.index
        return UUID(uuidString: String(format: "00000000-0000-4000-8000-%012X", n)) ?? UUID()
    }

    /// Blends provider signals with local ones for stability (provider-weighted).
    public static func blend(local: [TargetSignals], provider: [TargetSignals], providerWeight: Double = 0.7) -> [TargetSignals] {
        let byRef = Dictionary(provider.map { ($0.ref, $0) }, uniquingKeysWith: { a, _ in a })
        return local.map { l in
            guard let p = byRef[l.ref] else { return l }
            func mix(_ a: Int, _ b: Int) -> Int { Int((Double(b) * providerWeight + Double(a) * (1 - providerWeight)).rounded()) }
            return TargetSignals(ref: l.ref, replyPotential: mix(l.replyPotential, p.replyPotential), specificity: mix(l.specificity, p.specificity),
                                 humorPotential: mix(l.humorPotential, p.humorPotential), flirtPotential: mix(l.flirtPotential, p.flirtPotential),
                                 originalityPotential: mix(l.originalityPotential, p.originalityPotential),
                                 styleCompatibility: mix(l.styleCompatibility, p.styleCompatibility),
                                 rationale: p.rationale.isEmpty ? l.rationale : p.rationale)
        }
    }
}

extension String {
    func ifEmpty(_ fallback: String) -> String { isEmpty ? fallback : self }
}

extension Array {
    func prefixArray(_ n: Int) -> [Element] { Array(prefix(n)) }
}
