// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexCat",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "CodexCat", targets: ["CodexCat"])
    ],
    targets: [
        .executableTarget(
            name: "CodexCat",
            resources: [.process("Resources")]
        )
    ]
)
