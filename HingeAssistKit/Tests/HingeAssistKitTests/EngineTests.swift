import XCTest
@testable import HingeAssistKit

final class RankingTests: XCTestCase {
    func testInteractionScoreUsesBuildDocWeights() {
        let s = TargetSignals(ref: TargetRef(.prompt, 1), replyPotential: 100, specificity: 80, humorPotential: 60, flirtPotential: 40, originalityPotential: 20, styleCompatibility: 0, rationale: "")
        // 100*.30 + 80*.25 + 60*.15 + 40*.15 + 20*.10 + 0*.05 = 30 + 20 + 9 + 6 + 2 = 67
        XCTAssertEqual(InteractionRanker.score(s), 67)
    }

    func testRankingIsDeterministicAndPrefersPromptsOnTies() {
        let profile = SyntheticProfiles.maya
        let a = TargetSignals(ref: TargetRef(.photo, 2), replyPotential: 50, specificity: 50, humorPotential: 50, flirtPotential: 50, originalityPotential: 50, styleCompatibility: 50, rationale: "")
        let b = TargetSignals(ref: TargetRef(.prompt, 1), replyPotential: 50, specificity: 50, humorPotential: 50, flirtPotential: 50, originalityPotential: 50, styleCompatibility: 50, rationale: "")
        let r1 = InteractionRanker.rank([a, b], profile: profile)
        let r2 = InteractionRanker.rank([b, a], profile: profile)
        XCTAssertEqual(r1.map(\.ref), r2.map(\.ref))
        XCTAssertEqual(r1.first?.ref, TargetRef(.prompt, 1))
    }

    func testRankingDropsTargetsThatDoNotExist() {
        let ghost = TargetSignals(ref: TargetRef(.prompt, 9), replyPotential: 100, specificity: 100, humorPotential: 100, flirtPotential: 100, originalityPotential: 100, styleCompatibility: 100, rationale: "")
        XCTAssertTrue(InteractionRanker.rank([ghost], profile: SyntheticProfiles.maya).isEmpty)
    }

    func testLocalAnalyzerPrefersSpecificPromptOverBlankFirstPhoto() {
        let out = ProfileHeuristicAnalyzer.analyze(SyntheticProfiles.maya, preferences: .default, dna: .neutral)
        let ranked = InteractionRanker.rank(out.targets, profile: SyntheticProfiles.maya)
        XCTAssertEqual(ranked.first?.type, .prompt)
        XCTAssertNotEqual(ranked.first?.ref, TargetRef(.photo, 1))
        XCTAssertEqual(ranked.last?.type, .photo, "photos with no context should rank last")
        XCTAssertEqual(ranked.count, SyntheticProfiles.maya.prompts.count + SyntheticProfiles.maya.photos.count, "every photo and prompt is ranked")
    }
}

final class CriticTests: XCTestCase {
    func context(_ profile: DatingProfile = SyntheticProfiles.maya, target: TargetRef = TargetRef(.photo, 2), flirt: FlirtIntensity = .flirty, spicy: Bool = false, minor: Bool = false) -> CritiqueContext {
        let text: String
        switch target.type {
        case .prompt: text = profile.prompt(target.index).map { "\($0.question) — \($0.answer)" } ?? ""
        case .photo: text = profile.photo(target.index).map { ($0.visibleContext + [$0.caption ?? ""]).joined(separator: " ") } ?? ""
        }
        return CritiqueContext(profile: profile, target: target, targetText: text, hooks: [], flirtTarget: flirt, spicyAllowed: spicy, possibleMinor: minor, dna: .neutral)
    }

    func evaluate(_ text: String, style: CandidateStyle = .funny, _ ctx: CritiqueContext) -> ScoredCandidate {
        CommentCritic.evaluate(CommentCandidate(text: text, style: style, target: ctx.target, source: .local), context: ctx)
    }

    func testBuildDocWeakExampleIsRejectedAndBetterOneAccepted() {
        let ctx = context()
        let weak = evaluate("That's really interesting! What made you get into hiking?", ctx)
        XCTAssertTrue(weak.isRejected)
        let better = evaluate("okay but I need to know if this was an actual hike or a 20-minute walk followed by a photo shoot 😂", ctx)
        XCTAssertFalse(better.isRejected, better.rejectionReasons.joined(separator: ", "))
        XCTAssertEqual(better.verdict, .realPerson)
        XCTAssertGreaterThanOrEqual(better.scores.specificityRating, 3)
        XCTAssertGreaterThan(better.scores.total, weak.scores.total)
    }

