// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuadCastStudio",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "QuadCastStudio", targets: ["QuadCastStudio"]),
        .library(name: "QuadCastStudioCore", targets: ["QuadCastStudioCore"])
    ],
    targets: [
        .target(name: "QuadCastStudioCore"),
        .executableTarget(name: "QuadCastStudio", dependencies: ["QuadCastStudioCore"]),
        .testTarget(name: "QuadCastStudioCoreTests", dependencies: ["QuadCastStudioCore"])
    ]
)
