import Foundation

/// How the user actually writes (Build Doc §20). All trait values are 0...1; `averageLength` is in characters.
public struct MessageDNA: Codable, Hashable, Sendable {
    public var averageLength: Double
    public var emojiFrequency: Double
    public var lowercasePreference: Double
    public var humor: Double
    public var teasing: Double
    public var flirt: Double
    public var directness: Double
    public var boldness: Double
    public var questionFrequency: Double
    public var slang: Double
    /// How many messages/choices have shaped this DNA. Higher = more trustworthy.
    public var sampleCount: Int

    public init(averageLength: Double = 70, emojiFrequency: Double = 0.3, lowercasePreference: Double = 0.5, humor: Double = 0.5, teasing: Double = 0.5, flirt: Double = 0.45, directness: Double = 0.5, boldness: Double = 0.45, questionFrequency: Double = 0.4, slang: Double = 0.4, sampleCount: Int = 0) {
        self.averageLength = averageLength
        self.emojiFrequency = emojiFrequency
        self.lowercasePreference = lowercasePreference
        self.humor = humor
        self.teasing = teasing
        self.flirt = flirt
        self.directness = directness
        self.boldness = boldness
        self.questionFrequency = questionFrequency
        self.slang = slang
        self.sampleCount = sampleCount
    }

    public static let neutral = MessageDNA()

    /// Biggest change any single trait can make from one interaction (Build Doc §21: no large jumps).
    public static let maxStep = 0.06

    // MARK: Analysis

    /// Measures the traits of a set of messages the user has actually sent.
    public static func analyze(messages: [String], seed: MessageDNA = .neutral) -> MessageDNA {
        let msgs = messages.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !msgs.isEmpty else { return seed }
        let traits = msgs.map(traitsOf)
        func mean(_ kp: KeyPath<Traits, Double>) -> Double { traits.map { $0[keyPath: kp] }.reduce(0, +) / Double(traits.count) }
        // Blend with the seed so 1-2 examples don't swing everything to extremes.
        let w = min(1.0, Double(msgs.count) / 5.0) * 0.85
        func blend(_ seedValue: Double, _ measured: Double) -> Double { seedValue * (1 - w) + measured * w }
        return MessageDNA(
            averageLength: blend(seed.averageLength, mean(\.length)),
            emojiFrequency: blend(seed.emojiFrequency, mean(\.emoji)),
            lowercasePreference: blend(seed.lowercasePreference, mean(\.lowercase)),
            humor: blend(seed.humor, mean(\.humor)),
            teasing: blend(seed.teasing, mean(\.teasing)),
            flirt: blend(seed.flirt, mean(\.flirt)),
            directness: blend(seed.directness, mean(\.directness)),
            boldness: blend(seed.boldness, mean(\.boldness)),
            questionFrequency: blend(seed.questionFrequency, mean(\.question)),
            slang: blend(seed.slang, mean(\.slang)),
            sampleCount: msgs.count
        )
    }

    struct Traits {
        var length: Double, emoji: Double, lowercase: Double, humor: Double, teasing: Double
        var flirt: Double, directness: Double, boldness: Double, question: Double, slang: Double
    }

    static let slangWords = ["lol", "lmao", "ngl", "tbh", "lowkey", "highkey", "fr", "deadass", "bro", "bruh", "omg", "idk", "rn",
                             "gonna", "wanna", "gotta", "kinda", "sorta", "ya", "u ", "ur ", "vibe", "vibes", "slay", "iconic", "bestie"]

    static func traitsOf(_ m: String) -> Traits {
        let lowerRatio = TextFeatures.lowercaseStartRatio(m)
        let emoji = min(1, Double(TextFeatures.emojiCount(m)))
        let humor = min(1, Double(TextFeatures.countAny(m, TextFeatures.humorMarkers)) * 0.45 + (m.contains("😂") || m.contains("😭") ? 0.2 : 0))
        let teasing = min(1, Double(TextFeatures.countAny(m, TextFeatures.teasingMarkers)) * 0.5)
        var flirt = 0.0
        for (tier, cues) in TextFeatures.flirtTiers.enumerated() where TextFeatures.containsAny(m, cues) {
            flirt = max(flirt, 0.35 + Double(tier) * 0.2)
        }
        let direct = TextFeatures.containsAny(m, ["let's", "lets ", "we should", "want to grab", "come with", "take you", "drinks", "this week", "free on", "i like you", "you're cute"]) ? 0.8 : 0.35
        let bold = min(1, (TextFeatures.containsAny(m, ["bet", "dare", "trust me", "obviously", "clearly", "i'll", "you're welcome", "prove", "loser"]) ? 0.45 : 0.15) + flirt * 0.4)
        let question = m.contains("?") ? 1.0 : 0.0
        let slang = min(1, Double(TextFeatures.countAny(" " + m + " ", slangWords.map { " \($0)" })) * 0.4)
        return Traits(length: Double(m.count), emoji: emoji, lowercase: lowerRatio, humor: humor, teasing: teasing, flirt: flirt, directness: direct, boldness: bold, question: question, slang: slang)
    }

