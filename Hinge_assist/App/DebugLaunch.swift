#if DEBUG
import Foundation
import HingeAssistKit

/// Debug-only launch arguments for simulator QA and screenshots:
///   -skipOnboarding   finish onboarding with sample preferences
///   -runSample        immediately analyze the synthetic sample profile
///   -darkSample       use dark-mode sample screenshots
///   -demoReplies      add example copied openers so the "Did they reply?" card shows
///   -openSettings     open Settings on launch
@MainActor
enum DebugLaunch {
    static func apply(to coordinator: AppCoordinator) {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-skipOnboarding") || args.contains("-runSample"), !coordinator.settings.hasCompletedOnboarding {
            coordinator.update { s in
                s.preferences = UserPreferences(goal: .longTerm, ageMin: 24, ageMax: 34, interests: ["gaming", "hiking", "food"],
                                                dealbreakers: ["smoking"], greenFlags: ["funny"], isAdultConfirmed: true)
                s.dna = StylePreset.playfulBanter.seedDNA
            }
            coordinator.completeOnboarding()
        }
        if args.contains("-demoReplies"), coordinator.settings.sentOpeners.isEmpty {
            Task {
                guard let a = try? await coordinator.engine.analyze(profile: SyntheticProfiles.maya, photos: [], preferences: coordinator.settings.preferences, dna: coordinator.settings.dna),
                      let best = a.bestInteraction, let pick = best.comment else { return }
                coordinator.recordCopy(pick, passedOver: best.alternatives)
                if let second = best.alternatives.first { coordinator.recordCopy(second, passedOver: []) }
            }
        }
        if args.contains("-openSettings") { coordinator.showSettings = true }
        if args.contains("-runSample"), coordinator.activeAnalysis == nil {
            var options = FixtureRenderer.Options()
            options.darkMode = args.contains("-darkSample")
            coordinator.startAnalysis(imageData: FixtureRenderer.renderPNGs(SyntheticProfiles.maya, options: options), source: .sample)
        }
    }
}
#endif
