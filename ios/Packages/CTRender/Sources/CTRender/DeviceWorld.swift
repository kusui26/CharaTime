import Foundation
import CTCore
import CTAssets
import CTStore

/// `state.json` から、この端末のキャラと部屋を決める規則（プラン §9 Phase 3 の 3-C ②）。
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

    /// 日課エンジンへの入力。
    func worldInput(character: CTCore.Character, calendar: Calendar = .current) -> WorldInput {
        WorldInput(character: character, room: currentRoom, userSeed: userSeed,
                   context: context, calendar: calendar)
    }
}
