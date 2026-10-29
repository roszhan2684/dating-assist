import HingeAssistKit
import SwiftUI

enum PreferenceSuggestions {
    static let interests = ["hiking", "travel", "food", "coffee", "music", "fitness", "reading", "gaming", "movies", "art", "dogs", "cats", "beach", "comedy"]
    static let dealbreakers = ["smoking", "drugs", "kids", "no kids", "long distance", "hookups", "heavy drinking"]
    static let greenFlags = ["funny", "kind", "ambitious", "curious", "adventurous", "creative", "family", "travel"]
}

/// The five onboarding preferences: what you're looking for, age range, interests, dealbreakers, green flags.
struct PreferencesForm: View {
    @Binding var preferences: UserPreferences

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            section("1 · Looking for") {
                Picker("Looking for", selection: $preferences.goal) {
                    ForEach(RelationshipGoal.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            section("2 · Age range") {
                Stepper("From \(preferences.ageMin)", value: $preferences.ageMin, in: 18...preferences.ageMax)
                Stepper("To \(preferences.ageMax)", value: $preferences.ageMax, in: preferences.ageMin...99)
            }
            section("3 · Interests") {
                TagEditor(tags: $preferences.interests, suggestions: PreferenceSuggestions.interests)
            }
            section("4 · Dealbreakers") {
                TagEditor(tags: $preferences.dealbreakers, suggestions: PreferenceSuggestions.dealbreakers, placeholder: "e.g. smoking")
            }
            section("5 · Green flags") {
                TagEditor(tags: $preferences.greenFlags, suggestions: PreferenceSuggestions.greenFlags, placeholder: "e.g. kind")
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(title)
            content()
        }
    }
}

/// Flirt level: AUTO or 1-5, plus the adult-only Spicy Suggestions switch.
struct FlirtSettingsForm: View {
    @Binding var preferences: UserPreferences
    @State private var confirmSpicy = false

    private var isAuto: Bool { if case .auto = preferences.flirtSetting { true } else { false } }
    private var fixedLevel: Double {
        if case .fixed(let l) = preferences.flirtSetting { Double(l.rawValue) } else { 3 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: Binding(get: { isAuto }, set: { preferences.flirtSetting = $0 ? .auto : .fixed(.flirty) })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto").font(.headline)
                    Text("Match each profile's energy, then go one step bolder.").font(.footnote).foregroundStyle(Theme.textSecondary)
                }
            }
            if !isAuto {
                VStack(alignment: .leading, spacing: 6) {
                    Slider(value: Binding(get: { fixedLevel }, set: { preferences.flirtSetting = .fixed(FlirtIntensity(clamping: Int($0.rounded()))) }),
                           in: 1...5, step: 1)
                    HStack {
                        ForEach(FlirtIntensity.allCases) { l in
                            Text(l.label).font(.caption2.weight(Int(fixedLevel) == l.rawValue ? .bold : .regular))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .foregroundStyle(Theme.textSecondary)
                    if fixedLevel >= 5, !preferences.spicyAllowed {
                        Text("Spicy needs Spicy Suggestions on; until then it's capped at Bold.")
                            .font(.footnote).foregroundStyle(Theme.maybe)
                    }
                }
            }
            Divider()
            Toggle(isOn: Binding(get: { preferences.spicySuggestions }, set: { on in
                if on { confirmSpicy = true } else { preferences.spicySuggestions = false }
            })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Spicy Suggestions").font(.headline)
                    Text("Adults only. Allows innuendo and suggestive tension when a profile's own words invite it. Never graphic.")
                        .font(.footnote).foregroundStyle(Theme.textSecondary)
                }
            }
            .alert("Turn on Spicy Suggestions?", isPresented: $confirmSpicy) {
                Button("I'm 18+, turn on") {
                    preferences.isAdultConfirmed = true
                    preferences.spicySuggestions = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Suggestions may include sexual innuendo. They're only used when the other person's profile sets that tone, and never for anyone who may be under 18.")
            }
        }
    }
}
