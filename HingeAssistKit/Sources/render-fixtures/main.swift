import Foundation
import HingeAssistKit

// Usage: swift run render-fixtures <output-dir> [--demo]
//   Writes synthetic profile screenshots (PNG) for manual testing in the Simulator.
//   With --demo, also runs the full offline pipeline on them and prints the result.

let args = CommandLine.arguments.dropFirst()
let outDir = URL(fileURLWithPath: args.first(where: { !$0.hasPrefix("--") }) ?? "SyntheticScreenshots", isDirectory: true)
let demo = args.contains("--demo")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let profiles: [(String, DatingProfile)] = [("maya", SyntheticProfiles.maya), ("theo", SyntheticProfiles.theo)]
for (slug, profile) in profiles {
    let pngs = FixtureRenderer.renderPNGs(profile)
    for (i, png) in pngs.enumerated() {
        let url = outDir.appendingPathComponent("\(slug)-\(i + 1).png")
        try png.write(to: url)
        print("wrote \(url.path)")
    }
    guard demo else { continue }

    let output = try await ScreenshotPipeline().process(imageData: pngs)
    print("\n=== Reconstructed \(slug) from \(pngs.count) screenshots ===")
    print(output.profile.renderedForModel())
    print("basics:", output.profile.basics, "other:", output.profile.otherText)

    let engine = WingmanEngine(router: ProviderRouter())
    var prefs = UserPreferences(goal: .longTerm, ageMin: 24, ageMax: 34, interests: ["hiking", "gaming", "food"], dealbreakers: ["smoking"], greenFlags: ["funny"])
    prefs.isAdultConfirmed = true
    let analysis = try await engine.analyze(profile: output.profile, photos: output.providerImages(), preferences: prefs, dna: StylePreset.playfulBanter.seedDNA)
    print("\n\(analysis.overallCompatibility)% MATCH — \(analysis.recommendation.label) (tone: \(analysis.tone.label))")
    for t in analysis.rankedInteractionTargets { print("  \(t.ref.label)  \(t.overallInteractionScore)  \(t.context.prefix(60))") }
    if let best = analysis.bestInteraction {
        print("BEST MOVE: Like \(best.target.ref.label)\nWHY: \(best.why)\nSEND: \(best.comment?.text ?? "-")")
        for alt in best.alternatives { print("   alt [\(alt.candidate.style.rawValue) \(alt.scores.total)]: \(alt.text)") }
    }
}
