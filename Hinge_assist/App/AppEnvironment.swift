import Foundation
import HingeAssistKit

/// Builds and owns the long-lived services. Views never talk to these directly — they go through
/// `AppCoordinator` and `AnalysisViewModel` (Build Doc §22: no OCR/storage in Views).
/// Everything runs on the phone: no generative AI, no network calls.
final class AppEnvironment: @unchecked Sendable {
    let settingsStore: SettingsStore
    let inbox: CaptureInbox
    let pipeline: ScreenshotPipeline
    let router: ProviderRouter

    init(settingsStore: SettingsStore = SettingsStore(),
         inbox: CaptureInbox = CaptureInbox(),
         pipeline: ScreenshotPipeline = ScreenshotPipeline()) {
        self.settingsStore = settingsStore
        self.inbox = inbox
        self.pipeline = pipeline
        self.router = ProviderRouter() // built-in rules + templates engine only
    }

    /// The decision engine, ranked with your current personal model.
    func engine(model: OpenerModel) -> WingmanEngine {
        WingmanEngine(router: router, model: model)
    }

    /// In-memory environment for SwiftUI previews.
    static func preview() -> AppEnvironment {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("preview-\(UUID().uuidString)")
        return AppEnvironment(settingsStore: SettingsStore(directory: dir), inbox: CaptureInbox(root: dir.appendingPathComponent("inbox")))
    }
}
