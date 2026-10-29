import Foundation

/// Turns a scored opener into the numbers the personal model learns from.
public enum OpenerFeatures {
    public static let names: [String] = [
        "bias", "specific", "easy to reply", "natural", "funny", "original", "flirt fit", "flirt level", "length",
        "asks a question", "emoji", "lowercase", "lead-in", "closer",
        "style: funny", "style: flirty", "style: teasing", "style: complimentary", "style: bold",
        "style: mysterious", "style: direct", "style: suggestive",
        "on a photo", "debate-type prompt", "romance-type prompt",
    ]

    public static var count: Int { names.count }

    public static func vector(for c: ScoredCandidate, category: PromptCategory?) -> [Double] {
        let s = c.scores
        let text = c.text
        var x: [Double] = [
            1,
            Double(s.specificityRating) / 5,
            Double(s.replyProbability) / 100,
            Double(s.naturalness) / 100,
            Double(s.humor) / 100,
            Double(s.originality) / 100,
            Double(s.flirtQuality) / 100,
            Double(c.estimatedFlirt) / 5,
            min(Double(text.count), 160) / 160,
            text.contains("?") ? 1 : 0,
            TextFeatures.emojiCount(text) > 0 ? 1 : 0,
            (text.first?.isLowercase ?? false) ? 1 : 0,
            LocalCommentGenerator.hasLeadIn(text) ? 1 : 0,
            LocalCommentGenerator.hasCloser(text) ? 1 : 0,
        ]
        let styles: [CandidateStyle] = [.funny, .flirty, .teasing, .complimentary, .bold, .mysterious, .direct, .suggestive]
        x += styles.map { $0 == c.candidate.style ? 1 : 0 }
        x.append(c.candidate.target.type == .photo ? 1 : 0)
        x.append([.opinion, .challenge, .claim, .game].contains(category) ? 1 : 0)
        x.append([.lookingFor, .dateIdea].contains(category) ? 1 : 0)
        return x
    }
}

/// Your personal opener model: a small logistic-regression model that lives on the phone and
/// learns which openers *you* pick and which ones get replies. Not generative AI — it only ranks
/// openers the template engine wrote. Starts neutral and gains influence as it sees examples.
public struct OpenerModel: Codable, Hashable, Sendable {
    public var weights: [Double]
    /// Number of training signals seen (copies, skips, rewrites, replies).
    public var examples: Int
    public var replies: Int
    public var noReplies: Int

    public init() {
        weights = Array(repeating: 0, count: OpenerFeatures.count)
        examples = 0
        replies = 0
        noReplies = 0
    }

    /// Examples needed before the model gets its maximum say.
    public static let examplesForFullInfluence = 150.0
    public static let maxInfluence = 0.6

    /// How much the model's opinion counts vs the built-in rules (0 ... 0.6).
    public var influence: Double {
        min(OpenerModel.maxInfluence, Double(examples) / OpenerModel.examplesForFullInfluence * OpenerModel.maxInfluence)
    }

    /// Probability (0-1) that this opener is one you'd send and that gets a reply.
    public func probability(_ x: [Double]) -> Double {
        guard x.count == weights.count else { return 0.5 }
        let z = zip(weights, x).reduce(0) { $0 + $1.0 * $1.1 }
        return 1 / (1 + exp(-z))
    }

    /// One step of online gradient descent with L2 regularization. `weight` scales how strong the signal is.
    public mutating func train(_ x: [Double], label: Double, weight: Double = 1, learningRate: Double = 0.2, l2: Double = 0.002) {
        guard x.count == weights.count, weight > 0 else { return }
        let error = probability(x) - label
        for i in weights.indices {
            let reg = i == 0 ? 0 : l2 * weights[i]
            weights[i] -= learningRate * weight * (error * x[i] + reg)
            weights[i] = weights[i].clamped(-6, 6)
        }
        examples += 1
    }

    /// Final ranking score: built-in rules blended with the model as it earns trust.
    public func blendedScore(ruleScore: Double, features: [Double]) -> Double {
        guard !features.isEmpty else { return ruleScore }
        let model = probability(features) * 100
        return ruleScore * (1 - influence) + model * influence
    }

    /// The traits the model currently likes (+) or avoids (-), strongest first. Bias is excluded.
    public func learnedPreferences(limit: Int = 4) -> [(name: String, weight: Double)] {
        zip(OpenerFeatures.names, weights).dropFirst()
            .filter { abs($0.1) > 0.05 }
            .sorted { abs($0.1) > abs($1.1) }
            .prefix(limit)
            .map { ($0.0, $0.1) }
    }

    // Older saved models with a different feature count reset safely.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let w = try c.decodeIfPresent([Double].self, forKey: .weights) ?? []
        self.weights = w.count == OpenerFeatures.count ? w : Array(repeating: 0, count: OpenerFeatures.count)
        self.examples = w.count == OpenerFeatures.count ? (try c.decodeIfPresent(Int.self, forKey: .examples) ?? 0) : 0
        self.replies = try c.decodeIfPresent(Int.self, forKey: .replies) ?? 0
        self.noReplies = try c.decodeIfPresent(Int.self, forKey: .noReplies) ?? 0
    }
}

/// An opener you copied, kept (text only) so you can later say whether it got a reply.
public struct SentOpener: Codable, Hashable, Sendable, Identifiable {
    public enum Outcome: String, Codable, Sendable { case replied, noReply }

    public var id: UUID
    public var text: String
    public var style: CandidateStyle
    public var features: [Double]
    public var sentAt: Date
    public var outcome: Outcome?

    public init(id: UUID = UUID(), text: String, style: CandidateStyle, features: [Double], sentAt: Date = Date(), outcome: Outcome? = nil) {
        self.id = id
        self.text = text
        self.style = style
        self.features = features
        self.sentAt = sentAt
        self.outcome = outcome
    }
}
