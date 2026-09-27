import Foundation
import CTCore
import CTAssets
import CTStore

/// `state.json` から、この端末のキャラと部屋を決める規則（プラン §9 Phase 3 の 3-C ②。取り込んだキャラは
/// Phase 2 の 2-C ⑥⑪）。
///
/// **アプリとウィジェットは、どちらもここで組み立てる。** 片方だけ規則が違う（キャラが
/// 見つからないときの代わりなど）と、同じ `sceneState(at:)` を呼んでも入力が違い、
/// ウィジェットで見た姿とアプリを開いた姿が食い違う（R-20）。
public extension AppState {

    /// いま使っている部屋。選んでいなければ同梱の部屋。
    var currentRoom: Room { room ?? BundledRoom.room }

    /// 選んだキャラ。同梱データに見つからなければ同梱の先頭。1 体も無ければ nil。
    func currentCharacter(among characters: [CTCore.Character]) -> CTCore.Character? {
        characters.first { $0.id == selectedCharacterID } ?? characters.first
    }

    /// 選んだキャラを、絵と一緒に用意する（2-C ⑥⑪）。**アプリもウィジェットも、ここで決める**（R-20）。
    ///
    /// 取り込んだ子を選んでいれば、そのフォルダの `character.json` と、その大きさの絵だけを読む（一覧は取らない）。
    /// 読めなければ（フォルダが消えた・壊れた・書きかけ・絵が読めない・App Group が無い）、同梱の先頭に戻る
    /// （`currentCharacter(among:)` と同じ規則）。同梱の子を選んでいれば、今までどおり。
    func chooseCharacter(bundled: [CTCore.Character], store: CharacterStore,
                         size: SpriteSize) -> ChosenCharacter? {
        if let stored = store.load(id: selectedCharacterID)?.character,
           let sprites = SpriteSource.loading(stored, size: size, from: store) {
            return ChosenCharacter(character: stored, sprites: sprites)
        }
        return currentCharacter(among: bundled).map { ChosenCharacter(character: $0, sprites: .catalog) }
    }

    /// 日課エンジンへの入力。
    func worldInput(character: CTCore.Character, calendar: Calendar = .current) -> WorldInput {
        WorldInput(character: character, room: currentRoom, userSeed: userSeed,
                   context: context, calendar: calendar)
    }
}

/// 選んだキャラと、その絵の出どころ（`AppState.chooseCharacter`）。
public struct ChosenCharacter: Sendable {
    public let character: CTCore.Character
    public let sprites: SpriteSource
}

/// 選べるキャラの一覧（2-C ⑧）。既定の 5 体のあとに、取り込んだ子を連れてきた順に並べる。
///
/// 読めない子は並べない（`CharacterShelf.skipped`）。同じ id は、先に来たもの（同梱の子）を残す。
public enum CharacterRoster {

    public static func characters(bundled: [CTCore.Character], shelf: CharacterShelf) -> [CTCore.Character] {
        let bundledIDs = Set(bundled.map(\.id))
        return bundled + shelf.characters.filter { !bundledIDs.contains($0.id) }
    }
}
