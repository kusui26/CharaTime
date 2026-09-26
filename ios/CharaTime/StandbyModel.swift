import SwiftUI
import WidgetKit
import CTCore
import CTAssets
import CTRender
import CTStore
#if canImport(UIKit)
import UIKit
#endif

/// 待受モードが要る値をそろえ、端末の状態を見張る。
///
/// **決定論を壊さないために、時刻はここでは持たない。** 時刻は `TimelineView` が
/// 与えるものだけを使い、ここが持つのは「どのキャラか」「部屋はどれか」
/// 「電池はいくつか」という、時刻に依らない入力だけ。
@MainActor
@Observable
final class StandbyModel {

    private(set) var state = AppState(userSeed: 0)
    private(set) var world: SceneWorld?
    private(set) var battery: BatteryReading?
    private(set) var loadFailure: String?
    /// 確認のために時刻をずらす仕組み。実行引数で指定されたときだけ効く。
    let timeWarp = TimeWarp.fromArguments(ProcessInfo.processInfo.arguments)

    /// いま使っている部屋。選んでいなければ同梱の部屋。
    var room: Room { state.currentRoom }

    /// 日課エンジンへの入力。文脈（電池）だけが端末の状態で変わる。
    ///
    /// ウィジェットと同じ規則（`AppState.worldInput`）で、`state.json` に書いたものから組み立てる。
    /// 同じ入力なら同じ姿になる（プラン §9 Phase 3 の 3-C ②⑩）。
    var input: WorldInput {
        state.worldInput(character: character ?? .placeholder)
    }

    private var character: CTCore.Character?
    /// 電池の変化の知らせを受ける登録。待受モードを見ているあいだだけ持つ。
    @ObservationIgnored private var batteryObservers: [any NSObjectProtocol] = []

    func start() {
        load()
        beginWatchingBattery()
        keepScreenAwake(true)
    }

    func stop() {
        endWatchingBattery()
        keepScreenAwake(false)
    }

    /// 前面に戻ったら、電池とウィジェットの記録を読み直す。**背面では画面を点けたままにしない。**
    func scenePhaseChanged(to phase: ScenePhase) {
        keepScreenAwake(phase == .active)
        guard phase == .active else { return }
        readBattery()
        // ホーム画面でウィジェットを置いたり外したりして戻ってきたら、置き方のガイドの「いまの様子」や
        // 透過背景のラベルの有無に映す（どちらもウィジェットの記録から読む。3-4）。
        reloadWidgetRecord()
    }

    // MARK: - 同梱データ

    private func load() {
        state = (try? StateStore.shared.loadOrCreate()) ?? StateStore.shared.load().state
        weekRun = WeekRunStore.shared.load()
        guard let chosen = state.currentCharacter(among: Catalog.charactersOrEmpty()) else {
            loadFailure = "characters.json に 1 体も入っていません"
            return
        }
        character = chosen
        rebuildWorld()
    }

    /// 背景を読み直して、描画に渡す一式を組み直す。
    private func rebuildWorld() {
        guard let character else { return }
        world = SceneWorld.bundled(character: character, room: room, backdrop: backdrop())
    }

    /// いまの部屋の背景。画像が読めなければ同梱の部屋に落とす（画面が出ないより良い）。
    private func backdrop() -> RoomBackdrop {
        guard let fileName = room.background.imageFileName,
              let image = ImageStore.shared.load(fileName) else { return .drawn() }
        return .picture(image)
    }

    // MARK: - 部屋を選ぶ

    /// 同梱の部屋に戻す。取り込んだ画像も片づける。
    func chooseBundledRoom() {
        save(nil)
    }

    /// 選んだ画像と帯で部屋を作り直す。
    ///
    /// 写真とホーム画面の部屋は **アイテム無しで始める**。人の写真の上にベッドや
    /// ミラーボールが浮いていると、置いた覚えのないものが出てくることになる。
    /// 置く操作は Phase 2 の配置エディタで作る。
    func applyPicture(_ choice: RoomChoice, imageData: Data, floor: RoomRect) {
        do {
            // 秒までの時刻を名前にする。同じ秒に 2 枚選んでも、上書きされるのは
            // これから捨てるほうなので困らない。
            let name = "bg-\(Int(Date().timeIntervalSince1970))"
            try ImageStore.shared.store(imageData, as: name)
            save(Room(background: choice.background(imageName: name), floor: floor, items: []))
        } catch {
            loadFailure = String(describing: error)
        }
    }

