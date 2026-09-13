// swift-tools-version: 6.2

import PackageDescription

var dependencies: [Package.Dependency] = []
var targets: [Target] = [
    .target(name: "TrimmyCore"),
    .executableTarget(name: "TrimmyCLI", dependencies: ["TrimmyCore"]),
    .testTarget(name: "TrimmyCoreTests", dependencies: ["TrimmyCore"]),
    .testTarget(name: "TrimmyCLITests", dependencies: ["TrimmyCLI", "TrimmyCore"]),
]

#if os(macOS)
dependencies = [
    .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.6"),
    .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.4.0"),
    .package(url: "https://github.com/orchetect/MenuBarExtraAccess", exact: "1.3.1"),
]
targets += [
    .executableTarget(
        name: "Trimmy",
        dependencies: [
            "TrimmyCore",
            .product(name: "Sparkle", package: "Sparkle"),
            .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            .product(name: "MenuBarExtraAccess", package: "MenuBarExtraAccess"),
        ]),
    .testTarget(name: "TrimmyTests", dependencies: ["Trimmy", "TrimmyCore"]),
]
#endif

let package = Package(
    name: "Trimmy",
    platforms: [.macOS(.v15)],
    dependencies: dependencies,
    targets: targets)
