import Foundation

/// Conversation categories for photo context labels.
public enum PhotoTheme: String, Codable, Sendable, CaseIterable {
    case pet, outdoors, travel, food, drinks, music, sport, water, snow, party, art, generic

    static let vocabulary: [PhotoTheme: [String]] = [
        .pet: ["dog", "puppy", "cat", "kitten", "pet", "animal", "horse", "retriever", "poodle", "terrier", "canine", "feline", "bulldog", "corgi"],
        .outdoors: ["mountain", "hiking", "hike", "trail", "forest", "camping", "tent", "cliff", "canyon", "desert", "national park", "rock", "valley", "waterfall", "summit", "peak"],
        .travel: ["landmark", "monument", "tower", "architecture", "airplane", "airport", "cathedral", "castle", "ruins", "bridge", "city", "street", "plaza", "colosseum", "eiffel", "passport", "europe", "italy", "paris", "tokyo"],
        .food: ["pizza", "food", "sushi", "pasta", "burger", "taco", "dessert", "cake", "bread", "noodle", "ramen", "restaurant", "brunch", "cooking", "kitchen", "baking"],
        .drinks: ["coffee", "cocktail", "wine", "beer", "bar", "latte", "espresso", "drink", "matcha"],
        .music: ["concert", "guitar", "music", "stage", "festival", "piano", "microphone", "drum", "vinyl", "dj", "crowd"],
        .sport: ["sport", "ball", "tennis", "soccer", "basketball", "football", "baseball", "golf", "climbing", "bicycle", "cycling", "running", "marathon", "gym", "yoga", "boxing", "pickleball", "volleyball", "stadium", "kayak"],
        .water: ["beach", "ocean", "sea", "lake", "surfing", "surfboard", "boat", "sailing", "pool", "swimming", "island", "coast", "shore", "snorkel", "diving"],
        .snow: ["snow", "ski", "skiing", "snowboard", "snowboarding", "glacier", "ice"],
        .party: ["party", "wedding", "costume", "halloween", "celebration", "birthday", "karaoke"],
        .art: ["museum", "gallery", "painting", "sculpture", "pottery", "ceramic", "theater", "book", "library", "camera", "photography"],
    ]

    public static func themes(for context: [String], caption: String?) -> [PhotoTheme] {
        let text = (context + [caption ?? ""]).joined(separator: " ").lowercased()
        let found = vocabulary.filter { _, words in words.contains { text.contains($0) } }.map(\.key)
        return found.isEmpty ? [.generic] : found.sorted { $0.rawValue < $1.rawValue }
    }
}

/// The on-device analyzer: scores every photo and prompt from text features alone. It is the
/// fallback when no AI provider is available and a stabilizer blended with provider scores.
public enum ProfileHeuristicAnalyzer {
    public struct Output: Sendable {
        public var photos: [PhotoAnalysis]
        public var prompts: [PromptAnalysis]
        public var targets: [TargetSignals]
    }

    public static func analyze(_ profile: DatingProfile, preferences: UserPreferences, dna: MessageDNA) -> Output {
        let prompts = profile.prompts.map { analyzePrompt($0, profile: profile) }
        let photos = profile.photos.map { analyzePhoto($0) }
        var targets: [TargetSignals] = []

        for (p, a) in zip(profile.prompts, prompts) {
            let words = TextFeatures.words(p.answer)
            let specificity = min(100, 25 + a.uniqueness / 2 + min(30, a.hooks.count * 10) + (words.count >= 4 ? 10 : 0))
            let reply = min(100, a.conversationPotential)
            let originality = min(100, a.uniqueness + (p.category == .opinion || p.category == .challenge ? 10 : 0))
            let styleFit = styleCompatibility(category: p.category, dna: dna)
            targets.append(TargetSignals(
                ref: TargetRef(.prompt, p.index), replyPotential: reply, specificity: specificity,
                humorPotential: a.humorPotential, flirtPotential: a.flirtPotential, originalityPotential: originality,
                styleCompatibility: styleFit, rationale: promptRationale(p, analysis: a)))
        }
        for ph in profile.photos {
            let themes = PhotoTheme.themes(for: ph.visibleContext, caption: ph.caption)
            let isGeneric = themes == [.generic]
            let captionBonus = ph.caption == nil ? 0 : 8
            let shows = ph.visibleContext.prefix(2).joined(separator: " & ").ifEmpty(ph.caption.map { "“\($0)”" } ?? "a scene")
            targets.append(TargetSignals(
                ref: TargetRef(.photo, ph.index),
                replyPotential: isGeneric ? 30 + captionBonus : 55 + captionBonus,
                specificity: isGeneric ? 22 + captionBonus * 2 : 48 + min(16, ph.visibleContext.count * 4) + captionBonus,
                humorPotential: isGeneric ? 35 : 58,
                flirtPotential: isGeneric ? 50 : 55,
                originalityPotential: isGeneric ? 25 : 50 + captionBonus,
                styleCompatibility: 55,
                rationale: isGeneric
                    ? "Photo #\(ph.index) has no clear activity or place to talk about, so any comment would be a generic looks compliment."
                    : "Photo #\(ph.index) shows \(shows), a concrete scene you can tease or ask about."))
        }
        return Output(photos: photos, prompts: prompts, targets: targets)
    }

