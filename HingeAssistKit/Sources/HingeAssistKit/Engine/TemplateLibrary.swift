import Foundation

/// Opener templates. `{t}` is the most specific phrase from the chosen photo/prompt; `{t2}` is a
/// callback to another prompt. Every template contains `{t}` so outputs stay profile-specific.
/// The generator picks from these, adds optional lead-ins/closers, and the personal model ranks them.
enum TemplateLibrary {
    typealias Bank = [CandidateStyle: [String]]

    // MARK: - Composition fragments (the personal model learns which of these you like)

    static let leadIns = ["okay but", "not gonna lie,", "respectfully,", "be honest,", "wait,", "hold on,", "real question,", "so,"]
    static let closers = ["defend yourself", "be honest", "convince me", "your move", "I'll wait", "go on", "make your case", "thoughts?"]

    // MARK: - Prompt banks

    static let opinion: Bank = [
        .funny: [
            "okay putting {t} on your profile is insanely brave 😭 defend yourself",
            "you really said {t} publicly like there wouldn't be consequences 😭",
            "I respect the confidence but {t}?? we need to talk",
            "{t} is the kind of take that gets people uninvited from brunch 😂",
            "I've read {t} three times and I'm still recovering",
            "the audacity of {t} on a dating profile. iconic honestly",
            "{t} is a hostage situation and I'm the hostage 😭",
        ],
        .flirty: [
            "cute, but wrong about {t}. I'm willing to fix that over drinks 👀",
            "I'd lose a {t} debate to you on purpose honestly",
            "you're very attractive for someone this wrong about {t}",
            "I'd argue about {t} with you all night and still want a rematch 👀",
            "{t}? risky. luckily you're cute enough to get away with it",
            "wrong about {t} but somehow it's working for you",
        ],
        .teasing: [
            "this is either the greenest flag on your profile or the start of a very long argument about {t}",
            "bold of you to have opinions on {t} before hearing mine",
            "{t}? I've prepared a slideshow on why you're wrong",
            "I need you to know {t} is being reported to the authorities",
            "the {t} take is suspicious and I'm opening an investigation",
        ],
        .complimentary: [
            "a strong opinion on {t} and that smile is a dangerous combo",
            "respectfully, anyone this confident about {t} is my type",
            "I like someone who'll commit to {t} in writing",
            "{t} with zero hesitation? honestly attractive",
        ],
        .bold: [
            "wrong about {t}, right about everything else. first round's on me while you defend it",
            "let's settle the {t} thing in person. loser picks the second date",
            "{t} debate, one drink, winner picks the next spot",
            "I'm taking you out just to argue about {t}. clear your Thursday",
        ],
    ]

    static let challenge: Bank = [
        .funny: [
            "that's a lot of confidence about {t} for someone who's about to come second",
            "I've been training for this {t} moment my whole life 😭",
            "do you want a head start at {t} or is the ego fine",
            "I'd like to formally register as your {t} nemesis",
            "{t} trash talk before we've even met? I respect it 😂",
            "I'm putting my entire reputation on the line for this {t} match",
        ],
        .flirty: [
            "I was gonna let you win at {t} but you're making it hard to focus 👀",
            "careful, if you beat me at {t} I might actually fall for you",
            "winner of {t} picks the date. I'm already planning mine",
            "losing at {t} to you sounds weirdly okay 👀",
            "I'll play {t} with you, but I'm distracted in advance",
            "{t} rematch until one of us admits they're into the other",
        ],
        .teasing: [
            "big talk about {t}. best of three, loser buys drinks",
            "I'll need {t} receipts before I take this seriously",
            "{t}? cute. I've never lost and I don't plan to start",
            "your {t} confidence is adorable considering what's coming",
            "noted. {t} bragging rights are officially on the table",
        ],
        .complimentary: [
            "cute and competitive about {t}? that's an unfair combo",
            "anyone this confident about {t} is either a legend or a liar and I want to find out",
            "competitive about {t} and this charming? rude",
            "the {t} confidence is honestly a green flag",
        ],
        .bold: [
            "I'll let you win the first round of {t} if you make the rematch worth it",
            "name the time, {t} rematch. loser buys dinner",
            "{t} this week. if you win I'm buying, if I win you're buying round two",
            "let's play {t} for stakes. I already know what I want if I win",
        ],
    ]

