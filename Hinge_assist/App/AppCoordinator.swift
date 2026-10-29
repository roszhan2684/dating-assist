import Foundation
import HingeAssistKit
import Observation
import SwiftUI

/// App-wide state and navigation: settings, onboarding, the active analysis and shared-screenshot pickup.
@MainActor
@Observable
final class AppCoordinator {
    let env: AppEnvironment

    private(set) var settings: AppSettings
    /// The analysis currently on screen (sheet/full-screen).
    var activeAnalysis: AnalysisViewModel?
    var showSettings = false
    var pendingSessions: [CaptureInbox.Session] = []

    init(env: AppEnvironment) {
        self.env = env
        self.settings = env.settingsStore.load()
    }

    var engine: WingmanEngine { env.engine(model: settings.openerModel) }

    // MARK: Settings

    func update(_ change: (inout AppSettings) -> Void) {
        var s = settings
        change(&s)
        guard s != settings else { return }
        settings = s
        env.settingsStore.save(s)
    }

    func completeOnboarding() {
        update { $0.hasCompletedOnboarding = true }
    }

    func resetLearning() {
        update { s in
            s.dna = s.toneExamples.isEmpty ? s.preferences.stylePreset.seedDNA : MessageDNA.analyze(messages: s.toneExamples, seed: s.preferences.stylePreset.seedDNA)
            s.feedback = FeedbackStats()
        }
    }

    func resetEverything() {
        env.inbox.deleteAll()
        env.settingsStore.reset()
        settings = AppSettings()
    }

    func resetModel() {
        update { s in
            s.openerModel = OpenerModel()
            s.sentOpeners = []
        }
    }

    // MARK: Learning (Build Doc §21 + personal model)

    /// You copied an opener: a strong "I like this" for the model, a weak "not this" for the ones you
    /// passed over, and it goes on the "did they reply?" list.
    func recordCopy(_ candidate: ScoredCandidate, passedOver: [ScoredCandidate]) {
        update { s in
            s.dna.learn(fromChosen: candidate.text, style: candidate.candidate.style)
            s.feedback.copies += 1
            s.openerModel.train(candidate.features, label: 1)
            for other in passedOver.prefix(4) where other.id != candidate.id {
                s.openerModel.train(other.features, label: 0, weight: 0.25)
            }
            if !s.sentOpeners.contains(where: { $0.text == candidate.text }) {
                s.sentOpeners.append(SentOpener(text: candidate.text, style: candidate.candidate.style, features: candidate.features))
                if s.sentOpeners.count > 100 { s.sentOpeners.removeFirst(s.sentOpeners.count - 100) }
            }
        }
    }

    /// Rewrite buttons mean "not quite this one".
    func recordFeedback(_ direction: RewriteDirection, on current: ScoredCandidate?) {
        update { s in
            s.dna.applyFeedback(direction)
            s.feedback.counts[direction.rawValue, default: 0] += 1
            if let current {
                let strength = (direction == .tooMuch || direction == .tooSafe) ? 0.5 : 0.2
                s.openerModel.train(current.features, label: 0, weight: strength)
            }
        }
    }

    /// The strongest signal: did the opener actually get a reply?
    func recordReply(_ sent: SentOpener, replied: Bool) {
        update { s in
            guard let i = s.sentOpeners.firstIndex(where: { $0.id == sent.id }), s.sentOpeners[i].outcome == nil else { return }
            s.sentOpeners[i].outcome = replied ? .replied : .noReply
            s.openerModel.train(sent.features, label: replied ? 1 : 0, weight: 2)
            if replied { s.openerModel.replies += 1 } else { s.openerModel.noReplies += 1 }
        }
    }

    /// "Didn't send it" — remove from the list without teaching the model anything.
    func dismissSent(_ sent: SentOpener) {
        update { s in s.sentOpeners.removeAll { $0.id == sent.id } }
    }

    // MARK: Analysis

    func startAnalysis(imageData: [Data], source: AnalysisViewModel.Source) {
        let vm = AnalysisViewModel(coordinator: self, source: source)
        activeAnalysis = vm
        vm.start(imageData: imageData)
    }

    func startSample() {
        let pngs = FixtureRenderer.renderPNGs(SyntheticProfiles.maya)
        startAnalysis(imageData: pngs, source: .sample)
    }

    /// Picks up screenshots shared from the Share Extension. Images are read into memory and the
    /// temporary files deleted immediately (Build Doc §23).
    func checkInbox() {
        env.inbox.purge(olderThan: 3600)
        pendingSessions = env.inbox.pendingSessions()
        guard activeAnalysis == nil, let newest = pendingSessions.last else { return }
        open(newest)
    }

    func open(_ session: CaptureInbox.Session) {
        let images = env.inbox.images(for: session)
        env.inbox.delete(session)
        pendingSessions = env.inbox.pendingSessions()
        guard !images.isEmpty else { return }
        startAnalysis(imageData: images, source: .shareExtension)
    }

    func closeAnalysis() {
        activeAnalysis?.cancel()
        activeAnalysis = nil
    }
}
