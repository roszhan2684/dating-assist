import HingeAssistKit
import Observation
import SwiftUI
import UIKit

/// Runs one profile capture session: OCR + reconstruction, AI analysis, rewrites and copy.
/// Photos live only in memory for the life of this screen; nothing is written to disk.
@MainActor
@Observable
final class AnalysisViewModel: Identifiable {
    enum Source: Equatable { case photoLibrary, shareExtension, sample }

    enum Phase: Equatable {
        case working(step: String, progress: Double)
        case result
        case failed(String)
    }

    let id = UUID()
    let source: Source
    private unowned let coordinator: AppCoordinator

    private(set) var phase: Phase = .working(step: PipelineStage.normalizing.rawValue, progress: 0)
    private(set) var analysis: CompleteProfileAnalysis?
    private(set) var photoThumbnails: [Int: UIImage] = [:]
    private(set) var isRewriting = false
    private(set) var lastDirection: RewriteDirection?
    private(set) var copiedID: UUID?
    var showAlternatives = false

    private var providerImages: [ProviderImage] = []
    private var task: Task<Void, Never>?

    init(coordinator: AppCoordinator, source: Source) {
        self.coordinator = coordinator
        self.source = source
    }

    // MARK: Pipeline

    func start(imageData: [Data]) {
        task?.cancel()
        phase = .working(step: PipelineStage.normalizing.rawValue, progress: 0.02)
        let env = coordinator.env
        let settings = coordinator.settings
        let engine = coordinator.engine
        let ref = WeakRef(self)
        task = Task { [weak self] in
            do {
                let output = try await env.pipeline.process(imageData: imageData) { stage, p in
                    Task { @MainActor in ref.value?.phase = .working(step: stage.rawValue, progress: 0.05 + p * 0.45) }
                }
                try Task.checkCancellation()
                let images = output.providerImages()
                var thumbs: [Int: UIImage] = [:]
                for (index, crop) in output.photoCrops {
                    thumbs[index] = UIImage(cgImage: ImageProcessing.resized(crop, maxPixelSize: 1100))
                }
                await MainActor.run {
                    self?.providerImages = images
                    self?.photoThumbnails = thumbs
                }
                let result = try await engine.analyze(profile: output.profile, photos: images, preferences: settings.preferences, dna: settings.dna) { stage in
                    Task { @MainActor in
                        let order = AnalysisStage.allCases.firstIndex(of: stage) ?? 0
                        ref.value?.phase = .working(step: stage.rawValue, progress: 0.55 + Double(order) * 0.11)
                    }
                }
                try Task.checkCancellation()
                await MainActor.run {
                    self?.analysis = result
                    withAnimation(.snappy) { self?.phase = .result }
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run { self?.phase = .failed(error.localizedDescription) }
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        providerImages = []
        photoThumbnails = [:]
    }

    // MARK: Actions

    func rewrite(_ direction: RewriteDirection) {
        guard let analysis, !isRewriting else { return }
        isRewriting = true
        lastDirection = direction
        coordinator.recordFeedback(direction, on: analysis.bestInteraction?.comment)
        let settings = coordinator.settings
        let images = providerImages
        let engine = coordinator.engine
        Task {
            let updated = await engine.rewrite(analysis, direction: direction, photos: images, preferences: settings.preferences, dna: settings.dna)
            withAnimation(.snappy) {
                self.analysis = updated
                self.isRewriting = false
            }
        }
    }

    func moreOptions() {
        guard let analysis, !isRewriting else { return }
        isRewriting = true
        lastDirection = nil
        let settings = coordinator.settings
        let images = providerImages
        let engine = coordinator.engine
        Task {
            let updated = await engine.moreOptions(analysis, photos: images, preferences: settings.preferences, dna: settings.dna)
            withAnimation(.snappy) {
                self.analysis = updated
                self.isRewriting = false
                self.showAlternatives = true
            }
        }
    }

    func retarget(_ ref: TargetRef) {
        guard let analysis, !isRewriting, analysis.bestInteraction?.target.ref != ref else { return }
        isRewriting = true
        let settings = coordinator.settings
        let images = providerImages
        let engine = coordinator.engine
        Task {
            let updated = await engine.retarget(analysis, to: ref, photos: images, preferences: settings.preferences, dna: settings.dna)
            withAnimation(.snappy) {
                self.analysis = updated
                self.isRewriting = false
            }
        }
    }

    /// Promotes an alternative to the main suggestion.
    func choose(_ candidate: ScoredCandidate) {
        guard var analysis, var best = analysis.bestInteraction, let current = best.comment else { return }
        best.alternatives.removeAll { $0.id == candidate.id }
        best.alternatives.insert(current, at: 0)
        best.comment = candidate
        analysis.bestInteraction = best
        withAnimation(.snappy) { self.analysis = analysis }
    }

    /// The user copies; they still paste and send it themselves in the dating app.
    func copy(_ candidate: ScoredCandidate) {
        UIPasteboard.general.string = candidate.text
        let shown = ([analysis?.bestInteraction?.comment].compactMap { $0 } + (analysis?.bestInteraction?.alternatives ?? []))
        coordinator.recordCopy(candidate, passedOver: shown.filter { $0.id != candidate.id })
        copiedID = candidate.id
        Task {
            try? await Task.sleep(for: .seconds(2))
            if copiedID == candidate.id { copiedID = nil }
        }
    }

    var spicyAvailable: Bool { coordinator.settings.preferences.spicyAllowed }
    var modelInfluence: Double { coordinator.settings.openerModel.influence }
}

/// Weak reference that can cross into @Sendable progress callbacks.
final class WeakRef<T: AnyObject>: @unchecked Sendable {
    weak var value: T?
    init(_ value: T) { self.value = value }
}