    /// 背景はそのままで、歩ける帯だけを直す。
    func applyBand(_ floor: RoomRect) {
        var updated = room
        updated.floor = floor
        save(updated)
    }

    /// 部屋を保存して画面に反映する。nil は「同梱の部屋のまま」。
    ///
    /// 片づけは、`state.json` が参照する画像（部屋・壁紙・切り抜き）のほかを消す（3-C ⑦）。
    /// 書けたときだけ片づける。書けないまま片づけると、古い `state.json` を読むウィジェットが、
    /// そこに書いてある画像を見つけられなくなる。
    private func save(_ updated: Room?) {
        state.room = updated
        if persist(reloadingWidgets: true) {
            ImageStore.shared.removeAll(keeping: state.referencedImageNames)
        }
        rebuildWorld()
    }

    /// 状態を App Group に書く。ウィジェットは、ここで書いたものを読む。
    ///
    /// `reloadingWidgets` のときは、ホーム画面のウィジェットに作り直しを頼む（3-C ⑩）。前面の
    /// アプリからの作り直しは予算に数えない。頼むのは本番のウィジェットの名前（kind）だけ。
    @discardableResult
    private func persist(reloadingWidgets: Bool) -> Bool {
        do {
            try StateStore.shared.save(state)
        } catch {
            loadFailure = String(describing: error)
            return false
        }
        if reloadingWidgets { WidgetCenter.shared.reloadTimelines(ofKind: WidgetKind.home) }
        return true
    }

    // MARK: - ウィジェット

    /// ホーム画面ウィジェットの疑似アニメの入／切（3-2b）。保存して、ウィジェットを作り直す。
    func setPseudoAnimation(_ isOn: Bool) {
        state.widget.pseudoAnimation = isOn
        persist(reloadingWidgets: true)
    }

    /// ウィジェット拡張が残した記録（3-2c）。書くのは拡張なので、設定の画面を開くたびと、前面に戻るたびに読み直す。
    private(set) var widgetRecord = WidgetDiagnostics()

    /// 1 週間の運用の記録表（3-7）。書くのも読むのもアプリだけ。
    private(set) var weekRun = WeekRunRecord()
    /// 記録表を書けなかった理由。書けたら nil。画面に出す（つけた記録を黙って失わない）。
    private(set) var weekRunSaveFailure: String?

    func reloadWidgetRecord() {
        widgetRecord = DiagnosticsStore.shared.load()
    }

    /// ウィジェットと同じ規則の「動かしてよいか」。下見の画面と設定画面が使う。
    var widgetMotion: WidgetMotion { WidgetMotion.current(for: state.widget) }

    /// いまのホーム画面ウィジェットが、どの段で動く見込みか（3-C ⑩「いまの段を見せる」）。
    ///
    /// 見込みなのは、着色・クリアの外観と常時表示はウィジェットの側でしか分からないため。
    var widgetCapability: RenderCapability {
        #if canImport(UIKit)
        let reduceMotion = UIAccessibility.isReduceMotionEnabled
        #else
        let reduceMotion = false
        #endif
        return RenderCapability.resolve(RenderContext(
            surface: .homeWidget, pseudoAnimationEnabled: widgetMotion.pseudoAnimation,
            reduceMotion: reduceMotion, lowPowerMode: widgetMotion.lowPowerMode))
    }

    // MARK: - 端末の状態

    /// 電池の変化も見張る。アプリを開いたまま充電器に置いたとき、喜ぶのはその瞬間から（3-C ⑩）。
    private func beginWatchingBattery() {
        #if canImport(UIKit)
        UIDevice.current.isBatteryMonitoringEnabled = true
        if batteryObservers.isEmpty {
            batteryObservers = [UIDevice.batteryStateDidChangeNotification,
                                UIDevice.batteryLevelDidChangeNotification].map { observeBattery($0) }
        }
        #endif
        readBattery()
    }

