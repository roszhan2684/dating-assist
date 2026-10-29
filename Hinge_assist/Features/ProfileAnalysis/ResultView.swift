import HingeAssistKit
import SwiftUI

/// The result, laid out like the profile itself: header, then every photo and prompt as a card in
/// profile order. The best move is highlighted; tap the heart on any other card to write for that
/// one instead. The suggested comment lives in a composer bar pinned to the bottom.
struct ResultView: View {
    let model: AnalysisViewModel
    let analysis: CompleteProfileAnalysis
    @State private var showAlternatives = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ProfileHeader(analysis: analysis)
                    if !analysis.safetyNotes.isEmpty { safetyCard }
                    if let best = analysis.bestInteraction { WhyCard(best: best) }
                    ForEach(feedItems, id: \.self) { ref in
                        FeedCard(ref: ref, analysis: analysis, model: model)
                            .id(ref)
                    }
                    CompatibilityCard(analysis: analysis)
                    footer
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) {
                if let best = analysis.bestInteraction {
                    ComposerBar(model: model, best: best, showAlternatives: $showAlternatives) {
                        withAnimation(.snappy) { proxy.scrollTo(best.target.ref, anchor: .center) }
                    }
                }
            }
            .onChange(of: analysis.bestInteraction?.target.ref) { _, ref in
                if let ref { withAnimation(.snappy) { proxy.scrollTo(ref, anchor: .center) } }
            }
        }
        .sheet(isPresented: $showAlternatives) {
            if let best = analysis.bestInteraction {
                AlternativesSheet(model: model, best: best)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sensoryFeedback(.success, trigger: model.copiedID) { _, new in new != nil }
    }

    /// Photos and prompts interleaved the way dating profiles usually are.
    private var feedItems: [TargetRef] {
        var items: [TargetRef] = []
        let photos = analysis.profile.photos.map { TargetRef(.photo, $0.index) }
        let prompts = analysis.profile.prompts.map { TargetRef(.prompt, $0.index) }
        for i in 0..<max(photos.count, prompts.count) {
            if i < photos.count { items.append(photos[i]) }
            if i < prompts.count { items.append(prompts[i]) }
        }
        return items
    }

    private var safetyCard: some View {
        Card {
            Label("Heads up", systemImage: "exclamationmark.shield.fill").font(.headline).foregroundStyle(Theme.maybe)
            ForEach(analysis.safetyNotes, id: \.self) { Text($0).font(.subheadline) }
        }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text("You decide whether to like, skip, copy and send.")
            Text("No AI · on-device · your model's say: \(Int(model.modelInfluence * 100))%")
        }
        .font(.caption)
        .foregroundStyle(Theme.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }
}

// MARK: - Header

private struct ProfileHeader: View {
    let analysis: CompleteProfileAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.display(36))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    HStack(spacing: 8) {
                        RecommendationBadge(recommendation: analysis.recommendation)
                        Text("Tone: \(analysis.tone.label)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                ScoreRing(score: analysis.overallCompatibility, color: Theme.color(for: analysis.recommendation), size: 86)
            }
            if !analysis.profile.basics.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(analysis.profile.basics, id: \.self) { b in
                            Text(b)
                                .font(.footnote.weight(.medium))
                                .padding(.horizontal, 12).padding(.vertical, 7)
                                .background(Theme.surface, in: Capsule())
                                .overlay(Capsule().strokeBorder(Theme.stroke))
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(.vertical, 6)
    }

    private var title: String {
        let name = analysis.profile.name ?? "This profile"
        if let age = analysis.profile.age { return "\(name), \(age)" }
        return name
    }
}

private struct WhyCard: View {
    let best: RecommendedInteraction

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkle")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Theme.signalGradient, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text("Best move: like \(best.target.ref.label)")
                    .font(.headline)
                Text(best.why)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).strokeBorder(Theme.signal.opacity(0.35), lineWidth: 1))
    }
}

// MARK: - Feed cards

