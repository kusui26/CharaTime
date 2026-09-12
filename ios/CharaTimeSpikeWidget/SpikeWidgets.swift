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

    /// ずらす秒数。4 本を 0.25 秒ずつずらすと、点いている ● の数が
    /// 0.25 秒ごとに変わる。1 秒に 4 回変われば 4fps。
    static let phaseSeconds: Double = 0.25

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CTSpikeD", provider: StaticProvider()) { entry in
            SpikeFrame(title: "D 4fps", note: "点いている ● の数が増えたり減ったりする",
                       entryDate: entry.date) {
                HStack(spacing: SpikeDial.dotSpacing) {
                    ForEach(0..<SpikeDial.dotCount, id: \.self) { index in
                        MaskedTimerDot(anchor: entry.date,
                                       offsetSeconds: Double(index) * Self.phaseSeconds)
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

@main
struct SpikeWidgetBundle: WidgetBundle {
    var body: some Widget {
        StaticSpikeWidget()
        SteppingSpikeWidget()
        BlinkSpikeWidget()
        FastSpikeWidget()
    }
}
