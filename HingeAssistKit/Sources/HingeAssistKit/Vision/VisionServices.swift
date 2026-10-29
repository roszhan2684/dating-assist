import CoreGraphics
import Foundation
import Vision

/// One recognized line of text. `box` is normalized with a top-left origin.
public struct OCRLine: Codable, Hashable, Sendable {
    public var text: String
    public var box: CGRect
    public var confidence: Double
    /// Line height in pixels of the source screenshot; used to tell small questions from big answers.
    public var pixelHeight: Double

    public init(text: String, box: CGRect, confidence: Double, pixelHeight: Double) {
        self.text = text
        self.box = box
        self.confidence = confidence
        self.pixelHeight = pixelHeight
    }
}

/// A photo block found inside a screenshot.
public struct PhotoRegion: Codable, Hashable, Sendable {
    public var rect: CGRect
    public var labels: [String]
    public var hash: UInt64

    public init(rect: CGRect, labels: [String] = [], hash: UInt64 = 0) {
        self.rect = rect
        self.labels = labels
        self.hash = hash
    }

    public var touchesTop: Bool { rect.minY < 0.02 }
    public var touchesBottom: Bool { rect.maxY > 0.98 }
}

/// Everything read from one screenshot.
public struct ScreenshotScan: Codable, Hashable, Sendable {
    public var index: Int
    public var pixelSize: CGSize
    public var lines: [OCRLine]
    public var photos: [PhotoRegion]
    public var hash: UInt64

    public init(index: Int, pixelSize: CGSize, lines: [OCRLine], photos: [PhotoRegion], hash: UInt64 = 0) {
        self.index = index
        self.pixelSize = pixelSize
        self.lines = lines
        self.photos = photos
        self.hash = hash
    }
}

// MARK: - OCR

public enum TextRecognizer {
    /// Runs Vision's accurate text recognizer and returns lines top-to-bottom.
    public static func recognize(_ image: CGImage) throws -> [OCRLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.008
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        let observations = request.results ?? []
        let height = Double(image.height)
        let lines: [OCRLine] = observations.compactMap { obs in
            guard let candidate = obs.topCandidates(1).first else { return nil }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            let bb = obs.boundingBox // normalized, bottom-left origin
            let box = CGRect(x: bb.minX, y: 1 - bb.maxY, width: bb.width, height: bb.height)
            return OCRLine(text: text, box: box, confidence: Double(candidate.confidence), pixelHeight: bb.height * height)
        }
        return lines.sorted { $0.box.minY < $1.box.minY }
    }
}

// MARK: - Photo regions

