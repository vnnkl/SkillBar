// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SkillBar",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "SkillBar",
            path: "Sources/SkillBar"
        ),
        .testTarget(
            name: "SkillBarTests",
            dependencies: ["SkillBar"],
            path: "Tests/SkillBarTests"
        )
    ]
)
