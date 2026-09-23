import WidgetKit
import SwiftUI

/// ウィジェット疑似アニメの実機スパイク（プラン §9 Phase 0 の 0-9〜0-11、D-11）。
///
/// **これは製品ではない。** 判定が出たら丸ごと消す。
/// 本番のウィジェット拡張とは別のターゲットにしてあるので、ここで何が起きても
/// 本番のウィジェットは巻き添えにならない（拡張はターゲットごとに別プロセス）。
///
/// 4 つを並べて、どこまで動くかを見る。
///
/// | | 何 | 期待 |
/// |---|---|---|
/// | A | 静止した ● | 動かない。ほかを比べるための基準 |
/// | B | タイムラインのエントリ切替 | Apple 公式の方式。**最後の砦**。これが動かなければ何も動かない |
/// | C | マスクフォントで 1 秒ごとの点滅 | 非公式。Go / Conditional Go の分かれ目 |
/// | D | 0.25 秒ずらした 4 本で 4fps | 非公式。C が動いてから見る |
/// | E | C・D が点かなかった理由の切り分け | 原因を見分け、直し方を 4 通り試す（2026-09-23 追加） |
/// | F | 本番の組み方の確かめ（タイマーの本数、0 時起点、かつ、エントリ切替） | Phase 3 の 3-0b（2026-09-23 追加） |
/// | G | 背景を透明にしたときの見え方 | Phase 3 の 3-0c（2026-09-23 追加） |
///
/// **A〜D の描画は変えない。** E の結果と見比べる対照として、実機で観察したときのまま残す。
struct SpikeEntry: TimelineEntry {
    let date: Date
    /// B でだけ使う。エントリごとに動かす ● の位置。
    let step: Int
}

// MARK: - A 静止

struct StaticProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpikeEntry { SpikeEntry(date: .now, step: 0) }
    func getSnapshot(in context: Context, completion: @escaping (SpikeEntry) -> Void) {
        completion(SpikeEntry(date: .now, step: 0))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SpikeEntry>) -> Void) {
        // 1 時間ごとに作り直すだけ。動かないことを確かめるための基準。
        completion(Timeline(entries: [SpikeEntry(date: .now, step: 0)], policy: .atEnd))
    }
}

