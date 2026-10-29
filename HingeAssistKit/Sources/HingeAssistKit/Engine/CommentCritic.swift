import Foundation

/// Everything the critic needs to judge one candidate.
public struct CritiqueContext: Sendable {
    public var profile: DatingProfile
    public var target: TargetRef
    public var targetText: String
    public var hooks: [String]
    public var flirtTarget: FlirtIntensity
    public var spicyAllowed: Bool
    public var possibleMinor: Bool
    public var dna: MessageDNA

    public init(profile: DatingProfile, target: TargetRef, targetText: String, hooks: [String], flirtTarget: FlirtIntensity, spicyAllowed: Bool, possibleMinor: Bool, dna: MessageDNA) {
        self.profile = profile
        self.target = target
        self.targetText = targetText
        self.hooks = hooks
        self.flirtTarget = flirtTarget
        self.spicyAllowed = spicyAllowed
        self.possibleMinor = possibleMinor
        self.dna = dna
    }
}

/// Build Doc §15-17: naturalness critic, profile-specificity test, safety filter and scoring.
public enum CommentCritic {
    public static func evaluate(_ candidate: CommentCandidate, context ctx: CritiqueContext) -> ScoredCandidate {
        let text = candidate.text
        var reasons: [String] = []

        // --- Safety (hard rejects) ---
        let flirt = estimatedFlirt(text, ignoring: ctx.profile.allText)
        if TextFeatures.containsAny(" " + text + " ", TextFeatures.graphicTerms) { reasons.append("Graphic sexual language") }
        let profileLower = " " + TextFeatures.normalize(ctx.profile.allText) + " "
        let sensitiveMentioned = TextFeatures.sensitiveTerms.filter { (" " + TextFeatures.normalize(text) + " ").contains($0) && !profileLower.contains($0) }
        if !sensitiveMentioned.isEmpty { reasons.append("Brings up a sensitive trait") }
        if ctx.possibleMinor && flirt >= 2 { reasons.append("No flirting: the person may be under 18") }
        if flirt >= 5 && !ctx.spicyAllowed { reasons.append("Too suggestive (Spicy Suggestions is off)") }
        if flirt > ctx.flirtTarget.rawValue + 1 { reasons.append("Too forward for this profile") }

        // --- Specificity (§17) ---
        let rating = specificityRating(text, ctx: ctx)
        if rating < 3 { reasons.append("Could be sent to anyone") }

        // --- Repeats the profile ---
        if let answer = ctx.profile.prompt(ctx.target.index)?.answer, ctx.target.type == .prompt {
            let run = TextFeatures.longestSharedRun(text, answer)
            let cStems = TextFeatures.contentStems(text), aStems = TextFeatures.contentStems(answer)
            if run >= 7 || (cStems.count >= 4 && Double(cStems.intersection(aStems).count) / Double(cStems.count) > 0.8) {
                reasons.append("Just repeats the profile")
            }
        }

        // --- Fabrication ---
        if let made = fabricatedFact(text, profile: ctx.profile) { reasons.append("Assumes something not on the profile (\(made))") }

        // --- Naturalness (§16) ---
        let verdict = naturalness(text, specificity: rating)
        if !verdict.passes { reasons.append("Sounds like \(verdict.label)") }

        // --- Scores ---
        let lower = TextFeatures.normalize(text)
        var reply = 38 + min(36, TextFeatures.countAny(text, TextFeatures.replyHooks) * 12)
        if text.contains("?") { reply += 10 }
        if TextFeatures.containsAny(text, TextFeatures.teasingMarkers) { reply += 8 }
        if candidate.style == .complimentary && !text.contains("?") { reply -= 8 }
        if TextFeatures.containsAny(text, TextFeatures.interviewOpeners) { reply -= 12 }

        var humor = 22 + min(54, TextFeatures.countAny(text, TextFeatures.humorMarkers) * 16)
        if text.contains("😂") || text.contains("😭") || text.contains("💀") { humor += 10 }
        if [.funny, .teasing].contains(candidate.style) { humor += 10 }

        let flirtQuality = max(0, 100 - abs(flirt - ctx.flirtTarget.rawValue) * 28)

        var originality = 72
        originality -= TextFeatures.countAny(text, TextFeatures.clichés) * 30
        originality -= TextFeatures.countAny(text, TextFeatures.genericPhrases) * 30
        originality += min(18, TextFeatures.contentWords(text).filter { $0.count >= 7 }.count * 6)

        var natural = verdict.passes ? 74 : 18
        if verdict.passes {
            if lower.contains("'") { natural += 6 }
            if (20...120).contains(text.count) { natural += 10 } else if text.count > 160 { natural -= 15 }
            let emojis = TextFeatures.emojiCount(text)
            if emojis == 1 { natural += 4 } else if emojis > 2 { natural -= 12 }
            if text.hasSuffix(".") { natural -= 4 }
        }

        let lengthFit = max(0, 100 - Int(abs(Double(text.count) - ctx.dna.averageLength) * 0.8))
        let styleMatch = Int((ctx.dna.affinity(for: candidate.style) * 70 + Double(lengthFit) * 0.3).rounded())

        let specificity = rating * 20
        let total = Double(specificity) * 0.25 + Double(reply.clamped(0, 100)) * 0.20 + Double(natural.clamped(0, 100)) * 0.20
            + Double(flirtQuality) * 0.15 + Double(humor.clamped(0, 100)) * 0.10 + Double(originality.clamped(0, 100)) * 0.10

        let scores = CandidateScores(
            specificity: specificity, replyProbability: reply.clamped(0, 100), naturalness: natural.clamped(0, 100),
            flirtQuality: flirtQuality, humor: humor.clamped(0, 100), originality: originality.clamped(0, 100),
            styleMatch: styleMatch.clamped(0, 100), specificityRating: rating, total: Int(total.rounded()))
        return ScoredCandidate(candidate: candidate, scores: scores, verdict: verdict, estimatedFlirt: flirt, rejectionReasons: reasons)
    }

