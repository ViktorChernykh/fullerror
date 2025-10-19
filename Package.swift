// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "fullerror",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        .library(name: "FullError", targets: ["FullError"]),
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.56.0"),
        .package(url: "https://github.com/ViktorChernykh/fullerror-model.git", from: "1.0.0"),
    ],
    targets: [
        .target(name: "FullError", dependencies: [
            .product(name: "Vapor", package: "vapor"),
            .product(name: "FullErrorModel", package: "fullerror-model"),
        ]),
        .testTarget(name: "FullErrorTests", dependencies: [
            .product(name: "XCTVapor", package: "vapor"),
            .target(name: "FullError"),
        ])
    ]
)
