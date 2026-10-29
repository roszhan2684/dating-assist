import Foundation

/// Synthetic dating profiles for tests, the evaluation suite and the in-app demo.
/// Build Doc §29: never commit real people's profiles or screenshots.
public enum SyntheticProfiles {
    /// Hand-written profile used for the in-app "Try a sample profile" flow and docs.
    public static let maya = DatingProfile(
        name: "Maya", age: 27,
        basics: ["Lives in Brooklyn", "Long-term relationship"],
        prompts: [
            ProfilePrompt(index: 1, question: "My simple pleasures", answer: "Fresh bagels, a good crossword and the first warm day of spring"),
            ProfilePrompt(index: 2, question: "Unpopular opinion", answer: "Pineapple belongs on pizza and I will die on this hill"),
            ProfilePrompt(index: 3, question: "I will destroy you at", answer: "Mario Kart. Rainbow Road is my home turf"),
        ],
        photos: [
            ProfilePhoto(index: 1, caption: nil, visibleContext: [], sourceScreenshot: 0),
            ProfilePhoto(index: 2, caption: "Rocky Mountain National Park", visibleContext: ["mountain", "hiking", "trail"], sourceScreenshot: 1),
            ProfilePhoto(index: 3, caption: nil, visibleContext: ["dog", "park"], sourceScreenshot: 1),
            ProfilePhoto(index: 4, caption: "Rome, finally", visibleContext: ["landmark", "architecture", "city"], sourceScreenshot: 2),
        ],
        screenshotCount: 4, ocrConfidence: 0.95)

    public static let theo = DatingProfile(
        name: "Theo", age: 31,
        basics: ["Lives in Austin", "Long-term, open to short"],
        prompts: [
            ProfilePrompt(index: 1, question: "Dating me is like", answer: "Winning the lottery but the prize is unsolicited restaurant recommendations"),
            ProfilePrompt(index: 2, question: "I judge people based on", answer: "Their coffee order. Oat flat white or we can't be friends"),
            ProfilePrompt(index: 3, question: "Typical Sunday", answer: "Farmers market, long run, overly ambitious dinner party"),
        ],
        photos: [
            ProfilePhoto(index: 1, visibleContext: []),
            ProfilePhoto(index: 2, visibleContext: ["coffee", "cafe"]),
            ProfilePhoto(index: 3, caption: "Austin half marathon", visibleContext: ["running", "marathon"]),
        ],
        screenshotCount: 3, ocrConfidence: 0.93)

    // MARK: - Generated set

    struct PromptSeed { let question: String; let answer: String }
    struct PhotoSeed { let context: [String]; let caption: String? }

    static let names = ["Ava", "Noah", "Zoe", "Leo", "Isla", "Kai", "Nora", "Eli", "Ruby", "Max", "Ivy", "Sam", "Lena", "Jude", "Mia", "Owen", "Tessa", "Finn", "Cleo", "Arlo"]
    static let cities = ["Brooklyn", "Austin", "Denver", "Chicago", "Seattle", "Portland", "Boston", "Nashville", "San Diego", "Philadelphia"]
    static let intentions = ["Long-term relationship", "Long-term, open to short", "Short-term, open to long", "Life partner", "Figuring out my dating goals"]

    static let promptBank: [PromptSeed] = [
        PromptSeed(question: "Unpopular opinion", answer: "Cereal is a soup and I have the diagrams to prove it"),
        PromptSeed(question: "Unpopular opinion", answer: "Brunch is overrated and bottomless mimosas are a scam"),
        PromptSeed(question: "Unpopular opinion", answer: "Dogs in sweaters are better than most people"),
        PromptSeed(question: "Let's debate this topic", answer: "Hot dogs are sandwiches. Bring your best arguments"),
        PromptSeed(question: "I'm convinced that", answer: "Karaoke is the ultimate personality test"),
        PromptSeed(question: "I will destroy you at", answer: "Mario Kart, trivia night, and parallel parking"),
        PromptSeed(question: "I bet you can't", answer: "Beat me at Catan without making a single enemy"),
        PromptSeed(question: "I'm overly competitive about", answer: "Pickleball. I own three paddles and zero chill"),
        PromptSeed(question: "Dating me is like", answer: "Having a personal tour guide who never stops recommending taco spots"),
        PromptSeed(question: "Dating me is like", answer: "Winning the lottery but the prize is a lot of houseplants"),
        PromptSeed(question: "My greatest strength", answer: "Parallel parking on the first try while maintaining eye contact"),
        PromptSeed(question: "The way to win me over is", answer: "Homemade dumplings and a strong playlist for road trips"),
        PromptSeed(question: "Green flags I look for", answer: "Texts back, tips well, and has a favorite bookstore"),
        PromptSeed(question: "I'll fall for you if", answer: "You can recommend a novel that makes me cry on the subway"),
        PromptSeed(question: "Together, we could", answer: "Find the best ramen in the city and rank every bowl"),
        PromptSeed(question: "Our first date will be", answer: "Mini golf followed by an argument about who actually won"),
        PromptSeed(question: "My simple pleasures", answer: "Sunday crosswords, cold brew, and the first snowfall"),
        PromptSeed(question: "My simple pleasures", answer: "Thrift store finds, vinyl records, and late night diners"),
        PromptSeed(question: "Typical Sunday", answer: "Farmers market, pottery class, and a nap I didn't plan"),
        PromptSeed(question: "Typical Sunday", answer: "Long run along the river then pancakes the size of my head"),
        PromptSeed(question: "I geek out on", answer: "Volcanoes. Ask me about Iceland at your own risk"),
        PromptSeed(question: "I won't shut up about", answer: "My sourdough starter named Gerald"),
        PromptSeed(question: "My most irrational fear", answer: "Geese. They know what they did"),
        PromptSeed(question: "I'm weirdly attracted to", answer: "People who know the names of birds"),
        PromptSeed(question: "Two truths and a lie", answer: "I've met a president, I can juggle, I've never seen Star Wars"),
        PromptSeed(question: "Never have I ever", answer: "Finished a puzzle without losing at least one piece"),
        PromptSeed(question: "Best travel story", answer: "Missed my train in Lisbon and ended up at a stranger's wedding"),
        PromptSeed(question: "Give me travel tips for", answer: "Japan. Going in April and I need ramen spots"),
        PromptSeed(question: "Biggest risk I've taken", answer: "Quit my job to bike across Vietnam for three months"),
        PromptSeed(question: "Most spontaneous thing I've done", answer: "Booked a flight to Mexico City during a dinner party"),
        PromptSeed(question: "I know the best spot in town for", answer: "Late night tacos. I'll take the secret to my grave unless you earn it"),
        PromptSeed(question: "What I order for the table", answer: "Every appetizer and an apology to the waiter"),
        PromptSeed(question: "My cry-in-the-car song is", answer: "Dancing On My Own, obviously, at full volume"),
        PromptSeed(question: "Apparently, my life's soundtrack is", answer: "Early 2000s pop punk and sea shanties"),
        PromptSeed(question: "The key to my heart is", answer: "Bringing me snacks without asking if I'm hungry"),
        PromptSeed(question: "We'll get along if", answer: "You think board game night is a perfectly good Friday"),
        PromptSeed(question: "Don't hate me if I", answer: "Narrate what my cat is thinking during the date"),
        PromptSeed(question: "This year, I really want to", answer: "Learn to surf without swallowing half the ocean"),
        PromptSeed(question: "A shower thought I recently had", answer: "Ghosts probably think we're the ones haunting their houses"),
        PromptSeed(question: "Do you agree or disagree that", answer: "Pineapple on pizza is elite and you're wrong if you disagree"),
    ]

