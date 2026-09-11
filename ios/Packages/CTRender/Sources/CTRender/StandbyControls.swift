import SwiftUI
import CTCore
import CTStore

/// 待受モードから開ける画面。
public enum StandbySheet: String, Identifiable, Sendable, CaseIterable {
    case settings
    case dayPlan

    public var id: String { rawValue }

    var title: String {
        switch self {
        case .settings: "設定"
        case .dayPlan: "きょうの予定"
        }
    }

    var symbol: String {
        switch self {
        case .settings: "gearshape"
        case .dayPlan: "list.bullet"
        }
    }
}

/// 画面をさわったときだけ出る操作パネル。
///
/// **ふだんは何も出さない。** 据え置きの待受なので、部屋とキャラだけが見えているのが
/// 正しい姿で、操作するものは必要になったときだけ現れればよい。
struct StandbyControls: View {

    let isVisible: Bool
    let palette: RoomPalette
    let open: (StandbySheet) -> Void

    private static let cornerRadius: Double = 22
    private static let bottomInset: Double = 34

    var body: some View {
        HStack(spacing: 0) {
            ForEach(StandbySheet.allCases) { sheet in
                Button { open(sheet) } label: { label(sheet) }
                    .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 6)
        .background(panel)
        .padding(.horizontal, 22)
        .padding(.bottom, Self.bottomInset)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
    }

    private var panel: some View {
        RoundedRectangle(cornerRadius: Self.cornerRadius)
            .fill(.ultraThinMaterial)
            .overlay(RoundedRectangle(cornerRadius: Self.cornerRadius)
                .stroke(palette.clockInk.opacity(0.18), lineWidth: 1))
    }

    private func label(_ sheet: StandbySheet) -> some View {
        VStack(spacing: 5) {
            Image(systemName: sheet.symbol).font(.system(size: 21, weight: .regular))
            Text(sheet.title).font(.system(size: 11, weight: .medium, design: .rounded))
        }
        .foregroundStyle(palette.clockInk.opacity(0.92))
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

/// 時刻をずらしているあいだ出す印。**本物の時刻と取り違えないため。**
struct TimeWarpBadge: View {

    let warp: TimeWarp
    let palette: RoomPalette

    var body: some View {
        Text(warp.scale == 0 ? "時刻を止めています" : "\(Int(warp.scale)) 倍速")
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(palette.clockInk.opacity(0.9))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(.ultraThinMaterial))
            .padding(.top, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .allowsHitTesting(false)
    }
}