/// Finds photo blocks in a dating-profile screenshot by looking for tall bands of "busy" pixels that
/// differ strongly from the page background (text rows are mostly background, photos are not).
public enum PhotoRegionDetector {
    public static func detect(in image: CGImage) -> [CGRect] {
        let w = 72
        let h = max(40, Int(Double(image.height) / Double(image.width) * Double(w)))
        let px = ImageProcessing.rgbaPixels(image, width: w, height: h)

        func color(_ x: Int, _ y: Int) -> (Int, Int, Int) {
            let i = (y * w + x) * 4
            return (Int(px[i]), Int(px[i + 1]), Int(px[i + 2]))
        }
        // Background = most common quantized colour along the left/right margins.
        var counts: [Int: Int] = [:]
        for y in 0..<h {
            for x in [0, 1, w - 2, w - 1] {
                let (r, g, b) = color(x, y)
                counts[(r / 16) << 8 | (g / 16) << 4 | (b / 16), default: 0] += 1
            }
        }
        func unpack(_ k: Int) -> (Int, Int, Int) { (((k >> 8) & 0xF) * 16 + 8, ((k >> 4) & 0xF) * 16 + 8, (k & 0xF) * 16 + 8) }
        func dist(_ a: (Int, Int, Int), _ b: (Int, Int, Int)) -> Int { abs(a.0 - b.0) + abs(a.1 - b.1) + abs(a.2 - b.2) }
        let bgKey = counts.max { $0.value < $1.value }?.key ?? 0xFFF
        let bg = unpack(bgKey)

        // Card colour: a flat, non-background colour that fills whole rows (e.g. dark-mode prompt cards).
        var dominantRows: [Int: Int] = [:]
        for y in 0..<h {
            var row: [Int: Int] = [:]
            for x in (w / 10)..<(w - w / 10) {
                let (r, g, b) = color(x, y)
                row[(r / 16) << 8 | (g / 16) << 4 | (b / 16), default: 0] += 1
            }
            if let top = row.max(by: { $0.value < $1.value }), Double(top.value) / Double(w - 2 * (w / 10)) >= 0.7, dist(unpack(top.key), bg) > 24 {
                dominantRows[top.key, default: 0] += 1
            }
        }
        let card = dominantRows.max { $0.value < $1.value }.flatMap { Double($0.value) / Double(h) >= 0.06 ? unpack($0.key) : nil }

        func differs(_ c: (Int, Int, Int)) -> Bool {
            guard dist(c, bg) > 60 else { return false }
            if let card, dist(c, card) <= 40 { return false }
            return true
        }

        var photoRows = [Bool](repeating: false, count: h)
        for y in 0..<h {
            var busy = 0
            for x in 0..<w where differs(color(x, y)) { busy += 1 }
            photoRows[y] = Double(busy) / Double(w) > 0.62
        }
        // Close 1-row gaps.
        for y in 1..<(h - 1) where !photoRows[y] && photoRows[y - 1] && photoRows[y + 1] { photoRows[y] = true }

        var rects: [CGRect] = []
        var start: Int?
        for y in 0...h {
            let on = y < h && photoRows[y]
            if on, start == nil { start = y }
            if !on, let s = start {
                let height = Double(y - s) / Double(h)
                if height >= 0.08 {
                    // Horizontal extent from columns that are busy in this band.
                    var minX = w, maxX = 0
                    for x in 0..<w {
                        var busy = 0
                        for yy in s..<y where differs(color(x, yy)) { busy += 1 }
                        if Double(busy) / Double(y - s) > 0.5 { minX = min(minX, x); maxX = max(maxX, x) }
                    }
                    if maxX > minX {
                        rects.append(CGRect(x: Double(minX) / Double(w), y: Double(s) / Double(h),
                                            width: Double(maxX - minX + 1) / Double(w), height: height))
                    }
                }
                start = nil
            }
        }
        return rects.filter { $0.width > 0.5 }
    }
}

// MARK: - Photo labels

/// Labels a photo with Vision's on-device scene/object classifier and keeps only non-sensitive,
/// conversation-useful labels (Build Doc §4: never infer sensitive traits).
public enum PhotoLabeler {
    /// Labels that describe people or bodies — never used.
    static let blocked: Set<String> = [
        "people", "person", "adult", "child", "baby", "teen", "face", "portrait", "selfie", "woman", "man", "girl", "boy",
        "skin", "body", "hair", "lingerie", "swimwear", "bikini", "underwear", "underclothes", "shirtless", "tattoo",
        "religion", "religious", "church", "mosque", "temple", "cross", "wheelchair", "medical", "hospital",
    ]
    /// Labels too vague to start a conversation.
    static let vague: Set<String> = [
        "structure", "material", "texture", "art", "illustration", "graphic", "screenshot", "document", "text", "pattern",
        "abstract", "drawing", "painting", "outdoor", "indoor", "sky", "light", "night", "day", "liquid", "plant", "wood",
        "land", "blue_sky", "cloudy", "clothing", "apparel", "conveyance", "vehicle", "machine", "consumer_electronics",
        "jacket", "shirt", "hat", "sunglasses", "eyeglasses", "footwear", "shoes", "frame", "wall", "ceiling", "floor",
    ]

    public static func labels(for image: CGImage, minimumConfidence: Float = 0.25, limit: Int = 6) -> [String] {
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do { try handler.perform([request]) } catch { return [] }
        let results = (request.results ?? [])
            .filter { $0.confidence >= minimumConfidence }
            .sorted { $0.confidence > $1.confidence }
        var out: [String] = []
        for obs in results {
            let id = obs.identifier.lowercased()
            if blocked.contains(id) || vague.contains(id) { continue }
            if id.split(separator: "_").contains(where: { blocked.contains(String($0)) }) { continue }
            out.append(id.replacingOccurrences(of: "_", with: " "))
            if out.count >= limit { break }
        }
        return out
    }
}
