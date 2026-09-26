import Foundation
import CoreGraphics

/// ウィジェット拡張が残す記録（プラン §9 Phase 3 の 3-2c）。アプリの設定画面が読んで見せる。
///
/// 実機では、拡張のメモリもタイムラインを作り直した時刻も、外から見る手段が乏しい（シミュレータで
/// 使った `vmmap` は実機に使えない）。だから拡張が自分で測って App Group に書き、アプリが読む。
/// 3-7（1 週間の運用）では、作り直しの間隔と、メモリの最大値（R-18。15 MB 以下が目安、
/// 約 30 MB で落とされる）をここで読む。
public struct WidgetDiagnostics: Codable, Sendable, Equatable {

    /// 作り直した記録。古い順。
    public private(set) var reloads: [WidgetReload]

    /// 残す件数。1 週間の運用（3-7）の終わりに、1 日目の記録まで残っているように決める。大と小（スタンバイ）を
    /// 合わせて 1 日 10〜20 回の見込みなので、その 2 倍（1 日 40 回）でも 1 週間ぶん（280 件）が入る数にした。
    /// 増やしすぎると、拡張が作り直すたびに読み書きする JSON が大きくなる（300 件で約 70 KB）。
    public static let capacity = 300

    public init(reloads: [WidgetReload] = []) {
        self.reloads = Array(reloads.suffix(Self.capacity))
    }

    /// 1 件足す。上限を超えたら、古いものから捨てる。
    public func recording(_ reload: WidgetReload) -> WidgetDiagnostics {
        WidgetDiagnostics(reloads: reloads + [reload])
    }

    /// 同じ作り直しの記録（時刻と大きさが同じもの）のメモリの最大値を、あとで測った値で引き上げる。
    ///
    /// 拡張は、タイムラインを渡したあとでエントリの絵を作る。そのぶん、渡した直後に測った値より
    /// あとで測った値のほうが大きい。下げることはしない。
    public func raisingPeak(of reload: WidgetReload, to peakBytes: UInt64) -> WidgetDiagnostics {
        WidgetDiagnostics(reloads: reloads.map { recorded in
            guard recorded.isSameReload(as: reload), peakBytes > recorded.peakBytes else { return recorded }
            var raised = recorded
            raised.peakBytes = peakBytes
            return raised
        })
    }

    /// 新しい順に、`count` 件まで。
    public func latest(_ count: Int) -> [WidgetReload] {
        Array(reloads.reversed().prefix(count))
    }

    /// その大きさのウィジェットが最後に知らせた大きさ（pt）。まだ知らせていなければ nil。
    public func latestDisplaySize(of family: WidgetSlot.Family) -> CGSize? {
        reloads.last { $0.family == family && $0.displaySize != nil }?.displaySize
    }
}

/// タイムラインを 1 回作り直した記録。
public struct WidgetReload: Codable, Sendable, Equatable {
    /// 作り直した時刻。
    public var date: Date
    public var family: WidgetSlot.Family
    /// 作ったエントリの数。
    public var entryCount: Int
    /// 記録したときのメモリ（`phys_footprint`。OS がメモリの上限と比べる値）。
    public var footprintBytes: UInt64
    /// 拡張が起きてからのメモリの最大値。大・中・小を 1 つのプロセスで作るので、
    /// ほかの大きさを作ったぶんも入る。
    public var peakBytes: UInt64
    /// 疑似アニメで描くタイムラインだったか。
    public var pseudoAnimation: Bool
    /// ウィジェットの大きさ（pt。WidgetKit が渡す `displaySize`）。アプリはこれで、ホーム画面の
    /// アプリ名のラベルの有無を見分ける（透過背景の枠の表を選ぶ。3-3）。3-3 より前の記録には無い。
    public var displaySize: CGSize?

    public init(date: Date, family: WidgetSlot.Family, entryCount: Int, footprintBytes: UInt64,
                peakBytes: UInt64, pseudoAnimation: Bool, displaySize: CGSize? = nil) {
        self.date = date
        self.family = family
        self.entryCount = entryCount
        self.footprintBytes = footprintBytes
        self.peakBytes = peakBytes
        self.pseudoAnimation = pseudoAnimation
        self.displaySize = displaySize
    }

    func isSameReload(as other: WidgetReload) -> Bool {
        date == other.date && family == other.family
    }
}

// MARK: - 設定画面に見せるまとめ

public extension WidgetDiagnostics {

    /// 大きさごとのまとめ（作り直した時刻と回数）。
    ///
    /// メモリは大きさごとに分けない。拡張は大・中・小を 1 つのプロセスで作るので、記録した値は
    /// そのときのプロセス全体の値になる（約 30 MB の上限も、プロセス全体にかかる）。
    struct FamilySummary: Sendable, Equatable {
        public let family: WidgetSlot.Family
        /// いちばん新しい作り直し。
        public let lastReload: WidgetReload
        /// `now` までの 24 時間に作り直した回数。
        public let reloadsInLastDay: Int
    }

    /// 1 日の秒数。「24 時間」の窓。
    static let dayWindowSeconds: TimeInterval = 24 * 3600

    /// 記録のある大きさごとに、大・中・小の順でまとめる。
    func summaries(now: Date) -> [FamilySummary] {
        Self.displayOrder.compactMap { family in
            let ofFamily = reloads.filter { $0.family == family }
            guard let last = ofFamily.last else { return nil }
            let inLastDay = ofFamily.filter { Self.isWithinDay($0, now: now) }
            return FamilySummary(family: family, lastReload: last, reloadsInLastDay: inLastDay.count)
        }
    }

