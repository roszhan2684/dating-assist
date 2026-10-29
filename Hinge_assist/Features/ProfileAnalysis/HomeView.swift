import HingeAssistKit
import PhotosUI
import SwiftUI

struct HomeView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var selection: [PhotosPickerItem] = []
    @State private var isLoadingPicks = false
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    importCard
                    if !coordinator.pendingSessions.isEmpty { pendingCard }
                    if !coordinator.settings.pendingReplies().isEmpty { RepliesCard() }
                    howItWorks
                    voiceCard
                    boundaryNote
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 32)
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { coordinator.showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                        .accessibilityLabel("Settings")
                }
            }
            .alert("Couldn't import", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(importError ?? "") }
        }
        .onChange(of: selection) { _, items in loadPicked(items) }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image("BrandMark")
                .resizable()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Dating Assist")
                    .font(.display(30))
                    .foregroundStyle(Theme.textPrimary)
                Text("Your on-device wingman")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.top, 4)
    }

    private var importCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Screenshot the whole profile.")
                        .font(.display(26))
                        .foregroundStyle(Theme.inkInverse)
                    Text("Get the match score, the one photo or prompt to like, and the line to send.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkInverse.opacity(0.75))
                }
                Spacer(minLength: 0)
                MiniProfileStack()
            }
            PhotosPicker(selection: $selection, maxSelectionCount: 12, selectionBehavior: .ordered, matching: .images, photoLibrary: .shared()) {
                Label(isLoadingPicks ? "Loading…" : "Choose screenshots", systemImage: "photo.on.rectangle.angled")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isLoadingPicks)
            Button {
                coordinator.startSample()
            } label: {
                Label("Try a sample profile", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(Theme.inkInverse)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Theme.inkInverse.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .background(Theme.ink, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .softShadow()
    }

    private var pendingCard: some View {
        Card {
            Eyebrow("From Share", color: Theme.signal)
            ForEach(coordinator.pendingSessions) { session in
                Button {
                    coordinator.open(session)
                } label: {
                    HStack {
                        Text("\(session.imageCount) screenshot\(session.imageCount == 1 ? "" : "s") ready")
                        Spacer()
                        Text("Analyze").fontWeight(.semibold)
                        Image(systemName: "chevron.right")
                    }
                }
                .foregroundStyle(Theme.textPrimary)
            }
        }
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("How it works")
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    stepCard(1, "camera.viewfinder", "Screenshot", "Scroll the profile and screenshot every photo and prompt.")
                    stepCard(2, "square.and.arrow.up", "Share", "Share → Dating Assist, or pick them above.")
                    stepCard(3, "sparkle", "Best move", "One photo or prompt to like, and what to say.")
                    stepCard(4, "hand.tap", "You send it", "Copy, like and paste yourself. Screenshots get deleted.")
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func stepCard(_ n: Int, _ icon: String, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon).font(.title3.weight(.semibold)).foregroundStyle(Theme.signal)
                Spacer()
                Text("\(n)").font(.system(size: 13, weight: .heavy, design: .rounded)).foregroundStyle(Theme.textSecondary)
            }
            Text(title).font(.headline)
            Text(detail).font(.footnote).foregroundStyle(Theme.textSecondary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(width: 170, height: 160, alignment: .topLeading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.stroke))
        .accessibilityElement(children: .combine)
    }

    private var voiceCard: some View {
        let s = coordinator.settings
        return Card {
            HStack {
                Eyebrow("Your voice")
                Spacer()
                Text("Flirt: \(s.preferences.flirtSetting.label)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
            }
            Text(s.preferences.stylePreset.label).font(.headline)
            Text("Learned from \(s.dna.sampleCount) message\(s.dna.sampleCount == 1 ? "" : "s") and \(s.feedback.copies) copied opener\(s.feedback.copies == 1 ? "" : "s").")
                .font(.footnote).foregroundStyle(Theme.textSecondary)
        }
    }

    private var boundaryNote: some View {
        Text("Dating Assist only reads screenshots you choose to share. It never logs in, swipes, likes or messages for you.")
            .font(.footnote)
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }

    private func loadPicked(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        isLoadingPicks = true
        Task {
            var data: [Data] = []
            for item in items {
                if let d = try? await item.loadTransferable(type: Data.self) { data.append(d) }
            }
            isLoadingPicks = false
            selection = []
            if data.isEmpty {
                importError = "Those images couldn't be loaded. Try again or pick different screenshots."
            } else {
                coordinator.startAnalysis(imageData: data, source: .photoLibrary)
            }
        }
    }
}

/// "Did they reply?" — the strongest training signal for your personal opener model.
struct RepliesCard: View {
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        let pending = Array(coordinator.settings.pendingReplies().prefix(3))
        Card {
            HStack {
                Eyebrow("Did they reply?", color: Theme.signal)
                Spacer()
                Text("teaches your model").font(.caption).foregroundStyle(Theme.textSecondary)
            }
            ForEach(pending) { sent in
                VStack(alignment: .leading, spacing: 8) {
                    Text("“\(sent.text)”").font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Text(sent.sentAt, format: .relative(presentation: .named))
                            .font(.caption).foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Button { coordinator.recordReply(sent, replied: true) } label: { Label("Replied", systemImage: "hand.thumbsup.fill") }
                            .buttonStyle(.bordered).tint(Theme.like)
                        Button { coordinator.recordReply(sent, replied: false) } label: { Label("No reply", systemImage: "hand.thumbsdown") }
                            .buttonStyle(.bordered).tint(Theme.textSecondary)
                        Menu {
                            Button("I didn't send this", systemImage: "xmark") { coordinator.dismissSent(sent) }
                        } label: {
                            Image(systemName: "ellipsis").frame(width: 32, height: 32)
                        }
                        .accessibilityLabel("More")
                    }
                    .font(.caption.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                }
                if sent.id != pending.last?.id { Divider() }
            }
        }
    }
}

/// Little fanned stack of profile cards for the hero.
private struct MiniProfileStack: View {
    var body: some View {
        ZStack {
            card(tint: Theme.signalDeep, symbol: "text.quote").rotationEffect(.degrees(-10)).offset(x: -10, y: 6)
            card(tint: Theme.signal, symbol: "photo").rotationEffect(.degrees(6)).offset(x: 6)
            Image(systemName: "heart.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Theme.signalGradient, in: Circle())
                .offset(x: 26, y: 30)
        }
        .frame(width: 84, height: 96)
        .accessibilityHidden(true)
    }

    private func card(tint: Color, symbol: String) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(tint.gradient)
            .frame(width: 54, height: 72)
            .overlay(Image(systemName: symbol).foregroundStyle(.white.opacity(0.9)))
    }
}
