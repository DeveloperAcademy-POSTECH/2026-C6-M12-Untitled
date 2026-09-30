// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ScoreDetectCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "ScoreDetectCore", targets: ["ScoreDetectCore"])
    ],
    targets: [
        .target(name: "ScoreDetectCore"),
        .testTarget(name: "ScoreDetectCoreTests", dependencies: ["ScoreDetectCore"])
    ]
)
