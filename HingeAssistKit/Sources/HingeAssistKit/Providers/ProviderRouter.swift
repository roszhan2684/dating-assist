import Foundation

public struct LatencySample: Codable, Hashable, Sendable {
    public var provider: ProviderID
    public var operation: String
    public var seconds: TimeInterval
    public var succeeded: Bool
    public var date: Date
}

public struct Routed<T: Sendable>: Sendable {
    public var value: T
    public var report: ProviderReport
}

/// Single entry point for analysis/candidate calls: on-device enforcement, availability,
/// fallback to the built-in engine, and latency metrics live here.
public actor ProviderRouter {
    public struct Configuration: Sendable {
        /// Order to try. The built-in engine is always appended as the final fallback.
        public var order: [ProviderID]

        public init(order: [ProviderID] = [.local]) {
            self.order = order
        }
    }

    private let providers: [ProviderID: any DatingProvider]
    public private(set) var configuration: Configuration
    public private(set) var samples: [LatencySample] = []

    /// Providers that aren't on-device are dropped here, so nothing can ever leave the phone.
    public init(providers: [any DatingProvider] = [], configuration: Configuration = Configuration()) {
        var map: [ProviderID: any DatingProvider] = [:]
        for p in providers where p.isOnDevice { map[p.id] = p }
        if map[.local] == nil { map[.local] = LocalHeuristicProvider() }
        self.providers = map
        self.configuration = configuration
    }

    public func update(_ configuration: Configuration) {
        self.configuration = configuration
    }

    public func eligibleProviders() async -> [any DatingProvider] {
        var order = configuration.order
        if !order.contains(.local) { order.append(.local) }
        var result: [any DatingProvider] = []
        for id in order {
            guard let p = providers[id], p.isOnDevice else { continue }
            if await p.isAvailable() { result.append(p) }
        }
        return result
    }

    public func analyze(_ request: AnalysisRequest) async throws -> Routed<ProviderAnalysis> {
        try await route(operation: "analyze") { try await $0.analyze(request) }
    }

    public func generateCandidates(_ request: CandidateRequest) async throws -> Routed<[CommentCandidate]> {
        try await route(operation: "candidates") { try await $0.generateCandidates(request) }
    }

    private func route<T: Sendable>(operation: String, _ call: @escaping @Sendable (any DatingProvider) async throws -> T) async throws -> Routed<T> {
        var failed: [ProviderID] = []
        var lastError: Error = ProviderError.unavailable("no engine available")
        for provider in await eligibleProviders() {
            let start = Date()
            do {
                try Task.checkCancellation()
                let value = try await call(provider)
                let elapsed = Date().timeIntervalSince(start)
                record(provider.id, operation, elapsed, true)
                return Routed(value: value, report: ProviderReport(providerID: provider.id, providerName: provider.displayName, latency: elapsed, attempts: 1, fellBackFrom: failed))
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                record(provider.id, operation, Date().timeIntervalSince(start), false)
                lastError = error
                failed.append(provider.id)
            }
        }
        throw lastError
    }

    private func record(_ id: ProviderID, _ op: String, _ seconds: TimeInterval, _ ok: Bool) {
        samples.append(LatencySample(provider: id, operation: op, seconds: seconds, succeeded: ok, date: Date()))
        if samples.count > 200 { samples.removeFirst(samples.count - 200) }
    }

    public func averageLatency() -> [ProviderID: TimeInterval] {
        var sums: [ProviderID: (Double, Int)] = [:]
        for s in samples where s.succeeded {
            let cur = sums[s.provider] ?? (0, 0)
            sums[s.provider] = (cur.0 + s.seconds, cur.1 + 1)
        }
        return sums.mapValues { $0.0 / Double($0.1) }
    }
}
