// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "JSBridge",
    products: [
        .library(name: "JSBridge", targets: ["JSBridge"]),
    ],
    dependencies: [
        .package(url: "https://github.com/artman/Signals", from: "6.0.0"),
        .package(url: "https://github.com/mxcl/PromiseKit", from: "6.0.0"),
    ],
    targets: [
        .target(name: "JSBridge", dependencies: ["PromiseKit", "Signals"], path: "Sources"),
        .testTarget(name: "JSBridgeTests", dependencies: ["JSBridge"], path: "Tests"),
    ]
)
