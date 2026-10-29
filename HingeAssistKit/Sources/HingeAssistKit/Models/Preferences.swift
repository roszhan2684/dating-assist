import Foundation

public enum RelationshipGoal: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    case lifePartner, longTerm, longTermOpenToShort, shortTermOpenToLong, shortTermFun, figuringOut

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .lifePartner: "Life partner"
        case .longTerm: "Long-term relationship"
        case .longTermOpenToShort: "Long-term, open to short"
        case .shortTermOpenToLong: "Short-term, open to long"
        case .shortTermFun: "Short-term fun"
        case .figuringOut: "Still figuring it out"
        }
    }

    /// Phrases Hinge shows in the "dating intentions" basic.
    var profilePhrases: [String] {
        switch self {
        case .lifePartner: ["life partner"]
        case .longTerm: ["long-term relationship", "long term relationship"]
        case .longTermOpenToShort: ["long-term, open to short", "long term, open to short"]
        case .shortTermOpenToLong: ["short-term, open to long", "short term, open to long"]
        case .shortTermFun: ["short-term fun", "short term fun"]
        case .figuringOut: ["figuring out my dating goals", "figuring it out", "figuring out"]
        }
    }

    /// 0 = opposite intent, 1 = same intent.
    func alignment(with other: RelationshipGoal) -> Double {
        let order: [RelationshipGoal] = [.lifePartner, .longTerm, .longTermOpenToShort, .shortTermOpenToLong, .shortTermFun]
        if self == other { return 1 }
        if self == .figuringOut || other == .figuringOut { return 0.6 }
        guard let a = order.firstIndex(of: self), let b = order.firstIndex(of: other) else { return 0.5 }
        return max(0, 1 - Double(abs(a - b)) * 0.28)
    }

    static func detect(in text: String) -> RelationshipGoal? {
        let lower = text.lowercased()
        // Check longer phrases first so "long-term, open to short" wins over "long-term relationship".
        let ordered: [RelationshipGoal] = [.longTermOpenToShort, .shortTermOpenToLong, .lifePartner, .longTerm, .shortTermFun, .figuringOut]
        return ordered.first { goal in goal.profilePhrases.contains { lower.contains($0) } }
    }
}

public enum FlirtIntensity: Int, Codable, Hashable, Sendable, CaseIterable, Comparable, Identifiable {
    case friendly = 1
    case playful = 2
    case flirty = 3
    case bold = 4
    case spicy = 5

    public var id: Int { rawValue }

    public static func < (lhs: FlirtIntensity, rhs: FlirtIntensity) -> Bool { lhs.rawValue < rhs.rawValue }

    public init(clamping value: Int) {
        self = FlirtIntensity(rawValue: min(max(value, 1), 5)) ?? .playful
    }

    public var label: String {
        switch self {
        case .friendly: "Friendly"
        case .playful: "Playful"
        case .flirty: "Flirty"
        case .bold: "Bold"
        case .spicy: "Spicy"
        }
    }
}

/// AUTO matches (or slightly exceeds) the profile's own energy; fixed pins a level.
public enum FlirtSetting: Codable, Hashable, Sendable {
    case auto
    case fixed(FlirtIntensity)

    public var label: String {
        switch self {
        case .auto: "Auto"
        case .fixed(let level): level.label
        }
    }
}

public enum StylePreset: String, Codable, Hashable, Sendable, CaseIterable, Identifiable {
    case playfulBanter, dryWit, warmCharming, boldConfident, chaoticFunny

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .playfulBanter: "Playful banter"
        case .dryWit: "Dry wit"
        case .warmCharming: "Warm & charming"
        case .boldConfident: "Bold & confident"
        case .chaoticFunny: "Chaotic funny"
        }
    }

    public var blurb: String {
        switch self {
        case .playfulBanter: "teasing, light, lots of back-and-forth"
        case .dryWit: "deadpan, understated, clever"
        case .warmCharming: "sweet, specific compliments, easygoing"
        case .boldConfident: "direct, sure of yourself, date-forward"
        case .chaoticFunny: "unhinged in a good way, big energy, emojis"
        }
    }

    /// Starting MessageDNA for people who'd rather pick a preset than paste examples.
    public var seedDNA: MessageDNA {
        switch self {
        case .playfulBanter:
            MessageDNA(averageLength: 70, emojiFrequency: 0.35, lowercasePreference: 0.7, humor: 0.7, teasing: 0.75, flirt: 0.5, directness: 0.45, boldness: 0.5, questionFrequency: 0.4, slang: 0.5)
        case .dryWit:
            MessageDNA(averageLength: 60, emojiFrequency: 0.05, lowercasePreference: 0.8, humor: 0.75, teasing: 0.55, flirt: 0.35, directness: 0.5, boldness: 0.4, questionFrequency: 0.25, slang: 0.3)
        case .warmCharming:
            MessageDNA(averageLength: 85, emojiFrequency: 0.3, lowercasePreference: 0.35, humor: 0.45, teasing: 0.3, flirt: 0.55, directness: 0.5, boldness: 0.35, questionFrequency: 0.55, slang: 0.2)
        case .boldConfident:
            MessageDNA(averageLength: 65, emojiFrequency: 0.15, lowercasePreference: 0.5, humor: 0.5, teasing: 0.5, flirt: 0.7, directness: 0.85, boldness: 0.85, questionFrequency: 0.3, slang: 0.35)
        case .chaoticFunny:
            MessageDNA(averageLength: 75, emojiFrequency: 0.7, lowercasePreference: 0.9, humor: 0.9, teasing: 0.6, flirt: 0.45, directness: 0.4, boldness: 0.6, questionFrequency: 0.35, slang: 0.75)
        }
    }
}

/// The user's dating preferences (the five onboarding preferences plus flirt settings).
public struct UserPreferences: Codable, Hashable, Sendable {
    public var goal: RelationshipGoal
    public var ageMin: Int
    public var ageMax: Int
    public var interests: [String]
    public var dealbreakers: [String]
    public var greenFlags: [String]
    public var flirtSetting: FlirtSetting
    /// Build Doc §12: OFF by default; requires adult confirmation.
    public var spicySuggestions: Bool
    public var isAdultConfirmed: Bool
    public var stylePreset: StylePreset

    public init(goal: RelationshipGoal = .longTerm, ageMin: Int = 21, ageMax: Int = 35, interests: [String] = [], dealbreakers: [String] = [], greenFlags: [String] = [], flirtSetting: FlirtSetting = .auto, spicySuggestions: Bool = false, isAdultConfirmed: Bool = false, stylePreset: StylePreset = .playfulBanter) {
        self.goal = goal
        self.ageMin = ageMin
        self.ageMax = ageMax
        self.interests = interests
        self.dealbreakers = dealbreakers
        self.greenFlags = greenFlags
        self.flirtSetting = flirtSetting
        self.spicySuggestions = spicySuggestions
        self.isAdultConfirmed = isAdultConfirmed
        self.stylePreset = stylePreset
    }

    /// Spicy output is allowed only when the adult setting is on and the user confirmed they're 18+.
    public var spicyAllowed: Bool { spicySuggestions && isAdultConfirmed }

    public static let `default` = UserPreferences()
}
