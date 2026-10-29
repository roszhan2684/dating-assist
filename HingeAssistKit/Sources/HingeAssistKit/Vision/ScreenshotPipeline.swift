import CoreGraphics
import Foundation

public enum PipelineStage: String, Sendable, CaseIterable {
    case normalizing = "Fixing orientation & size"
    case readingText = "Reading every line"
    case findingPhotos = "Looking at every photo"
    case rebuilding = "Rebuilding the full profile"
}

public enum PipelineError: Error, LocalizedError, Equatable {
    case noImages
    case unreadableImage(Int)
    case nothingFound

    public var errorDescription: String? {
        switch self {
        case .noImages: "No screenshots were provided."
        case .unreadableImage(let i): "Screenshot \(i + 1) couldn't be opened."
        case .nothingFound: "Couldn't find any profile text or photos. Make sure the screenshots show a dating profile."
        }
    }
}

public struct PipelineOutput: @unchecked Sendable {
    public var profile: DatingProfile
    public var photoCrops: [Int: CGImage]
    public var scans: [ScreenshotScan]
    public var duplicateScreenshots: [Int]

    /// JPEG crops for vision-capable providers, longest edge `maxPixelSize`.
    public func providerImages(maxPixelSize: Int = 1024, limit: Int = 8) -> [ProviderImage] {
        photoCrops.keys.sorted().prefix(limit).compactMap { index in
            guard let crop = photoCrops[index] else { return nil }
            let small = ImageProcessing.resized(crop, maxPixelSize: maxPixelSize)
            return ImageProcessing.jpegData(small, quality: 0.75).map { ProviderImage(photoIndex: index, jpegData: $0) }
        }
    }
}

/// Build Doc §23: normalize -> resize -> OCR -> photo detection/labels -> dedupe -> reconstruct.
/// Everything here runs on-device with Apple's Vision framework.
public struct ScreenshotPipeline: Sendable {
    public var labelPhotos: Bool

    public init(labelPhotos: Bool = true) {
        self.labelPhotos = labelPhotos
    }

    public func process(imageData: [Data], progress: @escaping @Sendable (PipelineStage, Double) -> Void = { _, _ in }) async throws -> PipelineOutput {
        guard !imageData.isEmpty else { throw PipelineError.noImages }
        progress(.normalizing, 0)
        var images: [CGImage] = []
        for (i, data) in imageData.enumerated() {
            guard let img = ImageProcessing.normalizedImage(from: data) else { throw PipelineError.unreadableImage(i) }
            images.append(img)
        }
        return try await process(images: images, progress: progress)
    }

    public func process(images: [CGImage], progress: @escaping @Sendable (PipelineStage, Double) -> Void = { _, _ in }) async throws -> PipelineOutput {
        guard !images.isEmpty else { throw PipelineError.noImages }
        let labelPhotos = self.labelPhotos
        let box = UncheckedBox(images)
        return try await Task.detached(priority: .userInitiated) {
            let images = box.value.map { ImageProcessing.resized($0, maxPixelSize: ImageProcessing.maxPixelSize) }
            var scans: [ScreenshotScan] = []
            for (i, image) in images.enumerated() {
                try Task.checkCancellation()
                progress(.readingText, Double(i) / Double(images.count))
                let lines = try TextRecognizer.recognize(image)
                progress(.findingPhotos, (Double(i) + 0.5) / Double(images.count))
                let regions = PhotoRegionDetector.detect(in: image).map { rect -> PhotoRegion in
                    guard let crop = ImageProcessing.crop(image, normalizedRect: rect) else { return PhotoRegion(rect: rect) }
                    let labels = labelPhotos ? PhotoLabeler.labels(for: crop) : []
                    return PhotoRegion(rect: rect, labels: labels, hash: ImageProcessing.dHash(crop))
                }
                scans.append(ScreenshotScan(index: i, pixelSize: CGSize(width: image.width, height: image.height), lines: lines, photos: regions, hash: ImageProcessing.dHash(image)))
            }
            progress(.rebuilding, 0.9)
            let result = ProfileReconstructor.reconstruct(scans)
            guard !result.profile.isEmpty else { throw PipelineError.nothingFound }
            var crops: [Int: CGImage] = [:]
            for (index, source) in result.photoSources {
                if let crop = ImageProcessing.crop(images[source.scanIndex], normalizedRect: source.rect) { crops[index] = crop }
            }
            progress(.rebuilding, 1)
            return PipelineOutput(profile: result.profile, photoCrops: crops, scans: scans, duplicateScreenshots: result.duplicateScreenshots)
        }.value
    }
}

struct UncheckedBox<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}
