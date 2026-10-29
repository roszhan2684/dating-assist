import Foundation
import NaturalLanguage

/// Pulls short, specific noun phrases ("pineapple on pizza", "mario kart") out of profile text
/// using Apple's on-device NaturalLanguage tagger. Used for hooks and the local comment generator.
public enum TopicExtractor {
    public static func topics(in text: String, max limit: Int = 3) -> [String] {
        let cleaned = text.replacingOccurrences(of: "\n", with: ". ")
        guard !cleaned.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = cleaned
        var tokens: [(String, NLTag?)] = []
        tagger.enumerateTags(in: cleaned.startIndex..<cleaned.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitWhitespace]) { tag, range in
            tokens.append((String(cleaned[range]), tag))
            return true
        }

        // Chunks: (Adjective|Noun)* Noun, optionally "Noun on/of/in Noun" (e.g. "pineapple on pizza").
        var chunks: [[String]] = []
        var current: [String] = []
        var i = 0
        func flush() {
            while let last = current.last, TextFeatures.stopwords.contains(last.lowercased()) || ["on", "of", "in"].contains(last.lowercased()) { current.removeLast() }
            if !current.isEmpty { chunks.append(current) }
            current = []
        }
        while i < tokens.count {
            let (word, tag) = tokens[i]
            let lower = word.lowercased()
            if tag == .noun || tag == .adjective || (tag == .number && !current.isEmpty) {
                if TextFeatures.stopwords.contains(lower) || lower.count < 2 { flush() } else { current.append(word) }
            } else if (lower == "on" || lower == "of" || lower == "in"), !current.isEmpty, i + 1 < tokens.count, tokens[i + 1].1 == .noun {
                current.append(lower)
            } else {
                flush()
            }
            i += 1
        }
        flush()

        let generic: Set<String> = ["time", "people", "person", "life", "day", "days", "week", "weekend", "year", "years", "guy", "girl",
                                    "man", "woman", "friends", "friend", "someone", "anyone", "everyone", "thing", "things", "stuff",
                                    "place", "fun", "love", "world", "lot", "bit", "way", "part", "kind", "sort", "type", "favorite",
                                    "best", "good", "great", "new", "first", "last", "next", "other", "same", "big", "little", "one"]
        let scored: [(String, Double)] = chunks.compactMap { chunk in
            let words = chunk.map { $0.lowercased() }
            let contentWords = words.filter { !generic.contains($0) && !["on", "of", "in"].contains($0) }
            guard !contentWords.isEmpty else { return nil }
            let phrase = words.joined(separator: " ")
            guard phrase.count >= 3, phrase.count <= 40 else { return nil }
            let lengthScore = min(Double(contentWords.count), 3)
            let rarity = contentWords.reduce(0.0) { $0 + min(Double($1.count), 9) / 9 }
            let properNoun = chunk.contains { $0.first?.isUppercase == true } && chunk.first != tokens.first?.0 ? 0.6 : 0
            return (phrase, lengthScore + rarity + properNoun)
        }
        var seen = Set<String>()
        var result: [String] = []
        for (phrase, _) in scored.sorted(by: { $0.1 > $1.1 }) {
            let key = TextFeatures.contentStems(phrase)
            if result.contains(where: { TextFeatures.jaccard(TextFeatures.contentStems($0), key) > 0.5 }) { continue }
            if seen.insert(phrase).inserted { result.append(phrase) }
            if result.count >= limit { break }
        }
        if result.isEmpty {
            result = Array(TextFeatures.contentWords(text).filter { !generic.contains($0) }.prefix(limit))
        }
        return result
    }

    /// One best phrase for templating, falling back to a short slice of the text.
    public static func primaryTopic(in text: String) -> String {
        if let t = topics(in: text, max: 1).first {
            // Long phrases read clunky inside a message: keep the head ("restaurant recommendations").
            let words = t.split(separator: " ")
            return t.count > 30 && words.count > 2 ? words.suffix(2).joined(separator: " ") : t
        }
        return TextFeatures.words(text).prefix(4).joined(separator: " ")
    }
}
