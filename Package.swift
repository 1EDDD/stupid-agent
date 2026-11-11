// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StupidAgent",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        // A stupid-app project contains exactly one library product representing the application.
        .library(name: "StupidAgent", targets: ["StupidAgent"]),
        .library(name: "VOIDKeyboard", targets: ["VOIDKeyboard"]),
        .library(name: "VOIDOnDeviceAI", targets: ["VOIDOnDeviceAI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/stephancill/stupid-chatkit", from: "0.5.0"),
        .package(url: "https://github.com/stephancill/swift-pi", from: "0.2.0"),
        // Core AI model access. Qwen3 0.6B is downloaded once and then cached locally.
        .package(url: "https://github.com/john-rocky/coreai-kit", exact: "0.4.1"),
    ],
    targets: [
        // SwiftUI screens.
        .target(name: "StupidAgent", dependencies: [
            "StupidAgentCore",
            "VOIDOnDeviceAI",
            .product(name: "PiAI", package: "swift-pi"),
            .product(name: "PiTools", package: "swift-pi"),
            // iOS-only: the kit is UIKit, and swift test builds the package on macOS for the core tests.
            .product(name: "StupidChatKit", package: "stupid-chatkit", condition: .when(platforms: [.iOS])),
        ]),
        // iOS keyboard extension. It deliberately does not link the large Qwen runtime.
        .target(name: "VOIDKeyboard", dependencies: ["StupidAgentCore"]),
        // The app/Shortcuts model runtime is isolated from the keyboard extension's tighter memory budget.
        .target(name: "VOIDOnDeviceAI", dependencies: [
            .product(name: "CoreAIKit", package: "coreai-kit", condition: .when(platforms: [.iOS])),
        ]),
        // Settings, storage and the agent session, without UI.
        .target(name: "StupidAgentCore", dependencies: [
            .product(name: "PiAI", package: "swift-pi"),
            .product(name: "PiAgent", package: "swift-pi"),
            .product(name: "PiTools", package: "swift-pi"),
            .product(name: "PiJavaScript", package: "swift-pi"),
        ]),
        .testTarget(name: "StupidAgentCoreTests", dependencies: [
            "StupidAgentCore",
            .product(name: "PiAI", package: "swift-pi"),
            .product(name: "PiAgent", package: "swift-pi"),
            .product(name: "PiTools", package: "swift-pi"),
        ]),
    ]
)
