import HingeAssistKit
import SwiftUI

/// Welcome -> 18+ -> five preferences -> your voice -> flirt level.
struct OnboardingView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var step = 0
    @State private var preferences = UserPreferences(interests: ["food", "travel"])
    @State private var preset: StylePreset = .playfulBanter
    @State private var examples: [String] = []
    @State private var isAdult = false

    private let steps = 5

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(step + 1), total: Double(steps))
                .tint(Theme.signal)
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 12)
                .accessibilityLabel("Step \(step + 1) of \(steps)")
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch step {
                    case 0: welcome
                    case 1: ageGate
                    case 2:
                        title("What are you looking for?", "Used to score compatibility. Stays on this phone.")
                        PreferencesForm(preferences: $preferences)
                    case 3:
                        title("How do you text?", "Openers should sound like you, not like an AI.")
                        MessageStyleForm(preset: $preset, examples: $examples, dna: MessageDNA.analyze(messages: examples, seed: preset.seedDNA))
                    default:
                        title("How flirty?", "You can change this any time, and nudge each suggestion with Flirtier / Too much.")
                        FlirtSettingsForm(preferences: $preferences)
                    }
                }
                .padding(Theme.gutter)
                .padding(.bottom, 24)
                .id(step)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            }
            .scrollDismissesKeyboard(.interactively)
            controls
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private func title(_ t: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t).font(.display(30))
            Text(sub).font(.subheadline).foregroundStyle(Theme.textSecondary)
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 22) {
            Image("BrandMark")
                .resizable()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .softShadow()
                .padding(.top, 24)
                .accessibilityHidden(true)
            Text("Your dating wingman.")
                .font(.display(38))
            Text("Share screenshots of a whole profile. Dating Assist reads every photo and prompt, tells you if it's a match, picks the single best thing to like, and suggests the line to send — in your voice.")
                .font(.body).foregroundStyle(Theme.textSecondary)
            Card {
                Label("No AI chatbots — everything runs on your phone", systemImage: "iphone")
                Label("Reads only the screenshots you share", systemImage: "hand.raised.fill")
                Label("Never logs in, swipes, likes or messages for you", systemImage: "nosign")
                Label("Screenshots deleted right after analysis", systemImage: "trash")
                Label("You copy, like and send yourself", systemImage: "person.fill.checkmark")
            }
            .font(.subheadline)
        }
    }

    private var ageGate: some View {
        VStack(alignment: .leading, spacing: 20) {
            title("Quick check", "Dating Assist is for adults using dating apps.")
            Toggle(isOn: $isAdult) {
                Text("I'm 18 or older").font(.headline)
            }
            .padding(16)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.corner))
            Text("Dating Assist never writes flirty messages for anyone who may be under 18.")
                .font(.footnote).foregroundStyle(Theme.textSecondary)
        }
    }

    private var canContinue: Bool { step != 1 || isAdult }

    private var controls: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button("Back") { withAnimation(.snappy) { step -= 1 } }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(width: 110)
            }
            Button(step == steps - 1 ? "Start" : "Continue") {
                if step == steps - 1 { finish() } else { withAnimation(.snappy) { step += 1 } }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0.5)
        }
        .padding(Theme.gutter)
        .background(.bar)
    }

    private func finish() {
        var prefs = preferences
        prefs.isAdultConfirmed = isAdult
        if !isAdult { prefs.spicySuggestions = false }
        prefs.stylePreset = preset
        let dna = MessageDNA.analyze(messages: examples, seed: preset.seedDNA)
        coordinator.update { s in
            s.preferences = prefs
            s.toneExamples = examples
            s.dna = dna
        }
        coordinator.completeOnboarding()
    }
}
