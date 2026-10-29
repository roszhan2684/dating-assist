import Foundation

public enum InteractionTargetType: String, Codable, Hashable, Sendable, CaseIterable {
    case photo
    case prompt
}

/// Points at one photo or prompt in the profile.
public struct TargetRef: Codable, Hashable, Sendable, CustomStringConvertible {
    public let type: InteractionTargetType
    public let index: Int

    public init(_ type: InteractionTargetType, _ index: Int) {
        self.type = type
        self.index = index
    }

    public var label: String { type == .photo ? "Photo #\(index)" : "Prompt #\(index)" }
    public var description: String { label }
}

public struct PhotoAnalysis: Codable, Hashable, Sendable {
    public let index: Int
    public var visibleContext: [String]
    public var conversationHooks: [String]
    public var interactionPotential: Int
    public var confidence: Double

    public init(index: Int, visibleContext: [String], conversationHooks: [String], interactionPotential: Int, confidence: Double) {
        self.index = index
        self.visibleContext = visibleContext
        self.conversationHooks = conversationHooks
        self.interactionPotential = interactionPotential.clamped(0, 100)
        self.confidence = confidence.clamped(0, 1)
    }
}

public struct PromptAnalysis: Codable, Hashable, Sendable {
    public let index: Int
    public var question: String
    public var answer: String
    public var humorPotential: Int
    public var flirtPotential: Int
    public var conversationPotential: Int
    public var uniqueness: Int
    public var hooks: [String]

    public init(index: Int, question: String, answer: String, humorPotential: Int, flirtPotential: Int, conversationPotential: Int, uniqueness: Int, hooks: [String]) {
        self.index = index
        self.question = question
        self.answer = answer
        self.humorPotential = humorPotential.clamped(0, 100)
        self.flirtPotential = flirtPotential.clamped(0, 100)
        self.conversationPotential = conversationPotential.clamped(0, 100)
        self.uniqueness = uniqueness.clamped(0, 100)
        self.hooks = hooks
    }
}

/// Raw per-target signals (0-100) before weighting. Produced by an AI provider or the local analyzer.
public struct TargetSignals: Codable, Hashable, Sendable {
    public let ref: TargetRef
    public var replyPotential: Int
    public var specificity: Int
    public var humorPotential: Int
    public var flirtPotential: Int
    public var originalityPotential: Int
    public var styleCompatibility: Int
    public var rationale: String

    public init(ref: TargetRef, replyPotential: Int, specificity: Int, humorPotential: Int, flirtPotential: Int, originalityPotential: Int, styleCompatibility: Int, rationale: String) {
        self.ref = ref
        self.replyPotential = replyPotential.clamped(0, 100)
        self.specificity = specificity.clamped(0, 100)
        self.humorPotential = humorPotential.clamped(0, 100)
        self.flirtPotential = flirtPotential.clamped(0, 100)
        self.originalityPotential = originalityPotential.clamped(0, 100)
        self.styleCompatibility = styleCompatibility.clamped(0, 100)
        self.rationale = rationale
    }
}

/// A ranked photo or prompt (Build Doc §6).
public struct InteractionTarget: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let type: InteractionTargetType
    public let profileIndex: Int
    public let context: String
    public let conversationPotential: Int
    public let personalizationPotential: Int
    public let flirtPotential: Int
    public let humorPotential: Int
    public let replyPotential: Int
    public let originalityPotential: Int
    public let styleCompatibility: Int
    public let overallInteractionScore: Int
    public let rationale: String

    public init(id: UUID = UUID(), type: InteractionTargetType, profileIndex: Int, context: String, conversationPotential: Int, personalizationPotential: Int, flirtPotential: Int, humorPotential: Int, replyPotential: Int, originalityPotential: Int, styleCompatibility: Int, overallInteractionScore: Int, rationale: String) {
        self.id = id
        self.type = type
        self.profileIndex = profileIndex
        self.context = context
        self.conversationPotential = conversationPotential
        self.personalizationPotential = personalizationPotential
        self.flirtPotential = flirtPotential
        self.humorPotential = humorPotential
        self.replyPotential = replyPotential
        self.originalityPotential = originalityPotential
        self.styleCompatibility = styleCompatibility
        self.overallInteractionScore = overallInteractionScore
        self.rationale = rationale
    }

    public var ref: TargetRef { TargetRef(type, profileIndex) }
}

public enum MatchRecommendation: String, Codable, Hashable, Sendable {
    case like
    case consider
    case skip