    // MARK: Learning (Build Doc §21)

    /// Moves gradually toward the style of a comment the user chose to copy.
    public mutating func learn(fromChosen text: String, style: CandidateStyle, rate: Double = 0.12) {
        let t = MessageDNA.traitsOf(text)
        func step(_ current: Double, toward target: Double) -> Double {
            let delta = (target - current) * rate
            return (current + delta.clamped(-MessageDNA.maxStep, MessageDNA.maxStep)).clamped(0, 1)
        }
        averageLength += ((t.length - averageLength) * rate).clamped(-8, 8)
        emojiFrequency = step(emojiFrequency, toward: t.emoji)
        lowercasePreference = step(lowercasePreference, toward: t.lowercase)
        humor = step(humor, toward: style == .funny ? 1 : t.humor)
        teasing = step(teasing, toward: style == .teasing ? 1 : t.teasing)
        flirt = step(flirt, toward: [.flirty, .suggestive].contains(style) ? 1 : t.flirt)
        directness = step(directness, toward: style == .direct ? 1 : t.directness)
        boldness = step(boldness, toward: style == .bold ? 1 : t.boldness)
        questionFrequency = step(questionFrequency, toward: t.question)
        slang = step(slang, toward: t.slang)
        sampleCount += 1
    }

    /// Applies feedback from rewrite buttons. Repeated FLIRTIER raises default flirt; repeated TOO MUCH lowers it.
    public mutating func applyFeedback(_ direction: RewriteDirection) {
        func nudge(_ v: inout Double, _ d: Double) { v = (v + d.clamped(-MessageDNA.maxStep, MessageDNA.maxStep)).clamped(0, 1) }
        switch direction {
        case .funnier: nudge(&humor, 0.04)
        case .flirtier: nudge(&flirt, 0.04)
        case .bolder: nudge(&boldness, 0.04); nudge(&directness, 0.02)
        case .moreTeasing: nudge(&teasing, 0.04)
        case .moreComplimenting: nudge(&flirt, 0.02)
        case .moreMysterious: nudge(&directness, -0.03)
        case .moreDirect: nudge(&directness, 0.04)
        case .moreSuggestive: nudge(&flirt, 0.05)
        case .shorter: averageLength = max(25, averageLength - 5)
        case .tooSafe: nudge(&boldness, 0.05); nudge(&flirt, 0.03)
        case .tooMuch: nudge(&flirt, -0.06); nudge(&boldness, -0.05)
        }
    }

    // MARK: Derived

    /// Small AUTO-flirt adjustment from the user's own habits: -1, 0 or +1.
    public var flirtBias: Int {
        if flirt > 0.68 { return 1 }
        if flirt < 0.25 { return -1 }
        return 0
    }

    /// Which candidate styles fit this user, as weights 0...1.
    public func affinity(for style: CandidateStyle) -> Double {
        switch style {
        case .funny: humor
        case .teasing: teasing
        case .flirty: flirt
        case .complimentary: (flirt + (1 - teasing)) / 2
        case .bold: boldness
        case .direct: directness
        case .mysterious: 1 - directness
        case .suggestive: (flirt + boldness) / 2
        }
    }

    public var summary: [(String, Double)] {
        [("Humor", humor), ("Teasing", teasing), ("Flirt", flirt), ("Directness", directness), ("Boldness", boldness),
         ("Emoji", emojiFrequency), ("lowercase", lowercasePreference), ("Questions", questionFrequency)]
    }

    /// One-line description used in AI prompts.
    public var promptDescription: String {
        func lvl(_ v: Double) -> String { v > 0.66 ? "high" : v > 0.33 ? "medium" : "low" }
        return "typical length ~\(Int(averageLength)) chars; emoji use \(lvl(emojiFrequency)); lowercase style \(lvl(lowercasePreference)); humor \(lvl(humor)); teasing \(lvl(teasing)); flirt \(lvl(flirt)); directness \(lvl(directness)); boldness \(lvl(boldness)); slang \(lvl(slang))"
    }
}
