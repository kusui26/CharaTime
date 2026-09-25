import SwiftUI
import CTCore
import CTStore
import CTRender

/// StandBy の見え方を、本体アプリで確かめる画面（`-CTScreen standBy`。プラン §9 Phase 3 の 3-5）。
///
/// シミュレータには StandBy が無いので、小ウィジェットを StandBy と同じ条件で描いて並べる。
/// 背景を外して黒の上に置き、拡大して、昼（フルカラー）と夜（明るさだけの赤）の 2 つ。
/// 拡大の倍率と夜の赤は、実機（iPhone 17 Pro / iOS 26.1）の StandBy のスクショで測った値に合わせてある。
struct StandByPreviewScreen: View {

    let input: WorldInput
    let world: SceneWorld
    let settings: CTStore.Settings
    let motion: WidgetMotion
    let timeWarp: TimeWarp

    /// StandBy が小ウィジェットを拡大する倍率。実機のスクショで、小（164.33pt）が 362pt に出た
    /// （横向きの画面の高さ 402pt から、上下に 20pt ずつ余白）。
    static let standByScale: Double = 2.2
    /// 描き直しの間隔（秒）。エントリが替わった瞬間を、早送りでも取りこぼさない細かさ。
    private static let refreshSeconds: Double = 0.25
    private static let spacing: Double = 8

    var body: some View {
        TimelineView(.periodic(from: .now, by: Self.refreshSeconds)) { context in
            let now = timeWarp.apply(to: context.date)
            let moment = PreviewMoments.moment(.small, at: now, input: input, world: world,
                                               settings: settings)
            VStack(spacing: Self.spacing) {
                panel(moment, display: .standByDay, title: "昼")
                panel(moment, display: .standByNight, title: "夜の赤（まね）")
                caption(moment)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
        }
    }

    private func panel(_ moment: WidgetMoment, display: WidgetDisplay, title: String) -> some View {
        let size = WidgetStage.referenceSize(for: .small)
        let scale = Self.standByScale
        return VStack(spacing: Self.spacing) {
            WidgetScene(family: .small, moment: moment, world: world, motion: motion, display: display)
                .frame(width: size.width, height: size.height)
                .clipShape(RoundedRectangle(cornerRadius: WidgetStage.cornerRadius, style: .continuous))
                .nightRed(display.tone == .vibrant)
                .scaleEffect(scale)
                .frame(width: size.width * scale, height: size.height * scale)
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.gray)
        }
    }

    private func caption(_ moment: WidgetMoment) -> some View {
        let entry = ClockFormat.time(moment.date, calendar: input.calendar)
        let scale = String(format: "%.1f", Self.standByScale)
        return Text("\(entry) のエントリ ・ \(moment.state.activity.label) ・ 拡大 \(scale) 倍")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.gray)
    }
}

private extension View {

    /// StandBy の夜の赤のまね（`isOn` のときだけ）。OS は中身を明るさだけにして、赤の濃さで描く。
    /// 明るさを透明度に移し（`luminanceToAlpha`）、赤い板をその形で抜く。
    ///
    /// **先に黒の上へ重ねて、1 枚にまとめる。** `luminanceToAlpha` は透明度を見ないので、
    /// そのままだと薄い白（床の帯の 1 割の白）まで真っ白として扱い、濃い赤になる。黒を敷くだけでは
    /// 効かず（部品ごとに変換される）、`compositingGroup` で 1 枚にしてから変換する。
    @ViewBuilder
    func nightRed(_ isOn: Bool) -> some View {
        if isOn {
            NightRed.color.mask { self.background(.black).compositingGroup().luminanceToAlpha() }
        } else {
            self
        }
    }
}

/// StandBy の夜の赤。実機のスクショでは緑と青が 0 の赤で、明るさがそのまま赤の濃さになった
/// （黄色の体が 255 のうち 222、床の帯の 1 割の白が 25）。
private enum NightRed {
    static let color = Color(red: 1, green: 0, blue: 0)
}
