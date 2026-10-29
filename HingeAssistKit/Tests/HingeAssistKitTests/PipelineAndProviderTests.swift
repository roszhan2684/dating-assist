import CoreGraphics
import XCTest
@testable import HingeAssistKit

final class ScreenshotPipelineTests: XCTestCase {
    func assertMatches(_ got: DatingProfile, _ expected: DatingProfile, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(got.name, expected.name, file: file, line: line)
        XCTAssertEqual(got.age, expected.age, file: file, line: line)
        XCTAssertEqual(got.prompts.map(\.question), expected.prompts.map(\.question), file: file, line: line)
        XCTAssertEqual(got.prompts.map(\.answer), expected.prompts.map(\.answer), file: file, line: line)
        XCTAssertEqual(got.photos.count, expected.photos.count, "photo count", file: file, line: line)
        XCTAssertEqual(got.photos.map(\.caption), expected.photos.map(\.caption), file: file, line: line)
        XCTAssertEqual(Set(got.basics), Set(expected.basics), file: file, line: line)
    }

    func testRebuildsCompleteProfileFromOverlappingScreenshots() async throws {
        let shots = FixtureRenderer.renderPNGs(SyntheticProfiles.maya)
        XCTAssertGreaterThanOrEqual(shots.count, 3, "profile should span several screenshots")
        let out = try await ScreenshotPipeline().process(imageData: shots)
        assertMatches(out.profile, SyntheticProfiles.maya)
        XCTAssertEqual(out.photoCrops.count, 4)
        XCTAssertEqual(out.providerImages().count, 4)
        XCTAssertGreaterThan(out.profile.ocrConfidence, 0.5)
    }

    func testDarkModeScreenshots() async throws {
        var options = FixtureRenderer.Options()
        options.darkMode = true
        let out = try await ScreenshotPipeline().process(imageData: FixtureRenderer.renderPNGs(SyntheticProfiles.theo, options: options))
        assertMatches(out.profile, SyntheticProfiles.theo)
    }

    func testWrappedAnswersStayTogetherInDarkMode() async throws {
        var options = FixtureRenderer.Options()
        options.darkMode = true
        let out = try await ScreenshotPipeline().process(imageData: FixtureRenderer.renderPNGs(SyntheticProfiles.maya, options: options))
        assertMatches(out.profile, SyntheticProfiles.maya)
    }

    func testDuplicateScreenshotsAreIgnored() async throws {
        let shots = FixtureRenderer.renderPNGs(SyntheticProfiles.theo)
        let out = try await ScreenshotPipeline().process(imageData: [shots[0], shots[0]] + shots.dropFirst())
        XCTAssertEqual(out.duplicateScreenshots, [1])
        assertMatches(out.profile, SyntheticProfiles.theo)
    }

    func testOutOfOrderIsStillAllInformationFromOneSession() async throws {
        // A single screenshot still gives a partial profile; never crashes.
        let shots = FixtureRenderer.renderPNGs(SyntheticProfiles.maya)
        let out = try await ScreenshotPipeline().process(imageData: [shots[1]])
        XCTAssertFalse(out.profile.isEmpty)
    }

    func testRejectsNonImagesAndEmptyInput() async {
        do { _ = try await ScreenshotPipeline().process(imageData: []); XCTFail() } catch { XCTAssertEqual(error as? PipelineError, .noImages) }
        do { _ = try await ScreenshotPipeline().process(imageData: [Data("hello".utf8)]); XCTFail() } catch { XCTAssertEqual(error as? PipelineError, .unreadableImage(0)) }
    }

    func testResizesToMaxLongestEdge() throws {
        let png = try XCTUnwrap(FixtureRenderer.renderPNGs(SyntheticProfiles.maya).first)
        let img = try XCTUnwrap(ImageProcessing.normalizedImage(from: png))
        XCTAssertLessThanOrEqual(max(img.width, img.height), ImageProcessing.maxPixelSize)
    }
}

final class ReconstructorUnitTests: XCTestCase {
    func line(_ text: String, _ y: Double, _ h: Double = 0.02, px: Double = 40) -> OCRLine {
        OCRLine(text: text, box: CGRect(x: 0.1, y: y, width: 0.7, height: h), confidence: 0.99, pixelHeight: px)
    }