    static let claim: Bank = [
        .funny: [
            "bold claim. I'm gonna need to see the {t} terms and conditions",
            "I need receipts on the {t} thing before I believe a word 😂",
            "okay but who verified the {t} claim 👀",
            "the {t} claim has big 'trust me bro' energy and I'm into it",
            "I'm requesting an independent audit of the {t} situation",
            "{t}? sounds like something a very confident liar would say 😂",
        ],
        .flirty: [
            "if the {t} claim checks out I might be in trouble",
            "I'm prepared to test the {t} claim personally",
            "you're making the {t} thing sound very convincing 👀",
            "the {t} thing might be true, the smile definitely is",
            "I'll believe the {t} thing after one date. maybe two",
            "{t} is a big promise. I'm willing to collect",
        ],
        .teasing: [
            "a lot of confidence about {t}. I'll be the judge of that",
            "the {t} claim is doing a lot of heavy lifting here",
            "{t}? I've heard that before. prove it",
            "I'm going to need a live demonstration of the {t} thing",
            "that {t} claim would hold up great in court. said no one",
        ],
        .complimentary: [
            "honestly the {t} confidence is attractive",
            "the {t} thing plus those photos is kind of unfair",
            "anyone who writes {t} with a straight face has my attention",
            "the {t} line made me smile, which was rude of you",
        ],
        .bold: [
            "prove the {t} thing over drinks. I'll be a very fair judge",
            "one date to verify the {t} claim. deal?",
            "let's test the {t} theory this weekend. I'll bring a clipboard",
            "{t}? put your money where your mouth is. Friday?",
        ],
    ]

    static let lookingFor: Bank = [
        .funny: [
            "{t}? I'm basically a professional. references available on request 😂",
            "you wrote {t} like it's a job requirement. consider this my application",
            "okay but what's the interview process for {t}",
            "{t} is very specific and I feel personally called out",
            "submitting my {t} resume, I've attached zero references",
            "{t}? I've been training for this role my whole life 😭",
        ],
        .flirty: [
            "{t}? I think I qualify, but you should probably check in person 👀",
            "{t} is easy. impressing you is the fun part",
            "I can do {t}. I can also make you laugh while doing it 👀",
            "{t} sounds great, especially if you're the one asking",
            "I read {t} and immediately started planning",
            "if {t} is the bar, I'm stepping over it confidently",
        ],
        .teasing: [
            "{t} is a very specific bar. lucky for you I've been practicing",
            "you say {t} like it's hard to find. I'm right here",
            "{t}? high standards. I respect it, I also meet them",
            "putting {t} in writing means I can hold you to it",
        ],
        .complimentary: [
            "anyone who asks for {t} has great taste, and it shows",
            "{t} and that smile, you're making this easy",
            "{t} is such a good thing to want. you seem lovely",
            "the {t} answer tells me you're a catch",
        ],
        .bold: [
            "{t}. this week. I'll handle the details",
            "let's skip ahead to the {t} part. when are you free?",
            "{t}? say less. I'm free Thursday",
            "I'll do {t} on the first date and you can grade me",
        ],
    ]

