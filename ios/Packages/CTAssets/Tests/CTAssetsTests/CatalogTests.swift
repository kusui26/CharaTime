import Testing
import Foundation
import CTCore
@testable import CTAssets

/// 同梱データはアプリ・ウィジェット・Python のパイプラインが共有する唯一の出どころ。
/// 形が崩れると 3 か所が同時に壊れるので、ここで押さえる。
@Suite("同梱データ")
struct CatalogTests {

    @Test("5 体そろっていて、順番が決まっている")
    func characters() throws {
        let all = try Catalog.characters()
        #expect(all.map(\.id) == ["piyo", "mochi", "kumao", "fuwa", "chip"])
        #expect(all.map(\.displayName) == ["ピヨ", "モチ", "クマオ", "フワ", "チップ"])
    }

    @Test("どの子も Tier 1 の 11 枚がそろっている")
    func everyCharacterHasTierOne() throws {
        let expected: [Pose: Int] = [.idle: 2, .walk: 4, .sit: 1, .sleep: 2, .happy: 2]
        for character in try Catalog.characters() {
            for (pose, count) in expected {
                #expect(character.frameCount(pose) == count,
                        "\(character.id) の \(pose) が \(character.frameCount(pose)) 枚")
            }
            let total = Pose.allCases.reduce(0) { $0 + character.frameCount($1) }
            #expect(total == 11, "\(character.id) の合計が \(total) 枚")
        }
    }

    @Test("アセット名が命名規則どおりで、重複しない")
    func assetNaming() throws {
        var seen = Set<String>()
        for character in try Catalog.characters() {
            for (pose, names) in character.poses {
                for (index, name) in names.enumerated() {
                    #expect(name == "\(character.id)_\(pose.rawValue)_\(String(format: "%02d", index + 1))",
                            "命名規則から外れている: \(name)")
                    #expect(seen.insert(name).inserted, "重複したアセット名: \(name)")
                }
            }
        }
    }

    @Test("性格が 0〜1 に収まり、キャラごとに違う")
    func personalities() throws {
        let all = try Catalog.characters()
        for character in all {
            let p = character.personality
            #expect((0...1).contains(p.activity) && (0...1).contains(p.nightOwl) && (0...1).contains(p.napiness))
        }
        // 全員が同じ性格だと日課が同じになってしまう
        #expect(Set(all.map(\.personality.activity)).count >= 4)
        // フワは夜型、ピヨは朝型（プラン §5.2）
        let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
        #expect(byID["fuwa"]!.personality.nightOwl > 0.8)
        #expect(byID["piyo"]!.personality.nightOwl < 0.2)
        #expect(byID["mochi"]!.personality.napiness > 0.7)
    }

    @Test("好きなアイテムが実在する")
    func favoritesExist() throws {
        let kinds = Set(try Catalog.items().map(\.kind))
        for character in try Catalog.characters() {
            for favorite in character.personality.favorites {
                #expect(kinds.contains(favorite), "\(character.id) の好物 \(favorite) が items.json に無い")
            }
        }
    }

    @Test("アイテムがそろっていて、id が重複しない")
    func items() throws {
        let all = try Catalog.items()
        #expect(all.contains { $0.kind == .mirrorBall })   // 象徴アイテム（プラン §5.6）
        #expect(Set(all.map(\.id)).count == all.count)
        #expect(Set(all.map(\.assetName)).count == all.count)
        for item in all {
            #expect(item.widthRatio > 0 && item.widthRatio < 1)
            #expect(!item.displayName.isEmpty)
        }
        // ミラーボールだけが天井から吊るされる
        #expect(all.filter(\.hangsFromCeiling).map(\.kind) == [.mirrorBall])
    }

    @Test("読めないときは空を返す道がある（ウィジェットは落ちてはいけない）")
    func safeFallback() {
        #expect(!Catalog.charactersOrEmpty().isEmpty)
    }
}
