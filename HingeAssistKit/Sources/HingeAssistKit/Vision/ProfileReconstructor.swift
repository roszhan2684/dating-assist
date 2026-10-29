import CoreGraphics
import Foundation

/// Where a reconstructed photo came from, so the app can crop it for vision models.
public struct PhotoSource: Codable, Hashable, Sendable {
    public var scanIndex: Int
    public var rect: CGRect
}

public struct ReconstructionResult: Codable, Hashable, Sendable {
    public var profile: DatingProfile
    public var photoSources: [Int: PhotoSource]
    public var duplicateScreenshots: [Int]
}

/// Turns all screenshots of one capture session into one `DatingProfile` (Build Doc §3, §23):
/// drops duplicate screenshots, removes text/photos repeated in overlapping scrolls, then reads
/// name, basics, prompts and photos in order.
public enum ProfileReconstructor {
    enum Element {
        case photo(PhotoRegion, scan: Int, caption: String?)
        /// `above`: the nearest line above it in the same screenshot (may be one already read earlier).
        case line(OCRLine, scan: Int, above: OCRLine?)
    }

    public static func reconstruct(_ scansIn: [ScreenshotScan]) -> ReconstructionResult {
        // 1. Duplicate screenshots.
        var scans: [ScreenshotScan] = []
        var duplicates: [Int] = []
        for scan in scansIn {
            if scan.hash != 0, scans.contains(where: { ImageProcessing.hamming($0.hash, scan.hash) <= 3 && $0.lines.map(\.text) == scan.lines.map(\.text) }) {
                duplicates.append(scan.index)
            } else {
                scans.append(scan)
            }
        }

        // 2. Build one ordered element stream with overlap removal.
        var elements: [Element] = []
        var seenLines: [String] = []
        var keptPhotoHashes: [UInt64] = []
        var lastPhotoTouchedBottom = false

        for (si, scan) in scans.enumerated() {
            // Line up with the previous screenshot using shared text, so anything already seen there is dropped.
            let shift = si > 0 ? scrollShift(scans[si - 1], scan) : nil
            // Rows above this were fully visible (not cut at the bottom edge) in the previous screenshot.
            let coveredUntil: Double = shift.map { (scans[si - 1].pixelSize.height * 0.995 - $0) / max(scan.pixelSize.height, 1) } ?? 0
            let sortedPhotos = scan.photos.sorted { $0.rect.minY < $1.rect.minY }

            var captionsByPhoto: [Int: [String]] = [:]
            var freeLines: [OCRLine] = []
            for line in scan.lines where !isNoise(line) {
                let center = CGPoint(x: line.box.midX, y: line.box.midY)
                if let pi = sortedPhotos.firstIndex(where: { $0.rect.insetBy(dx: -0.005, dy: -0.005).contains(center) }) {
                    if line.text.count >= 3 { captionsByPhoto[pi, default: []].append(line.text) }
                } else {
                    freeLines.append(line)
                }
            }

            var streamPhotos: [(PhotoRegion, String?)] = []
            var bottomPhotoKept = false
            for (pi, photo) in sortedPhotos.enumerated() {
                let caption = captionsByPhoto[pi].map { $0.joined(separator: " ") }
                let continuesPrevious: Bool
                if shift != nil {
                    if photo.rect.maxY <= coveredUntil { continue } // fully visible in the previous screenshot
                    continuesPrevious = photo.rect.minY < coveredUntil - 0.004
                } else {
                    continuesPrevious = pi == 0 && photo.touchesTop && lastPhotoTouchedBottom
                }
                // Same photo split across two screenshots: keep the taller part.
                if continuesPrevious,
                   let prevIdx = elements.lastIndex(where: { if case .photo = $0 { return true } else { return false } }),
                   case .photo(let prev, _, let prevCaption) = elements[prevIdx] {
                    if photo.rect.height > prev.rect.height {
                        elements[prevIdx] = .photo(photo, scan: scan.index, caption: caption ?? prevCaption)
                    } else if prevCaption == nil, let caption {
                        elements[prevIdx] = .photo(prev, scan: { if case .photo(_, let s, _) = elements[prevIdx] { return s } else { return scan.index } }(), caption: caption)
                    }
                    if photo.hash != 0 { keptPhotoHashes.append(photo.hash) }
                    if photo.touchesBottom { bottomPhotoKept = true }
                    continue
                }
                if shift == nil {
                    let partial = (photo.touchesTop || photo.touchesBottom) && photo.rect.height < 0.22
                    if partial { continue }
                    if photo.hash != 0, keptPhotoHashes.contains(where: { ImageProcessing.hamming($0, photo.hash) <= 8 }) { continue }
                }
                streamPhotos.append((photo, caption))
                if photo.hash != 0 { keptPhotoHashes.append(photo.hash) }
                if photo.touchesBottom { bottomPhotoKept = true }
            }
            lastPhotoTouchedBottom = bottomPhotoKept

            var scanElements: [(Double, Element)] = []
            for line in freeLines {
                if line.box.minY < 0.004 || line.box.maxY > 0.996 { continue } // cut-off line at the edge
                if shift != nil {
                    if line.box.maxY <= coveredUntil { continue } // already read in the previous screenshot
                } else {
                    let key = TextFeatures.normalize(line.text)
                    let repeated = key.count >= 12 ? seenLines.contains(key) : seenLines.suffix(8).contains(key)
                    if repeated { continue }
                }
                seenLines.append(TextFeatures.normalize(line.text))
                let above = freeLines.filter { $0.box.maxY <= line.box.minY + 0.004 && $0 != line }.max { $0.box.maxY < $1.box.maxY }
                scanElements.append((line.box.minY, .line(line, scan: scan.index, above: above)))
            }
            for (photo, caption) in streamPhotos {
                scanElements.append((photo.rect.minY, .photo(photo, scan: scan.index, caption: caption)))
            }
            elements += scanElements.sorted { $0.0 < $1.0 }.map(\.1)
        }

        // 3. Parse the stream.
        let heights = elements.compactMap { if case .line(let l, _, _) = $0 { return l.pixelHeight } else { return nil } }.sorted()
        let sizeSplit: Double? = {
            guard heights.count >= 3 else { return nil }
            let small = heights[heights.count / 4], large = heights[(heights.count * 3) / 4]
            return large / max(small, 1) >= 1.3 ? (small + large) / 2 : nil
        }()
        func isLarge(_ l: OCRLine) -> Bool? { sizeSplit.map { l.pixelHeight >= $0 } }

        var profile = DatingProfile(screenshotCount: scans.count)
        var photoSources: [Int: PhotoSource] = [:]
        var confidences: [Double] = []
        var pendingQuestion: [String] = []
        var answer: [String] = []
        var seenFirstContent = false

        func finishPrompt() {
            if !pendingQuestion.isEmpty, !answer.isEmpty {
                let q = pendingQuestion.joined(separator: " ")
                let question = HingePromptCatalog.match(q).map { m in prettyQuestion(q, catalog: m.question) } ?? q
                profile.prompts.append(ProfilePrompt(index: profile.prompts.count + 1, question: question, answer: answer.joined(separator: " ")))
            } else if !pendingQuestion.isEmpty {
                profile.otherText.append(pendingQuestion.joined(separator: " "))
            }
            pendingQuestion = []
            answer = []
        }

        for (i, element) in elements.enumerated() {
            switch element {
            case .photo(let region, let scan, let caption):
                finishPrompt()
                let index = profile.photos.count + 1
                profile.photos.append(ProfilePhoto(index: index, caption: caption, visibleContext: region.labels, sourceScreenshot: scan))
                photoSources[index] = PhotoSource(scanIndex: scan, rect: region.rect)
                seenFirstContent = true

            case .line(let line, _, let above):
                confidences.append(line.confidence)
                let text = line.text
                let next: OCRLine? = elements.dropFirst(i + 1).lazy.compactMap { if case .line(let l, _, _) = $0 { return l } else { return nil } }.first
                let large = isLarge(line)

                // Name (+ optional age) near the very top before any content.
                if profile.name == nil, !seenFirstContent, let (name, age) = parseName(text), large != false {
                    profile.name = name
                    if let age { profile.age = age }
                    continue
                }
                if profile.age == nil, let age = parseAge(text) {
                    profile.age = age
                    continue
                }
                // Tight line spacing right under the answer = same paragraph, whatever the glyph height says.
                if !pendingQuestion.isEmpty, !answer.isEmpty, let above, above.text == answer.last,
                   line.box.minY - above.box.maxY < 0.018, !isBasic(text), HingePromptCatalog.match(text) == nil {
                    answer.append(text)
                    continue
                }
                if looksLikeQuestion(line, next: next, large: large, nextLarge: next.flatMap(isLarge)) {
                    if !pendingQuestion.isEmpty, answer.isEmpty {
                        pendingQuestion.append(text) // wrapped question line
                    } else {
                        finishPrompt()
                        pendingQuestion = [text]
                    }
                    seenFirstContent = true
                    continue
                }
                if !pendingQuestion.isEmpty {
                    if large == false, !answer.isEmpty {
                        finishPrompt()
                    } else {
                        answer.append(text)
                        continue
                    }
                }
                if isBasic(text) {
                    profile.basics.append(text)
                } else {
                    profile.otherText.append(text)
                }
                seenFirstContent = true
            }
        }
        finishPrompt()

        profile.ocrConfidence = confidences.isEmpty ? 0 : confidences.reduce(0, +) / Double(confidences.count)
        profile.basics = profile.basics.uniqued()
        return ReconstructionResult(profile: profile, photoSources: photoSources, duplicateScreenshots: duplicates)
    }