private struct FeedCard: View {
    let ref: TargetRef
    let analysis: CompleteProfileAnalysis
    let model: AnalysisViewModel

    private var target: InteractionTarget? { analysis.rankedInteractionTargets.first { $0.ref == ref } }
    private var rank: Int? { analysis.rankedInteractionTargets.firstIndex { $0.ref == ref }.map { $0 + 1 } }
    private var isBest: Bool { analysis.bestInteraction?.target.ref == ref }

    var body: some View {
        Group {
            switch ref.type {
            case .photo: photoCard
            case .prompt: promptCard
            }
        }
        .overlay(alignment: .topLeading) {
            if isBest {
                Label("BEST MOVE", systemImage: "sparkle")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Theme.signalGradient, in: Capsule())
                    .padding(12)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .strokeBorder(isBest ? AnyShapeStyle(Theme.signalGradient) : AnyShapeStyle(Color.clear), lineWidth: 2.5)
        )
        .softShadow()
        .animation(.snappy, value: isBest)
    }

    // Photo

    @ViewBuilder private var photoCard: some View {
        let photo = analysis.profile.photo(ref.index)
        ZStack(alignment: .bottom) {
            Group {
                if let img = model.photoThumbnails[ref.index] {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    ZStack {
                        Theme.surfaceRaised
                        Image(systemName: "photo").font(.largeTitle).foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 420)
            .clipped()
            .accessibilityLabel("Photo \(ref.index)")

            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                .allowsHitTesting(false)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    if let caption = photo?.caption {
                        Text(caption).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    }
                    scoreChip(light: true)
                }
                Spacer()
                HeartButton(isOn: isBest, onDark: true) { model.retarget(ref) }
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
    }

    // Prompt

    @ViewBuilder private var promptCard: some View {
        if let p = analysis.profile.prompt(ref.index) {
            VStack(alignment: .leading, spacing: 14) {
                Text(p.question)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, isBest ? 30 : 0)
                Text(p.answer)
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    scoreChip(light: false)
                    Spacer()
                    HeartButton(isOn: isBest, onDark: false) { model.retarget(ref) }
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        }
    }

    private func scoreChip(light: Bool) -> some View {
        HStack(spacing: 6) {
            if let rank { Text("#\(rank)").fontWeight(.heavy) }
            if let t = target { Text("· \(t.overallInteractionScore)") }
        }
        .font(.caption.monospacedDigit())
        .foregroundStyle(light ? .white : Theme.textSecondary)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(light ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Theme.surfaceRaised), in: Capsule())
        .accessibilityLabel(rank.map { "Ranked \($0)" } ?? "")
    }
}

/// Circular heart in the bottom corner of each card. Filled = the current pick.
struct HeartButton: View {
    let isOn: Bool
    let onDark: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isOn ? "heart.fill" : "heart")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(isOn ? AnyShapeStyle(Theme.signalGradient) : AnyShapeStyle(Theme.textPrimary))
                .frame(width: 54, height: 54)
                .background(onDark ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(Theme.surfaceRaised), in: Circle())
                .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: onDark ? 0 : 1))
                .symbolEffect(.bounce, value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "Current pick" : "Write a comment for this instead")
    }
}

// MARK: - Composer