    func testGenericComplimentFailsSpecificityTest() {
        let c = evaluate("You're gorgeous.", style: .complimentary, context())
        XCTAssertTrue(c.isRejected)
        XCTAssertLessThan(c.scores.specificityRating, 3)
    }

    func testCreepyAndGraphicMessagesAreRejected() {
        XCTAssertEqual(evaluate("I've been staring at your hiking pics, where do you live", context()).verdict, .creepy)
        let graphic = evaluate("that hike looks fun but I'd rather see you naked", style: .suggestive, context(flirt: .spicy, spicy: true))
        XCTAssertTrue(graphic.rejectionReasons.contains("Graphic sexual language"))
    }

    func testAssistantPhrasingIsFlaggedAsAIWritten() {
        let c = evaluate("I couldn't help but notice your passion for hiking — it truly resonates with me!", context())
        XCTAssertEqual(c.verdict, .aiGenerated)
        XCTAssertTrue(c.isRejected)
    }

    func testRepeatingTheProfileIsRejected() {
        let ctx = context(target: TargetRef(.prompt, 2))
        let c = evaluate("Pineapple belongs on pizza and I will die on this hill", ctx)
        XCTAssertTrue(c.rejectionReasons.contains("Just repeats the profile"))
    }

    func testFabricatedFactsAreRejected() {
        let ctx = context(target: TargetRef(.prompt, 2))
        let c = evaluate("pineapple on pizza in Tokyo with your ex? bold", ctx)
        XCTAssertTrue(c.rejectionReasons.contains { $0.hasPrefix("Assumes something not on the profile") })
    }

    func testSensitiveTraitsAreNeverBroughtUp() {
        let c = evaluate("love the hiking photo, are you religious?", context())
        XCTAssertTrue(c.rejectionReasons.contains("Brings up a sensitive trait"))
    }

    func testNoFlirtingWhenPersonMayBeAMinor() {
        let c = evaluate("the hike photo is cute but I'm distracted by you 👀", style: .flirty, context(flirt: .friendly, minor: true))
        XCTAssertTrue(c.rejectionReasons.contains("No flirting: the person may be under 18"))
    }

    func testSuggestiveNeedsSpicySetting() {
        let text = "that hike is cute but I bet you're even more trouble after dark 😈"
        XCTAssertTrue(evaluate(text, style: .suggestive, context(flirt: .bold, spicy: false)).isRejected)
        XCTAssertFalse(evaluate(text, style: .suggestive, context(flirt: .spicy, spicy: true)).rejectionReasons.contains("Too suggestive (Spicy Suggestions is off)"))
    }

    func testInterviewQuestionIsBoring() {
        XCTAssertEqual(CommentCritic.naturalness("How long have you been hiking for", specificity: 3), .boring)
    }

    func testRankerRemovesNearDuplicates() {
        let ctx = context(target: TargetRef(.prompt, 2))
        let a = evaluate("okay putting pineapple on pizza on your profile is insanely brave 😭 defend yourself", ctx)
        let b = evaluate("okay putting pineapple on pizza on your profile is insanely brave 😭 defend it", ctx)
        XCTAssertEqual(CandidateRanker.rank([a, b]).count, 1)
    }
}

final class FlirtCalibrationTests: XCTestCase {
    func profile(_ answer: String) -> DatingProfile {
        DatingProfile(name: "Sam", age: 28, prompts: [ProfilePrompt(index: 1, question: "My simple pleasures", answer: answer)], photos: [ProfilePhoto(index: 1)])
    }

    let wholesome = "Baking bread with my grandma, cozy board games and volunteering on weekends"
    let suggestive = "Flirting is a sport 😏 and I'm a bad influence after dark. Kiss me at the bar"

    func testAutoMatchesOrSlightlyExceedsProfileEnergy() {
        let p = profile(wholesome)
        let tone = FlirtCalibrator.tone(of: p)
        XCTAssertEqual(tone, .wholesome)
        let level = FlirtCalibrator.target(setting: .auto, tone: tone, dna: .neutral, preferences: .default, safety: SafetyAssessment.assess(p))
        XCTAssertEqual(level, .playful)
    }

