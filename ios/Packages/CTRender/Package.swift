// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CTRender",
    platforms: [.iOS(.v26), .macOS(.v14)],
    products: [
        .library(name: "CTRender", targets: ["CTRender"])
    ],
    dependencies: [
        .package(path: "../CTCore"),
        .package(path: "../CTAssets"),
        .package(path: "../CTStore"),
    ],
    targets: [
        .target(
            name: "CTRender",
            dependencies: ["CTCore", "CTAssets", "CTStore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CTRenderTests",
            dependencies: ["CTRender"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
