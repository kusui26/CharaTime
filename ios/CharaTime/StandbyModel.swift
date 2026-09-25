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

    /// 前面に戻ったら電池を測り直す。**背面では画面を点けたままにしない。**
    func scenePhaseChanged(to phase: ScenePhase) {
        keepScreenAwake(phase == .active)
        if phase == .active { readBattery() }
    }

    // MARK: - 同梱データ

    private func load() {
        state = (try? StateStore.shared.loadOrCreate()) ?? StateStore.shared.load().state
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

    /// ウィジェット拡張が残した記録（3-2c）。書くのは拡張なので、設定画面を開くたびに読み直す。
    private(set) var widgetRecord = WidgetDiagnostics()

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
