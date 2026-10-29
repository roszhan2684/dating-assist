import HingeAssistKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false
    @State private var confirmModelReset = false

    var body: some View {
        NavigationStack {
            Form {
                modelSection
                flirtSection
                Section("You") {
                    NavigationLink("Preferences") { PreferencesScreen() }
                    NavigationLink("Message style") { MessageStyleView() }
                }
                privacySection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    // MARK: Personal model

    private var modelSection: some View {
        let m = coordinator.settings.openerModel
        let learned = m.learnedPreferences()
        return Section {
            LabeledContent("Learned from", value: "\(m.examples) signal\(m.examples == 1 ? "" : "s")")
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Its say in rankings")
                    Spacer()
                    Text("\(Int(m.influence * 100))%").monospacedDigit().foregroundStyle(Theme.textSecondary)
                }
                ScoreBar(value: Int(m.influence / OpenerModel.maxInfluence * 100))
            }
            LabeledContent("Replies tracked", value: "\(m.replies) 👍 · \(m.noReplies) 👎")
            if !learned.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("What it's learned").font(.subheadline.weight(.semibold))
                    ForEach(learned, id: \.name) { item in
                        Label(item.name, systemImage: item.weight > 0 ? "hand.thumbsup" : "hand.thumbsdown")
                            .font(.footnote)
                            .foregroundStyle(item.weight > 0 ? Theme.like : Theme.textSecondary)
                    }
                }
            }
            Button("Reset my model", role: .destructive) { confirmModelReset = true }
                .confirmationDialog("Forget everything the model has learned?", isPresented: $confirmModelReset, titleVisibility: .visible) {
                    Button("Reset model", role: .destructive) { coordinator.resetModel() }
                }
        } header: {
            Text("Your opener model")
        } footer: {
            Text("No AI chatbots are used. Openers come from a template library, checked by quality rules, and ranked partly by a small model that lives only on this phone. It learns from what you copy, what you rewrite and whether people reply, and gets more say as it learns (up to 60%).")
        }
    }

    private var flirtSection: some View {
        Section {
            FlirtSettingsForm(preferences: binding(\.preferences))
        } header: {
            Text("Flirt level")
        }
    }

    // MARK: Privacy

    private var privacySection: some View {
        Section {
            LabeledContent("Screenshots", value: "Deleted after analysis")
            LabeledContent("Saved data", value: "Preferences, style & your model")
            LabeledContent("Network", value: "Never used")
            Button("Delete temporary screenshots now") { coordinator.env.inbox.deleteAll(); coordinator.pendingSessions = [] }
            Button("Reset learned style") { coordinator.resetLearning() }
            Button("Reset everything", role: .destructive) { confirmReset = true }
                .confirmationDialog("Erase all preferences, learned style and your model?", isPresented: $confirmReset, titleVisibility: .visible) {
                    Button("Erase everything", role: .destructive) {
                        coordinator.resetEverything()
                        dismiss()
                    }
                }
        } header: {
            Text("Privacy")
        } footer: {
            Text("Dating Assist never stores other people's photos. Shared screenshots wait in a temporary folder only until you open the app, and anything older than an hour is deleted automatically.")
        }
    }

    private var aboutSection: some View {
        Section {
            Text("Dating Assist analyzes screenshots you choose to share and suggests what to say, entirely on your phone with no generative AI. It never scrapes, swipes, likes or messages on any dating app — you take every action yourself.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        } header: {
            Text("About")
        }
    }

    private func binding<T: Equatable>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(get: { coordinator.settings[keyPath: keyPath] }, set: { v in coordinator.update { $0[keyPath: keyPath] = v } })
    }
}

struct PreferencesScreen: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        ScrollView {
            PreferencesForm(preferences: Binding(
                get: { coordinator.settings.preferences },
                set: { p in coordinator.update { $0.preferences = p } }))
            .padding(Theme.gutter)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Preferences")
    }
}