    static let game: Bank = [
        .funny: [
            "the lie is obviously {t} and I'm prepared to be wrong about that 😂",
            "my guess: {t} is the lie. if I'm right you owe me a coffee",
            "I've read this four times and {t} is still the most suspicious one 👀",
            "{t} is too weird to be a lie, which is exactly what a liar would want",
            "I'm locking in {t} as the lie. no takebacks 😭",
        ],
        .flirty: [
            "if {t} is true I'm impressed, if it's the lie I'm still impressed 👀",
            "I'll guess right about {t} if the prize is a date",
            "{t} is the lie. winner picks the bar?",
            "guessing {t}. if I'm right I get to ask you out properly",
            "{t}? I'd play this game with you all night",
        ],
        .teasing: [
            "{t} is way too specific to be made up, which means it's definitely the lie",
            "nice try with {t}. I see you",
            "{t} is giving 'I panicked and made something up'",
            "you thought {t} would fool me. adorable",
        ],
        .complimentary: [
            "every option here including {t} makes you sound like a lot of fun",
            "honestly {t} being true would make you even more interesting",
            "{t} or not, you seem like great company",
            "the {t} thing alone makes you the most interesting profile today",
        ],
        .bold: [
            "let's play the {t} game in person. loser buys round two",
            "tell me the truth about {t} over drinks",
            "I'll guess {t} wrong on purpose if it gets me a date",
            "{t}: I'll find out the truth on our first date",
        ],
    ]

    static let food: Bank = [
        .funny: [
            "{t}? I need to know if this is a recommendation or a warning 😂",
            "{t} on a dating profile is a power move and now I'm hungry",
            "I'd like to file a formal request for the {t} location",
            "{t} is a very strong opening argument",
            "my stomach read {t} before my brain did 😭",
        ],
        .flirty: [
            "{t} with you sounds like a perfect evening 👀",
            "share the {t} spot and I'll share the bill",
            "{t}? you're speaking my love language",
            "I'd split {t} with you, and I don't split food",
            "taking you for {t} would be a great excuse to see you again",
        ],
        .teasing: [
            "your {t} order says a lot and I'm judging very fairly",
            "{t}? I bet my spot is better",
            "I'm going to need to taste-test the {t} claim myself",
            "the {t} take is bold. I have counterarguments",
        ],
        .complimentary: [
            "great taste in {t}, which bodes well",
            "anyone into {t} this much is my kind of person",
            "{t} is such a good detail. you clearly know what's good",
            "{t} plus that smile is an elite combo",
        ],
        .bold: [
            "{t} date. you pick the place, I'll pick dessert",
            "let's settle the {t} question in person this week",
            "{t} on me. when are you free?",
            "first date: {t}. second date: you choose",
        ],
    ]

    static let travel: Bank = [
        .funny: [
            "{t}? okay now my weekend feels very boring 😭",
            "I need the {t} story and I'll know if you skip parts",
            "rate {t} out of 10, no diplomacy",
            "{t} is the kind of story that needs a whiteboard",
            "the {t} detail is carrying this whole profile 😂",
        ],
        .flirty: [
            "{t} sounds amazing but I'd rather hear about it from you 👀",
            "you + {t} is kind of unfair",
            "I'd follow you to {t} honestly",
            "tell me about {t} and I'll pretend I'm not jealous",
            "{t}? take me next time",
        ],
        .teasing: [
            "{t}? that's a bold flex for a first impression",
            "I'm assuming {t} was 90% airport snacks",
            "the {t} story better have a plot twist",
            "{t} is giving 'I'll mention this trip a lot'",
        ],
        .complimentary: [
            "{t} looks good on you",
            "the {t} detail tells me you're fun to travel with",
            "someone with a {t} story is instantly more interesting",
            "{t} plus that smile is kind of unfair",
        ],
        .bold: [
            "tell me the {t} story over drinks. I'll pick the place",
            "next trip like {t}, I'm carrying your bags",
            "{t} stories this week? I'm buying",
            "let's plan the sequel to {t}. drinks first",
        ],
    ]

