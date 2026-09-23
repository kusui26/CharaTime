import WidgetKit
import SwiftUI
import CTCore
import CTAssets
import CTStore
import CTRender

/// ホーム画面ウィジェット（面 1。プラン §9 Phase 3 の 3-2）。大・中・小の 3 つ。
///
/// 5 分刻みで 6 時間ぶんのエントリを先に作り、使い切ったら作り直す（`.atEnd`。1 日に約 4 回）。
/// 各エントリの姿は、アプリと同じ `sceneState(at:)` の答え（3-C ②③）。
struct HomeWidget: Widget {

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKind.home, provider: HomeProvider()) { entry in
            HomeWidgetView(entry: entry)
        }
        .configurationDisplayName(Self.displayName)
        .description(Self.summary)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        // 既定の余白を外し、枠いっぱいに描く。部屋・透過の背景・位置合わせの目印が、
        // 同じ枠を基準にそろう（3-C ⑥）。
        .contentMarginsDisabled()
    }

    // **表示名は `String` の定数で渡す。** 文字列補間を直接書くと書式付きの文字列になり、
    // WidgetKit が実行時に止める（CLAUDE.md §3 の落とし穴）。
    private static let displayName = "CharaTime"
    private static let summary = "キャラクターが部屋で暮らします。5 分ごとに居場所と姿が変わります。"
}

/// エントリ 1 件。描く材料（姿と、キャラと部屋の一式）を持つ。
struct HomeEntry: TimelineEntry {
    let date: Date
    let moment: WidgetMoment
    /// 描くキャラと部屋。同梱データが読めなかったときは nil（落とさずに理由を出す）。
    let world: SceneWorld?
}

struct HomeProvider: TimelineProvider {

    func placeholder(in context: Context) -> HomeEntry {
        HomeEntries.sample(at: .now)
    }

    /// ギャラリーでは見本を、置いたあとの一瞬の絵には、いまの姿を出す。
    func getSnapshot(in context: Context, completion: @escaping (HomeEntry) -> Void) {
        guard !context.isPreview else { return completion(HomeEntries.sample(at: .now)) }
        let now = HomeEntries.make(at: [.now], family: WidgetSlot.Family(context.family),
                                   size: context.displaySize).first
        completion(now ?? HomeEntries.sample(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HomeEntry>) -> Void) {
        // 暦は端末のもの。日課エンジンへの入力（`AppState.worldInput`）と同じ暦で升目を切る。
        let dates = WidgetTimeline.entryDates(from: Date(), calendar: .current)
        let entries = HomeEntries.make(at: dates, family: WidgetSlot.Family(context.family),
                                       size: context.displaySize)
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

/// エントリを作る。**何があっても 1 件以上を返し、落とさない**（CLAUDE.md §2）。
enum HomeEntries {

    static func make(at dates: [Date], family: WidgetSlot.Family, size: CGSize) -> [HomeEntry] {
        let state = StateStore.shared.load().state
        guard let character = state.currentCharacter(among: Catalog.charactersOrEmpty()) else {
            let now = dates.first ?? Date()
            return [HomeEntry(date: now, moment: .sample(room: state.currentRoom, at: now), world: nil)]
        }
        let input = state.worldInput(character: character)
        // 背景の写真は読まない（大きく、拡張のメモリを食う。D-20）。ウィジェットは図形の部屋で描く。
        let world = SceneWorld.bundled(character: character, room: input.room)
        let layout = WidgetStage.stage(for: family).layout(
            size: size, room: world.room, geometry: world.spriteGeometry, characterScale: character.scale)
        return WidgetMoments.make(at: dates, input: input, settings: state.settings, layout: layout)
            .map { HomeEntry(date: $0.date, moment: $0, world: world) }
    }

    /// 見本（ギャラリーと、読み込み中の仮の絵）。同梱の先頭のキャラが、同梱の部屋に立つ。
    static func sample(at date: Date) -> HomeEntry {
        let room = BundledRoom.room
        let world = Catalog.charactersOrEmpty().first.map { SceneWorld.bundled(character: $0, room: room) }
        return HomeEntry(date: date, moment: .sample(room: room, at: date), world: world)
    }
}

struct HomeWidgetView: View {

    let entry: HomeEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let world = entry.world {
            WidgetScene(family: WidgetSlot.Family(family), moment: entry.moment, world: world)
        } else {
            Text("キャラクターのデータを読めませんでした")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding()
                .containerBackground(Palette.background, for: .widget)
        }
    }
}

extension WidgetSlot.Family {
    /// WidgetKit の大きさから。このウィジェットは小・中・大だけを名乗る。
    init(_ family: WidgetFamily) {
        switch family {
        case .systemSmall: self = .small
        case .systemMedium: self = .medium
        default: self = .large
        }
    }
}
