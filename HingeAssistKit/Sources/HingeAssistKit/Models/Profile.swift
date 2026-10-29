import Foundation

/// One prompt (question + answer) read from the profile. `index` is 1-based, in profile order.
public struct ProfilePrompt: Codable, Hashable, Sendable, Identifiable {
    public var id: Int { index }
    public let index: Int
    public var question: String
    public var answer: String

    public init(index: Int, question: String, answer: String) {
        self.index = index
        self.question = question
        self.answer = answer
    }

    public var category: PromptCategory { HingePromptCatalog.category(for: question) }
}

/// One photo found in the profile. Only non-sensitive visible context is kept (scene/object labels
/// and any caption text). `index` is 1-based, in profile order.
public struct ProfilePhoto: Codable, Hashable, Sendable, Identifiable {
    public var id: Int { index }
    public let index: Int
    public var caption: String?
    public var visibleContext: [String]
    public var sourceScreenshot: Int

    public init(index: Int, caption: String? = nil, visibleContext: [String] = [], sourceScreenshot: Int = 0) {
        self.index = index
        self.caption = caption
        self.visibleContext = visibleContext
        self.sourceScreenshot = sourceScreenshot
    }
}

/// The complete profile rebuilt from every screenshot in one capture session.
public struct DatingProfile: Codable, Hashable, Sendable {
    public var name: String?
    public var age: Int?
    public var basics: [String]
    public var prompts: [ProfilePrompt]
    public var photos: [ProfilePhoto]
    public var otherText: [String]
    public var screenshotCount: Int
    /// Mean OCR confidence (0-1) across the lines that were used.
    public var ocrConfidence: Double

    public init(
        name: String? = nil,
        age: Int? = nil,
        basics: [String] = [],
        prompts: [ProfilePrompt] = [],
        photos: [ProfilePhoto] = [],
        otherText: [String] = [],
        screenshotCount: Int = 0,
        ocrConfidence: Double = 1
    ) {
        self.name = name
        self.age = age
        self.basics = basics
        self.prompts = prompts
        self.photos = photos
        self.otherText = otherText
        self.screenshotCount = screenshotCount
        self.ocrConfidence = ocrConfidence
    }

    public func prompt(_ index: Int) -> ProfilePrompt? { prompts.first { $0.index == index } }
    public func photo(_ index: Int) -> ProfilePhoto? { photos.first { $0.index == index } }

    public var isEmpty: Bool { prompts.isEmpty && photos.isEmpty && basics.isEmpty }

    /// Every piece of written profile text, used for tone, compatibility and fact-checking.
    public var allText: String {
        var parts: [String] = []
        if let name { parts.append(name) }
        if let age { parts.append(String(age)) }
        parts += basics
        for p in prompts { parts.append(p.question); parts.append(p.answer) }
        for ph in photos { if let c = ph.caption { parts.append(c) } }
        parts += otherText
        return parts.joined(separator: "\n")
    }

    /// Text the person wrote themselves (answers and captions), excluding app-provided questions.
    public var authoredText: String {
        (prompts.map(\.answer) + photos.compactMap(\.caption) + otherText).joined(separator: "\n")
    }

    /// Plain-text rendering used in AI prompts and for debugging.
    public func renderedForModel(includePhotoContext: Bool = true) -> String {
        var lines: [String] = []
        if let name { lines.append("Name: \(name)") }
        if let age { lines.append("Age: \(age)") }
        if !basics.isEmpty { lines.append("Basics: \(basics.joined(separator: " · "))") }
        for p in prompts {
            lines.append("Prompt #\(p.index): \"\(p.question)\" — \"\(p.answer)\"")
        }
        for ph in photos {
            var desc = "Photo #\(ph.index):"
            if includePhotoContext, !ph.visibleContext.isEmpty { desc += " visible context [\(ph.visibleContext.joined(separator: ", "))]" }
            if let c = ph.caption { desc += " caption \"\(c)\"" }
            if ph.visibleContext.isEmpty && ph.caption == nil { desc += " (no readable context)" }
            lines.append(desc)
        }
        if !otherText.isEmpty { lines.append("Other text: \(otherText.joined(separator: " | "))") }
        return lines.joined(separator: "\n")
    }
}
