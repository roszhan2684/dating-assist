import Foundation

/// The opener writer. No generative AI: it fills style-specific templates (`TemplateLibrary`) with the
/// most specific phrase from the chosen photo/prompt, then composes variants with optional lead-ins
/// and closers. The critics filter them and your personal on-device model ranks what's left.
public enum LocalCommentGenerator {
    typealias Bank = TemplateLibrary.Bank

    public static func generate(_ req: CandidateRequest) -> [CommentCandidate] {
        let (topic, bank) = material(for: req)
        let other = callbackTopic(req)
        var mix: [(CandidateStyle, Int)] = CandidateStyle.standardMix
        if let direction = req.direction {
            // Rewrites: lean hard into the requested styles.
            mix = direction.preferredStyles.map { ($0, max(3, 12 / max(1, direction.preferredStyles.count))) }
        }
        if req.flirtTarget >= .bold { mix.append((.direct, 1)) }
        if req.spicyAllowed && req.flirtTarget == .spicy { mix.append((.suggestive, 2)) }
        if req.flirtTarget <= .friendly { mix = mix.filter { ![.flirty, .bold, .suggestive].contains($0.0) } + [(.funny, 2), (.teasing, 2)] }

        let avoid = Set(req.avoid.map(TextFeatures.normalize))
        var out: [CommentCandidate] = []
        var used = Set<String>()
        let seed = stableSeed(req.profile.allText + req.target.label + (req.direction?.rawValue ?? ""))
        for (style, count) in mix {
            // Angle-specific templates first; generic ones only top up.
            var templates = rotate(bank[style] ?? [], by: seed) + rotate(TemplateLibrary.lifestyle[style] ?? [], by: seed)
            if style == .suggestive { templates = rotate(TemplateLibrary.suggestive, by: seed) }
            var added = 0
            for t in templates where added < count {
                if t.contains("{t2}") && other == nil { continue }
                var text = t.replacingOccurrences(of: "{t}", with: topic)
                if let other { text = text.replacingOccurrences(of: "{t2}", with: other) }
                if req.direction == .shorter { text = shorten(text) }
                let key = TextFeatures.normalize(text)
                guard !used.contains(key), !avoid.contains(key) else { continue }
                used.insert(key)
                out.append(CommentCandidate(text: text, style: style, target: req.target, source: .local))
                added += 1
            }
        }
        // Composed variants: same line with a lead-in or a closer. The personal model learns which you prefer.
        if req.direction != .shorter {
            var variants: [CommentCandidate] = []
            for (i, c) in out.enumerated() {
                let pick = (seed + i) % TemplateLibrary.leadIns.count
                if let v = withLeadIn(c.text, TemplateLibrary.leadIns[pick]), used.insert(TextFeatures.normalize(v)).inserted {
                    variants.append(CommentCandidate(text: v, style: c.style, target: c.target, source: .local))
                }
                if let v = withCloser(c.text, TemplateLibrary.closers[(seed + i * 3) % TemplateLibrary.closers.count]), used.insert(TextFeatures.normalize(v)).inserted {
                    variants.append(CommentCandidate(text: v, style: c.style, target: c.target, source: .local))
                }
            }
            out += variants.filter { !avoid.contains(TextFeatures.normalize($0.text)) }
        }
        return out
    }

    static func withLeadIn(_ text: String, _ lead: String) -> String? {
        let lower = text.lowercased()
        let startsAlready = ["okay", "ok ", "not gonna", "respectfully", "be honest", "wait", "hold on", "real question", "so,", "i ", "i'", "bold claim", "{"]
        guard text.count < 95, !startsAlready.contains(where: { lower.hasPrefix($0) }) else { return nil }
        // Don't echo the lead-in's own word ("respectfully, ... I respect it").
        let roots = Set(TextFeatures.words(lead).filter { $0.count >= 5 }.map { String($0.prefix(6)) })
        let textRoots = Set(TextFeatures.words(text).filter { $0.count >= 5 }.map { String($0.prefix(6)) })
        guard roots.isDisjoint(with: textRoots) else { return nil }
        return lead + " " + (text.hasPrefix("I ") || text.hasPrefix("I'") ? text : text.prefix(1).lowercased() + text.dropFirst())
    }

