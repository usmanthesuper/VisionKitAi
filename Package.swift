// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "visionkit-swift",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    
    products: [
        .library(
            name: "VisionKit",
            targets: ["VisionKit"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "VisionKit",
            dependencies: [],
            path: "Sources/VisionKit"
        ),
        .testTarget(
            name: "VisionKitTests",
            dependencies: ["VisionKit"],
            path: "Tests/VisionKitTests",
            resources: [
                .copy("assets")
            ]
        )
    ]
)
