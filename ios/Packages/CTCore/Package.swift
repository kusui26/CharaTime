// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CTCore",
    // macOS も宣言しておくと `swift test` がシミュレータを介さず直接動く。
    // メモリ 8 GB の機械では、この差が検証ループの速さを決める（プラン §8.4）。
    platforms: [.iOS(.v26), .macOS(.v14)],
    products: [
        .library(name: "CTCore", targets: ["CTCore"])
    ],
    targets: [
        .target(
            name: "CTCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CTCoreTests",
            dependencies: ["CTCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