/// Pinned "comment" bar: target, suggested message, Copy, and rewrite chips.
private struct ComposerBar: View {
    let model: AnalysisViewModel
    let best: RecommendedInteraction
    @Binding var showAlternatives: Bool
    let onJumpToTarget: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button(action: onJumpToTarget) {
                    Label("Comment on \(best.target.ref.label)", systemImage: "arrow.up.forward.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.signal)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(best.flirtIntensity.label)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(Theme.surfaceRaised, in: Capsule())
            }

            HStack(alignment: .center, spacing: 10) {
                Group {
                    if let comment = best.comment {
                        Text(comment.text)
                            .font(.body.weight(.medium))
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    } else {
                        Text("Nothing cleared the quality bar here. Try a rewrite or tap another heart.")
                            .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    }
                }
                .opacity(model.isRewriting ? 0.3 : 1)
                .overlay { if model.isRewriting { ProgressView() } }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                if let comment = best.comment {
                    let copied = model.copiedID == comment.id
                    Button { model.copy(comment) } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 52, height: 52)
                            .background(copied ? AnyShapeStyle(Theme.like) : AnyShapeStyle(Theme.signalGradient), in: Circle())
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isRewriting)
                    .accessibilityLabel(copied ? "Copied" : "Copy message")
                }
            }

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Chip(title: "Options", systemImage: "square.stack") { showAlternatives = true }
                    chip(.funnier, "face.smiling")
                    chip(.flirtier, "heart")
                    chip(.bolder, "flame")
                    chip(.tooSafe, "tortoise")
                    chip(.tooMuch, "hand.raised")
                    chip(.moreTeasing, "bubble.left.and.exclamationmark.bubble.right")
                    chip(.shorter, "scissors")
                    Menu {
                        ForEach([RewriteDirection.moreComplimenting, .moreMysterious, .moreDirect], id: \.self) { d in
                            Button(d.label) { model.rewrite(d) }
                        }
                        if model.spicyAvailable { Button(RewriteDirection.moreSuggestive.label) { model.rewrite(.moreSuggestive) } }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 40, height: 40)
                            .background(Theme.surfaceRaised, in: Capsule())
                            .overlay(Capsule().strokeBorder(Theme.stroke))
                    }
                    .accessibilityLabel("More rewrites")
                }
                .padding(.vertical, 1)
            }
            .scrollIndicators(.hidden)
            .disabled(model.isRewriting)
            .overlay(alignment: .trailing) {
                if model.copiedID != nil {
                    Text("Copied — paste it in the app").font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Theme.like, in: Capsule()).foregroundStyle(.white)
                        .transition(.opacity)
                }
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .animation(.snappy, value: model.copiedID)
    }

    private func chip(_ d: RewriteDirection, _ icon: String) -> some View {
        Chip(title: d.label, systemImage: icon, isSelected: model.lastDirection == d && model.isRewriting) { model.rewrite(d) }
    }
}

private struct AlternativesSheet: View {
    let model: AnalysisViewModel
    let best: RecommendedInteraction
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(best.alternatives) { alt in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(alt.text).font(.body).fixedSize(horizontal: false, vertical: true)
                            HStack {
                                Text(alt.candidate.style.rawValue.capitalized)
                                    .font(.caption.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                                Spacer()
                                Button("Use") { model.choose(alt); dismiss() }
                                    .buttonStyle(.bordered).tint(Theme.signal)
                                Button { model.copy(alt) } label: {
                                    Image(systemName: model.copiedID == alt.id ? "checkmark" : "doc.on.doc")
                                }
                                .buttonStyle(.bordered)
                                .accessibilityLabel("Copy")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } footer: {
                    Text("Every option passed the specificity and naturalness checks.")
                }
            }
            .navigationTitle("More options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { model.moreOptions() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

// MARK: - Compatibility

private struct CompatibilityCard: View {
    let analysis: CompleteProfileAnalysis

    var body: some View {
        Card {
            HStack {
                Eyebrow("Why \(analysis.overallCompatibility)%")
                Spacer()
                Text("\(Int(analysis.confidence * 100))% sure").font(.caption).foregroundStyle(Theme.textSecondary)
            }
            ForEach(analysis.compatibility.reasons, id: \.self) { r in
                Label(r, systemImage: "checkmark.circle.fill").font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                    .symbolRenderingMode(.multicolor)
            }
            ForEach(analysis.compatibility.concerns, id: \.self) { c in
                Label(c, systemImage: "exclamationmark.circle").font(.subheadline).foregroundStyle(Theme.maybe)
            }
        }
    }
}

extension String {
    func ifEmptyText(_ fallback: String) -> String { isEmpty ? fallback : self }
}
