import SwiftUI
import CTCore

// 疑似アニメの仕掛け（プラン §9 Phase 3 の 3-C ④、スパイク E・F で確かめた組み方を移した）。
//
// `Text(timerInterval:)` は、ウィジェット拡張が止まっていても OS が毎秒描き直す。そこに
// 「数字の集まりに入る数字だけが 1em の塗りつぶし、ほかは空」のマスク書体を当て、右から k 字目の
// 1 字だけを切り出す。その 1 字をマスクにして絵を出し入れすると、拡張が動かないまま絵が動く。
// いつ開くかは CTCore の `TimerWindow` が決め、ここはそれを描く。

/// タイマーの数え方（D-18）。
enum MidnightClock {
    /// 数える長さ。その日の 0 時から 36 時間（翌日の昼まで、作り直しなしで数え続ける）。
    static let spanSeconds: TimeInterval = 36 * 3600
    /// 最長の字数（「35:59:59」）。枠はこの字数ぶん取って右に寄せる。
    static let glyphCount = 8
}

/// マスク書体の名前。`tools/pipeline/masks.py` と同じ規則で、`CTMask` に数字の並びを付ける。
public enum MaskFont {

    static let prefix = "CTMask"

    public static func name(for digits: DigitSet) -> String { prefix + digits.key }

    /// 一族の書体の名前すべて（`MaskFontFamily`）。アプリと拡張は、これが登録されているかを
    /// 確かめてから疑似アニメを使う。無い書体はシステムの字に落ち、数字の形の穴から絵が覗くため。
    public static var familyNames: [String] { MaskFontFamily.digitSets.map(name(for:)) }
}

/// その日の 0 時から数えるタイマーの文字（D-18）。表示は時刻そのもの（「15:32:11」）。
///
/// `advanceSeconds` だけ起点を前に置くと、表示がそのぶん進み、窓の開く時刻がそのぶん早まる。
///
/// **字の入れ替わりをアニメにしない**（`.contentTransition(.identity)`）。エントリ切替のアニメ
/// （約 1.5 秒）のあいだは、OS が字の入れ替わりまで溶かして重ねるので、そこに当たった 0.25 秒の
/// まばたきが、開いた目に半透明のまぶたが乗った姿になった（3-2b のホーム画面の収録。R-21）。
struct MidnightTimerText: View {

    /// エントリの日付の 0 時。**日をまたいだエントリは翌日の 0 時**（3-C ④ 原則 2）。
    let anchor: Date
    let advanceSeconds: Double
    let fontName: String
    let size: Double

    var body: some View {
        let start = anchor.addingTimeInterval(-advanceSeconds)
        Text(timerInterval: start...start.addingTimeInterval(MidnightClock.spanSeconds),
             countsDown: false, showsHours: true)
            .font(.custom(fontName, size: size))
            .lineLimit(1)
            .contentTransition(.identity)
    }
}

/// タイマーの文字から、**右から数えて `index` 字目**の 1 字ぶんだけを切り出す（0 = 秒の一の位）。
///
/// **`.fixedSize()` を当てない。** ウィジェットの中では、字にぴったりの枠の幅が有限にならず、
/// 字が描かれない（スパイク C・D の失敗。CLAUDE.md §3）。最長の 8 字ぶんの枠を決めて右に寄せ、
/// `index` 字ぶん右へずらしてから、右端 1 字の窓で切り取る。
struct GlyphWindow<Glyphs: View>: View {

    let index: Int
    let cell: Double
    @ViewBuilder let glyphs: Glyphs

    var body: some View {
        glyphs.multilineTextAlignment(.trailing)
            .frame(width: cell * Double(MidnightClock.glyphCount), alignment: .trailing)
            .offset(x: cell * Double(index))
            .frame(width: cell, height: cell, alignment: .trailing)
            .clipped()
    }
}

/// 窓の 1 項（タイマー 1 本）のマスク。桁の数字が集まりに入っているあいだだけ、1em の四角になる。
struct TermMask: View {

    let term: WindowTerm
    let anchor: Date
    let cell: Double

    var body: some View {
        GlyphWindow(index: term.position.glyphIndexFromRight, cell: cell) {
            MidnightTimerText(anchor: anchor, advanceSeconds: term.advanceSeconds,
                              fontName: MaskFont.name(for: term.digits), size: cell)
        }
    }
}

/// 窓（項の「かつ」）のマスク。項が 2 つなら、マスクを入れ子にする（3-C ④ 原則 3）。
///
/// 動かし方が作る窓は、どれもタイマー 2 本まで（CTCore のテストが見張る）。
struct WindowMask: View {

    let window: TimerWindow
    let anchor: Date
    let cell: Double

    var body: some View {
        if let first = window.terms.first {
            if let second = window.terms.dropFirst().first {
                TermMask(term: first, anchor: anchor, cell: cell)
                    .mask { TermMask(term: second, anchor: anchor, cell: cell) }
            } else {
                TermMask(term: first, anchor: anchor, cell: cell)
            }
        }
    }
}

/// 窓と、そのタイマーの起点。出し入れする部品（吹き出し・寝ている z）に渡す。
struct AnchoredWindow: Sendable, Equatable {
    let window: TimerWindow
    /// タイマーの起点。エントリの日付の 0 時（D-18）。
    let anchor: Date
}

extension View {

    /// 窓が開いているあいだだけ見せる（3-C ④）。
    ///
    /// マスクは一辺 `cell` の四角で、中身の真ん中に重なる。中身がすっぽり入る大きさを渡す。
    /// 窓は書体の少ない形（`TimerWindow.canonical`）に回してから描く（書体は一族の 7 本だけ）。
    func shown(during window: TimerWindow, anchor: Date, cell: Double) -> some View {
        mask { WindowMask(window: window.canonical, anchor: anchor, cell: cell) }
    }

    /// 窓があれば開いているあいだだけ見せ、無ければ出したままにする。
    @ViewBuilder
    func shown(during window: AnchoredWindow?, cell: Double) -> some View {
        if let window {
            shown(during: window.window, anchor: window.anchor, cell: cell)
        } else {
            self
        }
    }
}