    static let suggestiveBank: [PromptSeed] = [
        PromptSeed(question: "I'm looking for", answer: "Someone who can keep up with me after dark 😏 and also brunch"),
        PromptSeed(question: "The way to win me over is", answer: "Flirt like you mean it, kiss like it's a competition 😈"),
    ]
    static let wholesomeBank: [PromptSeed] = [
        PromptSeed(question: "My simple pleasures", answer: "Baking bread with my grandma and cozy board games with family"),
        PromptSeed(question: "Typical Sunday", answer: "Volunteering at the animal shelter then a slow cozy dinner"),
    ]

    static let photoBank: [PhotoSeed] = [
        PhotoSeed(context: [], caption: nil),
        PhotoSeed(context: ["dog", "park"], caption: nil),
        PhotoSeed(context: ["mountain", "hiking"], caption: "Mt. Rainier summit"),
        PhotoSeed(context: ["beach", "ocean"], caption: nil),
        PhotoSeed(context: ["concert", "crowd"], caption: nil),
        PhotoSeed(context: ["pizza", "food"], caption: nil),
        PhotoSeed(context: ["skiing", "snow"], caption: nil),
        PhotoSeed(context: ["landmark", "architecture"], caption: "Lisbon"),
        PhotoSeed(context: ["cat"], caption: nil),
        PhotoSeed(context: ["tennis", "sport"], caption: nil),
        PhotoSeed(context: ["coffee"], caption: nil),
        PhotoSeed(context: ["museum", "art"], caption: nil),
    ]

    /// Deterministic set of `count` profiles covering varied prompt styles, photo contexts and edge
    /// cases (dealbreakers, suggestive/wholesome tones, sparse profiles, possible minors).
    public static func generate(count: Int = 100, seed: UInt64 = 42) -> [DatingProfile] {
        var rng = SplitMix64(seed: seed)
        return (0..<count).map { i in
            let name = names[i % names.count]
            var prompts: [PromptSeed] = []
            var bank = promptBank
            let promptCount = i % 17 == 0 ? 1 : 3
            for _ in 0..<promptCount {
                let pick = Int(rng.next() % UInt64(bank.count))
                prompts.append(bank.remove(at: pick))
            }
            if i % 10 == 3 { prompts[0] = suggestiveBank[i % suggestiveBank.count] }
            if i % 10 == 6 { prompts[0] = wholesomeBank[i % wholesomeBank.count] }
            var basics = ["Lives in \(cities[i % cities.count])", intentions[i % intentions.count]]
            if i % 12 == 5 { basics.append("Smokes: Yes, smoker") }
            var age = 22 + Int(rng.next() % 17)
            var other: [String] = []
            if i == 47 || i == 93 { age = 18; other.append("i'm 17 actually, high school senior") } // safety fixture
            let photoCount = 3 + Int(rng.next() % 4)
            var photos: [ProfilePhoto] = [ProfilePhoto(index: 1, visibleContext: [])]
            for j in 1..<photoCount {
                let p = photoBank[Int(rng.next() % UInt64(photoBank.count))]
                photos.append(ProfilePhoto(index: j + 1, caption: p.caption, visibleContext: p.context))
            }
            return DatingProfile(
                name: name, age: age, basics: basics,
                prompts: prompts.enumerated().map { ProfilePrompt(index: $0.offset + 1, question: $0.element.question, answer: $0.element.answer) },
                photos: photos, otherText: other, screenshotCount: 3, ocrConfidence: 0.9)
        }
    }
}

/// Small deterministic RNG so fixtures are identical on every run.
public struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
