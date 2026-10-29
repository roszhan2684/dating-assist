import HingeAssistKit
import SwiftUI

@main
struct HingeAssistApp: App {
    @State private var coordinator = AppCoordinator(env: AppEnvironment())
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(coordinator)
                .tint(Theme.signal)
                #if DEBUG
                .task { DebugLaunch.apply(to: coordinator) }
                #endif
                .onChange(of: scenePhase, initial: true) { _, phase in
                    // Screenshots shared via the Share Extension are picked up when the app comes forward.
                    if phase == .active, coordinator.settings.hasCompletedOnboarding { coordinator.checkInbox() }
                }
        }
    }
}

struct RootView: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        @Bindable var coordinator = coordinator
        Group {
            if coordinator.settings.hasCompletedOnboarding {
                HomeView()
                    .fullScreenCover(item: $coordinator.activeAnalysis, onDismiss: { coordinator.closeAnalysis() }) { vm in
                        AnalysisScreen(model: vm)
                    }
                    .sheet(isPresented: $coordinator.showSettings) { SettingsView() }
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.snappy, value: coordinator.settings.hasCompletedOnboarding)
    }
}