    /// 知らせを受けたら電池を読み直す。知らせはメインキューで受けるので、隔離の中でそのまま読める。
    private func observeBattery(_ name: Notification.Name) -> any NSObjectProtocol {
        NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.readBattery() }
        }
    }

    private func endWatchingBattery() {
        batteryObservers.forEach { NotificationCenter.default.removeObserver($0) }
        batteryObservers = []
    }

    /// 電池を測って、表示にも日課エンジンにもウィジェットにも同じ値を渡す（3-C ⑩）。
    ///
    /// 充電を始めた時刻は、読み直しても前の値を引き継ぐ（`ContextSnapshot.reading`）。
    /// 充電したままアプリを開き直すたびに「ありがとう」と言い直さないため。
    /// ウィジェットの作り直しは、割り込みの答えが変わりうるときだけ頼む（1% ごとには頼まない）。
    private func readBattery() {
        #if canImport(UIKit)
        let device = UIDevice.current
        // 測れないときは -1 が返る。そのまま使うと「電池切れ」と誤解される。
        let level = device.batteryLevel < 0 ? nil : Double(device.batteryLevel)
        let charging = device.batteryState == .charging || device.batteryState == .full
        battery = BatteryReading(level: level, isCharging: charging)
        let previous = state.context
        state.context = ContextSnapshot.reading(batteryLevel: level, isCharging: charging,
                                                at: Date(), previous: previous)
        persist(reloadingWidgets: Interrupts.mayChangeScene(from: previous, to: state.context))
        #endif
    }

    /// 待受モードを見ているあいだだけ、画面を消させない（プラン §4.4）。
    private func keepScreenAwake(_ awake: Bool) {
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = awake
        #endif
    }
}

extension CTCore.Character {
    /// 同梱データが読めなかったときの仮のキャラ。**絵は出ないが落ちない。**
    static let placeholder = CTCore.Character(
        id: "placeholder", displayName: "？",
        personality: Personality(activity: 0.5, nightOwl: 0.5, napiness: 0.5),
        poses: [:])
}

// MARK: - 透過背景（プラン §9 Phase 3 の 3-3）

extension StandbyModel {

    /// ウィジェットが知らせた大きさ（`WidgetReload.displaySize`）から読んだ、ホーム画面のラベルの有無。
    var iconStyleReading: SlotGeometry.IconStyleReading {
        SlotGeometry.iPhone402x874.iconStyleReading(from: widgetRecord)
    }

    /// 見分けたラベルの有無。まだ分からなければ nil（大も中も置いていない、表に無い大きさ、
    /// または 3-3 より前の記録しか無い）。
    var detectedIconStyle: SlotGeometry.IconStyle? { iconStyleReading.style }

    /// 壁紙のスクショを取り込み、切り抜く。失敗したら理由を返す（画面に出す）。
    func importWallpaper(_ data: Data, as appearance: Appearance,
                         style: SlotGeometry.IconStyle) async -> String? {
        await changeWallpaper { store, widget, stamp in
            try store.importScreenshot(data, as: appearance, style: style, into: widget, stamp: stamp)
        }
    }

    /// 枠を寄せて、切り抜き直す。
    func nudgeWallpaper(_ offsets: [WidgetSlot: PixelOffset]) async -> String? {
        await changeWallpaper { store, widget, stamp in
            try store.recrop(widget, nudging: offsets, stamp: stamp)
        }
    }

    /// ラベルの有無の表で枠を作り直す（寄せた分は捨てる。「表の値に戻す」もこれ）。
    func setWallpaperIconStyle(_ style: SlotGeometry.IconStyle) async -> String? {
        await changeWallpaper { store, widget, stamp in
            try store.recrop(widget, style: style, stamp: stamp)
        }
    }

    /// 透過背景をやめ、部屋の絵に戻す。
    func removeWallpaper() {
        saveTransparency(from: state.widget.removingTransparency())
    }

