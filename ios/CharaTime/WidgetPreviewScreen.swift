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
/// **ここで分からないこと**: 着色・クリアの外観、StandBy、メモリ。それはホーム画面に置いて見る
/// （`scripts/home-screen.sh`）。
struct WidgetPreviewScreen: View {

    let input: WorldInput
    let world: SceneWorld
    let settings: CTStore.Settings
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

    /// ホーム画面がその時刻に出しているエントリ（5 分の升目）と、ひとつ前のエントリから作る。
    /// ひとつ前が要るのは、遠くへ移ったか（消えて現れるか）を決めるため。
    private func moment(_ family: WidgetSlot.Family, at now: Date) -> WidgetMoment {
        let size = WidgetStage.referenceSize(for: family)
        let layout = WidgetStage.stage(for: family).layout(
            size: size, room: world.room, geometry: world.spriteGeometry,
            characterScale: world.character.scale)
        let entry = WidgetTimeline.gridPoint(atOrBefore: now, calendar: input.calendar)
        let dates = [entry.addingTimeInterval(-Schedule.gridMinutes * 60), entry]
        return WidgetMoments.make(at: dates, input: input, settings: settings, layout: layout).last
            ?? .sample(room: world.room, at: entry)
    }

    private func widget(_ family: WidgetSlot.Family, at now: Date) -> some View {
        let size = WidgetStage.referenceSize(for: family)
        return WidgetScene(family: family, moment: moment(family, at: now), world: world)
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