    func testParsesQuestionsAnswersBasicsAndNoise() {
        let scan = ScreenshotScan(index: 0, pixelSize: CGSize(width: 1000, height: 2000), lines: [
            line("9:41", 0.02, px: 40),
            line("Jordan", 0.06, px: 90),
            line("Unpopular opinion", 0.40, px: 38),
            line("Cereal is a soup and I", 0.43, px: 75),
            line("have diagrams", 0.46, px: 52),
            line("29", 0.60, px: 36),
            line("Lives in Denver", 0.63, px: 40),
            line("Send Like", 0.95, px: 40),
        ], photos: [PhotoRegion(rect: CGRect(x: 0.05, y: 0.1, width: 0.9, height: 0.28))])
        let result = ProfileReconstructor.reconstruct([scan])
        XCTAssertEqual(result.profile.name, "Jordan")
        XCTAssertEqual(result.profile.age, 29)
        XCTAssertEqual(result.profile.prompts.first?.answer, "Cereal is a soup and I have diagrams")
        XCTAssertEqual(result.profile.basics, ["Lives in Denver"])
        XCTAssertEqual(result.profile.photos.count, 1)
        XCTAssertTrue(result.profile.otherText.isEmpty, "\(result.profile.otherText)")
    }

    func testCatalogMatchesWithOCRNoise() {
        XCTAssertEqual(HingePromptCatalog.match("Unpopuiar opinion")?.category, .opinion)
        XCTAssertEqual(HingePromptCatalog.match("I will destroy you at")?.category, .challenge)
        XCTAssertNil(HingePromptCatalog.match("Fresh bagels and a crossword"))
    }
}

final class ProviderRouterTests: XCTestCase {
    let request = AnalysisRequest(profile: SyntheticProfiles.maya, photos: [], preferences: .default, dna: .neutral, flirtTarget: .flirty, spicyAllowed: false, tone: .playful)

    func testOffDeviceProvidersAreRefused() async throws {
        let offDevice = MockProvider(id: .mock, isOnDevice: false)
        let router = ProviderRouter(providers: [offDevice], configuration: .init(order: [.mock, .local]))
        let result = try await router.analyze(request)
        XCTAssertEqual(offDevice.callCount, 0, "nothing may leave the phone")
        XCTAssertEqual(result.report.providerID, .local)
    }

    func testFallsBackToBuiltInEngineOnError() async throws {
        let flaky = MockProvider(id: .mock, errors: [.invalidResponse("boom")])
        let router = ProviderRouter(providers: [flaky], configuration: .init(order: [.mock, .local]))
        let result = try await router.analyze(request)
        XCTAssertEqual(result.report.providerID, .local)
        XCTAssertEqual(result.report.fellBackFrom, [.mock])
        let samples = await router.samples
        XCTAssertEqual(samples.filter(\.succeeded).count, 1)
    }

    func testDefaultRouterIsTheBuiltInEngineOnly() async {
        let ids = await ProviderRouter().eligibleProviders().map(\.id)
        XCTAssertEqual(ids, [.local])
    }
}

final class OpenerModelTests: XCTestCase {
    func scored(_ text: String, style: CandidateStyle) -> ScoredCandidate {
        let ctx = CritiqueContext(profile: SyntheticProfiles.maya, target: TargetRef(.prompt, 3), targetText: "I will destroy you at — Mario Kart. Rainbow Road is my home turf",
                                  hooks: ["mario kart"], flirtTarget: .flirty, spicyAllowed: false, possibleMinor: false, dna: .neutral)
        var s = CommentCritic.evaluate(CommentCandidate(text: text, style: style, target: ctx.target, source: .local), context: ctx)
        s.features = OpenerFeatures.vector(for: s, category: .challenge)
        return s
    }

    func testStartsNeutralWithNoInfluence() {
        let m = OpenerModel()
        let c = scored("that's a lot of confidence about mario kart for someone who's about to come second", style: .teasing)
        XCTAssertEqual(c.features.count, OpenerFeatures.count)
        XCTAssertEqual(m.probability(c.features), 0.5, accuracy: 1e-9)
        XCTAssertEqual(m.influence, 0)
        XCTAssertEqual(m.blendedScore(ruleScore: 70, features: c.features), 70)
    }

    func testLearnsWhatYouPickAndReranks() {
        let teasing = scored("big talk about mario kart. best of three, loser buys drinks", style: .teasing)
        let flirty = scored("careful, if you beat me at mario kart I might actually fall for you 👀", style: .flirty)
        var m = OpenerModel()
        for _ in 0..<60 {
            m.train(teasing.features, label: 1)
            m.train(flirty.features, label: 0, weight: 0.5)
        }
        XCTAssertGreaterThan(m.probability(teasing.features), 0.8)
        XCTAssertLessThan(m.probability(flirty.features), 0.3)
        XCTAssertGreaterThan(m.influence, 0.3)
        XCTAssertEqual(CandidateRanker.rank([flirty, teasing], model: m).first?.text, teasing.text)
        XCTAssertTrue(m.learnedPreferences().contains { $0.name == "style: teasing" && $0.weight > 0 })
    }

