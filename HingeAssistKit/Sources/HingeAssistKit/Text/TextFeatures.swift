import Foundation

/// Small, dependency-free text utilities shared by the analyzers and critics.
public enum TextFeatures {
    public static func normalize(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "‘", with: "'")
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Lowercased word tokens (letters, digits and apostrophes).
    public static func words(_ s: String) -> [String] {
        let norm = normalize(s)
        var out: [String] = []
        var current = ""
        for ch in norm {
            if ch.isLetter || ch.isNumber || ch == "'" {
                current.append(ch)
            } else if !current.isEmpty {
                out.append(current.trimmingCharacters(in: CharacterSet(charactersIn: "'")))
                current = ""
            }
        }
        if !current.isEmpty { out.append(current.trimmingCharacters(in: CharacterSet(charactersIn: "'"))) }
        return out.filter { !$0.isEmpty }
    }

    /// Crude stemmer, good enough to match "hiking" with "hike" and "dogs" with "dog".
    public static func stem(_ w: String) -> String {
        var s = w
        if s.hasSuffix("'s") { s.removeLast(2) }
        for suffix in ["ing", "ers", "er", "ed", "es", "s"] where s.count > suffix.count + 2 && s.hasSuffix(suffix) {
            s.removeLast(suffix.count)
            if suffix == "ing" || suffix == "ed", s.count >= 3, let last = s.last, let prev = s.dropLast().last, last == prev { s.removeLast() }
            break
        }
        // "hike" and "hiking" -> "hik"; "date"/"dated" -> "dat".
        if s.count > 3, s.hasSuffix("e"), !s.hasSuffix("ee") { s.removeLast() }
        return s
    }

    /// Meaningful (non-stopword) stems of length >= 3.
    public static func contentStems(_ s: String) -> Set<String> {
        Set(words(s).filter { $0.count >= 3 && !stopwords.contains($0) && !Double($0).isNotNil }.map(stem))
    }

    public static func contentWords(_ s: String) -> [String] {
        words(s).filter { $0.count >= 3 && !stopwords.contains($0) }
    }

    public static func emojiCount(_ s: String) -> Int {
        s.unicodeScalars.filter { $0.properties.isEmojiPresentation || ($0.properties.isEmoji && $0.value > 0x238C) }.count
    }

    public static func containsAny(_ text: String, _ phrases: [String]) -> Bool {
        let t = " " + normalize(text) + " "
        return phrases.contains { t.contains($0) }
    }

    public static func countAny(_ text: String, _ phrases: [String]) -> Int {
        let t = " " + normalize(text) + " "
        return phrases.reduce(0) { $0 + (t.contains($1) ? 1 : 0) }
    }

    /// Fraction of letters that are lowercase in sentence-initial positions (1 = always lowercase starts).
    public static func lowercaseStartRatio(_ s: String) -> Double {
        let sentences = s.split(whereSeparator: { ".!?\n".contains($0) }).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !sentences.isEmpty else { return 0.5 }
        let lower = sentences.filter { $0.first.map { $0.isLowercase } ?? false }.count
        return Double(lower) / Double(sentences.count)
    }

    public static func jaccard(_ a: Set<String>, _ b: Set<String>) -> Double {
        guard !a.isEmpty || !b.isEmpty else { return 0 }
        return Double(a.intersection(b).count) / Double(a.union(b).count)
    }

    /// Longest run of consecutive words shared by both strings.
    public static func longestSharedRun(_ a: String, _ b: String) -> Int {
        let x = words(a), y = words(b)
        guard !x.isEmpty, !y.isEmpty else { return 0 }
        var best = 0
        var prev = [Int](repeating: 0, count: y.count + 1)
        for i in 1...x.count {
            var cur = [Int](repeating: 0, count: y.count + 1)
            for j in 1...y.count where x[i - 1] == y[j - 1] {
                cur[j] = prev[j - 1] + 1
                best = max(best, cur[j])
            }
            prev = cur
        }
        return best
    }

