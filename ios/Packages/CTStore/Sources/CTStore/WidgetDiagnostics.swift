import Foundation

/// ウィジェット拡張が残す記録（プラン §9 Phase 3 の 3-2c）。アプリの設定画面が読んで見せる。
///
/// 実機では、拡張のメモリもタイムラインを作り直した時刻も、外から見る手段が乏しい（シミュレータで
/// 使った `vmmap` は実機に使えない）。だから拡張が自分で測って App Group に書き、アプリが読む。
/// 3-7（1 週間の運用）では、作り直しの間隔と、メモリの最大値（R-18。15 MB 以下が目安、
/// 約 30 MB で落とされる）をここで読む。
public struct WidgetDiagnostics: Codable, Sendable, Equatable {

    /// 作り直した記録。古い順。
    public private(set) var reloads: [WidgetReload]

    /// 残す件数。大と中を置くと 1 日に 10 回ほど作り直すので、1 週間ぶん（3-7）より少し多く残す。
    public static let capacity = 100

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

    public init(date: Date, family: WidgetSlot.Family, entryCount: Int, footprintBytes: UInt64,
                peakBytes: UInt64, pseudoAnimation: Bool) {
        self.date = date
        self.family = family
        self.entryCount = entryCount
        self.footprintBytes = footprintBytes
        self.peakBytes = peakBytes
        self.pseudoAnimation = pseudoAnimation
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
