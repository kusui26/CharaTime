import Foundation
import CTCore
import CTAssets

/// アイテムの前後関係を決める。
///
/// **View の中に置かない。** SwiftUI の `View` は `@MainActor` に縛られるので、
/// その中の静的メソッドで `sorted(by:)` を呼ぶと、メインスレッド以外から使ったときに
/// 隔離の検査に引っかかって落ちる。純粋な計算はここに置き、View は結果を受け取るだけにする。
public enum ItemOrder {

    /// キャラの手前に来るアイテムと、奥に来るアイテムに分ける。
    ///
    /// 画面の下にあるものほど手前にある（プラン §7.5 の「y でソート」）。
    /// 吊るすものは必ず奥に置く。天井から下がっているので、キャラの前には来ない。
    public static func split(_ items: [PlacedItem], character: RoomPoint,
                             definitions: [ItemKind: ItemDefinition])
        -> (behind: [PlacedItem], front: [PlacedItem]) {
        let sorted = items.sorted { $0.position.y < $1.position.y }
        let front = sorted.filter { item in
            let hangs = definitions[item.kind]?.hangsFromCeiling ?? false
            return !hangs && item.position.y > character.y
        }
        let frontIDs = Set(front.map(\.id))
        return (sorted.filter { !frontIDs.contains($0.id) }, front)
    }
}
