import SwiftUI
import CTCore
import CTAssets
import CTStore

/// 骨組みの自己診断。
///
/// Phase 1 で待受モードに置き換わる一時的な画面。ここにあるのは「4 つのパッケージと
/// App Group がつながっているか」を目で確かめるための表示だけで、製品の UI ではない。
public struct SkeletonView: View {

    public struct Check: Identifiable, Sendable {
        public let id = UUID()
        public var title: String
        public var passed: Bool
        public var detail: String
    }

    private let checks: [Check]
    private let capability: RenderCapability

    public init(store: StateStore = .shared) {
        self.checks = Self.run(store: store)
        self.capability = RenderCapability.resolve(RenderContext(surface: .homeWidget))
    }

    public var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    VStack(spacing: 0) {
                        ForEach(Array(checks.enumerated()), id: \.element.id) { index, check in
                            if index > 0 { Divider().overlay(Palette.line) }
                            row(check)
                        }
                    }
                    .background(Palette.card)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Palette.line, lineWidth: 2))
                    footer
                }
                .padding(20)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("CharaTime")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text("骨組みの自己診断 ・ Phase 0")
                .font(.system(size: 13))
                .foregroundStyle(Palette.inkMuted)
        }
    }

    private func row(_ check: Check) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: check.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 19))
                .foregroundStyle(check.passed ? Palette.ok : Palette.ng)
            VStack(alignment: .leading, spacing: 3) {
                Text(check.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text(check.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ウィジェットの描画段: \(capability.label)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Palette.accent)
            Text("Phase 0 のスパイクで実機の判定を入れるまでは、安全側の段に留める。")
                .font(.system(size: 11))
                .foregroundStyle(Palette.inkMuted)
        }
    }

    // MARK: - 検査

    static func run(store: StateStore) -> [Check] {
        let loaded = store.load()
        let characters = Catalog.charactersOrEmpty()
        // 日課エンジンの検査だけは、キャラが 1 体も読めないと成り立たないので nil になる。
        let all: [Check?] = [
            deterministicHashCheck(),
            bundledDataCheck(characters),
            appGroupCheck(store: store, outcome: loaded.outcome),
            fallbackCheck(),
            dayPlanCheck(characters: characters, state: loaded.state)
        ]
        return all.compactMap { $0 }
    }

    /// プロセスをまたいでも同じ値になるか。値が変わったら、ウィジェットで見た姿と
    /// アプリを開いた姿が食い違う（`Hash64` の説明を参照）。
    private static func deterministicHashCheck() -> Check {
        let golden = Hash64.combine(0, [1])
        return Check(title: "CTCore ・ 決定論ハッシュ",
                     passed: golden == expectedCombineGolden,
                     detail: "combine(0,[1]) = \(golden)")
    }

    /// 同梱データが読めるか。
    private static func bundledDataCheck(_ characters: [CTCore.Character]) -> Check {
        let frameTotal = characters.first.map { character in
            Pose.allCases.reduce(0) { $0 + character.frameCount($1) }
        } ?? 0
        let names = characters.map(\.displayName).joined(separator: "、")
        return Check(
            title: "CTAssets ・ 同梱データ",
            passed: characters.count == expectedCharacterCount && frameTotal == expectedFrameCount,
            detail: characters.isEmpty
                ? "characters.json を読めなかった"
                : "\(characters.count) 体 ・ \(names) ・ 1 体 \(frameTotal) 枚")
    }

    /// App Group に書いて読み返せるか。
    private static func appGroupCheck(store: StateStore, outcome: StateStore.LoadOutcome) -> Check {
        let title = "CTStore ・ App Group"
        guard outcome != .noContainer else {
            return Check(title: title, passed: false,
                         detail: "共有コンテナに届かない（\(AppGroup.identifier) が未設定）")
        }
        do {
            let state = try store.loadOrCreate()
            let again = store.load()
            let seed = String(state.userSeed, radix: 16)
            return Check(title: title,
                         passed: again.state.userSeed == state.userSeed && again.outcome == .loaded,
                         detail: "種 \(seed) ・ \(store.fileURL?.lastPathComponent ?? "-")")
        } catch {
            return Check(title: title, passed: false, detail: String(describing: error))
        }
    }

    /// 描画の梯子が期待どおりに落ちるか。
    private static func fallbackCheck() -> Check {
        let dimmed = RenderCapability.resolve(RenderContext(surface: .homeWidget,
                                                            luminanceReduced: true))
        return Check(title: "CTRender ・ フォールバック",
                     passed: dimmed == .staticOnly,
                     detail: "減光中は \(dimmed.label) まで落ちる")
    }

    /// 同梱キャラで、いまの姿を引けるか。キャラが 1 体も読めなければ検査そのものが無い。
    private static func dayPlanCheck(characters: [CTCore.Character], state: AppState) -> Check? {
        guard let character = characters.first(where: { $0.id == state.selectedCharacterID })
                ?? characters.first else { return nil }
        let world = WorldInput(character: character, room: sampleRoom, userSeed: state.userSeed)
        let now = Date()
        let scene = SceneEngine.sceneState(at: now, input: world)
        let plan = DayPlan.make(for: DayKey(now, calendar: world.calendar), input: world)
        return Check(
            title: "日課エンジン ・ いまの姿",
            passed: plan.segments.count > minimumSegmentCount,
            detail: "\(character.displayName)は「\(scene.activity.label)」"
                + " ・ 起床 \(clock(plan.wakeMinute)) 就寝 \(clock(plan.bedtimeMinute))"
                + " ・ 今日は \(plan.segments.count) 区切り")
    }

    private static func clock(_ minute: Double) -> String {
        String(format: "%02d:%02d", Int(minute) / 60 % 24, Int(minute) % 60)
    }

    // MARK: - 検査が期待する値

    /// `Hash64.combine(0, [1])` の凍結値。テスト側と同じ数字を、わざと別々に書いてある。
    /// 片方を書き換えただけでは検査が通らないようにするため。
    private static let expectedCombineGolden: UInt64 = 10_257_114_587_443_610_966
    private static let expectedCharacterCount = 5
    /// Tier 1 の 1 体あたりの総コマ数（プラン §5.5）。
    private static let expectedFrameCount = 11
    /// 一日の区切りがこれ以下なら、日課表が組み立てられていない。
    private static let minimumSegmentCount = 10

    /// 自己診断だけで使う仮の部屋。製品の部屋ではない。
    private static let sampleRoom = Room(
        background: .bundled("room-a"),
        floor: RoomRect(x: 0.06, y: 0.62, width: 0.88, height: 0.24),
        items: [PlacedItem(id: "mb", kind: .mirrorBall, position: RoomPoint(x: 0.5, y: 0.70)),
                PlacedItem(id: "cu", kind: .cushion, position: RoomPoint(x: 0.86, y: 0.74))])
}

#Preview {
    SkeletonView(store: StateStore(directory: FileManager.default.temporaryDirectory))
}
