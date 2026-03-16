// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SpecttyTerminal",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SpecttyTerminal", targets: ["SpecttyTerminal"]),
    ],
    targets: [
        .target(
            name: "CGhosttyVT",
            path: "Sources/CGhosttyVT",
            publicHeadersPath: "include"
        ),
        .target(
            name: "SpecttyTerminal",
            dependencies: ["CGhosttyVT"]
        ),
    ]
)
