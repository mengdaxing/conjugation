// swift-tools-version: 6.1
// This is a Skip (https://skip.dev) package.
import PackageDescription

let package = Package(
    name: "french-conjugation",
    defaultLocalization: "zh-Hans",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Conjugation", type: .dynamic, targets: ["Conjugation"]),
    ],
    dependencies: [
        .package(url: "https://github.com/skiptools/skip.git", from: "1.9.20"),
        .package(url: "https://github.com/skiptools/skip-fuse-ui.git", from: "1.0.0")
    ],
    targets: [
        .target(name: "Conjugation", dependencies: [
            .product(name: "SkipFuseUI", package: "skip-fuse-ui")
        ], resources: [
            .process("Resources/verbs.json"),
            .process("Resources/LICENSE.txt"),
            .process("Resources/MaterialIcons-LICENSE.txt"),
            .process("Resources/MaterialIcons-NOTICE.txt"),
            // Raw catalogs are read by Skip's Android renderer. The standalone
            // iOS app uses its own asset catalog and Apple's system symbols.
            .copy("Resources/Module.xcassets")
        ], plugins: [.plugin(name: "skipstone", package: "skip")]),
    ],
    // Match the standalone iOS project while using the Swift 6.4 Android toolchain.
    swiftLanguageModes: [.v5]
)
