// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HingeAssistKit",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "HingeAssistKit", targets: ["HingeAssistKit"]),
    ],
    targets: [
        .target(
            name: "HingeAssistKit",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // macOS helper: renders the synthetic fixture profiles to PNG screenshots.
        .executableTarget(
            name: "render-fixtures",
            dependencies: ["HingeAssistKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "HingeAssistKitTests",
            dependencies: ["HingeAssistKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