    static let quirk: Bank = [
        .funny: [
            "{t} is the most relatable thing I've read today 😭",
            "the {t} confession has me crying",
            "{t}? valid. completely valid",
            "I came for the photos and stayed for {t}",
            "{t} is the plot of a very niche documentary and I'd watch it",
        ],
        .flirty: [
            "{t} is weirdly charming and I'm into it 👀",
            "you had me laughing at {t}, that's dangerous",
            "{t}? I like you more already",
            "the {t} thing is cute and I'm not taking questions",
            "I'd protect you from {t} honestly",
        ],
        .teasing: [
            "{t}? I have so many follow-up questions and zero chill",
            "I'm screenshotting {t} for future evidence",
            "{t} is either a red flag or my favorite flag",
            "{t}? we're going to need to discuss this",
        ],
        .complimentary: [
            "{t} is such a fun detail. you seem great",
            "anyone who admits {t} is my kind of person",
            "{t} made me smile, which is a big deal on this app",
            "{t} is the most honest thing on here and I love it",
        ],
        .bold: [
            "I need the full {t} story in person. Thursday?",
            "{t}? let's talk about it over drinks this week",
            "I'll trade you my weirdest secret for the {t} story",
            "tell me about {t} on a date and I'll tell you mine",
        ],
    ]

    static let music: Bank = [
        .funny: [
            "{t}? I need to know if you sing along or just cry quietly 😭",
            "{t} at full volume is a lifestyle and I respect it",
            "the {t} pick says a lot and I'm here for all of it",
            "{t}? okay now I know you're fun in a car",
            "I'd like to request {t} on our first road trip 😂",
        ],
        .flirty: [
            "{t} on repeat with you sounds like a great night 👀",
            "you, me and {t} in the car. I'm in",
            "{t}? I like your taste already",
            "I'd let you take the aux for {t}",
            "your {t} pick is attractive, not gonna lie",
        ],
        .teasing: [
            "your {t} taste is about to be judged very fairly",
            "{t}? we're going to have a music debate",
            "I bet I can top {t}. challenge accepted?",
            "{t} is a bold choice to admit publicly",
        ],
        .complimentary: [
            "great taste in {t}, which is rare",
            "{t} tells me you're a lot of fun",
            "anyone who loves {t} this much is my kind of person",
            "the {t} answer is the best one I've seen today",
        ],
        .bold: [
            "{t} karaoke this week. I'll go first",
            "let's find a bar that plays {t}. Friday?",
            "{t} road trip. you drive, I'll sing badly",
            "send me your {t} playlist and I'll pick the date spot",
        ],
    ]

    static let lifestyle: Bank = [
        .funny: [
            "okay but {t} on your profile is a power move 😭",
            "I need the full story behind {t} immediately",
            "{t} is either genius or chaos and I need to know which",
            "{t} AND {t2}? okay now you're just showing off 😭",
            "{t} sounds like the plot of a very good sitcom",
            "the {t} detail is doing a lot of work and I'm here for it",
        ],
        .flirty: [
            "I wasn't going to message first but {t} changed my mind 👀",
            "{t} and you? that's a very good combo",
            "{t} is a great start. I have ideas for the rest 👀",
            "{t} sounds perfect, especially with company",
            "I could get used to {t} with you",
            "{t} is cute. you're cuter",
        ],
        .teasing: [
            "ranking {t} that high is a bold choice. defend yourself",
            "{t}? I have notes. many notes",
            "{t} is a strong pick. mine's better though",
            "the {t} answer is suspicious in the best way",
            "I'm going to need you to justify {t}",
        ],
        .complimentary: [
            "someone into {t} is instantly more interesting to me",
            "{t} is such a good detail. you clearly have taste",
            "{t} tells me you're great company",
            "{t}? you seem like a genuinely fun person",
        ],
        .bold: [
            "{t} sounds like a great first date. I'll bring the snacks",
            "let me in on {t}. this weekend?",
            "{t} this weekend, you and me. yes or yes?",
            "I'm stealing {t} as our first date idea",
        ],
        .mysterious: [
            "I have a theory about {t} but I'll only tell you in person",
            "there's a {t} story I'm not telling you yet 👀",
            "you mentioned {t}. I have exactly one question and it's not the obvious one",
            "{t} reminded me of something. you'll have to earn the story",
            "I know something about {t} you don't. ask me nicely",
        ],
        .direct: [
            "I like your vibe and {t} sealed it. drinks this week?",
            "not gonna play it cool, {t} got me. want to grab a drink?",
            "{t} is my excuse to say hi. dinner Thursday?",
            "{t} was the moment I decided to message. coffee soon?",
            "simple: {t} made me smile, I'd like to take you out",
        ],
    ]

