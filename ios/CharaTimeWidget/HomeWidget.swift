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
        // CarPlay には勧めない（3-5、ユーザーの判断。D-30）。iOS 26 の CarPlay は StandBy と同じ小を出せるが、
        // 運転中に動くキャラは要らず、CarPlay での見え方も確かめていない。CarPlay の設定では「その他」に回る。
        .disfavoredLocations([.carPlay], for: [.systemSmall])
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
    /// 動かしてよいか（疑似アニメの設定・書体・低電力モード。タイムラインを作ったときに決まる）。
    var motion: WidgetMotion = .still
    /// 透過背景の切り抜き（3-3）。用意していなければ nil で、部屋の絵を描く。
    var wallpaper: WidgetWallpaper?
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
        let family = WidgetSlot.Family(context.family)
        let entries = HomeEntries.make(at: dates, family: family, size: context.displaySize)
        completion(Timeline(entries: entries, policy: .atEnd))
        // 実機でメモリと作り直しの間隔を読むための記録（3-2c）。設定画面の「ウィジェットの記録」で見る。
        // 大きさも残す。アプリは、それでホーム画面のラベルの有無を見分ける（透過背景。3-3）。
        ReloadRecorder.record(family: family, size: context.displaySize, entries: entries)
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
        let motion = WidgetMotion.current(for: state.widget)
        let wallpaper = HomeWallpaper.load(for: family, settings: state.widget)
        let input = state.worldInput(character: character)
        // 部屋の背景の写真は読まない（大きく、拡張のメモリを食う。D-20）。ウィジェットは図形の部屋で描く。
        // 透過背景だけは、自分のスロットの切り抜きを 1 枚読む（全体のスクショは読まない）。
        let world = SceneWorld.bundled(character: character, room: input.room)
        let layout = WidgetStage.stage(for: family).layout(
            size: size, room: world.room, geometry: world.spriteGeometry, characterScale: character.scale)
        return WidgetMoments.make(at: dates, input: input, settings: state.settings, layout: layout)
            .map { HomeEntry(date: $0.date, moment: $0, world: world, motion: motion, wallpaper: wallpaper) }
    }

    /// 見本（ギャラリーと、読み込み中の仮の絵）。同梱の先頭のキャラが、同梱の部屋に立つ。
    /// 見本は動かさない（止めた 1 枚。置いたあとのウィジェットだけが、設定に従って動く）。
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
            WidgetScene(family: WidgetSlot.Family(family), moment: entry.moment, world: world,
                        motion: entry.motion, wallpaper: entry.wallpaper)
        } else {
            Text("キャラクターのデータを読めませんでした")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .padding()
                .containerBackground(Palette.background, for: .widget)
        }
    }
}

/// 透過背景の切り抜きを読む（3-3）。
enum HomeWallpaper {

    /// その大きさのスロットの切り抜きを、外観ごとに読む。**タイムラインごとに 1 度だけ読み、
    /// 全エントリで同じ画像を使う**（エントリごとに読むと、同じ壁紙を何十枚も展開しかねない）。
    /// 読めなければ nil で、部屋の絵に戻る（拡張を落とさない）。
    static func load(for family: WidgetSlot.Family, settings: WidgetSettings) -> WidgetWallpaper? {
        guard let crops = settings.slot(for: family)?.crops else { return nil }
        let store = ImageStore.shared
        let wallpaper = WidgetWallpaper(light: crops.light.flatMap(store.load),
                                        dark: crops.dark.flatMap(store.load))
        return wallpaper.light == nil && wallpaper.dark == nil ? nil : wallpaper
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
