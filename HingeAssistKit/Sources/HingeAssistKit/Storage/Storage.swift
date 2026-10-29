import Foundation

// MARK: - Settings

public struct FeedbackStats: Codable, Hashable, Sendable {
    public var counts: [String: Int] = [:]
    public var copies = 0
    public init() {}
}

/// Everything the app persists locally. Text and numbers only: no screenshots, no photos.
public struct AppSettings: Codable, Hashable, Sendable {
    public var hasCompletedOnboarding = false
    public var preferences = UserPreferences()
    public var dna = MessageDNA.neutral
    public var toneExamples: [String] = []
    public var feedback = FeedbackStats()
    /// Your personal on-device opener model.
    public var openerModel = OpenerModel()
    /// Openers you copied, waiting for a "did they reply?" answer. Capped at 100.
    public var sentOpeners: [SentOpener] = []

    public init() {}

    enum CodingKeys: String, CodingKey {
        case hasCompletedOnboarding, preferences, dna, toneExamples, feedback, openerModel, sentOpeners
    }

    /// Tolerant decoding so new fields never wipe saved settings.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? d.hasCompletedOnboarding
        preferences = (try? c.decodeIfPresent(UserPreferences.self, forKey: .preferences)) ?? d.preferences
        dna = (try? c.decodeIfPresent(MessageDNA.self, forKey: .dna)) ?? d.dna
        toneExamples = (try? c.decodeIfPresent([String].self, forKey: .toneExamples)) ?? d.toneExamples
        feedback = (try? c.decodeIfPresent(FeedbackStats.self, forKey: .feedback)) ?? d.feedback
        openerModel = (try? c.decodeIfPresent(OpenerModel.self, forKey: .openerModel)) ?? d.openerModel
        sentOpeners = (try? c.decodeIfPresent([SentOpener].self, forKey: .sentOpeners)) ?? d.sentOpeners
    }

    /// Openers still waiting for a reply answer (newest first, last 21 days).
    public func pendingReplies(now: Date = Date()) -> [SentOpener] {
        sentOpeners.filter { $0.outcome == nil && now.timeIntervalSince($0.sentAt) < 21 * 86400 }.sorted { $0.sentAt > $1.sentAt }
    }
}

/// JSON file store for `AppSettings` in Application Support (excluded from nothing; it's text only).
public final class SettingsStore: @unchecked Sendable {
    private let url: URL
    private let lock = NSLock()

    public init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("HingeAssist", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.url = dir.appendingPathComponent("settings.json")
    }

    public func load() -> AppSettings {
        lock.withLock {
            guard let data = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(AppSettings.self, from: data) else { return AppSettings() }
            return s
        }
    }

    public func save(_ settings: AppSettings) {
        lock.withLock {
            guard let data = try? JSONEncoder().encode(settings) else { return }
            // Full data protection on iOS; macOS (tests, tools) may not support it, so fall back.
            if (try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])) == nil {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    public func reset() {
        lock.withLock { try? FileManager.default.removeItem(at: url) }
    }
}

// MARK: - Temporary screenshot inbox

/// Temporary hand-off of screenshots between the Share Extension and the app (Build Doc §23).
/// Screenshots live here only until analyzed, then are deleted. Stale sessions are purged.
public struct CaptureInbox: Sendable {
    public static let appGroup = "group.com.roszhanraj.HingeAssist"

    public struct Session: Codable, Hashable, Sendable, Identifiable {
        public var id: String
        public var createdAt: Date
        public var imageCount: Int
    }

    public let root: URL

    /// Uses the App Group container when available, otherwise the app's temporary directory.
    public init(appGroup: String? = CaptureInbox.appGroup, fallback: URL? = nil) {
        let container = appGroup.flatMap { FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0) }
        let base = container ?? fallback ?? FileManager.default.temporaryDirectory
        root = base.appendingPathComponent("CaptureInbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    public init(root: URL) {
        self.root = root
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    /// Saves one capture session (all screenshots of one profile). Returns its id.
    @discardableResult
    public func save(_ images: [Data]) throws -> Session {
        let id = UUID().uuidString
        let dir = root.appendingPathComponent(id, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (i, data) in images.enumerated() {
            let file = dir.appendingPathComponent(String(format: "%03d.img", i))
            if (try? data.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])) == nil {
                try data.write(to: file, options: .atomic)
            }
        }
        let session = Session(id: id, createdAt: Date(), imageCount: images.count)
        try JSONEncoder().encode(session).write(to: dir.appendingPathComponent("session.json"), options: .atomic)
        return session
    }

    public func pendingSessions() -> [Session] {
        let dirs = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        return dirs.compactMap { dir in
            guard let data = try? Data(contentsOf: dir.appendingPathComponent("session.json")) else { return nil }
            return try? JSONDecoder().decode(Session.self, from: data)
        }.sorted { $0.createdAt < $1.createdAt }
    }

    public func images(for session: Session) -> [Data] {
        let dir = root.appendingPathComponent(session.id, isDirectory: true)
        let files = ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "img" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return files.compactMap { try? Data(contentsOf: $0) }
    }

    public func delete(_ session: Session) {
        try? FileManager.default.removeItem(at: root.appendingPathComponent(session.id, isDirectory: true))
    }

    /// Deletes sessions older than `age` (default 1 hour) — screenshots are never kept long-term.
    @discardableResult
    public func purge(olderThan age: TimeInterval = 3600, now: Date = Date()) -> Int {
        let dirs = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.creationDateKey])) ?? []
        var removed = 0
        for dir in dirs {
            let created = (try? dir.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let session = (try? Data(contentsOf: dir.appendingPathComponent("session.json"))).flatMap { try? JSONDecoder().decode(Session.self, from: $0) }
            if now.timeIntervalSince(session?.createdAt ?? created) > age {
                try? FileManager.default.removeItem(at: dir)
                removed += 1
            }
        }
        return removed
    }

    public func deleteAll() {
        for s in pendingSessions() { delete(s) }
        let dirs = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        dirs.forEach { try? FileManager.default.removeItem(at: $0) }
    }
}