struct StaticSpikeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CTSpikeA", provider: StaticProvider()) { entry in
            SpikeFrame(title: "A 静止", note: "動かないのが正しい", entryDate: entry.date) {
                HStack(spacing: SpikeDial.dotSpacing) {
                    ForEach(0..<SpikeDial.dotCount, id: \.self) { index in
                        SpikeDot(isLit: index == 0)
                    }
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("スパイク A 静止")
        .description("動かない ●。ほかを比べるための基準です。")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - B タイムラインのエントリ切替（Apple 公式）

struct SteppingProvider: TimelineProvider {

    /// エントリの間隔。**公式の目安は 5 分以上**だが、スパイクでは短くして
    /// OS がどこまで拾うかを見る。1 本のタイムラインに何個入れても、
    /// 更新予算に数えられるのは「タイムラインを作り直した回数」なので費用は変わらない。
    static let spacingSeconds: TimeInterval = 60
    static let entryCount = 60

    func placeholder(in context: Context) -> SpikeEntry { SpikeEntry(date: .now, step: 0) }
    func getSnapshot(in context: Context, completion: @escaping (SpikeEntry) -> Void) {
        completion(SpikeEntry(date: .now, step: 0))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SpikeEntry>) -> Void) {
        let now = Date()
        let entries = (0..<Self.entryCount).map { index in
            SpikeEntry(date: now.addingTimeInterval(Double(index) * Self.spacingSeconds),
                       step: index % SpikeDial.dotCount)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct SteppingSpikeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CTSpikeB", provider: SteppingProvider()) { entry in
            SpikeFrame(title: "B エントリ切替", note: "1 分ごとに ● が 1 つ進む",
                       entryDate: entry.date) {
                HStack(spacing: SpikeDial.dotSpacing) {
                    ForEach(0..<SpikeDial.dotCount, id: \.self) { index in
                        SpikeDot(isLit: index == entry.step)
                    }
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("スパイク B エントリ切替")
        .description("Apple 公式の方式。1 分ごとに ● が進みます。")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - C マスクフォントで 1 秒ごとの点滅

struct BlinkSpikeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CTSpikeC", provider: StaticProvider()) { entry in
            SpikeFrame(title: "C 1 秒ごとの点滅", note: "左 2 つが交互に点く",
                       entryDate: entry.date) {
                HStack(spacing: SpikeDial.dotSpacing) {
                    MaskedTimerDot(anchor: entry.date, showsOnEvenSeconds: true)
                    MaskedTimerDot(anchor: entry.date, showsOnEvenSeconds: false)
                    SpikeDot(isLit: false)
                    SpikeDot(isLit: false)
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("スパイク C 1 秒の点滅")
        .description("マスクフォントで ● を毎秒出し入れします。")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - D 0.25 秒ずらした 4 本で 4fps

struct FastSpikeWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CTSpikeD", provider: StaticProvider()) { entry in
            SpikeFrame(title: "D 4fps", note: "点いている ● の数が増えたり減ったりする",
                       entryDate: entry.date) {
                HStack(spacing: SpikeDial.dotSpacing) {
                    ForEach(0..<SpikeDial.dotCount, id: \.self) { index in
                        MaskedTimerDot(anchor: entry.date,
                                       offsetSeconds: Double(index) * SpikeDial.phaseSeconds)
                    }
                }
            }
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("スパイク D 4fps")
        .description("0.25 秒ずらした 4 本を重ねます。")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - E C・D が点かなかった理由の切り分け

/// 1 枚の大ウィジェットに、原因を見分ける 4 行（①〜④）と、直し方を試す 4 行（α〜δ）を並べる。
/// 中身は `ProbeBoard`。本体アプリの下見画面（`-CTScreen spike`）にも同じものが出る。
///
/// **地の色だけは E で決める。** 字の並びを細かく見比べるので、明暗どちらの外観でも
/// 同じ明るい地にする。A〜D の地（`.fill.tertiary`）は対照として変えない。
struct ProbeSpikeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CTSpikeE", provider: StaticProvider()) { entry in
            SpikeFrame(title: "E 切り分け", note: "1 秒ずらして 2 枚撮る", entryDate: entry.date,
                       counterSpanSeconds: DigitCut.dailySpanSeconds) {
                ProbeBoard(anchor: entry.date)
            }
            .containerBackground(ProbeLayout.paper, for: .widget)
        }
        .configurationDisplayName("スパイク E 切り分け")
        .description("C・D が点かない理由を見分け、直し方を 4 通り試します。")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - F タイマーの本数（Phase 3 の 3-0b）

/// 0 時にだけ作り直すタイムライン。点滅はタイマーが受け持つので、エントリは 1 つでよい。
///
/// 途中で作り直されると描き直しが混ざり、戻った直後の測りを乱す。タイマーは 0 時から 36 時間
/// 数えるので（D-18）、0 時に作り直せば途切れない。
struct MidnightProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpikeEntry { SpikeEntry(date: .now, step: 0) }
    func getSnapshot(in context: Context, completion: @escaping (SpikeEntry) -> Void) {
        completion(SpikeEntry(date: .now, step: 0))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SpikeEntry>) -> Void) {
        let now = Date()
        let tomorrow = MidnightClock.startOfDay(for: now).addingTimeInterval(Self.daySeconds)
        completion(Timeline(entries: [SpikeEntry(date: now, step: 0)], policy: .after(tomorrow)))
    }

    /// 次の 0 時までの目安。夏時間の日は 1 時間ずれるが、作り直しが 1 時間ずれるだけで困らない。
    private static let daySeconds: TimeInterval = 86_400
}

/// タイマーを決まった本数だけ抱えた F の小。本数ごとに型を分ける
/// （WidgetKit のウィジェットは引数なしで作られるので、本数は型に持たせる）。
protocol TimerCountSpikeWidget: Widget {
    static var count: Int { get }
}

extension TimerCountSpikeWidget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CTSpikeF\(Self.count)", provider: MidnightProvider()) { entry in
            TimerCountBoard(count: Self.count, entryDate: entry.date)
                .containerBackground(ProbeLayout.paper, for: .widget)
        }
        .configurationDisplayName(Self.displayName)
        .description(Self.summary)
        .supportedFamilies([.systemSmall])
    }

    /// **表示名は `String` に組み立ててから渡す。** `configurationDisplayName("… \(count) …")` と
    /// 補間を直接書くと書式付きの文字列（`LocalizedStringKey`）になり、WidgetKit が実行時に止める
    /// （「Formatted text for `configurationDisplayName` is not supported」。2026-09-23、拡張ごと落ちた）。
    private static var displayName: String { "スパイク F \(count) 本" }
    private static var summary: String { "タイマーを \(count) 本だけ抱えます。ホーム画面に戻った直後の動き出しを比べます。" }
}

struct TimerCount1SpikeWidget: TimerCountSpikeWidget { static let count = 1 }
struct TimerCount2SpikeWidget: TimerCountSpikeWidget { static let count = 2 }
struct TimerCount4SpikeWidget: TimerCountSpikeWidget { static let count = 4 }
struct TimerCount6SpikeWidget: TimerCountSpikeWidget { static let count = 6 }
struct TimerCount8SpikeWidget: TimerCountSpikeWidget { static let count = 8 }
struct TimerCount14SpikeWidget: TimerCountSpikeWidget { static let count = 14 }

// MARK: - F 組み方（Phase 3 の 3-0b）

/// 1 分ごとのエントリを 1 時間ぶん。エントリの境目は毎分 0 秒にそろえる。
///
/// 台はエントリが替わるたびに左右を入れ替える。境目の時刻が分かっているので、画面収録の
/// どこを見ればよいかが決まる。1 分刻みは公式の目安（5 分以上）より細かいが、B で拾われると分かっている。
struct MinuteProvider: TimelineProvider {

    static let entryCount = 60
    static let spacingSeconds: TimeInterval = 60

    func placeholder(in context: Context) -> SpikeEntry { SpikeEntry(date: .now, step: 0) }
    func getSnapshot(in context: Context, completion: @escaping (SpikeEntry) -> Void) {
        completion(SpikeEntry(date: .now, step: 0))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SpikeEntry>) -> Void) {
        let now = Date()
        let minute = Calendar.current.dateInterval(of: .minute, for: now)?.start ?? now
        let entries = (0..<Self.entryCount).map { index in
            let date = index == 0 ? now : minute.addingTimeInterval(Double(index) * Self.spacingSeconds)
            return SpikeEntry(date: date, step: Calendar.current.component(.minute, from: date) % 2)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct DesignSpikeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CTSpikeFDesign", provider: MinuteProvider()) { entry in
            DesignBoard(entryDate: entry.date, movedRight: entry.step == 1)
                .containerBackground(ProbeLayout.paper, for: .widget)
        }
        .configurationDisplayName("スパイク F 組み方")
        .description("0 時起点、桁の切り出し、入れ子の「かつ」、エントリ切替を確かめます。")
        .supportedFamilies([.systemLarge])
    }
}

// MARK: - G 透け方（Phase 3 の 3-0c）

struct ClearBackgroundSpikeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CTSpikeGClear", provider: StaticProvider()) { _ in
            ClearProbe(label: "Color.clear").containerBackground(Color.clear, for: .widget)
        }
        .configurationDisplayName("スパイク G 透明")
        .description("背景を Color.clear にします。壁紙が透けるかを見ます。")
        .supportedFamilies([.systemSmall])
    }
}

struct EmptyBackgroundSpikeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CTSpikeGEmpty", provider: StaticProvider()) { _ in
            ClearProbe(label: "EmptyView").containerBackground(for: .widget) { EmptyView() }
        }
        .configurationDisplayName("スパイク G 空")
        .description("背景を EmptyView にします。壁紙が透けるかを見ます。")
        .supportedFamilies([.systemSmall])
    }
}

struct AlmostClearBackgroundSpikeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CTSpikeGAlmostClear", provider: StaticProvider()) { _ in
            ClearProbe(label: "白 0.0000001")
                .containerBackground(Color.white.opacity(Self.almostZeroOpacity), for: .widget)
        }
        .configurationDisplayName("スパイク G ほぼ透明")
        .description("背景を、ほぼ透明な白にします。壁紙が透けるかを見ます。")
        .supportedFamilies([.systemSmall])
    }

    /// `research/B` §2.2 が挙げた 3 通りのうちの 1 つ。0 だと「透明」と同じ扱いになりうるので、わずかに残す。
    private static let almostZeroOpacity = 0.000_000_1
}

@main
struct SpikeWidgetBundle: WidgetBundle {
    var body: some Widget {
        StaticSpikeWidget()
        SteppingSpikeWidget()
        BlinkSpikeWidget()
        FastSpikeWidget()
        ProbeSpikeWidget()
        TimerCount1SpikeWidget()
        TimerCount2SpikeWidget()
        TimerCount4SpikeWidget()
        TimerCount6SpikeWidget()
        TimerCount8SpikeWidget()
        TimerCount14SpikeWidget()
        DesignSpikeWidget()
        ClearBackgroundSpikeWidget()
        EmptyBackgroundSpikeWidget()
        AlmostClearBackgroundSpikeWidget()
    }
}
