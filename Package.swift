// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AHAPpy",
    platforms: [
        .iOS(.v15),
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "AHAPpy",
            targets: ["AHAPpy"]
        )
    ],
    targets: [
        .target(
            name: "AHAPpy",
            dependencies: [],
            path: "Sources/AHAPpy"
        ),
        .testTarget(
            name: "AHAPpyTests",
            dependencies: ["AHAPpy"],
            path: "Tests/AHAPpyTests"
        )
    ]
)
