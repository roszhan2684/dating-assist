import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Orientation fix, resizing, cropping, JPEG encoding and perceptual hashing.
public enum ImageProcessing {
    /// Build Doc §23: max ~2048 px on the longest edge.
    public static let maxPixelSize = 2048

    /// Decodes image data, applies its EXIF orientation and downsizes to `maxPixelSize`.
    public static func normalizedImage(from data: Data, maxPixelSize: Int = ImageProcessing.maxPixelSize) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Downsizes an already-decoded image (orientation assumed upright).
    public static func resized(_ image: CGImage, maxPixelSize: Int) -> CGImage {
        let longest = max(image.width, image.height)
        guard longest > maxPixelSize else { return image }
        let scale = Double(maxPixelSize) / Double(longest)
        let w = max(1, Int(Double(image.width) * scale)), h = max(1, Int(Double(image.height) * scale))
        return render(image, width: w, height: h) ?? image
    }

    static func render(_ image: CGImage, width: Int, height: Int) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }

    /// Crops with a rect in normalized, top-left-origin coordinates.
    public static func crop(_ image: CGImage, normalizedRect r: CGRect) -> CGImage? {
        let rect = CGRect(x: r.minX * Double(image.width), y: r.minY * Double(image.height),
                          width: r.width * Double(image.width), height: r.height * Double(image.height)).integral
        return image.cropping(to: rect)
    }

    public static func jpegData(_ image: CGImage, quality: Double = 0.8) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    public static func pngData(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    /// RGBA8 pixel buffer of the image drawn at the given size.
    static func rgbaPixels(_ image: CGImage, width: Int, height: Int) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            ctx.interpolationQuality = .low
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return pixels
    }

    /// 64-bit difference hash. Near-identical images have a small Hamming distance.
    public static func dHash(_ image: CGImage) -> UInt64 {
        let w = 9, h = 8
        let px = rgbaPixels(image, width: w, height: h)
        func lum(_ x: Int, _ y: Int) -> Int {
            let i = (y * w + x) * 4
            return Int(px[i]) * 299 + Int(px[i + 1]) * 587 + Int(px[i + 2]) * 114
        }
        var hash: UInt64 = 0
        var bit: UInt64 = 0
        for y in 0..<h {
            for x in 0..<(w - 1) {
                if lum(x, y) > lum(x + 1, y) { hash |= (1 << bit) }
                bit += 1
            }
        }
        return hash
    }

    public static func hamming(_ a: UInt64, _ b: UInt64) -> Int { (a ^ b).nonzeroBitCount }
}
