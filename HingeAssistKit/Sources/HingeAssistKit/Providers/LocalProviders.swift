import Foundation

/// Always-available on-device provider built on the heuristic analyzer and template generator.
public struct LocalHeuristicProvider: DatingProvider {
    public init() {}
    public var id: ProviderID { .local }
    public var displayName: String { ProviderID.local.displayName }
    public var isOnDevice: Bool { true }
    public func isAvailable() async -> Bool { true }

    public func analyze(_ request: AnalysisRequest) async throws -> ProviderAnalysis {
        let local = ProfileHeuristicAnalyzer.analyze(request.profile, preferences: request.preferences, dna: request.dna)
        let compat = CompatibilityScorer.score(request.profile, preferences: request.preferences)
        let top = InteractionRanker.rank(local.targets, profile: request.profile).prefix(2)
        var candidates: [CommentCandidate] = []
        for t in top {
            let hooks = WingmanEngine.hooks(for: t.ref, photos: local.photos, prompts: local.prompts)
            candidates += LocalCommentGenerator.generate(CandidateRequest(
                profile: request.profile, target: t.ref, targetContext: t.context, hooks: hooks,
                preferences: request.preferences, dna: request.dna, flirtTarget: request.flirtTarget,
                spicyAllowed: request.spicyAllowed, tone: request.tone))
        }
        return ProviderAnalysis(tone: nil, compatibility: compat, photoAnalyses: local.photos, promptAnalyses: local.prompts, targets: local.targets, candidates: candidates)
    }

    public func generateCandidates(_ request: CandidateRequest) async throws -> [CommentCandidate] {
        LocalCommentGenerator.generate(request)
    }
}

/// Deterministic, configurable provider for tests and SwiftUI previews.
public final class MockProvider: DatingProvider, @unchecked Sendable {
    public let id: ProviderID
    public let isOnDevice: Bool
    public var displayName: String { "Mock (\(id.rawValue))" }

    private let lock = NSLock()
    private var _analysis: ProviderAnalysis?
    private var _candidates: [String]
    private var _errors: [ProviderError]
    private var _available: Bool
    private var _calls = 0
    private var _lastPhotoCount = -1
    private let delay: TimeInterval

    public init(id: ProviderID = .mock, isOnDevice: Bool = true, analysis: ProviderAnalysis? = nil, candidateTexts: [String] = [], errors: [ProviderError] = [], available: Bool = true, delay: TimeInterval = 0) {
        self.id = id
        self.isOnDevice = isOnDevice
        self._analysis = analysis
        self._candidates = candidateTexts
        self._errors = errors
        self._available = available
        self.delay = delay
    }

    public var callCount: Int { lock.withLock { _calls } }
    /// Number of photos in the most recent request (-1 before any call).
    public var lastPhotoCount: Int { lock.withLock { _lastPhotoCount } }

    public func isAvailable() async -> Bool { lock.withLock { _available } }

    private func nextError() -> ProviderError? {
        lock.withLock {
            _calls += 1
            return _errors.isEmpty ? nil : _errors.removeFirst()
        }
    }

    public func analyze(_ request: AnalysisRequest) async throws -> ProviderAnalysis {
        lock.withLock { _lastPhotoCount = request.photos.count }
        if delay > 0 { try await Task.sleep(nanoseconds: UInt64(delay * 1e9)) }
        if let e = nextError() { throw e }
        if let a = lock.withLock({ _analysis }) { return a }
        return try await LocalHeuristicProvider().analyze(request)
    }

    public func generateCandidates(_ request: CandidateRequest) async throws -> [CommentCandidate] {
        lock.withLock { _lastPhotoCount = request.photos.count }
        if let e = nextError() { throw e }
        let texts = lock.withLock { _candidates }
        if texts.isEmpty { return LocalCommentGenerator.generate(request) }
        return texts.map { CommentCandidate(text: $0, style: .funny, target: request.target, source: id) }
    }
}