    /// 1 (friendly) ... 5 (spicy). Cue words that come from the profile itself (e.g. "late night diners")
    /// don't count — echoing their words isn't escalation.
    public static func estimatedFlirt(_ text: String, ignoring profileText: String = "") -> Int {
        let profile = " " + TextFeatures.normalize(profileText) + " "
        var level = 1
        for (tier, cues) in TextFeatures.flirtTiers.enumerated() {
            let own = cues.filter { !profile.contains($0) }
            if TextFeatures.containsAny(" " + text + " ", own) { level = max(level, tier + 2) }
        }
        return level
    }

    /// 0-5. "Could this exact message be sent to 20 unrelated profiles?" -> low rating.
    public static func specificityRating(_ text: String, ctx: CritiqueContext) -> Int {
        let c = TextFeatures.contentStems(text)
        let hookStems = TextFeatures.contentStems(([ctx.targetText] + ctx.hooks).joined(separator: " "))
        let profileStems = TextFeatures.contentStems(ctx.profile.allText)
        let genericStems: Set<String> = ["photo", "profile", "pic", "picture", "smile", "cute", "date", "drink", "fun", "vibe", "view", "story", "taste", "combo", "honest", "talk", "person"]
        let targetHits = c.intersection(hookStems).subtracting(genericStems).count
        let profileHits = c.intersection(profileStems).subtracting(genericStems).count
        switch (targetHits, profileHits) {
        case (3..., _): return 5
        case (2, _): return 4
        case (1, _): return 3
        case (0, 1...): return 2
        default: return c.isEmpty ? 0 : 1
        }
    }

    public static func naturalness(_ text: String, specificity: Int) -> NaturalnessVerdict {
        let lower = " " + TextFeatures.normalize(text) + " "
        if TextFeatures.containsAny(lower, TextFeatures.creepyPhrases) { return .creepy }
        let sentences = text.split(whereSeparator: { ".!?".contains($0) }).filter { $0.trimmingCharacters(in: .whitespaces).count > 2 }
        if TextFeatures.containsAny(lower, TextFeatures.aiPhrases) || sentences.count > 3 || text.count > 220 || text.contains("—") || text.contains(";") {
            return .aiGenerated
        }
        if text.filter({ $0 == "!" }).count >= 2 && text.contains("?") { return .aiGenerated }
        if TextFeatures.containsAny(lower, TextFeatures.genericPhrases) && specificity < 4 { return .genericAdvice }
        if TextFeatures.containsAny(lower, TextFeatures.clichés) { return .genericAdvice }
        let playful = TextFeatures.containsAny(lower, TextFeatures.humorMarkers + TextFeatures.teasingMarkers) || TextFeatures.emojiCount(text) > 0
        if TextFeatures.containsAny(lower, TextFeatures.interviewOpeners) && !playful { return .boring }
        if text.trimmingCharacters(in: .whitespaces).count < 12 { return .boring }
        return .realPerson
    }

