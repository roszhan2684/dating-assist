import Foundation

public enum ProviderID: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    /// The built-in rules + templates engine, ranked by your personal on-device model.
    case local
    /// Test double.
    case mock

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .local: "On-device engine"
        case .mock: "Mock"
        }
    }
}

/// A downscaled JPEG photo crop kept in memory for the current analysis only.
public struct ProviderImage: Codable, Hashable, Sendable {
    public let photoIndex: Int
    public let jpegData: Data

    public init(photoIndex: Int, jpegData: Data) {
        self.photoIndex = photoIndex
        self.jpegData = jpegData
    }
}

public struct AnalysisRequest: Sendable {
    public var profile: DatingProfile
    public var photos: [ProviderImage]
    public var preferences: UserPreferences
    public var dna: MessageDNA
    public var flirtTarget: FlirtIntensity
    public var spicyAllowed: Bool
    public var tone: ProfileTone

    public init(profile: DatingProfile, photos: [ProviderImage], preferences: UserPreferences, dna: MessageDNA, flirtTarget: FlirtIntensity, spicyAllowed: Bool, tone: ProfileTone) {
        self.profile = profile
        self.photos = photos
        self.preferences = preferences
        self.dna = dna
        self.flirtTarget = flirtTarget
        self.spicyAllowed = spicyAllowed
        self.tone = tone
    }
}

public struct CandidateRequest: Sendable {
    public var profile: DatingProfile
    public var target: TargetRef
    public var targetContext: String
    public var hooks: [String]
    public var photos: [ProviderImage]
    public var preferences: UserPreferences
    public var dna: MessageDNA
    public var flirtTarget: FlirtIntensity
    public var spicyAllowed: Bool
    public var tone: ProfileTone
    /// Set for rewrites.
    public var direction: RewriteDirection?
    public var baseMessage: String?
    /// Messages to avoid repeating (already shown or rejected).
    public var avoid: [String]
    /// Why the last batch was rejected, fed back for regeneration.
    public var critique: [String]
    public var count: Int

    public init(profile: DatingProfile, target: TargetRef, targetContext: String, hooks: [String], photos: [ProviderImage] = [], preferences: UserPreferences, dna: MessageDNA, flirtTarget: FlirtIntensity, spicyAllowed: Bool, tone: ProfileTone, direction: RewriteDirection? = nil, baseMessage: String? = nil, avoid: [String] = [], critique: [String] = [], count: Int = 12) {
        self.profile = profile
        self.target = target
        self.targetContext = targetContext
        self.hooks = hooks
        self.photos = photos
        self.preferences = preferences
        self.dna = dna
        self.flirtTarget = flirtTarget
        self.spicyAllowed = spicyAllowed
        self.tone = tone
        self.direction = direction
        self.baseMessage = baseMessage
        self.avoid = avoid
        self.critique = critique
        self.count = count
    }
}

/// What a provider returns. The engine validates, clamps and re-ranks everything here;
/// providers never decide the final answer on their own.
public struct ProviderAnalysis: Codable, Hashable, Sendable {
    public var tone: ProfileTone?
    public var compatibility: CompatibilityAssessment?
    public var photoAnalyses: [PhotoAnalysis]
    public var promptAnalyses: [PromptAnalysis]
    public var targets: [TargetSignals]
    public var candidates: [CommentCandidate]

    public init(tone: ProfileTone? = nil, compatibility: CompatibilityAssessment? = nil, photoAnalyses: [PhotoAnalysis] = [], promptAnalyses: [PromptAnalysis] = [], targets: [TargetSignals] = [], candidates: [CommentCandidate] = []) {
        self.tone = tone
        self.compatibility = compatibility
        self.photoAnalyses = photoAnalyses
        self.promptAnalyses = promptAnalyses
        self.targets = targets
        self.candidates = candidates
    }
}

public enum ProviderError: Error, Equatable, Sendable, LocalizedError {
    case unavailable(String)
    case invalidResponse(String)
    /// Only on-device providers are allowed; anything else is rejected.
    case notOnDevice

    public var isRetryable: Bool { false }

    public var errorDescription: String? {
        switch self {
        case .unavailable(let why): "Engine unavailable: \(why)"
        case .invalidResponse(let why): "Engine error: \(why)"
        case .notOnDevice: "Only on-device engines are allowed."
        }
    }
}

/// A source of profile analysis and candidate openers. Dating Assist ships with one: the on-device
/// rules + templates engine. No generative AI and no network calls. All calls go through `ProviderRouter`.
public protocol DatingProvider: Sendable {
    var id: ProviderID { get }
    var displayName: String { get }
    /// Must be true: the router refuses anything that could send data off the phone.
    var isOnDevice: Bool { get }
    func isAvailable() async -> Bool
    func analyze(_ request: AnalysisRequest) async throws -> ProviderAnalysis
    func generateCandidates(_ request: CandidateRequest) async throws -> [CommentCandidate]
}