    func testSpicyOnlyWithSettingAdultConfirmationAndSuggestiveProfile() {
        let p = profile(suggestive)
        let tone = FlirtCalibrator.tone(of: p)
        XCTAssertEqual(tone, .suggestive)
        var prefs = UserPreferences.default
        XCTAssertEqual(FlirtCalibrator.target(setting: .fixed(.spicy), tone: tone, dna: .neutral, preferences: prefs, safety: SafetyAssessment.assess(p)), .bold)
        prefs.spicySuggestions = true
        XCTAssertEqual(FlirtCalibrator.target(setting: .fixed(.spicy), tone: tone, dna: .neutral, preferences: prefs, safety: SafetyAssessment.assess(p)), .bold, "needs adult confirmation")
        prefs.isAdultConfirmed = true
        XCTAssertEqual(FlirtCalibrator.target(setting: .fixed(.spicy), tone: tone, dna: .neutral, preferences: prefs, safety: SafetyAssessment.assess(p)), .spicy)
        XCTAssertEqual(FlirtCalibrator.target(setting: .fixed(.spicy), tone: .wholesome, dna: .neutral, preferences: prefs, safety: SafetyAssessment.assess(profile(wholesome))), .bold, "profile must invite it")
    }

    func testPhotoContextNeverEscalatesTone() {
        var p = profile(wholesome)
        p.photos = [ProfilePhoto(index: 1, visibleContext: ["beach", "swimwear", "bikini"])]
        XCTAssertEqual(FlirtCalibrator.tone(of: p), .wholesome)
    }

    func testPossibleMinorForcesFriendly() {
        var p = profile(suggestive)
        p.otherText = ["high school senior lol"]
        let safety = SafetyAssessment.assess(p)
        XCTAssertTrue(safety.possibleMinor)
        var prefs = UserPreferences.default
        prefs.spicySuggestions = true; prefs.isAdultConfirmed = true
        XCTAssertEqual(FlirtCalibrator.target(setting: .fixed(.spicy), tone: .suggestive, dna: .neutral, preferences: prefs, safety: safety), .friendly)
    }
}

final class MessageDNATests: XCTestCase {
    func testAnalyzeReadsLowercaseAndEmojiHabits() {
        let dna = MessageDNA.analyze(messages: [
            "okay but that's a bold claim 😭", "lowkey obsessed with this", "nah you're wrong about tacos 😂",
            "bet. loser buys drinks", "this is unhinged and I love it 😭",
        ])
        XCTAssertGreaterThan(dna.lowercasePreference, 0.6)
        XCTAssertGreaterThan(dna.emojiFrequency, 0.35)
        XCTAssertLessThan(dna.averageLength, 60)
        XCTAssertEqual(dna.sampleCount, 5)
    }

    func testLearningMovesGraduallyWithCappedSteps() {
        var dna = MessageDNA.neutral
        let before = dna
        dna.learn(fromChosen: "I was gonna challenge you but I'm slightly distracted 👀", style: .flirty)
        XCTAssertGreaterThan(dna.flirt, before.flirt)
        XCTAssertLessThanOrEqual(dna.flirt - before.flirt, MessageDNA.maxStep + 1e-9)
        XCTAssertEqual(dna.sampleCount, 1)
    }

    func testRepeatedFeedbackShiftsDefaults() {
        var dna = MessageDNA.neutral
        for _ in 0..<5 { dna.applyFeedback(.flirtier) }
        XCTAssertGreaterThan(dna.flirt, MessageDNA.neutral.flirt + 0.15)
        let raised = dna.flirt
        for _ in 0..<3 { dna.applyFeedback(.tooMuch) }
        XCTAssertLessThan(dna.flirt, raised)
    }

    func testStyleApplierRespectsHabits() {
        var dna = MessageDNA.neutral
        dna.lowercasePreference = 0.9
        dna.emojiFrequency = 0.05
        XCTAssertEqual(StyleApplier.apply("Okay but that hike looks fake 😂", dna: dna, style: .funny), "okay but that hike looks fake")
    }
}

final class CompatibilityTests: XCTestCase {
    func testDealbreakerForcesSkip() {
        var p = SyntheticProfiles.maya
        p.basics.append("Smoker, sorry")
        let prefs = UserPreferences(dealbreakers: ["smoking"])
        let c = CompatibilityScorer.score(p, preferences: prefs)
        XCTAssertEqual(c.dealbreakersHit, ["smoking"])
        XCTAssertLessThanOrEqual(c.score, 35)
        XCTAssertEqual(CompatibilityScorer.recommendation(for: c, safety: SafetyAssessment.assess(p)), .skip)
    }

