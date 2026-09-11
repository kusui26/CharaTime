import Foundation

/// プロセスをまたいでも同じ値を返すハッシュ。
///
/// **なぜ標準の `Hasher` を使わないか。**
/// Swift の `Hasher` はプロセスごとに違う種で初期化される。同じ文字列でも
/// 実行のたびに違う値になる。CharaTime ではアプリ本体とウィジェット拡張が
/// **別プロセス**で動き、どちらも同じ時刻から同じ姿を計算しなければならない
/// （プラン §5.4）。`Hasher` を使うと「ウィジェットで見た姿」と「アプリを開いた姿」が
/// 食い違う。ここはその代わりで、入力が同じなら必ず同じ値を返す。
///
/// 出典の定数は SplitMix64（Vigna）の最終ミキサと FNV-1a のもの。
public enum Hash64 {

    /// 黄金比に由来する奇数。連番の入力を散らすために足す。
    public static let gamma: UInt64 = 0x9E37_79B9_7F4A_7C15

    /// SplitMix64 の最終ミキサ。1 ビットの違いが全ビットに広がる。
    @inlinable
    public static func mix(_ value: UInt64) -> UInt64 {
        var z = value
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 種と座標の並びから値を作る。
    ///
    /// 「座標」は日付・セグメント番号・経由点番号のような、意味のある添字を想定する。
    /// 連番の疑似乱数と違って途中を再生する必要がないので、3 時間後の姿も直接引ける。
    /// 並び順と個数が違えば違う値になる（`[1]` と `[1, 0]` は別物）。
    public static func combine(_ seed: UInt64, _ parts: [UInt64]) -> UInt64 {
        parts.reduce(mix(seed &+ gamma)) { accumulated, part in
            mix(accumulated ^ mix(part &+ gamma))
        }
    }

    /// `combine(_:_:)` の可変長引数版。
    public static func combine(_ seed: UInt64, _ parts: UInt64...) -> UInt64 {
        combine(seed, parts)
    }
}

/// 文字列から安定した 64 ビット値を作る（FNV-1a のあと SplitMix64 で撹拌）。
///
/// キャラ ID やアイテム ID を種に混ぜるために使う。`String.hashValue` は
/// プロセスごとに変わるので使えない（`Hash64` の説明を参照）。
public enum StableHash {

    /// FNV-1a の初期値と乗数（64 ビット版の定数）。
    static let fnvOffsetBasis: UInt64 = 0xCBF2_9CE4_8422_2325
    static let fnvPrime: UInt64 = 0x0000_0100_0000_01B3

    public static func string(_ value: String) -> UInt64 {
        let folded = value.utf8.reduce(fnvOffsetBasis) { hash, byte in
            (hash ^ UInt64(byte)) &* fnvPrime
        }
        // FNV-1a は下位ビットの散りが弱い。最後にもう一度撹拌する。
        return Hash64.mix(folded)
    }
}