    /// `now` までの 24 時間の、拡張のメモリの最大値。その間に記録が無ければ nil。
    func peakBytes(now: Date) -> UInt64? {
        reloads.filter { Self.isWithinDay($0, now: now) }.map(\.peakBytes).max()
    }

    /// 見せる順。ホーム画面のページで上に置く大きいほうから。
    private static let displayOrder: [WidgetSlot.Family] = [.large, .medium, .small]

    /// `now` までの 24 時間に入るか。ちょうど 24 時間前は入れない。
    private static func isWithinDay(_ reload: WidgetReload, now: Date) -> Bool {
        now.timeIntervalSince(reload.date) < dayWindowSeconds
    }
}

// MARK: - 1 週間の運用の日ごとのまとめ（3-7）

public extension WidgetDiagnostics {

    /// 1 日ぶんのまとめ。1 週間の運用の記録表に、日ごとに並べる。
    struct DaySummary: Sendable, Equatable {
        /// その日の 0 時。
        public let day: Date
        /// 大きさごとの、その日に作り直した回数。
        public let reloadCounts: [WidgetSlot.Family: Int]
        /// 大きさごとの、いちばん長い間隔（秒）。前の作り直しから、その日の作り直しまで。
        /// タイムラインは 6 時間ぶんなので、それより長いと、終わりの姿のまま止まっていた時間がある。
        public let longestGapSeconds: [WidgetSlot.Family: TimeInterval]
        /// その日の、拡張のメモリの最大値。記録が無ければ nil。
        public let peakBytes: UInt64?
        /// その日に作ったタイムラインの疑似アニメ（入は true）。入と切が混ざれば両方。記録が無ければ空。
        public let pseudoAnimation: Set<Bool>
        /// 記録が上限まで詰まっていて、その日の前のほうが捨てられているかもしれない。回数が 0 でも、
        /// 作り直しが無かったとは限らない（止まっていたと取り違えないための印）。
        public let isPartial: Bool

        public init(day: Date, reloadCounts: [WidgetSlot.Family: Int],
                    longestGapSeconds: [WidgetSlot.Family: TimeInterval], peakBytes: UInt64?,
                    pseudoAnimation: Set<Bool>, isPartial: Bool = false) {
            self.day = day
            self.reloadCounts = reloadCounts
            self.longestGapSeconds = longestGapSeconds
            self.peakBytes = peakBytes
            self.pseudoAnimation = pseudoAnimation
            self.isPartial = isPartial
        }
    }

    /// まとめる日数の上限。記録は 300 件（1 日 40 回で 1 週間）なので、それより前は数えても空になる。
    /// 時計が大きくずれたときに、何百日も並べないための歯止め。
    static let maximumSummaryDays = 31

    /// `start` の日から `now` の日まで、1 日ずつまとめる。記録の無い日も 0 回として並べる
    /// （作り直しが止まっていた日が分かる）。`now` が `start` より前なら空。
    func daySummaries(from start: Date, through now: Date, calendar: Calendar) -> [DaySummary] {
        guard now >= start else { return [] }
        let lastDay = calendar.startOfDay(for: now)
        let nextDay = { (day: Date) in calendar.date(byAdding: .day, value: 1, to: day) }
        let days = sequence(first: calendar.startOfDay(for: start), next: nextDay).prefix { $0 <= lastDay }
        let gaps = self.gaps
        return days.suffix(Self.maximumSummaryDays).map { day in
            summary(of: day, gaps: gaps.filter { calendar.isDate($0.endedAt, inSameDayAs: day) },
                    reloads: reloads.filter { calendar.isDate($0.date, inSameDayAs: day) },
                    isPartial: mayHaveDropped(before: day))
        }
    }
}

extension WidgetDiagnostics {

    /// 同じ大きさの、となり合う作り直しの間隔。後の作り直しの時刻で、どの日のものかを決める。
    struct Gap {
        let family: WidgetSlot.Family
        let endedAt: Date
        let seconds: TimeInterval
    }

    var gaps: [Gap] {
        Dictionary(grouping: reloads, by: \.family).flatMap { family, ofFamily in
            let dates = ofFamily.map(\.date).sorted()
            return zip(dates, dates.dropFirst()).map { earlier, later in
                Gap(family: family, endedAt: later, seconds: later.timeIntervalSince(earlier))
            }
        }
    }

    func summary(of day: Date, gaps: [Gap], reloads: [WidgetReload], isPartial: Bool) -> DaySummary {
        DaySummary(day: day,
                   reloadCounts: Dictionary(grouping: reloads, by: \.family).mapValues(\.count),
                   longestGapSeconds: Dictionary(grouping: gaps, by: \.family)
                       .compactMapValues { $0.map(\.seconds).max() },
                   peakBytes: reloads.map(\.peakBytes).max(),
                   pseudoAnimation: Set(reloads.map(\.pseudoAnimation)),
                   isPartial: isPartial)
    }

    /// `time` より前の記録が、上限で捨てられているかもしれないか。上限まで詰まっていて、いちばん古い記録が
    /// `time` より後なら、その間の記録は捨てられた恐れがある（詰まっていなければ、捨てたものは無い）。
    func mayHaveDropped(before time: Date) -> Bool {
        guard reloads.count >= Self.capacity, let oldest = reloads.map(\.date).min() else { return false }
        return oldest > time
    }
}
