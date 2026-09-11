import SwiftUI
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
    var room: Room { state.room ?? BundledRoom.room }

    /// 日課エンジンへの入力。文脈（電池）だけが端末の状態で変わる。
    var input: WorldInput {
        WorldInput(character: character ?? .placeholder,
                   room: room,
                   userSeed: state.userSeed,
                   context: context)
    }

    private var character: CTCore.Character?
    private var context: ContextSnapshot?

    func start() {
        load()
        beginWatchingBattery()
        keepScreenAwake(true)
    }

    func stop() {
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
        let characters = Catalog.charactersOrEmpty()
        guard let chosen = characters.first(where: { $0.id == state.selectedCharacterID })
                ?? characters.first else {
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
        switch room.background {
        case .bundled:
            return .drawn()
        case .photo(let fileName), .homeScreenShot(let fileName):
            guard let image = ImageStore.shared.load(fileName) else { return .drawn() }
            return .picture(image)
        }
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
    private func save(_ updated: Room?) {
        state.room = updated
        do {
            try StateStore.shared.save(state)
        } catch {
            loadFailure = String(describing: error)
        }
        ImageStore.shared.removeAll(keeping: imageNames(of: updated))
        rebuildWorld()
    }

    private func imageNames(of room: Room?) -> Set<String> {
        switch room?.background {
        case .photo(let name), .homeScreenShot(let name): [name]
        default: []
        }
    }

    // MARK: - 端末の状態

    private func beginWatchingBattery() {
        #if canImport(UIKit)
        UIDevice.current.isBatteryMonitoringEnabled = true
        #endif
        readBattery()
    }

    /// 電池を測って、表示にも日課エンジンにも同じ値を渡す。
    private func readBattery() {
        #if canImport(UIKit)
        let device = UIDevice.current
        // 測れないときは -1 が返る。そのまま使うと「電池切れ」と誤解される。
        let level = device.batteryLevel < 0 ? nil : Double(device.batteryLevel)
        let charging = device.batteryState == .charging || device.batteryState == .full
        battery = BatteryReading(level: level, isCharging: charging)
        context = ContextSnapshot(batteryLevel: level, isCharging: charging, capturedAt: Date())
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
