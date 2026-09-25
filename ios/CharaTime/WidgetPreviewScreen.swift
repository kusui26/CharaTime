import SwiftUI
import CTCore
import CTStore
import CTRender

/// ホーム画面ウィジェットの見た目を、本体アプリで確かめる画面（`-CTScreen widgets`）。
///
/// 大・中・小を、ホーム画面と同じ大きさ（iOS 26 の実測）で並べ、ウィジェットと同じ
/// `WidgetScene` で描く。ホーム画面のウィジェットは実時刻でしか動かないので、ここで
/// `-CTTime`（その時刻の姿）と `-CTSpeed`（早送りでエントリ切替）を見る（プラン §9 Phase 3 の 3-2）。
///
/// 疑似アニメが入なら、ここでもマスク書体のタイマーで動く（アプリにも同じ書体を登録してある）。
/// タイマーは本物の時計で数えるので、`-CTTime`・`-CTSpeed` で変わるのはエントリの姿だけ。
/// まばたきや寝息の刻みは、いまの壁時計の秒で動く。
/// **ここで分からないこと**: 拡張が止まっていても動くか、着色・クリアの外観、メモリ。
/// それはホーム画面に置いて見る（`scripts/home-screen.sh`）。StandBy は `-CTScreen standBy` でまねる。
struct WidgetPreviewScreen: View {

    let input: WorldInput
    let world: SceneWorld
    let settings: CTStore.Settings
    let motion: WidgetMotion
    let timeWarp: TimeWarp

    /// 描き直しの間隔（秒）。エントリが替わった瞬間を、早送りでも取りこぼさない細かさ。
    private static let refreshSeconds: Double = 0.25
    private static let spacing: Double = 14

    var body: some View {
        TimelineView(.periodic(from: .now, by: Self.refreshSeconds)) { context in
            let now = timeWarp.apply(to: context.date)
            VStack(spacing: Self.spacing) {
                ForEach([WidgetSlot.Family.large, .medium, .small], id: \.self) { family in
                    widget(family, at: now)
                }
                caption(at: now)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.inkMuted.opacity(0.35))
        }
    }

    private func widget(_ family: WidgetSlot.Family, at now: Date) -> some View {
        let size = WidgetStage.referenceSize(for: family)
        let moment = PreviewMoments.moment(family, at: now, input: input, world: world, settings: settings)
        return WidgetScene(family: family, moment: moment, world: world, motion: motion)
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: WidgetStage.cornerRadius, style: .continuous))
    }

    private func caption(at now: Date) -> some View {
        let entry = WidgetTimeline.gridPoint(atOrBefore: now, calendar: input.calendar)
        let state = SceneEngine.sceneState(at: entry, input: input)
        return Text("\(ClockFormat.time(entry, calendar: input.calendar)) のエントリ ・ \(state.activity.label)")
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundStyle(Palette.ink)
    }
}

/// 下見の画面で描くエントリ。ホーム画面がその時刻に出しているもの（5 分の升目）を、
/// ひとつ前のエントリと一緒に作る。ひとつ前が要るのは、遠くへ移ったか（消えて現れるか）を決めるため。
enum PreviewMoments {

    static func moment(_ family: WidgetSlot.Family, at now: Date, input: WorldInput, world: SceneWorld,
                       settings: CTStore.Settings) -> WidgetMoment {
        let size = WidgetStage.referenceSize(for: family)
        let layout = WidgetStage.stage(for: family).layout(
            size: size, room: world.room, geometry: world.spriteGeometry,
            characterScale: world.character.scale)
        let entry = WidgetTimeline.gridPoint(atOrBefore: now, calendar: input.calendar)
        let dates = [entry.addingTimeInterval(-Schedule.gridMinutes * 60), entry]
        return WidgetMoments.make(at: dates, input: input, settings: settings, layout: layout).last
            ?? .sample(room: world.room, at: entry)
    }
}