    /// 透過背景を作り直す。重い仕事（スクショの展開・切り抜き・PNG の書き出し）は裏で行い、
    /// 書き戻すのは透過の項目だけにする（そのあいだに疑似アニメの入／切を変えても、消さないように）。
    private func changeWallpaper(
        _ change: @escaping @Sendable (WallpaperStore, WidgetSettings, String) throws -> WidgetSettings
    ) async -> String? {
        let widget = state.widget
        let stamp = String(Int(Date().timeIntervalSince1970 * Self.stampPerSecond))
        do {
            let updated = try await Task.detached(priority: .userInitiated) {
                try change(.shared, widget, stamp)
            }.value
            saveTransparency(from: updated)
            return nil
        } catch {
            return String(describing: error)
        }
    }

    /// 作り直すたびにファイルの名前を変える印の細かさ（1 秒あたり）。続けて寄せても名前がぶつからない。
    private static let stampPerSecond: Double = 1000

    /// 透過の項目（壁紙・スロット・ラベルの有無）を書き戻して保存し、ウィジェットを作り直し、
    /// 使わなくなった画像（前の切り抜きなど）を片づける。
    private func saveTransparency(from updated: WidgetSettings) {
        state.widget.wallpaper = updated.wallpaper
        state.widget.slots = updated.slots
        state.widget.iconStyle = updated.iconStyle
        if persist(reloadingWidgets: true) {
            ImageStore.shared.removeAll(keeping: state.referencedImageNames)
        }
    }

    /// `-CTImportWallpaper <ライトの名前> <ダークの名前>` で、App Group の images に置いた壁紙のスクショを
    /// 取り込む（確認用。シミュレータで写真アプリを通さずに 3-3 を確かめる。`-CTTime` と同じ考え方）。
    func importWallpapersForChecking(_ arguments: [String]) async {
        guard let index = arguments.firstIndex(of: "-CTImportWallpaper") else { return }
        reloadWidgetRecord()
        let names = arguments.dropFirst(index + 1).prefix(Appearance.allCases.count)
        // 先に全部読む。1 枚目を取り込むと片づけが走り、まだ参照していない 2 枚目のファイルを消すため。
        let files = zip(Appearance.allCases, names).compactMap { appearance, name in
            ImageStore.shared.url(for: name).flatMap { try? Data(contentsOf: $0) }.map { (appearance, $0) }
        }
        for (appearance, data) in files {
            let style = detectedIconStyle ?? .labeled
            if let failure = await importWallpaper(data, as: appearance, style: style) {
                loadFailure = failure
            }
        }
    }
}

// MARK: - 1 週間の運用（プラン §9 Phase 3 の 3-7）

extension StandbyModel {

    /// 始める。前の記録は消す（始め直すときも、これを使う）。
    func startWeekRun(at date: Date) {
        saveWeekRun(WeekRunRecord(startedAt: date))
    }

    /// 記録を消して、始める前に戻す。
    func resetWeekRun() {
        saveWeekRun(WeekRunRecord())
    }

    /// その日の記録を書き換えて保存する。
    func updateWeekRunDay(_ number: Int, _ change: (inout WeekRunDay) -> Void) {
        saveWeekRun(weekRun.updatingDay(number, change))
    }

    /// 一度だけ確かめることの結果を書き換えて保存する。
    func updateWeekRunCheck(_ id: String, _ change: (inout WeekRunCheck) -> Void) {
        saveWeekRun(weekRun.updatingCheck(id, change))
    }

    /// 書き出す文章。記録は実時刻なので、時刻の早送り（`-CTTime`）はかけない。
    func weekRunReport(now: Date) -> String {
        WeekRunReport.markdown(record: weekRun, diagnostics: widgetRecord, now: now, calendar: input.calendar,
                               system: .current)
    }

    private func saveWeekRun(_ record: WeekRunRecord) {
        weekRun = record
        do {
            try WeekRunStore.shared.save(record)
            weekRunSaveFailure = nil
        } catch {
            weekRunSaveFailure = String(describing: error)
        }
    }
}
