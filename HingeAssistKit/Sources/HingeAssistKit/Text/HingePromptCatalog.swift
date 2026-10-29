import Foundation

public enum PromptCategory: String, Codable, Hashable, Sendable, CaseIterable {
    case opinion, challenge, claim, dateIdea, lookingFor, lifestyle, food, travel, story, quirk, game, music, general
}

/// Known dating-app prompt questions. Used to tell questions from answers in OCR text and to pick
/// the right comment angle. Matching is fuzzy so OCR mistakes and line wraps still match.
public enum HingePromptCatalog {
    public static let entries: [(String, PromptCategory)] = [
        ("unpopular opinion", .opinion),
        ("my most controversial opinion is", .opinion),
        ("let's debate this topic", .opinion),
        ("change my mind about", .opinion),
        ("do you agree or disagree that", .opinion),
        ("a shower thought i recently had", .opinion),
        ("i'll fall for you if", .lookingFor),
        ("i will destroy you at", .challenge),
        ("i bet you can't", .challenge),
        ("i'm overly competitive about", .challenge),
        ("i'm convinced that", .opinion),
        ("i judge people based on", .opinion),
        ("dating me is like", .claim),
        ("my greatest strength", .claim),
        ("i'm known for", .claim),
        ("believe it or not, i", .claim),
        ("the one thing you should know about me is", .claim),
        ("my most irrational fear", .quirk),
        ("i'm weirdly attracted to", .quirk),
        ("don't hate me if i", .quirk),
        ("my simple pleasures", .lifestyle),
        ("typical sunday", .lifestyle),
        ("my sunday is", .lifestyle),
        ("a perfect day", .lifestyle),
        ("i recently discovered that", .lifestyle),
        ("i geek out on", .lifestyle),
        ("i won't shut up about", .lifestyle),
        ("this year, i really want to", .lifestyle),
        ("a life goal of mine", .lifestyle),
        ("the way to win me over is", .lookingFor),
        ("green flags i look for", .lookingFor),
        ("i want someone who", .lookingFor),
        ("i'm looking for", .lookingFor),
        ("we'll get along if", .lookingFor),
        ("the key to my heart is", .lookingFor),
        ("you should not go out with me if", .lookingFor),
        ("the hallmark of a good relationship is", .lookingFor),
        ("my love language is", .lookingFor),
        ("let's make sure we're on the same page about", .lookingFor),
        ("i go crazy for", .lifestyle),
        ("together, we could", .dateIdea),
        ("our first date will be", .dateIdea),
        ("first round is on me if", .dateIdea),
        ("i know the best spot in town for", .food),
        ("what i order for the table", .food),
        ("the dorkiest thing about me is", .quirk),
        ("biggest risk i've taken", .story),
        ("best travel story", .travel),
        ("give me travel tips for", .travel),
        ("most spontaneous thing i've done", .story),
        ("worst idea i've ever had", .story),
        ("weirdest gift i have given or received", .story),
        ("two truths and a lie", .game),
        ("try to guess this", .game),
        ("never have i ever", .game),
        ("i'll pick the topic if you start the conversation", .game),
        ("teach me something about", .game),
        ("my cry-in-the-car song is", .music),
        ("apparently, my life's soundtrack is", .music),
        ("my karaoke song", .music),
        ("i'll brag about you to my friends if", .lookingFor),
        ("all i ask is that you", .lookingFor),
        ("my therapist would say i", .quirk),
        ("i get along best with people who", .lookingFor),
        ("i want to know more about", .lookingFor),
        ("i'm a regular at", .food),
        ("my golden rule", .claim),
        ("i feel most supported when", .lookingFor),
        ("a random fact i love is", .quirk),
        ("my best celebrity impression is", .quirk),
        ("my friends ask me for advice about", .claim),
        ("the best way to ask me out is", .dateIdea),
        ("i'm the type of texter who", .quirk),
        ("we're the same type of weird if", .quirk),
        ("if loving this is wrong, i don't want to be right", .opinion),
        ("you'd be lucky to have me because", .claim),
        ("boundary of mine", .lookingFor),
        ("i'd fall for you if", .lookingFor),
        ("my happy place", .lifestyle),
        ("i'm happiest when", .lifestyle),
    ]

    private static let normalizedEntries: [(String, PromptCategory)] = entries.map { (key($0.0), $0.1) }

    static func key(_ s: String) -> String {
        TextFeatures.words(s).joined(separator: " ")
    }

    /// Returns the matched catalog question if `line` looks like a known prompt question.
    public static func match(_ line: String) -> (question: String, category: PromptCategory)? {
        let k = key(line)
        guard k.count >= 6 else { return nil }
        for (i, (entry, cat)) in normalizedEntries.enumerated() {
            if k == entry || k.hasPrefix(entry) || (entry.hasPrefix(k) && k.count >= 12) {
                return (entries[i].0, cat)
            }
        }
        // Fuzzy: OCR errors.
        var best: (Int, Double) = (-1, 0)
        for (i, (entry, _)) in normalizedEntries.enumerated() {
            let comparable = String(k.prefix(entry.count + 2))
            let sim = TextFeatures.similarity(comparable, entry)
            if sim > best.1 { best = (i, sim) }
        }
        if best.0 >= 0, best.1 >= 0.84 { return (entries[best.0].0, entries[best.0].1) }
        return nil
    }

    public static func category(for question: String) -> PromptCategory {
        if let m = match(question) { return m.category }
        let q = TextFeatures.normalize(question)
        if TextFeatures.containsAny(q, ["opinion", "debate", "agree", "convinced", "controversial"]) { return .opinion }
        if TextFeatures.containsAny(q, ["bet", "compet", "beat", "destroy", "challenge"]) { return .challenge }
        if TextFeatures.containsAny(q, ["travel", "trip", "country"]) { return .travel }
        if TextFeatures.containsAny(q, ["food", "eat", "order", "restaurant", "cook"]) { return .food }
        if TextFeatures.containsAny(q, ["date", "together"]) { return .dateIdea }
        if TextFeatures.containsAny(q, ["looking for", "win me", "fall for", "green flag", "want someone"]) { return .lookingFor }
        if TextFeatures.containsAny(q, ["song", "music", "karaoke"]) { return .music }
        return .general
    }
}
