import Foundation

public enum CandidateStyle: String, Codable, Hashable, Sendable, CaseIterable {
    case funny, flirty, teasing, complimentary, bold, mysterious, direct, suggestive

    /// Build Doc §15 candidate mix (12 total).
    public static let standardMix: [(CandidateStyle, Int)] = [
        (.funny, 3), (.flirty, 3), (.teasing, 2), (.complimentary, 2), (.bold, 2),
    ]

    /// Rough flirt level a message of this style carries.
    public var typicalFlirt: Int {
        switch self {
        case .funny, .teasing, .direct: 2
        case .complimentary, .mysterious: 3
        case .flirty, .bold: 3
        case .suggestive: 5
        }
    }
}

public struct CommentCandidate: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public var text: String
    public var style: CandidateStyle
    public var target: TargetRef
    public var source: ProviderID

    public init(id: UUID = UUID(), text: String, style: CandidateStyle, target: TargetRef, source: ProviderID) {
        self.id = id
        self.text = text
        self.style = style
        self.target = target
        self.source = source
    }
}

/// Build Doc §16: how the message reads to a stranger.
public enum NaturalnessVerdict: String, Codable, Hashable, Sendable {
    case realPerson = "A"
    case genericAdvice = "B"
    case aiGenerated = "C"
    case creepy = "D"
    case boring = "E"

    public var passes: Bool { self == .realPerson }

    public var label: String {
        switch self {
        case .realPerson: "a real confident person"
        case .genericAdvice: "generic dating advice"
        case .aiGenerated: "AI-generated writing"
        case .creepy: "creepy"
        case .boring: "boring"
        }
    }
}

/// Per-candidate scores, each 0-100 except `specificityRating` (0-5, Build Doc §29).
public struct CandidateScores: Codable, Hashable, Sendable {
    public var specificity: Int
    public var replyProbability: Int
    public var naturalness: Int
    public var flirtQuality: Int
    public var humor: Int
    public var originality: Int
    public var styleMatch: Int
    public var specificityRating: Int
    public var total: Int

    public init(specificity: Int, replyProbability: Int, naturalness: Int, flirtQuality: Int, humor: Int, originality: Int, styleMatch: Int, specificityRating: Int, total: Int) {
        self.specificity = specificity
        self.replyProbability = replyProbability
        self.naturalness = naturalness
        self.flirtQuality = flirtQuality
        self.humor = humor
        self.originality = originality
        self.styleMatch = styleMatch
        self.specificityRating = specificityRating
        self.total = total
    }
}

public struct ScoredCandidate: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID { candidate.id }
    public var candidate: CommentCandidate
    public var scores: CandidateScores
    public var verdict: NaturalnessVerdict
    public var estimatedFlirt: Int
    public var rejectionReasons: [String]
    /// Inputs for the personal opener model (see `OpenerFeatures`).
    public var features: [Double]

    public init(candidate: CommentCandidate, scores: CandidateScores, verdict: NaturalnessVerdict, estimatedFlirt: Int, rejectionReasons: [String], features: [Double] = []) {
        self.candidate = candidate
        self.scores = scores
        self.verdict = verdict
        self.estimatedFlirt = estimatedFlirt
        self.rejectionReasons = rejectionReasons
        self.features = features
    }

    public var isRejected: Bool { !rejectionReasons.isEmpty }
    public var text: String { candidate.text }
}

/// Build Doc §18-19 rapid rewrite controls, plus the TOO SAFE / TOO MUCH feedback buttons.
public enum RewriteDirection: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    case funnier, flirtier, bolder, moreTeasing, moreComplimenting, moreMysterious, moreDirect, moreSuggestive, shorter, tooSafe, tooMuch

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .funnier: "Funnier"
        case .flirtier: "Flirtier"
        case .bolder: "Bolder"
        case .moreTeasing: "More teasing"
        case .moreComplimenting: "More complimenting"
        case .moreMysterious: "More mysterious"
        case .moreDirect: "More direct"
        case .moreSuggestive: "More suggestive"
        case .shorter: "Shorter"
        case .tooSafe: "Too safe"
        case .tooMuch: "Too much"
        }
    }

    /// Instruction sent to AI providers.
    public var instruction: String {
        switch self {
        case .funnier: "Make it funnier: sharper joke, playful exaggeration, still specific."
        case .flirtier: "Make it flirtier: add attraction or playful tension, keep it charming."
        case .bolder: "Make it bolder: more confident, a little daring, maybe a light date-forward move."
        case .moreTeasing: "Tease more: playful challenge or mock disagreement about the profile detail."
        case .moreComplimenting: "Add a specific compliment tied to the profile detail, not generic looks praise."
        case .moreMysterious: "Make it more mysterious: hint, leave a hook, don't over-explain."
        case .moreDirect: "Be more direct: clear interest, simple invitation to talk or meet."
        case .moreSuggestive: "Make it more suggestive: innuendo or playful tension, never graphic, never pushy."
        case .shorter: "Make it shorter: under ~60 characters, keep the hook."
        case .tooSafe: "The last one was too safe. Raise the energy: bolder, more playful, more personality."
        case .tooMuch: "The last one was too much. Dial it back: lighter, friendlier, less forward."
        }
    }

    /// Style the rewrite should lean toward.
    public var preferredStyles: [CandidateStyle] {
        switch self {
        case .funnier: [.funny, .teasing]
        case .flirtier: [.flirty, .complimentary]
        case .bolder: [.bold, .direct]
        case .moreTeasing: [.teasing]
        case .moreComplimenting: [.complimentary]
        case .moreMysterious: [.mysterious]
        case .moreDirect: [.direct, .bold]
        case .moreSuggestive: [.suggestive, .flirty]
        case .shorter: CandidateStyle.allCases
        case .tooSafe: [.bold, .flirty, .teasing]
        case .tooMuch: [.funny, .complimentary]
        }
    }

    /// Change to the flirt target for the rewrite.
    public var flirtDelta: Int {
        switch self {
        case .flirtier, .bolder, .tooSafe: 1
        case .moreSuggestive: 2
        case .tooMuch: -1
        default: 0
        }
    }
}