    func testNegatedDealbreakerDoesNotTrigger() {
        var p = SyntheticProfiles.maya
        p.otherText = ["I never smoke"]
        XCTAssertTrue(CompatibilityScorer.score(p, preferences: UserPreferences(dealbreakers: ["smoking"])).dealbreakersHit.isEmpty)
    }

    func testSharedInterestsAndIntentionRaiseScore() {
        let base = CompatibilityScorer.score(SyntheticProfiles.maya, preferences: UserPreferences(goal: .shortTermFun))
        let good = CompatibilityScorer.score(SyntheticProfiles.maya, preferences: UserPreferences(goal: .longTerm, interests: ["hiking", "gaming", "food"]))
        XCTAssertGreaterThan(good.score, base.score)
        XCTAssertTrue(good.reasons.contains { $0.contains("hiking") })
    }

    func testAgeOutsideRangeIsAConcern() {
        let c = CompatibilityScorer.score(SyntheticProfiles.maya, preferences: UserPreferences(ageMin: 30, ageMax: 40))
        XCTAssertTrue(c.concerns.contains { $0.hasPrefix("Age 27") })
    }

    func testProviderCannotOverrideDealbreaker() {
        let local = CompatibilityAssessment(score: 30, confidence: 0.7, dealbreakersHit: ["smoking"])
        let blended = CompatibilityScorer.blend(local: local, provider: CompatibilityAssessment(score: 99, confidence: 0.9))
        XCTAssertLessThanOrEqual(blended.score, 35)
    }
}

final class WingmanEngineTests: XCTestCase {
    func engine() -> WingmanEngine {
        WingmanEngine(router: ProviderRouter())
    }

    func testFullAnalysisChoosesOneTargetAndASpecificComment() async throws {
        var prefs = UserPreferences(goal: .longTerm, ageMin: 24, ageMax: 34, interests: ["gaming", "hiking"])
        prefs.isAdultConfirmed = true
        let a = try await engine().analyze(profile: SyntheticProfiles.maya, photos: [], preferences: prefs, dna: StylePreset.playfulBanter.seedDNA)
        XCTAssertEqual(a.photoAnalyses.count, 4)
        XCTAssertEqual(a.promptAnalyses.count, 3)
        XCTAssertEqual(a.rankedInteractionTargets.count, 7)
        XCTAssertEqual(a.recommendation, .like)
        let best = try XCTUnwrap(a.bestInteraction)
        XCTAssertNotEqual(best.target.ref, TargetRef(.photo, 1), "should not default to the first photo")
        let comment = try XCTUnwrap(best.comment)
        XCTAssertFalse(comment.isRejected)
        XCTAssertGreaterThanOrEqual(comment.scores.specificityRating, 3)
        XCTAssertFalse(best.alternatives.isEmpty)
        XCTAssertTrue(best.why.contains("Don't use the first photo"))
    }

    func testGeneratesAtLeastTwelveCandidatesInTheStandardMix() {
        let req = CandidateRequest(profile: SyntheticProfiles.maya, target: TargetRef(.prompt, 2), targetContext: "", hooks: [], preferences: .default, dna: .neutral, flirtTarget: .flirty, spicyAllowed: false, tone: .teasing)
        let c = LocalCommentGenerator.generate(req)
        XCTAssertGreaterThanOrEqual(c.count, 12)
        let base = Array(c.prefix(12)) // composed variants are appended after the base mix
        XCTAssertEqual(base.filter { $0.style == .funny }.count, 3)
        XCTAssertEqual(base.filter { $0.style == .flirty }.count, 3)
        XCTAssertEqual(base.filter { $0.style == .teasing }.count, 2)
        XCTAssertEqual(base.filter { $0.style == .complimentary }.count, 2)
        XCTAssertEqual(base.filter { $0.style == .bold }.count, 2)
        XCTAssertGreaterThan(c.count, base.count, "composed lead-in/closer variants are added")
        XCTAssertTrue(c.allSatisfy { $0.text.lowercased().contains("pineapple") })
    }

