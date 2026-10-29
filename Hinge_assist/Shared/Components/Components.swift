import HingeAssistKit
import SwiftUI

/// Rounded surface card used across the app.
struct Card<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1))
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = Theme.textSecondary

    init(_ text: String, color: Color = Theme.textSecondary) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(.eyebrow)
            .tracking(1.2)
            .foregroundStyle(color)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Big primary action with the signal gradient.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Theme.signalGradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.stroke))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// Small capsule button used for rewrite controls.
struct Chip: View {
    let title: String
    var systemImage: String?
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage).imageScale(.small) }
                Text(title).lineLimit(1)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .foregroundStyle(isSelected ? .white : Theme.textPrimary)
            .background(isSelected ? AnyShapeStyle(Theme.signalGradient) : AnyShapeStyle(Theme.surfaceRaised), in: Capsule())
            .overlay(Capsule().strokeBorder(isSelected ? .clear : Theme.stroke))
        }
        .buttonStyle(.plain)
    }
}

/// Animated match score ring with rolling digits.
struct ScoreRing: View {
    let score: Int
    var color: Color = Theme.signal
    var size: CGFloat = 104
    @State private var shown = 0

    var body: some View {
        ZStack {
            Circle().stroke(Theme.stroke, lineWidth: 10)
            Circle()
                .trim(from: 0, to: CGFloat(shown) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(shown)%")
                    .font(.system(size: size * 0.27, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText(value: Double(shown)))
                    .monospacedDigit()
                Text("MATCH").font(.eyebrow).foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(5) // keep the stroke inside the frame
        .frame(width: size, height: size)
        .onAppear { withAnimation(.easeOut(duration: 0.9)) { shown = score } }
        .onChange(of: score) { _, new in withAnimation(.easeOut(duration: 0.5)) { shown = new } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(score) percent match")
    }
}

/// Horizontal score bar (0-100).
struct ScoreBar: View {
    let value: Int
    var tint: Color = Theme.signal

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.stroke)
                Capsule().fill(tint).frame(width: geo.size.width * CGFloat(max(0, min(100, value))) / 100)
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

/// Wrapping layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: min(maxX, width), height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct RecommendationBadge: View {
    let recommendation: MatchRecommendation

    var body: some View {
        Text(recommendation.label)
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .tracking(1.5)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .foregroundStyle(.white)
            .background(Theme.color(for: recommendation), in: Capsule())
            .accessibilityLabel("Recommendation: \(recommendation.label)")
    }
}

/// Editable list of short tags (interests, dealbreakers, green flags).
struct TagEditor: View {
    @Binding var tags: [String]
    let suggestions: [String]
    var placeholder = "Add your own"
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlowLayout {
                ForEach(Array(Set(suggestions + tags)).sorted(), id: \.self) { tag in
                    Chip(title: tag, isSelected: tags.contains(tag)) {
                        if let i = tags.firstIndex(of: tag) { tags.remove(at: i) } else { tags.append(tag) }
                    }
                }
            }
            HStack {
                TextField(placeholder, text: $draft)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    .onSubmit(add)
                Button("Add", action: add).disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func add() {
        let t = draft.trimmingCharacters(in: .whitespaces).lowercased()
        guard !t.isEmpty, !tags.contains(t) else { return }
        tags.append(t)
        draft = ""
    }
}
