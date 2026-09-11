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
        var checks: [Check] = []

        // CTCore: プロセスをまたいでも同じ値になるか
        let golden = Hash64.combine(0, [1])
        checks.append(Check(
            title: "CTCore ・ 決定論ハッシュ",
            passed: golden == 10_257_114_587_443_610_966,
            detail: "combine(0,[1]) = \(golden)"))

        // CTAssets: 同梱データが読めるか
        let characters = Catalog.charactersOrEmpty()
        let frameTotal = characters.first.map { c in Pose.allCases.reduce(0) { $0 + c.frameCount($1) } } ?? 0
        checks.append(Check(
            title: "CTAssets ・ 同梱データ",
            passed: characters.count == 5 && frameTotal == 11,
            detail: characters.isEmpty
                ? "characters.json を読めなかった"
                : "\(characters.count) 体 ・ \(characters.map(\.displayName).joined(separator: "、")) ・ 1 体 \(frameTotal) 枚"))

        // CTStore: App Group に書いて読めるか
        let loaded = store.load()
        switch loaded.outcome {
        case .noContainer:
            checks.append(Check(title: "CTStore ・ App Group", passed: false,
                                detail: "共有コンテナに届かない（\(AppGroup.identifier) が未設定）"))
        default:
            var passed = false
            var detail = ""
            do {
                let state = try store.loadOrCreate()
                let again = store.load()
                passed = again.state.userSeed == state.userSeed && again.outcome == .loaded
                detail = "種 \(String(state.userSeed, radix: 16)) ・ \(store.fileURL?.lastPathComponent ?? "-")"
            } catch {
                detail = String(describing: error)
            }
            checks.append(Check(title: "CTStore ・ App Group", passed: passed, detail: detail))
        }

        // CTRender: 梯子が期待どおりに落ちるか
        let dimmed = RenderCapability.resolve(RenderContext(surface: .homeWidget, luminanceReduced: true))
        checks.append(Check(
            title: "CTRender ・ フォールバック",
            passed: dimmed == .staticOnly,
            detail: "減光中は \(dimmed.label) まで落ちる"))

        // 日課エンジン: 同梱キャラで、いまの姿を引けるか
        if let character = characters.first(where: { $0.id == loaded.state.selectedCharacterID })
            ?? characters.first {
            let world = WorldInput(
                character: character,
                room: Room(background: .bundled("room-a"),
                           floor: RoomRect(x: 0.06, y: 0.62, width: 0.88, height: 0.24),
                           items: [PlacedItem(id: "mb", kind: .mirrorBall, position: RoomPoint(x: 0.5, y: 0.70)),
                                   PlacedItem(id: "cu", kind: .cushion, position: RoomPoint(x: 0.86, y: 0.74))]),
                userSeed: loaded.state.userSeed)
            let now = Date()
            let state = SceneEngine.sceneState(at: now, input: world)
            let plan = DayPlan.make(for: DayKey(now, calendar: world.calendar), input: world)
            let wake = String(format: "%02d:%02d", Int(plan.wakeMinute) / 60, Int(plan.wakeMinute) % 60)
            let bed = String(format: "%02d:%02d", Int(plan.bedtimeMinute) / 60 % 24, Int(plan.bedtimeMinute) % 60)
            checks.append(Check(
                title: "日課エンジン ・ いまの姿",
                passed: plan.segments.count > 10,
                detail: "\(character.displayName)は「\(state.activity.label)」"
                    + " ・ 起床 \(wake) 就寝 \(bed) ・ 今日は \(plan.segments.count) 区切り"))
        }

        return checks
    }
}

#Preview {
    SkeletonView(store: StateStore(directory: FileManager.default.temporaryDirectory))
}