    /// Pixel offset between consecutive screenshots (row in B + shift = row in A), from text both contain.
    static func scrollShift(_ a: ScreenshotScan, _ b: ScreenshotScan) -> Double? {
        let ha = a.pixelSize.height, hb = b.pixelSize.height
        let aLines = a.lines.filter { $0.text.count >= 4 && !isNoise($0) }
        var diffs: [Double] = []
        for lb in b.lines where lb.text.count >= 4 && !isNoise(lb) {
            let key = TextFeatures.normalize(lb.text)
            let matches = aLines.filter { TextFeatures.normalize($0.text) == key }
            if matches.count == 1 { diffs.append(matches[0].box.minY * ha - lb.box.minY * hb) }
        }
        guard !diffs.isEmpty else { return nil }
        let median = diffs.sorted()[diffs.count / 2]
        let agreeing = diffs.filter { abs($0 - median) < 0.012 * ha }
        guard median > 0, agreeing.count * 2 >= diffs.count else { return nil }
        return agreeing.reduce(0, +) / Double(agreeing.count)
    }

    // MARK: - Classification helpers

    static let uiWords: Set<String> = [
        "discover", "standouts", "likes you", "matches", "profile", "send like", "send rose", "add a comment", "skip", "undo",
        "active today", "active now", "recently active", "most compatible", "report", "hide", "block", "comment", "like",
        "send", "rose", "hinge", "new here", "nearby", "verified", "send a like", "send a rose", "add a comment...",
        "back", "next", "done", "cancel", "share", "more", "edit", "preferences", "settings", "you", "for you", "home",
        "messages", "chat", "boost", "superlike", "super like", "upgrade", "hinge+", "hingex", "x", "♡", "♥", "...", "•••",
    ]

