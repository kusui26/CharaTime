import Foundation

/// 入力が変わったかを安く比べるための値。
///
/// **日課表を作り直すべきかの判断に使う。** 部屋を模様替えしたりキャラを変えたりすると
/// その日の予定は変わるが、持ち回している表は古いままになる。毎フレーム作り直すのは
/// 無駄なので、入力の指紋を突き合わせて、変わったときだけ作り直す。
///
/// **時刻は含めない。** 時刻で変わるのは「表のどこを引くか」であって、表そのものではない。
public extension WorldInput {

    /// 小数を指紋に混ぜるときの細かさ。1 万分の 1 まで見る。
    /// 画面の 1 画素よりずっと細かいので、見た目に出る違いは取りこぼさない。
    private static var quantum: Double { 10_000 }

    var fingerprint: UInt64 {
        Hash64.combine(userSeed, [
            StableHash.string(character.id),
            Self.quantized(character.scale),
            character.personality.fingerprint,
            room.fingerprint,
        ])
    }

    static func quantized(_ value: Double) -> UInt64 {
        UInt64(bitPattern: Int64((value * quantum).rounded()))
    }
}

extension Personality {
    var fingerprint: UInt64 {
        Hash64.combine(0, [
            WorldInput.quantized(activity),
            WorldInput.quantized(nightOwl),
            WorldInput.quantized(napiness),
            // 好物は並び順に依らない値にする（集合なので順番に意味が無い）。
            favorites.reduce(0) { $0 ^ StableHash.string($1.rawValue) },
        ])
    }
}

extension Room {
    var fingerprint: UInt64 {
        Hash64.combine(0, [floor.fingerprint] + items.map(\.fingerprint))
    }
}

extension RoomRect {
    var fingerprint: UInt64 {
        Hash64.combine(0, [x, y, width, height].map(WorldInput.quantized))
    }
}

extension PlacedItem {
    var fingerprint: UInt64 {
        Hash64.combine(0, [
            StableHash.string(id),
            StableHash.string(kind.rawValue),
            WorldInput.quantized(position.x),
            WorldInput.quantized(position.y),
        ])
    }
}
