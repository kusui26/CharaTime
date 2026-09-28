// swift-tools-version: 6.2
import PackageDescription

// 取り込んだ絵を整える処理（プラン §9 Phase 2 の 2-C ⑤、D-35）。
//
// **アプリと Mac の道具だけが使い、ウィジェット拡張にはリンクしない**（画素の処理を拡張に持ち込まない。
// 拡張のメモリは約 30 MB）。整えた絵の大きさと置く前の中身は CTStore の型を使う（`CharacterImageKind`・
// `CharacterPackage`・`ImportRecord`）。テストの見本には、同梱の絵（CTAssets の @3x）を使う。
//
// Mac の道具 `chara-bake`（既定の 5 体を焼く。2-C ⑦、2-3）も、このパッケージに置く。中身は `CharaBake`
// に書き、入口の `chara-bake` は引数を渡すだけにする（中身をテストできるように）。アプリは `CTStudio` だけを使う。
let package = Package(
    name: "CTStudio",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "CTStudio", targets: ["CTStudio"]),
        .executable(name: "chara-bake", targets: ["chara-bake"]),
    ],
    dependencies: [
        .package(path: "../CTCore"),
        .package(path: "../CTStore"),
        .package(path: "../CTAssets"),
    ],
    targets: [
        .target(
            name: "CTStudio",
            dependencies: ["CTCore", "CTStore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "CharaBake",
            dependencies: ["CTStudio", "CTCore", "CTStore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "chara-bake",
            dependencies: ["CharaBake"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CTStudioTests",
            dependencies: ["CTStudio", "CTAssets"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "CharaBakeTests",
            dependencies: ["CharaBake", "CTStudio", "CTCore", "CTStore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
