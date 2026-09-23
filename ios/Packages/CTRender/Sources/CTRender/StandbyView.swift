import SwiftUI
import CTCore
import CTAssets
import CTStore

/// 面 0・待受モード。**このアプリの核**（プラン §4.3）。
///
/// 時刻を `TimelineView` から受け取り、日課エンジンに「いまの姿」を聞いて描く。
/// アニメーションの状態を持たないので、アプリを閉じて開き直しても、
/// ウィジェットで見た姿と食い違わない。
public struct StandbyView: View {

    public let input: WorldInput
    public let world: SceneWorld
    public let settings: CTStore.Settings
    /// 電池の読み。本体アプリが測って渡す（CTRender は UIKit を持たない）。
    public let battery: BatteryReading?
    /// 確認のために時刻をずらす仕組み。ふだんは `.real`。
    public let timeWarp: TimeWarp

    /// 開いている画面。**中身は本体アプリが出す**（写真アプリを開く画面など、
    /// ウィジェット拡張と共有できないものが混ざるため）。
    @Binding public var sheet: StandbySheet?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var plans = DayPlanCache()
    @State private var showsControls = false
    @State private var isResting = false

    public init(input: WorldInput, world: SceneWorld,
                settings: CTStore.Settings = CTStore.Settings(),
                battery: BatteryReading? = nil, timeWarp: TimeWarp = .real,
                sheet: Binding<StandbySheet?>) {
        self.input = input
        self.world = world
        self.settings = settings
        self.battery = battery
        self.timeWarp = timeWarp
        _sheet = sheet
    }

    /// 動いているときは画面のリフレッシュレートまで、止まっているときは 30fps に落とす
    /// （プラン §7.5）。据え置きで使うので、電池の持ちが体験に直結する。
    private static let movingInterval: Double = 1.0 / 120
    private static let restingInterval: Double = 1.0 / 30
    /// 操作パネルが出ている時間。
    private static let controlsLingerSeconds: Double = 4.5

    public var body: some View {
        TimelineView(.animation(minimumInterval: isResting ? Self.restingInterval
                                                           : Self.movingInterval)) { context in
            let date = timeWarp.apply(to: context.date)
            let state = sceneState(at: date)
            let night = isNight(at: date)
            let palette = RoomPalette.forNight(night)
            ZStack {
                SceneView(state: state, world: world, palette: palette,
                          reducesMotion: reduceMotion,
                          seconds: date.timeIntervalSinceReferenceDate, isNight: night)
                if settings.showsClock { clock(palette: palette, at: date) }
                StandbyControls(isVisible: showsControls, palette: palette) { sheet = $0 }
                if timeWarp.isActive { TimeWarpBadge(warp: timeWarp, palette: palette) }
            }
            // 早送り中は姿がめまぐるしく変わるので、描き直しを落とさない。
            .onChange(of: state.activity.restsTheScreen) { _, resting in
                isResting = resting && !timeWarp.isActive
            }
        }
        .background(Color.black)
        .contentShape(Rectangle())
        .onTapGesture { revealControls() }
    }

    private func sceneState(at date: Date) -> SceneState {
        let day = DayKey(date, calendar: input.calendar)
        return SceneEngine.sceneState(at: date, input: input,
                                      plan: plans.plan(for: day, input: input))
    }

    private func isNight(at date: Date) -> Bool {
        settings.nightMode && NightMode.isNight(at: date, calendar: input.calendar)
    }

    /// 画面のいちばん上から時計までの余白（図形で描く部屋のとき。画面の高さに対する比）。
    ///
    /// **Dynamic Island の下に来る値にしてある。** 時計は画面の外枠を無視して置くので、
    /// 安全領域ぶんをここで見込まないと、数字の上が島に隠れる。
    private static let clockTopRatio: Double = 0.105
    /// 取り込んだ画像のとき、時計と歩ける帯のあいだに空ける高さ。
    private static let clockBandGap: Double = 26

    /// 時計。
    ///
    /// 図形で描く部屋では画面の上に置く（ガラケー待受の顔）。
    /// **取り込んだ画像では、歩ける帯のすぐ上に置く。** 画面の上にはアイコンや
    /// 空が来ることが多く、そこに大きな数字を重ねると互いに読めなくなる。
    /// 帯の上はユーザーが「床ではない」と決めた場所なので、いちばん空いている。
    private func clock(palette: RoomPalette, at date: Date) -> some View {
        GeometryReader { geometry in
            let face = ClockView(
                date: date, style: settings.clockStyle,
                palette: world.backdrop.isPicture ? palette.overPicture() : palette,
                battery: battery, calendar: input.calendar,
                referenceHeight: geometry.size.height)
            if world.backdrop.isPicture {
                // 帯のすぐ上に、中身の大きさぴったりの板を敷いて置く。
                let bottom = geometry.size.height * world.room.floor.minY - Self.clockBandGap
                ClockPlate { face }
                    .fixedSize()
                    .frame(width: geometry.size.width,
                           height: Swift.max(160, bottom), alignment: .bottom)
            } else {
                face.frame(maxWidth: .infinity)
                    .padding(.top, geometry.size.height * Self.clockTopRatio)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .ignoresSafeArea()
    }

    private func revealControls() {
        withAnimation(.easeOut(duration: 0.22)) { showsControls = true }
        Task {
            try? await Task.sleep(for: .seconds(Self.controlsLingerSeconds))
            withAnimation(.easeIn(duration: 0.35)) { showsControls = false }
        }
    }
}

/// その日の行動表を持ち回す入れ物。
///
/// 行動表を作るのは 0.3 ミリ秒、引くだけなら 6 マイクロ秒。待受モードは毎フレーム
/// 引くので、日付が変わるまで作り直さない。
@MainActor
final class DayPlanCache {

    private var cached: DayPlan?
    /// 表を作ったときの入力の指紋。**部屋を模様替えすると日課も変わる**ので、
    /// 日付だけでなく入力そのものが変わったかも見る。
    private var fingerprint: UInt64?

    func plan(for day: DayKey, input: WorldInput) -> DayPlan {
        let current = input.fingerprint
        if let cached, cached.day == day, fingerprint == current { return cached }
        let fresh = DayPlan.make(for: day, input: input)
        cached = fresh
        fingerprint = current
        return fresh
    }
}

extension Activity {
    /// 描き直しを 30fps に落としてよい行動か。
    ///
    /// 位置が動かない行動は、呼吸とまばたきしか変わらない。120fps で描く意味がない。
    var restsTheScreen: Bool {
        switch self {
        case .wander, .dance, .play, .happyStretch: false
        default: true
        }
    }
}
