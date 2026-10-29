import HingeAssistKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Share Extension: receives the screenshots of one profile, downsizes them, and drops them in the
/// shared temporary inbox. The app picks them up (and deletes them) next time it opens.
final class ShareViewController: UIViewController {
    private let state = ShareState()

    override func viewDidLoad() {
        super.viewDidLoad()
        let host = UIHostingController(rootView: ShareView(state: state, onDone: { [weak self] in self?.finish() }))
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
        Task { await receive() }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func receive() async {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
            .filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
        guard !providers.isEmpty else {
            state.status = .failed("No images found. Share screenshots of a dating profile.")
            return
        }
        var images: [Data] = []
        for (i, provider) in providers.prefix(12).enumerated() {
            state.status = .saving(i + 1, min(providers.count, 12))
            // One at a time keeps memory low inside the extension.
            if let data = await loadImageData(provider),
               let cg = ImageProcessing.normalizedImage(from: data),
               let jpeg = ImageProcessing.jpegData(cg, quality: 0.85) {
                images.append(jpeg)
            }
        }
        guard !images.isEmpty else {
            state.status = .failed("Those images couldn't be read.")
            return
        }
        do {
            try CaptureInbox().save(images)
            state.status = .done(images.count)
        } catch {
            state.status = .failed("Couldn't save the screenshots: \(error.localizedDescription)")
        }
    }

    private func loadImageData(_ provider: NSItemProvider) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
                continuation.resume(returning: data)
            }
        }
    }
}

@MainActor
@Observable
final class ShareState {
    enum Status: Equatable {
        case loading
        case saving(Int, Int)
        case done(Int)
        case failed(String)
    }
    var status: Status = .loading
}

struct ShareView: View {
    let state: ShareState
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            icon
            Text(title).font(.title3.weight(.bold)).multilineTextAlignment(.center)
            Text(detail).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Spacer()
            Button(action: onDone) {
                Text(isFinished ? "Done" : "Cancel").font(.headline).frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 1, green: 0.30, blue: 0.37))
        }
        .padding(24)
    }

    private var isFinished: Bool {
        if case .done = state.status { return true }
        if case .failed = state.status { return true }
        return false
    }

    @ViewBuilder private var icon: some View {
        switch state.status {
        case .done: Image(systemName: "checkmark.circle.fill").font(.system(size: 52)).foregroundStyle(.green)
        case .failed: Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 52)).foregroundStyle(.orange)
        default: ProgressView().controlSize(.large)
        }
    }

    private var title: String {
        switch state.status {
        case .loading: "Getting screenshots…"
        case .saving(let i, let n): "Preparing \(i) of \(n)…"
        case .done(let n): "\(n) screenshot\(n == 1 ? "" : "s") ready"
        case .failed: "Something went wrong"
        }
    }

    private var detail: String {
        switch state.status {
        case .done: "Open Dating Assist to see your best move. The screenshots are deleted once they're analyzed."
        case .failed(let message): message
        default: "Treating these as one profile."
        }
    }
}