    public var label: String {
        switch self {
        case .like: "LIKE"
        case .consider: "MAYBE"
        case .skip: "SKIP"
        }
    }
}

public enum ProfileTone: String, Codable, Hashable, Sendable, CaseIterable {
    case reserved, wholesome, neutral, playful, teasing, bold, suggestive

    /// The flirt level that "matches" this tone before AUTO adds its small step up.
    public var baseFlirtLevel: Int {
        switch self {
        case .reserved, .wholesome: 1
        case .neutral: 2
        case .playful, .teasing: 3
        case .bold: 3
        case .suggestive: 4
        }
    }

    public var label: String {
        switch self {
        case .reserved: "reserved"
        case .wholesome: "wholesome"
        case .neutral: "easygoing"
        case .playful: "playful"
        case .teasing: "teasing"
        case .bold: "bold"
        case .suggestive: "flirty / suggestive"
        }
    }
}

public struct CompatibilityAssessment: Codable, Hashable, Sendable {
    public var score: Int
    public var confidence: Double
    public var reasons: [String]
    public var concerns: [String]
    public var dealbreakersHit: [String]

    public init(score: Int, confidence: Double, reasons: [String] = [], concerns: [String] = [], dealbreakersHit: [String] = []) {
        self.score = score.clamped(0, 100)
        self.confidence = confidence.clamped(0, 1)
        self.reasons = reasons
        self.concerns = concerns
        self.dealbreakersHit = dealbreakersHit
    }
}

public struct RecommendedInteraction: Codable, Hashable, Sendable {
    public var target: InteractionTarget
    public var why: String
    /// nil only when every candidate failed the critics (UI then offers a rewrite).
    public var comment: ScoredCandidate?
    public var alternatives: [ScoredCandidate]
    public var flirtIntensity: FlirtIntensity

    public init(target: InteractionTarget, why: String, comment: ScoredCandidate?, alternatives: [ScoredCandidate], flirtIntensity: FlirtIntensity) {
        self.target = target
        self.why = why
        self.comment = comment
        self.alternatives = alternatives
        self.flirtIntensity = flirtIntensity
    }
}

/// Which provider served a request, how long it took and whether it fell back.
public struct ProviderReport: Codable, Hashable, Sendable {
    public var providerID: ProviderID
    public var providerName: String
    public var latency: TimeInterval
    public var attempts: Int
    public var fellBackFrom: [ProviderID]

    public init(providerID: ProviderID, providerName: String, latency: TimeInterval, attempts: Int, fellBackFrom: [ProviderID]) {
        self.providerID = providerID
        self.providerName = providerName
        self.latency = latency
        self.attempts = attempts
        self.fellBackFrom = fellBackFrom
    }
}

/// Final output of one full-profile analysis (Build Doc §3).
public struct CompleteProfileAnalysis: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let createdAt: Date
    public var profile: DatingProfile
    public var overallCompatibility: Int
    public var confidence: Double
    public var recommendation: MatchRecommendation
    public var compatibility: CompatibilityAssessment
    public var tone: ProfileTone
    public var photoAnalyses: [PhotoAnalysis]
    public var promptAnalyses: [PromptAnalysis]
    public var rankedInteractionTargets: [InteractionTarget]
    public var bestInteraction: RecommendedInteraction?
    public var safetyNotes: [String]
    public var providerReport: ProviderReport?

    public init(id: UUID = UUID(), createdAt: Date = Date(), profile: DatingProfile, overallCompatibility: Int, confidence: Double, recommendation: MatchRecommendation, compatibility: CompatibilityAssessment, tone: ProfileTone, photoAnalyses: [PhotoAnalysis], promptAnalyses: [PromptAnalysis], rankedInteractionTargets: [InteractionTarget], bestInteraction: RecommendedInteraction?, safetyNotes: [String], providerReport: ProviderReport?) {
        self.id = id
        self.createdAt = createdAt
        self.profile = profile
        self.overallCompatibility = overallCompatibility
        self.confidence = confidence
        self.recommendation = recommendation
        self.compatibility = compatibility
        self.tone = tone
        self.photoAnalyses = photoAnalyses
        self.promptAnalyses = promptAnalyses
        self.rankedInteractionTargets = rankedInteractionTargets
        self.bestInteraction = bestInteraction
        self.safetyNotes = safetyNotes
        self.providerReport = providerReport
    }
}

// MARK: - Helpers

extension Comparable {
    func clamped(_ lo: Self, _ hi: Self) -> Self { Swift.min(Swift.max(self, lo), hi) }
}