    static let suggestive: [String] = [
        "{t} is cute, but I have a feeling you're even more trouble after dark 😏",
        "careful, talk about {t} like that and I'll start getting ideas 😏",
        "I can think of a few ways to make {t} a lot more interesting 😏",
        "{t} first, then we see who can behave longer",
        "{t} sounds fun. I suspect you're more fun 😏",
        "I'd ruin {t} for you in the best possible way 😏",
    ]

    // MARK: - Photo banks

    static let photoBanks: [PhotoTheme: Bank] = [
        .pet: [
            .funny: ["okay but I need the {t}'s name before I can continue", "the {t} is clearly the main character of this profile 😭", "I'm here for the {t}, you can stay too", "the {t} looks like it has opinions and I respect that", "is the {t} single too 😂"],
            .flirty: ["the {t} is cute but I'm more distracted by the person next to it 👀", "if the {t} approves of me, do I get a date?", "two very good reasons to message you in this {t} photo", "the {t} and you is a very unfair combo 👀"],
            .teasing: ["be honest, is the {t} yours or a profile prop 👀", "the {t} has better photo instincts than most people on here", "I'm pretty sure the {t} is the one running this account"],
            .complimentary: ["you and the {t} are a very unfair combo", "that smile with the {t} is doing a ridiculous amount of work", "anyone the {t} likes this much has to be good people"],
            .bold: ["I'd like to formally request a walk with you and the {t}", "park date? I'll bring treats for you and the {t}", "introduce me to the {t} this weekend?"],
        ],
        .outdoors: [
            .funny: ["okay but was this {t} an actual hike or a 20-minute walk followed by a photo shoot 😂", "the {t} photo is giving 'I'll carry the snacks' energy", "how many summit selfies did it take to get this {t} shot", "I'm out of breath just looking at this {t} 😭"],
            .flirty: ["I was gonna compliment the {t} but you're making that unnecessarily difficult", "the {t} is nice but it's not the view I'm looking at 👀", "you + {t} is a very unfair combination", "I'd hike any {t} if you were at the top"],
            .teasing: ["be honest, who carried who up that {t}", "the {t} looks easy. I'm assuming you took the shortcut", "I bet I could beat you up that {t}"],
            .complimentary: ["the {t} photo is doing a ridiculous amount of work for your profile", "that smile at the top of the {t} is kind of unfair", "the {t} suits you"],
            .bold: ["next {t}, I'm coming. I'll carry the snacks", "show me your favorite {t} trail this weekend?", "{t} date. loser of the race buys tacos after"],
        ],
        .travel: [
            .funny: ["okay where was this {t} and why wasn't I invited 😭", "the {t} photo is making my weekend look very boring", "rate the {t} trip out of 10, be honest", "{t} looks great but I need to see the blooper reel 😂"],
            .flirty: ["the {t} is nice but I'd rather hear about it from you 👀", "you + {t} is kind of unfair", "I'd follow you to {t} honestly", "{t} looks good, you look better"],
            .teasing: ["{t}? that's a bold flex for a first impression", "I'm gonna need the {t} story, and I'll know if you skip parts", "the {t} photo is a humble brag and I see it"],
            .complimentary: ["the smile + {t} combination is kind of unfair", "{t} looks good on you", "you look so happy in this {t} photo"],
            .bold: ["tell me the {t} story over drinks. I'll pick the place", "next trip to {t}, I'm carrying your bags", "{t} stories this week? first round's mine"],
        ],
        .food: [
            .funny: ["the {t} photo is a power move and I'm hungry now 😭", "I need to know where this {t} is from, for research", "rate this {t} honestly. I'll know if you lie", "this {t} photo has main character energy"],
            .flirty: ["you and {t}? I'm interested in both 👀", "the {t} looks great but you're the reason I stopped scrolling", "share the {t} spot and I'll share the bill", "I'd split this {t} with you"],
            .teasing: ["{t} as a profile photo is a bold strategy. it's working", "I bet I know a better {t} spot", "posting {t} on here is a strong flex"],
            .complimentary: ["good taste in {t}, good taste in general it seems", "someone who posts {t} this proudly is my kind of person", "you look so happy with that {t}"],
            .bold: ["{t} date. I'm picking the place, you're picking the dessert", "let's find out who has better {t} taste. this week?", "{t} on me this weekend"],
        ],
        .drinks: [
            .funny: ["your {t} order says a lot about you and I need to hear it", "this {t} photo has main character energy 😭", "rate the {t}, be honest", "the {t} looks expensive and I'm scared"],
            .flirty: ["the {t} looks good but I'm more interested in who's holding it 👀", "I'd buy you a {t} just to hear your order", "you + {t} is a dangerous combo", "{t} with you sounds like a great evening"],
            .teasing: ["I'll judge your {t} order very fairly. probably", "a {t} that fancy is a bold choice", "I bet my {t} order beats yours"],
            .complimentary: ["clearly great {t} taste. I'm hoping that extends to people", "that {t} smile is very convincing", "you look like the best company at that {t} spot"],
            .bold: ["{t} on me this week. you choose the spot", "let me buy the next {t}. Thursday?", "{t} date. I'll find the place"],
        ],
        .music: [
            .funny: ["who was this {t} for and how loud did you scream 😭", "I need your top 3 from that {t} night, no thinking", "the {t} photo is giving 'knows every lyric' energy", "how many songs did you actually know at that {t}"],
            .flirty: ["I'd go to a {t} with you just to watch you sing along 👀", "your {t} taste + that smile is unfair", "next {t} we go together?", "I'd lose my voice at a {t} with you"],
            .teasing: ["your {t} taste is about to be judged very fairly", "be honest, how many songs did you know at that {t}", "I bet my {t} story is better"],
            .complimentary: ["the {t} energy in this photo is everything", "you look like the most fun person at that {t}", "great {t} taste is attractive"],
            .bold: ["next {t} is on me. you pick the band", "send me your {t} pick and I'll get tickets", "{t} this month, you and me?"],
        ],
        .sport: [
            .funny: ["okay but are you actually good at {t} or is this a very convincing photo 😭", "the {t} form is suspiciously good", "I'll need {t} stats before I believe this", "I'm scared of how competitive you look at {t} 😂"],
            .flirty: ["I'd lose at {t} to you on purpose 👀", "the {t} photo is distracting in the best way", "{t} rematch, winner picks the date", "you make {t} look very attractive"],
            .teasing: ["I could beat you at {t}. probably. maybe", "{t}? we'll see about that", "the {t} confidence is cute, I'm better though"],
            .complimentary: ["the {t} confidence is honestly attractive", "you make {t} look easy", "you look so happy playing {t}"],
            .bold: ["{t} this weekend. loser buys dinner", "let's play {t}. I'll book the court", "{t} match, drinks after, you're on"],
        ],
        .water: [
            .funny: ["okay but did you actually go in the {t} or just pose next to it 😭", "the {t} photo is making my week look sad", "rate this {t} trip out of 10", "how cold was the {t}, be honest 😂"],
            .flirty: ["the {t} is nice but it's not what I'm looking at 👀", "you and the {t}, that's an unfair combination", "I'd follow you to that {t} honestly", "{t} days with you sound great"],
            .teasing: ["{t} photo as a profile pic is a bold flex. it's working", "be honest, how cold was the {t}", "I bet I'm a better swimmer than this {t} photo suggests you are"],
            .complimentary: ["that {t} smile is doing a lot of work", "the {t} looks good on you", "you look so relaxed at the {t}"],
            .bold: ["next {t} day, I'm coming. I'll bring the snacks", "let's find a {t} spot this summer. you lead", "{t} day this weekend?"],
        ],
        .snow: [
            .funny: ["{t} trip: ski or snowboard, choose carefully, this decides everything 😭", "the {t} photo is giving 'fell twice, still cute' energy", "how many times did you fall before this {t} shot", "I'm cold just looking at this {t} photo 😂"],
            .flirty: ["the {t} is cold but this photo isn't 👀", "I'd freeze on a {t} trip with you honestly", "you + {t} gear is unfairly cute", "{t} trip and hot chocolate with you sounds perfect"],
            .teasing: ["I'm assuming you stayed on the bunny slope for this {t} shot", "{t} photo, sure, but can you actually ski", "I'd beat you down any {t} run"],
            .complimentary: ["the {t} glow is real", "that {t} smile is kind of unfair", "you look so happy in the {t}"],
            .bold: ["next {t} trip, I'm in. hot chocolate's on me", "let's go up for {t} this season. you pick the mountain", "{t} weekend? I'll drive"],
        ],
        .party: [
            .funny: ["I need the context behind this {t} photo immediately 😭", "the {t} energy here is chaotic and I respect it", "rate this {t} night out of 10", "this {t} photo has a story and I want it"],
            .flirty: ["you look like the most fun person at that {t} 👀", "invite me to the next {t}?", "this {t} photo is distracting", "I'd crash that {t} for you"],
            .teasing: ["I feel like this {t} has a story you're not telling", "be honest, who started the {t} chaos", "the {t} photo is suspicious in a fun way"],
            .complimentary: ["main character energy at the {t}", "you make that {t} look fun", "you clearly light up a {t}"],
            .bold: ["next {t}, I'm your plus one", "let's make our own {t}. this weekend?", "{t} stories over drinks this week?"],
        ],
        .art: [
            .funny: ["are you the type to read every {t} plaque, be honest 😭", "I need your {t} hot take immediately", "this {t} photo is very cultured of you", "you look like you'd critique the {t} lighting 😂"],
            .flirty: ["the {t} is nice but you're the one I'm looking at 👀", "take me to your favorite {t}?", "{t} and you, very good combo", "I'd let you give me a {t} tour"],
            .teasing: ["you look like you'd judge my {t} opinions", "{t} photo? I see you being cultured", "I bet I'd last longer at the {t} than you"],
            .complimentary: ["clearly great {t} taste", "the {t} vibe suits you", "you look right at home at the {t}"],
            .bold: ["{t} date, you're the tour guide", "let's do a {t} afternoon this week", "{t} this weekend, coffee after?"],
        ],
    ]

    static func bank(for category: PromptCategory) -> Bank {
        switch category {
        case .opinion: opinion
        case .challenge: challenge
        case .claim: claim
        case .lookingFor, .dateIdea: lookingFor
        case .game: game
        case .food: food
        case .travel, .story: travel
        case .quirk: quirk
        case .music: music
        case .lifestyle, .general: lifestyle
        }
    }

    /// Total number of templates, for docs/tests.
    static var count: Int {
        let banks: [Bank] = [opinion, challenge, claim, lookingFor, game, food, travel, quirk, music, lifestyle] + Array(photoBanks.values)
        return banks.reduce(0) { $0 + $1.values.reduce(0) { $0 + $1.count } } + suggestive.count + leadIns.count + closers.count
    }
}
