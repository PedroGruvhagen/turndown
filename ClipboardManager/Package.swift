// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DemoskopClipboard",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "DemoskopClipboard",
            targets: ["DemoskopClipboard"]
        )
    ],
    dependencies: [
        // Markdown parsing library
        .package(url: "https://github.com/johnxnguyen/Down.git", from: "0.11.0"),
        // Global keyboard shortcuts
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts.git", from: "2.0.0"),
        // Auto-update framework
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.5.0"),
        // Programmatic MenuBarExtra control
        .package(url: "https://github.com/orchetect/MenuBarExtraAccess.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "DemoskopClipboard",
            dependencies: [
                "Down",
                "KeyboardShortcuts",
                "Sparkle",
                "MenuBarExtraAccess"
            ],
            path: "ClipboardManager"
        )
    ]
)
