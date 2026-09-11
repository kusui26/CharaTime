// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CTAssets",
    platforms: [.iOS(.v26), .macOS(.v14)],
    products: [
        .library(name: "CTAssets", targets: ["CTAssets"])
    ],
    dependencies: [
        .package(path: "../CTCore")
    ],
    targets: [
        .target(
            name: "CTAssets",
            dependencies: ["CTCore"],
            // characters.json / items.json と、のちに Assets.xcassets が入る。
            // 画像は tools/pipeline が書き出したものだけを置く（手で追加しない）。
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CTAssetsTests",
            dependencies: ["CTAssets"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
