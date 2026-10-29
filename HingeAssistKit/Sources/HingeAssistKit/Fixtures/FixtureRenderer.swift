import CoreGraphics
import CoreText
import Foundation

/// Renders a synthetic profile as realistic, scrolling dating-app screenshots (with status bar,
/// overlapping scroll positions, photo cards and prompt cards). Used by the OCR tests and the
/// in-app "Try a sample profile" demo so the full Vision pipeline runs on believable input.
public enum FixtureRenderer {
    public struct Options: Sendable {
        public var width = 1179
        public var screenHeight = 2556
        public var statusBarHeight = 140
        public var overlap = 520
        public var darkMode = false
        public init() {}
    }

    enum Block {
        case name(String)
        case basics([String])
        case photo(seed: Int, caption: String?)
        case prompt(question: String, answer: String)
    }

    /// Hinge-like order: name, photo 1, prompt 1, basics, then alternate photos and prompts.
    static func blocks(for profile: DatingProfile) -> [Block] {
        var blocks: [Block] = []
        if let name = profile.name { blocks.append(.name(name)) }
        var photos = profile.photos.makeIterator()
        var prompts = profile.prompts.makeIterator()
        if let p = photos.next() { blocks.append(.photo(seed: p.index, caption: p.caption)) }
        if let q = prompts.next() { blocks.append(.prompt(question: q.question, answer: q.answer)) }
        var basics = profile.basics
        if let age = profile.age { basics.insert(String(age), at: 0) }
        if !basics.isEmpty { blocks.append(.basics(basics)) }
        while true {
            let p = photos.next(), q = prompts.next()
            if p == nil && q == nil { break }
            if let p { blocks.append(.photo(seed: p.index, caption: p.caption)) }
            if let q { blocks.append(.prompt(question: q.question, answer: q.answer)) }
        }
        return blocks
    }

    public static func renderScreenshots(_ profile: DatingProfile, options: Options = Options()) -> [CGImage] {
        guard let canvas = renderCanvas(profile, options: options) else { return [] }
        let visible = options.screenHeight - options.statusBarHeight
        var offsets: [Int] = [0]
        while offsets.last! + visible < canvas.height {
            offsets.append(min(offsets.last! + visible - options.overlap, canvas.height - visible))
        }
        return offsets.compactMap { renderSlice(canvas, offset: $0, options: options) }
    }

    /// PNG data for each screenshot (handy for tests, previews and the share flow).
    public static func renderPNGs(_ profile: DatingProfile, options: Options = Options()) -> [Data] {
        renderScreenshots(profile, options: options).compactMap(ImageProcessing.pngData)
    }

    // MARK: - Drawing

    static func colors(_ dark: Bool) -> (bg: CGColor, card: CGColor, text: CGColor, secondary: CGColor) {
        dark
            ? (CGColor(gray: 0.0, alpha: 1), CGColor(gray: 0.11, alpha: 1), CGColor(gray: 0.96, alpha: 1), CGColor(gray: 0.7, alpha: 1))
            : (CGColor(gray: 1.0, alpha: 1), CGColor(gray: 0.965, alpha: 1), CGColor(gray: 0.08, alpha: 1), CGColor(gray: 0.35, alpha: 1))
    }

    static func font(_ size: Double, bold: Bool = false, serif: Bool = false) -> CTFont {
        let name = serif ? "Georgia" : (bold ? "Helvetica-Bold" : "Helvetica")
        return CTFontCreateWithName(name as CFString, size, nil)
    }