    /// Returns the offending detail if the message states facts the profile doesn't support.
    static func fabricatedFact(_ text: String, profile: DatingProfile) -> String? {
        let profileText = TextFeatures.normalize(profile.allText)
        // Proper nouns that aren't in the profile (skip sentence starts and "I").
        let tokens = text.split(whereSeparator: { $0 == " " || $0 == "\n" })
        let allowed: Set<String> = ["I", "I'm", "I'll", "I'd", "I've", "OK", "Okay", "Thursday", "Friday", "Saturday", "Sunday", "Monday", "Tuesday", "Wednesday"]
        for (i, raw) in tokens.enumerated() where i > 0 {
            let word = raw.trimmingCharacters(in: .punctuationCharacters.union(.symbols))
            guard let first = word.first, first.isUppercase, word.count >= 3, !allowed.contains(word) else { continue }
            let prev = tokens[i - 1]
            if let last = prev.last, ".!?".contains(last) { continue }
            if !profileText.contains(word.lowercased()) { return word }
        }
        // Personal facts asserted about them.
        let assumptions = ["your ex", "your husband", "your wife", "your boyfriend", "your girlfriend", "your kids", "your son", "your daughter", "your job as", "you work at", "your sister", "your brother", "your mom", "your dad"]
        for a in assumptions where TextFeatures.normalize(text).contains(a) {
            let noun = a.split(separator: " ").last.map(String.init) ?? a
            if !profileText.contains(noun) { return a }
        }
        return nil
    }
}

/// Orders accepted candidates (built-in rules blended with your personal model) and removes
/// near-duplicates so alternatives feel different.
public enum CandidateRanker {
    public static func rank(_ scored: [ScoredCandidate], preferredStyles: [CandidateStyle] = [], model: OpenerModel? = nil) -> [ScoredCandidate] {
        let accepted = scored.filter { !$0.isRejected }
        func score(_ c: ScoredCandidate) -> Double {
            let rule = adjusted(c, preferredStyles)
            return model?.blendedScore(ruleScore: rule, features: c.features) ?? rule
        }
        let ordered = accepted.sorted { a, b in
            let sa = score(a), sb = score(b)
            if sa != sb { return sa > sb }
            return a.text < b.text
        }
        var result: [ScoredCandidate] = []
        for c in ordered {
            let stems = TextFeatures.contentStems(c.text)
            if result.contains(where: { TextFeatures.jaccard(TextFeatures.contentStems($0.text), stems) > 0.6 }) { continue }
            result.append(c)
        }
        return result
    }

    static func adjusted(_ c: ScoredCandidate, _ preferred: [CandidateStyle]) -> Double {
        var s = Double(c.scores.total) + Double(c.scores.styleMatch - 50) * 0.12
        if preferred.contains(c.candidate.style) { s += 9 }
        return s
    }
}

/// Applies the user's MessageDNA surface habits (case, emoji, length) to a message.
public enum StyleApplier {
    public static func apply(_ text: String, dna: MessageDNA, style: CandidateStyle) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasSuffix("."), !t.hasSuffix("..") { t.removeLast() }

        // Emoji habits.
        if dna.emojiFrequency < 0.15 {
            t = stripEmoji(t)
        } else if dna.emojiFrequency > 0.55, TextFeatures.emojiCount(t) == 0, t.count < 110 {
            switch style {
            case .funny, .teasing: t += " 😭"
            case .flirty, .mysterious: t += " 👀"
            case .suggestive: t += " 😏"
            default: break
            }
        }

        // Case habits.
        if dna.lowercasePreference > 0.6, let first = t.first, first.isUppercase, !t.hasPrefix("I ") && !t.hasPrefix("I'") {
            t = first.lowercased() + t.dropFirst()
        } else if dna.lowercasePreference < 0.3, let first = t.first, first.isLowercase {
            t = first.uppercased() + t.dropFirst()
        }

        // Length habits: very short texters get the shorter version.
        if dna.averageLength < 45, t.count > 70 { t = LocalCommentGenerator.shorten(t) }
        return t
    }

    static func stripEmoji(_ s: String) -> String {
        String(s.unicodeScalars.filter { !($0.properties.isEmojiPresentation || ($0.properties.isEmoji && $0.value > 0x238C)) }.map(Character.init))
            .replacingOccurrences(of: "\u{FE0F}", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}