    func testInfluenceIsCapped() {
        var m = OpenerModel()
        m.examples = 10_000
        XCTAssertEqual(m.influence, OpenerModel.maxInfluence)
    }

    func testModelSurvivesSaveAndOldFormats() throws {
        var m = OpenerModel()
        m.train(Array(repeating: 1, count: OpenerFeatures.count), label: 1)
        let data = try JSONEncoder().encode(m)
        XCTAssertEqual(try JSONDecoder().decode(OpenerModel.self, from: data), m)
        let old = try JSONDecoder().decode(OpenerModel.self, from: Data(#"{"weights":[1,2,3],"examples":9}"#.utf8))
        XCTAssertEqual(old.weights.count, OpenerFeatures.count)
        XCTAssertEqual(old.examples, 0, "mismatched old weights reset")
    }

    func testEngineAttachesFeaturesToEveryOpener() async throws {
        let a = try await WingmanEngine().analyze(profile: SyntheticProfiles.maya, photos: [], preferences: .default, dna: .neutral)
        let best = try XCTUnwrap(a.bestInteraction)
        XCTAssertEqual(best.comment?.features.count, OpenerFeatures.count)
        XCTAssertTrue(best.alternatives.allSatisfy { $0.features.count == OpenerFeatures.count })
    }

    func testTemplateLibraryIsLargeAndAlwaysSpecific() {
        XCTAssertGreaterThan(TemplateLibrary.count, 350)
        let banks: [TemplateLibrary.Bank] = [TemplateLibrary.opinion, TemplateLibrary.challenge, TemplateLibrary.claim, TemplateLibrary.lookingFor,
                                             TemplateLibrary.game, TemplateLibrary.food, TemplateLibrary.travel, TemplateLibrary.quirk,
                                             TemplateLibrary.music, TemplateLibrary.lifestyle] + Array(TemplateLibrary.photoBanks.values)
        for bank in banks { for (_, lines) in bank { for line in lines { XCTAssertTrue(line.contains("{t}"), line) } } }
        XCTAssertTrue(TemplateLibrary.suggestive.allSatisfy { $0.contains("{t}") })
    }
}

final class StorageTests: XCTestCase {
    func tempDir() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testInboxSaveLoadDeleteAndPurge() throws {
        let inbox = CaptureInbox(root: tempDir())
        let session = try inbox.save([Data([1]), Data([2]), Data([3])])
        XCTAssertEqual(inbox.pendingSessions().map(\.id), [session.id])
        XCTAssertEqual(inbox.images(for: session), [Data([1]), Data([2]), Data([3])])
        inbox.delete(session)
        XCTAssertTrue(inbox.pendingSessions().isEmpty)

        _ = try inbox.save([Data([9])])
        XCTAssertEqual(inbox.purge(olderThan: 3600), 0)
        XCTAssertEqual(inbox.purge(olderThan: 3600, now: Date().addingTimeInterval(7200)), 1)
        XCTAssertTrue(inbox.pendingSessions().isEmpty, "screenshots must not be kept")
    }

    func testSettingsRoundTripContainsNoImages() throws {
        let store = SettingsStore(directory: tempDir())
        var s = store.load()
        XCTAssertFalse(s.hasCompletedOnboarding)
        s.hasCompletedOnboarding = true
        s.preferences.flirtSetting = .fixed(.bold)
        s.dna.flirt = 0.77
        s.openerModel.train(Array(repeating: 0.5, count: OpenerFeatures.count), label: 1)
        s.sentOpeners = [SentOpener(text: "mario kart rematch?", style: .bold, features: [])]
        store.save(s)
        let loaded = store.load()
        XCTAssertEqual(loaded, s)
        XCTAssertEqual(loaded.preferences.flirtSetting, .fixed(.bold))
        XCTAssertFalse(loaded.preferences.spicySuggestions, "spicy is off by default")
        XCTAssertEqual(loaded.pendingReplies().count, 1)
    }

    func testOldSettingsFilesStillLoad() throws {
        let dir = tempDir()
        let legacy = #"{"hasCompletedOnboarding":true,"privacyMode":"cloudAllowed","claudeModel":"x","toneExamples":["hey"]}"#
        try Data(legacy.utf8).write(to: dir.appendingPathComponent("settings.json"))
        let s = SettingsStore(directory: dir).load()
        XCTAssertTrue(s.hasCompletedOnboarding)
        XCTAssertEqual(s.toneExamples, ["hey"])
        XCTAssertEqual(s.openerModel.examples, 0)
    }
}