    static func withCloser(_ text: String, _ closer: String) -> String? {
        guard text.count < 85, !text.contains("?"), TextFeatures.emojiCount(text) == 0 else { return nil }
        let lower = text.lowercased()
        guard !TemplateLibrary.closers.contains(where: { lower.hasSuffix($0.trimmingCharacters(in: .punctuationCharacters)) }) else { return nil }
        return text + ". " + closer
    }

    static func hasLeadIn(_ text: String) -> Bool {
        let lower = text.lowercased()
        return TemplateLibrary.leadIns.contains { lower.hasPrefix($0) }
    }

    static func hasCloser(_ text: String) -> Bool {
        let lower = text.lowercased()
        return TemplateLibrary.closers.contains { lower.hasSuffix($0) }
    }

    // MARK: - Material

    static func material(for req: CandidateRequest) -> (String, Bank) {
        switch req.target.type {
        case .prompt:
            guard let p = req.profile.prompt(req.target.index) else { return ("this", TemplateLibrary.lifestyle) }
            let topic = TopicExtractor.primaryTopic(in: p.answer)
            if p.category == .challenge, let game = challengeTopic(p) { return (game, TemplateLibrary.challenge) }
            return (topic, TemplateLibrary.bank(for: p.category))
        case .photo:
            guard let ph = req.profile.photo(req.target.index) else { return ("this photo", TemplateLibrary.lifestyle) }
            let themes = PhotoTheme.themes(for: ph.visibleContext, caption: ph.caption)
            let captionTopic = ph.caption.map { TopicExtractor.primaryTopic(in: $0) }
            let theme = themes.first { $0 != .generic } ?? .generic
            let topic = captionTopic ?? themeNoun(theme, context: ph.visibleContext)
            var bank = TemplateLibrary.photoBanks[theme] ?? [:]
            if captionTopic != nil {
                for (style, lines) in TemplateLibrary.travel { bank[style, default: []] += lines }
            }
            return (topic, bank)
        }
    }

    static func challengeTopic(_ p: ProfilePrompt) -> String? {
        let text = (p.question + " " + p.answer).lowercased()
        for game in ["mario kart", "chess", "trivia", "beer pong", "ping pong", "pickleball", "monopoly", "catan", "uno", "scrabble", "pool", "darts", "bowling", "tennis", "karaoke", "wordle", "smash"] where text.contains(game) {
            return game
        }
        return nil
    }

    static func themeNoun(_ theme: PhotoTheme, context: [String]) -> String {
        let vocab = PhotoTheme.vocabulary[theme] ?? []
        if let word = context.first(where: { c in vocab.contains { c.contains($0) } }) { return word }
        return context.first ?? "this photo"
    }

    static func callbackTopic(_ req: CandidateRequest) -> String? {
        for p in req.profile.prompts where !(req.target.type == .prompt && req.target.index == p.index) {
            let t = TopicExtractor.primaryTopic(in: p.answer)
            if t.count >= 4 { return t }
        }
        return nil
    }

    static func shorten(_ text: String) -> String {
        guard text.count > 60 else { return text }
        for sep in [". ", "? ", ", ", " but ", " and "] {
            if let r = text.range(of: sep), text.distance(from: text.startIndex, to: r.lowerBound) >= 18 {
                return String(text[..<r.lowerBound])
            }
        }
        return text
    }

    static func stableSeed(_ s: String) -> Int {
        var h: UInt64 = 1469598103934665603
        for b in s.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return Int(h % 997)
    }

    static func rotate(_ a: [String], by seed: Int) -> [String] {
        guard a.count > 1 else { return a }
        let k = seed % a.count
        return Array(a[k...] + a[..<k])
    }
}