    /// Normalized similarity based on edit distance (0...1).
    public static func similarity(_ a: String, _ b: String) -> Double {
        let x = Array(normalize(a)), y = Array(normalize(b))
        if x.isEmpty && y.isEmpty { return 1 }
        if x.isEmpty || y.isEmpty { return 0 }
        var prev = Array(0...y.count)
        for i in 1...x.count {
            var cur = [i] + [Int](repeating: 0, count: y.count)
            for j in 1...y.count {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1))
            }
            prev = cur
        }
        return 1 - Double(prev[y.count]) / Double(max(x.count, y.count))
    }

    // MARK: - Lexicons

    public static let stopwords: Set<String> = [
        "the", "and", "for", "are", "but", "not", "you", "your", "you're", "all", "any", "can", "had", "her", "was", "one", "our", "out",
        "has", "him", "his", "how", "its", "it's", "let", "may", "now", "own", "say", "she", "too", "use", "who", "why", "yes", "yet",
        "with", "that", "this", "they", "them", "then", "than", "there", "their", "what", "when", "where", "which", "while", "will",
        "would", "could", "should", "about", "after", "again", "also", "been", "being", "both", "each", "from", "have", "here", "into",
        "just", "like", "more", "most", "much", "must", "only", "over", "same", "some", "such", "very", "were", "these", "those",
        "through", "under", "until", "upon", "well", "because", "before", "between", "does", "doing", "down", "during", "few",
        "further", "i'm", "i've", "i'll", "i'd", "don't", "doesn't", "didn't", "can't", "won't", "isn't", "aren't", "wasn't",
        "okay", "lol", "gonna", "wanna", "really", "actually", "literally", "thing", "things", "something", "anything", "everything",
        "get", "got", "make", "made", "know", "think", "want", "need", "going", "way", "lot", "kind", "sure", "maybe", "still",
        "even", "ever", "never", "always", "every", "other", "another", "off", "onto", "per", "via", "did", "said", "see", "seen",
        "that's", "what's", "there's", "let's", "we're", "they're", "she's", "he's", "who's", "here's", "yeah", "yep",
    ]

    /// Phrases that read like an assistant or polished marketing copy (Build Doc §16 verdict C).
    public static let aiPhrases: [String] = [
        "i couldn't help but notice", "couldn't help but notice", "i must say", "it's clear that", "it seems like you",
        "as an avid", "delve", "truly", "resonates", "embark", "i'd love to hear more", "i would love to hear", "i appreciate",
        "fascinating", "absolutely", "additionally", "furthermore", "moreover", "in conclusion", "certainly", "indeed",
        "a testament to", "intriguing", "it's evident", "your passion for", "your love for", "speaks volumes", "vibrant",
        "kindred spirit", "journey", "adventure awaits", "i'm curious to know", "i am curious", "what inspired you",
        "as someone who", "it's refreshing", "refreshing to see", "i noticed that you", "great taste in",
    ]

    /// Phrases that are generic advice-column openers (verdict B).
    public static let genericPhrases: [String] = [
        "hey how are you", "hi how are you", "how's your day", "how is your day", "how's your week", "what's up", "wyd",
        "you seem like a great person", "you seem really nice", "we have a lot in common", "you seem interesting",
        "you have a beautiful smile", "you have a nice smile", "you're beautiful", "you're gorgeous", "you are beautiful",
        "you are gorgeous", "you're so pretty", "you're cute", "you're hot", "nice profile", "love your profile",
        "great profile", "you look amazing", "hello beautiful", "hey beautiful", "hey gorgeous",
    ]

    /// Openers that turn the chat into an interview (verdict E).
    public static let interviewOpeners: [String] = [
        "what do you do", "what made you", "how long have you", "tell me more about", "tell me about", "what's your favorite",
        "what is your favorite", "where are you from", "do you like", "how was your", "what kind of", "what got you into",
        "how did you get into", "what's it like", "what is it like", "do you enjoy", "how often do you", "have you always",
        "what are you looking for", "what brings you",
    ]

    /// Pressure, surveillance or objectification (verdict D). Always rejected.
    public static let creepyPhrases: [String] = [
        "been staring", "can't stop looking", "can't stop staring", "your body", "i know where", "i found your",
        "send pics", "send me pics", "send a pic", "you owe me", "you'd better", "you better reply", "where do you live",
        "what's your address", "followed you", "looked you up", "your instagram", "your ig", "your last name",
        "i saw you at", "i've seen you", "answer me", "reply or", "why aren't you", "come over now", "good girl", "good boy",
        "obey", "you have no choice", "i won't take no",
    ]

    /// Graphic sexual terms. Never generated at any setting (Build Doc §12: prefer tension over graphic description).
    public static let graphicTerms: [String] = [
        " naked", " nude", " nudes", " sex ", " sexual", " orgasm", " cum ", " dick", " cock", " pussy", " tits", " boobs",
        " ass ", " blowjob", " horny", " fuck me", " fucking you", " in bed with you", " spread ", " moan", " thrust", " genital",
        " breasts", " nipple", " erotic", " porn", " bdsm", " kink", " daddy",
    ]

    /// Topics that must never be inferred from appearance or brought up unprompted (Build Doc §4, §26).
    public static let sensitiveTerms: [String] = [
        " race", " racial", " ethnic", " ethnicity", " skin color", " skin tone", " religion", " religious", " christian",
        " muslim", " jewish", " hindu", " buddhist", " atheist", " god ", " church", " mosque", " temple", " gay", " lesbian",
        " bisexual", " queer", " straight ", " trans ", " sexuality", " disabled", " disability", " wheelchair", " illness",
        " disease", " diagnosis", " depression", " anxiety", " adhd", " autism", " pregnant", " weight", " skinny", " chubby",
        " curvy", " thick ", " fat ", " body type", " income", " salary", " rich ", " poor ", " wealthy", " money", " politics",
        " political", " democrat", " republican", " liberal", " conservative", " trump", " biden", " immigrant", " accent",
        " exotic", " ethnic", " your age", " old for", " young for",
    ]

    /// Signals that the person may be under 18 (Build Doc §12, §26).
    public static let minorSignals: [String] = [
        "high school", "highschool", "in 9th grade", "in 10th grade", "in 11th grade", "in 12th grade", "freshman in hs",
        "sophomore in hs", "junior in hs", "senior in hs", "my parents won't let me", "16 y/o", "17 y/o", "16yo", "17yo",
        "15yo", "i'm 16", "i'm 17", "im 16", "im 17", "i am 16", "i am 17", "not 18", "underage", "minor", "homecoming",
        "learner's permit", "learners permit", "middle school",
    ]

    public static let humorMarkers: [String] = [
        "😂", "😭", "💀", "🤣", "okay but", "ok but", "respectfully", "bold claim", "insanely", "ridiculous", "unfair",
        "dangerous", "illegal", "criminal", "lawyer", "consequences", "defend yourself", "plot twist", "jury", "receipts",
        "be honest", "lowkey", "highkey", "no way", "imagine", "apparently", "technically", "allegedly", "suspicious",
        "red flag", "green flag", "chaos", "unhinged", "iconic", "not you", "the audacity", "audacity", "bro", "terms and conditions",
        "fine print", "payout", "disclaimer", "evidence", "investigation", "photo shoot", "brave",
    ]

    public static let teasingMarkers: [String] = [
        "bold claim", "fight me", "prove it", "defend yourself", "about to lose", "come second", "confidence", "doubt",
        "debate", "argument", "wrong", "settle this", "rematch", "challenge", "bet ", "i bet", "we'll see", "dangerous thing",
        "suspicious", "big talk", "talk is cheap", "receipts", "losing", "lose ", "beat you", "destroy", "competitive",
    ]

    /// Flirt cues by intensity tier. Index 0 = level 2 cues ... index 3 = level 5 cues.
    public static let flirtTiers: [[String]] = [
        ["cute", "adorable", "charming", "smile", "sweet", "dangerous combo", "unfair", "distracted", "trouble", "👀", "☺️", "😊"],
        ["date", "drinks", "drink ", "kiss", "attractive", "pretty", "handsome", "gorgeous", "stunning", "crush", "butterflies",
         "flirt", "😏", "😉", "falling for", "fall for", "swoon", "hot ", "worth it", "steal you", "take you out"],
        ["second date", "first date", "my place", "your place", "dare", "can't behave", "behave", "tension", "chemistry",
         "keep up with me", "tempt", "irresistible", "weak", "breathless", "late night", "after dark", "nightcap"],
        ["bedroom", "wicked", "naughty", " tie me", "handcuffs", "sinful", "spank", "undress", "make out", "can't keep my hands",
         "on top", "all night", "under the covers", "😈", "🍑", "🔥"],
    ]

    public static let clichés: [String] = [
        "you had me at", "is it hot in here", "did it hurt", "fell from heaven", "are you a magician", "come here often",
        "on a scale of 1 to 10", "netflix and chill", "you must be tired", "can i follow you home", "pizza or tacos",
        "two truths and a lie", "what's your love language", "favorite food", "travel buddy", "partner in crime",
        "adventure buddy", "the one", "soulmate", "wifey", "hubby", "mlady", "hey there",
    ]

    public static let replyHooks: [String] = [
        "?", "defend yourself", "prove it", "settle this", "which", "either", "or ", "bet", "dare", "rate", "guess",
        "convince me", "explain", "need to know", "tell me", "pick", "choose", "rematch", "challenge", "verdict",
        "who wins", "be honest", "what's the", "how many", "terms", "first round",
    ]

    public static let opinionMarkers: [String] = [
        "unpopular opinion", "controversial", "hot take", "overrated", "underrated", "fight me", "hill i will die on",
        "die on this hill", "change my mind", "debate", "disagree", "agree", "belongs", "doesn't belong", "is better than",
        "best", "worst", "should be illegal", "is a crime", "is not a", "superior", "inferior", "the only",
    ]

    public static let challengeMarkers: [String] = [
        "bet you", "i bet", "destroy you", "beat you", "challenge", "competitive", "i will win", "i'll win", "undefeated",
        "can't beat", "try me", "prove me wrong", "dare you", "race you", "loser buys", "best of three", "never lost",
        "mario kart", "chess", "trivia", "beer pong", "ping pong", "pickleball", "monopoly", "catan", "uno", "scrabble",
    ]

    public static let suggestiveProfileMarkers: [String] = [
        "😏", "😈", "😉", "🔥", "spicy", "bad influence", "behave", "trouble", "naughty", "flirt", "flirting", "kiss",
        "kissing", "chemistry", "tension", "after dark", "nightcap", "seduce", "tease", "teasing", "bedroom", "cuddle",
        "make out", "wild side", "dangerous", "sinful", "steamy", "thirst", "thirsty",
    ]

    public static let wholesomeProfileMarkers: [String] = [
        "family", "grandma", "grandmother", "my mom", "my dad", "volunteer", "baking", "bake", "cozy", "wholesome",
        "farmers market", "sunday dinner", "board games", "puzzle", "tea", "gardening", "knitting", "crochet", "reading",
        "book club", "walks", "nephew", "niece", "slow mornings", "home cooked", "kind", "kindness", "gentle",
    ]

    public static let boldProfileMarkers: [String] = [
        "fight me", "bold", "confident", "don't bother", "swipe left if", "dealbreaker", "i'm always right", "loud",
        "chaos", "unhinged", "zero chill", "no chill", "savage", "ruthless", "lottery", "you're welcome", "trust me",
        "destroy", "dominate", "obsessed", "ride or die",
    ]
}

extension Optional {
    var isNotNil: Bool { self != nil }
}