    static func attributed(_ text: String, font: CTFont, color: CGColor) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        ])
    }

    static func textHeight(_ s: NSAttributedString, width: Double) -> Double {
        let setter = CTFramesetterCreateWithAttributedString(s)
        let size = CTFramesetterSuggestFrameSizeWithConstraints(setter, CFRange(location: 0, length: s.length), nil, CGSize(width: width, height: .greatestFiniteMagnitude), nil)
        return ceil(size.height)
    }

    /// Draws text with its top-left at (x, yTop) in a top-down coordinate system of height `H`.
    static func draw(_ s: NSAttributedString, in ctx: CGContext, x: Double, yTop: Double, width: Double, canvasHeight H: Double) -> Double {
        let h = textHeight(s, width: width)
        let setter = CTFramesetterCreateWithAttributedString(s)
        let path = CGPath(rect: CGRect(x: x, y: H - yTop - h, width: width, height: h), transform: nil)
        let frame = CTFramesetterCreateFrame(setter, CFRange(location: 0, length: s.length), path, nil)
        CTFrameDraw(frame, ctx)
        return h
    }

    static func layoutHeight(_ blocks: [Block], width: Double) -> Double {
        var y = 60.0
        let inner = width - 96 - 96
        for b in blocks {
            switch b {
            case .name: y += 150
            case .basics(let items): y += Double(items.count) * 78 + 90
            case .photo: y += 1420 + 48
            case .prompt(let q, let a):
                y += 70 + textHeight(attributed(q, font: font(46, bold: true), color: CGColor(gray: 0, alpha: 1)), width: inner)
                y += 30 + textHeight(attributed(a, font: font(80, serif: true), color: CGColor(gray: 0, alpha: 1)), width: inner) + 90 + 48
            }
        }
        return y + 200
    }

    static func renderCanvas(_ profile: DatingProfile, options o: Options) -> CGImage? {
        let blocks = blocks(for: profile)
        let W = Double(o.width)
        let H = layoutHeight(blocks, width: W)
        guard let ctx = CGContext(data: nil, width: o.width, height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let c = colors(o.darkMode)
        ctx.setFillColor(c.bg)
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

        var y = 60.0
        let margin = 48.0
        let inner = W - 96 - 96
        for b in blocks {
            switch b {
            case .name(let name):
                _ = draw(attributed(name, font: font(96, bold: true), color: c.text), in: ctx, x: margin + 12, yTop: y, width: W - 2 * margin, canvasHeight: H)
                y += 150
            case .basics(let items):
                let cardH = Double(items.count) * 78 + 50
                fillRounded(ctx, CGRect(x: margin, y: H - y - cardH, width: W - 2 * margin, height: cardH), radius: 36, color: c.card)
                var yy = y + 30
                for item in items {
                    _ = draw(attributed(item, font: font(50), color: c.text), in: ctx, x: margin + 48, yTop: yy, width: inner, canvasHeight: H)
                    yy += 78
                }
                y += cardH + 40
            case .photo(let seed, let caption):
                let rect = CGRect(x: margin, y: H - y - 1420, width: W - 2 * margin, height: 1420)
                drawSyntheticPhoto(ctx, rect: rect, seed: seed)
                if let caption {
                    let s = attributed(caption, font: font(44, bold: true), color: CGColor(gray: 1, alpha: 1))
                    let pill = CGRect(x: rect.minX + 40, y: rect.minY + 50, width: min(rect.width - 80, Double(caption.count) * 26 + 70), height: 84)
                    fillRounded(ctx, pill, radius: 42, color: CGColor(gray: 0, alpha: 0.55))
                    _ = draw(s, in: ctx, x: pill.minX + 34, yTop: H - pill.maxY + 16, width: pill.width - 40, canvasHeight: H)
                }
                y += 1420 + 48
            case .prompt(let q, let a):
                let qs = attributed(q, font: font(46, bold: true), color: c.text)
                let as_ = attributed(a, font: font(80, serif: true), color: c.text)
                let qh = textHeight(qs, width: inner), ah = textHeight(as_, width: inner)
                let cardH = 70 + qh + 30 + ah + 90
                fillRounded(ctx, CGRect(x: margin, y: H - y - cardH, width: W - 2 * margin, height: cardH), radius: 36, color: c.card)
                _ = draw(qs, in: ctx, x: margin + 48, yTop: y + 70, width: inner, canvasHeight: H)
                _ = draw(as_, in: ctx, x: margin + 48, yTop: y + 70 + qh + 30, width: inner, canvasHeight: H)
                y += cardH + 48
            }
        }
        return ctx.makeImage()
    }

    static func renderSlice(_ canvas: CGImage, offset: Int, options o: Options) -> CGImage? {
        let W = o.width, H = o.screenHeight
        guard let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let c = colors(o.darkMode)
        ctx.setFillColor(c.bg)
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
        let visible = H - o.statusBarHeight
        // Canvas row `offset` (top-down) maps to screen row `statusBarHeight`.
        if let part = canvas.cropping(to: CGRect(x: 0, y: offset, width: W, height: min(visible, canvas.height - offset))) {
            ctx.draw(part, in: CGRect(x: 0, y: H - o.statusBarHeight - part.height, width: W, height: part.height))
        }
        ctx.setFillColor(c.bg)
        ctx.fill(CGRect(x: 0, y: H - o.statusBarHeight, width: W, height: o.statusBarHeight))
        _ = draw(attributed("9:41", font: font(48, bold: true), color: c.text), in: ctx, x: 120, yTop: 50, width: 200, canvasHeight: Double(H))
        _ = draw(attributed("100%", font: font(40, bold: true), color: c.text), in: ctx, x: Double(W) - 240, yTop: 55, width: 180, canvasHeight: Double(H))
        return ctx.makeImage()
    }

    static func fillRounded(_ ctx: CGContext, _ rect: CGRect, radius: Double, color: CGColor) {
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        ctx.setFillColor(color)
        ctx.fillPath()
    }

    /// A colorful abstract "photo": gradient sky, hills and a sun. Distinct per seed.
    static func drawSyntheticPhoto(_ ctx: CGContext, rect: CGRect, seed: Int) {
        var rng = SplitMix64(seed: UInt64(seed) &* 7919)
        func comp() -> Double { 0.15 + Double(rng.next() % 1000) / 1000 * 0.7 }
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 36, cornerHeight: 36, transform: nil))
        ctx.clip()
        let top = CGColor(red: comp(), green: comp(), blue: comp(), alpha: 1)
        let bottom = CGColor(red: comp() * 0.6, green: comp() * 0.6, blue: comp() * 0.6, alpha: 1)
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [bottom, top] as CFArray, locations: [0, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: rect.minX, y: rect.minY), end: CGPoint(x: rect.maxX, y: rect.maxY), options: [])
        }
        ctx.setFillColor(CGColor(red: 1, green: 0.85, blue: 0.4, alpha: 0.9))
        let r = 120 + Double(rng.next() % 80)
        ctx.fillEllipse(in: CGRect(x: rect.minX + 150 + Double(rng.next() % 600), y: rect.maxY - 450, width: r, height: r))
        for k in 0..<3 {
            ctx.setFillColor(CGColor(red: comp() * 0.5, green: comp() * 0.7, blue: comp() * 0.5, alpha: 1))
            let baseY = rect.minY + Double(k) * 140
            ctx.move(to: CGPoint(x: rect.minX, y: baseY))
            for x in stride(from: 0.0, through: rect.width, by: 60) {
                ctx.addLine(to: CGPoint(x: rect.minX + x, y: baseY + 250 + sin(x / 180 + Double(k)) * 120))
            }
            ctx.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            ctx.closePath()
            ctx.fillPath()
        }
        // Texture so it reads like a real photo (not a flat card).
        for _ in 0..<700 {
            ctx.setFillColor(CGColor(red: comp(), green: comp(), blue: comp(), alpha: 0.45))
            let s = 14 + Double(rng.next() % 60)
            ctx.fill(CGRect(x: rect.minX + Double(rng.next() % UInt64(rect.width)), y: rect.minY + Double(rng.next() % UInt64(rect.height)), width: s, height: s))
        }
        ctx.restoreGState()
    }
}