    public static func analyzePrompt(_ p: ProfilePrompt, profile: DatingProfile) -> PromptAnalysis {
        let answer = p.answer
        let words = TextFeatures.words(answer)
        let content = TextFeatures.contentWords(answer)
        let category = p.category

        var humor = 30 + TextFeatures.countAny(answer, TextFeatures.humorMarkers) * 12 + TextFeatures.emojiCount(answer) * 6
        if [.opinion, .challenge, .claim, .quirk, .game].contains(category) { humor += 22 }
        if answer.contains("!") { humor += 4 }

        var flirt = 25 + TextFeatures.countAny(answer, TextFeatures.suggestiveProfileMarkers) * 14
        if [.lookingFor, .dateIdea, .claim].contains(category) { flirt += 25 }
        if TextFeatures.containsAny(answer, ["date", "kiss", "cute", "win me", "fall for", "attracted", "dinner", "drinks"]) { flirt += 15 }

        var conversation = 35 + min(25, content.count * 3)
        if TextFeatures.containsAny(answer, TextFeatures.opinionMarkers) { conversation += 20 }
        if TextFeatures.containsAny(answer, TextFeatures.challengeMarkers) { conversation += 18 }
        if answer.contains("?") { conversation += 10 }
        if [.opinion, .challenge, .game, .claim].contains(category) { conversation += 12 }
        if words.count <= 2 { conversation -= 15 }

        // Uniqueness: share of uncommon content words and concrete details (numbers, proper nouns).
        let rare = content.filter { $0.count >= 6 }.count
        let proper = answer.split(separator: " ").dropFirst().filter { $0.first?.isUppercase == true }.count
        let numbers = words.filter { Int($0) != nil }.count
        var uniqueness = 25 + min(35, rare * 8) + min(20, proper * 7) + min(10, numbers * 5)
        if TextFeatures.containsAny(answer, TextFeatures.clichés + ["travel", "the gym", "dogs", "my friends", "family", "netflix", "good food", "laugh", "adventure", "wine"]) && content.count < 5 { uniqueness -= 15 }

        var hooks = TopicExtractor.topics(in: answer, max: 3)
        if TextFeatures.containsAny(answer, TextFeatures.opinionMarkers) || category == .opinion { hooks.append("a take you can playfully disagree with") }
        if TextFeatures.containsAny(answer, TextFeatures.challengeMarkers) || category == .challenge { hooks.append("a challenge you can accept") }
        if category == .claim { hooks.append("a bold claim you can ask them to prove") }
        if category == .game { hooks.append("a game you can play along with") }

        return PromptAnalysis(index: p.index, question: p.question, answer: answer,
                              humorPotential: humor, flirtPotential: flirt, conversationPotential: conversation,
                              uniqueness: uniqueness, hooks: hooks)
    }

    public static func analyzePhoto(_ ph: ProfilePhoto) -> PhotoAnalysis {
        let themes = PhotoTheme.themes(for: ph.visibleContext, caption: ph.caption)
        var hooks: [String] = []
        if let c = ph.caption { hooks.append("caption: \(c)") }
        for theme in themes where theme != .generic {
            switch theme {
            case .pet: hooks.append("the pet — ask for an introduction or tease about who's the favourite")
            case .outdoors: hooks.append("the hike/outdoor spot — real hike vs photo-op tease")
            case .travel: hooks.append("the trip — ask for the story or the best spot")
            case .food: hooks.append("the food — challenge their taste or ask for the spot")
            case .drinks: hooks.append("the drink — judge the order playfully")
            case .music: hooks.append("the show — who they saw / music taste debate")
            case .sport: hooks.append("the sport — challenge them to a match")
            case .water: hooks.append("the water/beach — vacation story or skill tease")
            case .snow: hooks.append("the snow trip — ski vs snowboard debate")
            case .party: hooks.append("the event/costume — ask for the context")
            case .art: hooks.append("the art/culture spot — ask for a recommendation")
            case .generic: break
            }
        }
        let generic = themes == [.generic] && ph.caption == nil
        let potential = generic ? 30 : min(90, 55 + hooks.count * 10)
        return PhotoAnalysis(index: ph.index, visibleContext: ph.visibleContext, conversationHooks: hooks,
                             interactionPotential: potential, confidence: ph.visibleContext.isEmpty ? 0.4 : 0.7)
    }

    static func styleCompatibility(category: PromptCategory, dna: MessageDNA) -> Int {
        let v: Double
        switch category {
        case .opinion, .challenge: v = (dna.teasing + dna.humor) / 2
        case .claim, .quirk, .game: v = dna.humor
        case .lookingFor, .dateIdea: v = (dna.flirt + dna.directness) / 2
        default: v = (dna.humor + dna.flirt) / 2
        }
        return Int(30 + v * 70)
    }

    static func promptRationale(_ p: ProfilePrompt, analysis a: PromptAnalysis) -> String {
        switch p.category {
        case .opinion: "It's a take you can playfully argue with — banter beats a generic compliment."
        case .challenge: "It's a challenge — accepting it is an easy, confident opener with built-in back-and-forth."
        case .claim: "It's a bold claim — asking them to back it up is playful and easy to answer."
        case .game: "It's literally an invitation to play — answering in kind gets a reply."
        case .lookingFor: "It tells you what wins them over — you can show you fit, with a wink."
        case .dateIdea: "It's a date idea — you can build on it or counter-offer."
        case .food: "Food opinions are low-stakes and fun to tease."
        case .travel: "There's a story here they'll enjoy telling."
        case .quirk: "It's a quirky detail — perfect for a playful callback."
        default:
            a.hooks.isEmpty ? "It's the most specific thing they wrote." : "It has a specific detail (\(a.hooks[0])) that's easy to riff on."
        }
    }
}