    func testRewriteChangesTheMessageAndRespectsDirection() async throws {
        let e = engine()
        let prefs = UserPreferences.default
        let a = try await e.analyze(profile: SyntheticProfiles.maya, photos: [], preferences: prefs, dna: .neutral)
        let original = try XCTUnwrap(a.bestInteraction?.comment?.text)
        let flirtier = await e.rewrite(a, direction: .flirtier, photos: [], preferences: prefs, dna: .neutral)
        let new = try XCTUnwrap(flirtier.bestInteraction?.comment)
        XCTAssertNotEqual(new.text, original)
        XCTAssertGreaterThanOrEqual(flirtier.bestInteraction!.flirtIntensity, a.bestInteraction!.flirtIntensity)
        let shorter = await e.rewrite(a, direction: .shorter, photos: [], preferences: prefs, dna: .neutral)
        XCTAssertLessThanOrEqual(try XCTUnwrap(shorter.bestInteraction?.comment?.text).count, 75)
    }

    func testRetargetToAnotherPromptOrPhoto() async throws {
        let e = engine()
        let a = try await e.analyze(profile: SyntheticProfiles.maya, photos: [], preferences: .default, dna: .neutral)
        let moved = await e.retarget(a, to: TargetRef(.photo, 3), photos: [], preferences: .default, dna: .neutral)
        XCTAssertEqual(moved.bestInteraction?.target.ref, TargetRef(.photo, 3))
        XCTAssertTrue(moved.bestInteraction?.comment?.text.lowercased().contains("dog") ?? false)
    }

    func testNoOpenerForPossibleMinor() async throws {
        var p = SyntheticProfiles.maya
        p.otherText = ["17 y/o, junior in hs"]
        let a = try await engine().analyze(profile: p, photos: [], preferences: .default, dna: .neutral)
        XCTAssertNil(a.bestInteraction)
        XCTAssertEqual(a.recommendation, .skip)
        XCTAssertFalse(a.safetyNotes.isEmpty)
    }

    func testEmptyProfileThrows() async {
        do {
            _ = try await engine().analyze(profile: DatingProfile(), photos: [], preferences: .default, dna: .neutral)
            XCTFail("expected error")
        } catch {
            XCTAssertEqual(error as? EngineError, .emptyProfile)
        }
    }

    func testProviderHallucinationsAreDiscarded() async throws {
        let bogus = ProviderAnalysis(
            targets: [TargetSignals(ref: TargetRef(.prompt, 42), replyPotential: 100, specificity: 100, humorPotential: 100, flirtPotential: 100, originalityPotential: 100, styleCompatibility: 100, rationale: "made up")],
            candidates: [CommentCandidate(text: "prompt 42 is iconic", style: .funny, target: TargetRef(.prompt, 42), source: .mock)])
        let mock = MockProvider(id: .mock, analysis: bogus)
        let e = WingmanEngine(router: ProviderRouter(providers: [mock], configuration: .init(order: [.mock, .local])))
        let a = try await e.analyze(profile: SyntheticProfiles.maya, photos: [], preferences: .default, dna: .neutral)
        XCTAssertFalse(a.rankedInteractionTargets.contains { $0.profileIndex == 42 })
        XCTAssertNotEqual(a.bestInteraction?.comment?.text, "prompt 42 is iconic")
    }
}

final class EvaluationSuiteTests: XCTestCase {
    func testHundredSyntheticProfilesMeetLaunchBar() async {
        let profiles = SyntheticProfiles.generate(count: 100)
        XCTAssertEqual(profiles.count, 100)
        let engine = WingmanEngine(router: ProviderRouter())
        let prefs = UserPreferences(goal: .longTerm, ageMin: 21, ageMax: 40, interests: ["food", "travel", "music"], dealbreakers: ["smoking"])
        let report = await EvaluationSuite.run(profiles: profiles, preferences: prefs, engine: engine)
        print(report)
        XCTAssertEqual(report.safetyViolations, 0, report.failures.joined(separator: "\n"))
        XCTAssertEqual(report.hallucinationRate, 0, report.failures.joined(separator: "\n"))
        XCTAssertEqual(report.rankingConsistency, 1)
        XCTAssertEqual(report.preferenceAdherence, 1, report.failures.joined(separator: "\n"))
        XCTAssertEqual(report.autoRejectedShown, 0, "specificity < 3 must never be shown")
        XCTAssertEqual(report.naturalPassRate, 1)
        XCTAssertEqual(report.withRecommendation, 98, report.failures.joined(separator: "\n"))
        XCTAssertGreaterThanOrEqual(report.meanSpecificity, 3)
        XCTAssertLessThanOrEqual(report.flirtCalibrationError, 1.5)
    }
}
