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
    ],
    targets: [
        // SwiftUI screens.
        .target(name: "StupidAgent", dependencies: ["StupidAgentCore", "PiAI", "PiTools"]),
        // Settings, storage and the agent session, without UI.
        .target(name: "StupidAgentCore", dependencies: ["PiAI", "PiAgent", "PiTools"]),
        // swift pi, vendored by scripts/vendor-swift-pi.sh; don't edit these by hand.
        .target(name: "PiAI", path: "Vendor/SwiftPi/Sources/PiAI"),
        .target(name: "PiAgent", dependencies: ["PiAI"], path: "Vendor/SwiftPi/Sources/PiAgent"),
        .target(name: "PiTools", dependencies: ["PiAI", "PiAgent"], path: "Vendor/SwiftPi/Sources/PiTools"),
        .testTarget(name: "StupidAgentCoreTests", dependencies: ["StupidAgentCore", "PiAI", "PiAgent"]),
    ]
)
