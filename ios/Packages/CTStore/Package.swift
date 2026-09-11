// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CTStore",
    platforms: [.iOS(.v26), .macOS(.v14)],
    products: [
        .library(name: "CTStore", targets: ["CTStore"])
    ],
    dependencies: [
        .package(path: "../CTCore")
    ],
    targets: [
        .target(
            name: "CTStore",
            dependencies: ["CTCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CTStoreTests",
            dependencies: ["CTStore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