    static func isNoise(_ line: OCRLine) -> Bool {
        let t = TextFeatures.normalize(line.text)
        if t.count <= 1 { return true }
        if uiWords.contains(t) { return true }
        if t.range(of: #"^\d{1,2}:\d{2}(\s?(am|pm))?$"#, options: .regularExpression) != nil { return true }
        if t.range(of: #"^\d{1,3}\s?%$"#, options: .regularExpression) != nil { return true }
        if ["5g", "lte", "4g", "wi-fi", "wifi", "sos"].contains(t) { return true }
        if line.box.minY < 0.045, t.count <= 6 { return true } // status bar
        return false
    }

    static func parseName(_ text: String) -> (String, Int?)? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        var namePart = trimmed
        var age: Int?
        if let comma = trimmed.firstIndex(of: ",") {
            namePart = String(trimmed[..<comma]).trimmingCharacters(in: .whitespaces)
            age = Int(trimmed[trimmed.index(after: comma)...].trimmingCharacters(in: .whitespaces)).flatMap { (18...99).contains($0) ? $0 : nil }
        }
        let words = namePart.split(separator: " ")
        guard (1...3).contains(words.count), namePart.count <= 24 else { return nil }
        guard words.allSatisfy({ w in w.first?.isUppercase == true && w.allSatisfy { $0.isLetter || $0 == "-" || $0 == "'" || $0 == "." } }) else { return nil }
        guard HingePromptCatalog.match(namePart) == nil, !isBasic(namePart) else { return nil }
        return (namePart, age)
    }

    static func parseAge(_ text: String) -> Int? {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard t.range(of: #"^\d{2}$"#, options: .regularExpression) != nil, let v = Int(t), (18...99).contains(v) else { return nil }
        return v
    }

    static func looksLikeQuestion(_ line: OCRLine, next: OCRLine?, large: Bool?, nextLarge: Bool?) -> Bool {
        let text = line.text
        if let m = HingePromptCatalog.match(text) {
            // Strong match unless this line is clearly answer-sized and the catalog key is short.
            return large != true || m.question.count >= 14
        }
        guard large == false, nextLarge == true, next != nil else { return false }
        let words = TextFeatures.words(text)
        guard words.count >= 3, words.count <= 14 else { return false }
        if text.hasSuffix(".") || text.hasSuffix("!") { return false }
        return !isBasic(text)
    }

    static let basicsPatterns: [String] = [
        #"^\d'\s?\d{1,2}"?$"#, #"^\d'\d{1,2}''$"#, #"^\d{3}\s?cm$"#,
    ]
    static let basicsWords: [String] = [
        "long-term", "long term", "short-term", "short term", "life partner", "figuring out", "monogamy", "non-monogamy",
        "lives in", "works at", "studied at", "hometown", "drinks", "drinking", "smokes", "smoking", "weed", "drugs", "sometimes",
        "socially", "never", "don't have children", "have children", "want children", "don't want children", "open to children",
        "not sure yet", "prefer not to say", "she/her", "he/him", "they/them", "virgo", "leo", "aries", "taurus", "gemini",
        "cancer", "libra", "scorpio", "sagittarius", "capricorn", "aquarius", "pisces", "university", "college", "bachelors",
        "masters", "phd", "undergrad", "grad school", "high school", "no pets", "dog", "cat",
    ]

    static func isBasic(_ text: String) -> Bool {
        let t = TextFeatures.normalize(text)
        if basicsPatterns.contains(where: { t.range(of: $0, options: .regularExpression) != nil }) { return true }
        let words = t.split(separator: " ")
        guard words.count <= 5 else { return false }
        return basicsWords.contains { t == $0 || t.hasPrefix($0 + " ") || t.hasSuffix(" " + $0) || (t.contains($0) && $0.count >= 8) }
    }

    /// Uses the catalog's wording but keeps OCR'd text when it has extra words (e.g. "I will destroy you at Mario Kart").
    static func prettyQuestion(_ ocr: String, catalog: String) -> String {
        // OCR keeps the app's real casing; fall back to the catalog wording only if OCR mangled it.
        TextFeatures.similarity(HingePromptCatalog.key(ocr).prefix(catalog.count + 2).description, HingePromptCatalog.key(catalog)) >= 0.9
            ? ocr.trimmingCharacters(in: .whitespaces)
            : catalog.prefix(1).uppercased() + catalog.dropFirst()
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
