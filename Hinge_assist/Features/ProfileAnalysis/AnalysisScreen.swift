import HingeAssistKit
import SwiftUI

/// Full-screen flow for one profile: progress -> result (or a clear failure state).
struct AnalysisScreen: View {
    @Environment(AppCoordinator.self) private var coordinator
    let model: AnalysisViewModel

    var body: some View {
        NavigationStack {
            Group {
                switch model.phase {
                case .working(let step, let progress):
                    ProgressStateView(step: step, progress: progress)
                case .failed(let message):
                    FailureView(message: message) { coordinator.closeAnalysis() }
                case .result:
                    if let analysis = model.analysis {
                        ResultView(model: model, analysis: analysis)
                    }
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { coordinator.closeAnalysis() }
                }
                if model.source == .sample, model.phase == .result {
                    ToolbarItem(placement: .principal) {
                        Text("Sample profile").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
    }
}

struct ProgressStateView: View {
    let step: String
    let progress: Double

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle().stroke(Theme.stroke, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Theme.signalGradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.4), value: progress)
                Image(systemName: "viewfinder")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(Theme.signalGradient)
                    .symbolEffect(.pulse, options: .repeating)
            }
            .frame(width: 120, height: 120)
            VStack(spacing: 8) {
                Text("Reading the whole profile")
                    .font(.title3.weight(.bold))
                Text(step)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .contentTransition(.opacity)
                    .animation(.easeInOut, value: step)
            }
            Spacer()
            Text("Screenshots stay on this phone and are deleted after analysis.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Analyzing. \(step). \(Int(progress * 100)) percent")
    }
}

struct FailureView: View {
    let message: String
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(Theme.textSecondary)
            Text("Couldn't read that profile").font(.title3.weight(.bold))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Text("Tip: share every screenshot of a single profile, top to bottom, with the text clearly visible.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Close", action: onClose).buttonStyle(PrimaryButtonStyle())
        }
        .padding(24)
    }
}
