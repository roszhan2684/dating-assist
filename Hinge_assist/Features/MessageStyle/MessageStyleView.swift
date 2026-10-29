import HingeAssistKit
import SwiftUI

/// Pick a vibe and paste a few messages you've really sent; Dating Assist learns your Message DNA.
struct MessageStyleForm: View {
    @Binding var preset: StylePreset
    @Binding var examples: [String]
    let dna: MessageDNA

    @State private var draft: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Eyebrow("Your vibe")
            VStack(spacing: 10) {
                ForEach(StylePreset.allCases) { p in
                    Button {
                        preset = p
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.label).font(.headline)
                                Text(p.blurb).font(.footnote).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: preset == p ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(preset == p ? Theme.signal : Theme.stroke)
                                .font(.title3)
                        }
                        .padding(14)
                        .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(preset == p ? Theme.signal : Theme.stroke))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(preset == p ? .isSelected : [])
                }
            }

            Eyebrow("Messages you've actually sent (optional)")
            Text("One per line. They're used only to learn length, emoji, casing and humor — never sent anywhere or copied.")
                .font(.footnote).foregroundStyle(Theme.textSecondary)
            TextEditor(text: $draft)
                .frame(minHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.stroke))
                .overlay(alignment: .topLeading) {
                    if draft.isEmpty {
                        Text("okay that's a bold claim 😭\nloser buys tacos")
                            .foregroundStyle(Theme.textSecondary.opacity(0.6))
                            .padding(16)
                            .allowsHitTesting(false)
                    }
                }
                .onAppear { draft = examples.joined(separator: "\n") }
                .onChange(of: draft) { _, text in
                    examples = text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                }

            DNASummary(dna: dna)
        }
    }
}

struct DNASummary: View {
    let dna: MessageDNA

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Your Message DNA")
            ForEach(dna.summary, id: \.0) { name, value in
                HStack {
                    Text(name).font(.footnote).frame(width: 90, alignment: .leading)
                    ScoreBar(value: Int(value * 100))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(name) \(Int(value * 100)) percent")
            }
            Text("~\(Int(dna.averageLength)) characters per message")
                .font(.caption).foregroundStyle(Theme.textSecondary)
        }
    }
}

/// Settings screen wrapper.
struct MessageStyleView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var preset: StylePreset = .playfulBanter
    @State private var examples: [String] = []

    var body: some View {
        ScrollView {
            MessageStyleForm(preset: $preset, examples: $examples, dna: liveDNA)
                .padding(Theme.gutter)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Message style")
        .onAppear {
            preset = coordinator.settings.preferences.stylePreset
            examples = coordinator.settings.toneExamples
        }
        .onDisappear(perform: save)
    }

    private var liveDNA: MessageDNA {
        let changed = preset != coordinator.settings.preferences.stylePreset || examples != coordinator.settings.toneExamples
        guard changed else { return coordinator.settings.dna }
        return MessageDNA.analyze(messages: examples, seed: preset.seedDNA)
    }

    private func save() {
        let dna = liveDNA
        coordinator.update { s in
            s.preferences.stylePreset = preset
            s.toneExamples = examples
            s.dna = dna
        }
    }
}
