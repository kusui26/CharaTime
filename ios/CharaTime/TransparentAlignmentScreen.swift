import SwiftUI
import CTStore
import CTRender

/// 透過背景の枠を確かめて、1 画素ずつ寄せる画面（プラン §9 Phase 3 の 3-3。D-21 の手動の微調整）。
///
/// 取り込んだ壁紙のスクショに、大と中の枠を重ねて見せる。寄せた量はここでためておき、
/// 「この位置で使う」で切り抜き直す（押すたびに切り抜くと、PNG の書き出しで待たされる）。
struct TransparentAlignmentScreen: View {

    let model: StandbyModel

    @State private var target = SlotGeometry.largeOverMedium[0]
    @State private var offsets: [WidgetSlot: PixelOffset] = [:]
    @State private var preview: CGImage?
    @State private var isWorking = false
    @State private var failure: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SlotFramesPreview(image: preview, frames: frames, target: target)
                Picker("寄せる枠", selection: $target) {
                    ForEach(SlotGeometry.largeOverMedium, id: \.self) { Text($0.family.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                NudgePad { nudge(by: $0) }
                Text("\(target.family.displayName): \(NudgeFormat.text(offsets[target] ?? .zero))")
                    .monospacedDigit()
                actions
                Text(Self.help).font(.footnote).foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("位置を寄せる")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(isWorking)
        .overlay { if isWorking { ProgressView() } }
        .alert("うまくいきませんでした", isPresented: isFailing) {
            Button("わかりました") { failure = nil }
        } message: {
            Text(failure ?? "")
        }
        .task { preview = loadPreview() }
    }

    private var isFailing: Binding<Bool> {
        Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
    }

    /// ずれの見つけ方。中の模様が外より右にずれているのは、枠が左に寄りすぎているから。
    private static let help = "ホーム画面で、ウィジェットの縁に継ぎ目が見えたら寄せます。ウィジェットの中の模様が、"
        + "外より右にずれて見えたら「→」、下にずれて見えたら「↓」。1 回で 1 画素（1/3 ポイント）動きます。"

    private var actions: some View {
        HStack {
            Button("表の値に戻す") { resetToTable() }
                .buttonStyle(.bordered)
            Button("この位置で使う") { apply() }
                .buttonStyle(.borderedProminent)
                .disabled(offsets.values.allSatisfy { $0 == .zero })
        }
    }

    /// いまの枠（保存した枠に、ためている寄せを足したもの）。
    private var frames: [WidgetSlot: PixelRect] {
        Dictionary(uniqueKeysWithValues: model.state.widget.slots.map { setting in
            (setting.slot, setting.frame.offset(by: offsets[setting.slot] ?? .zero))
        })
    }

    private func nudge(by step: PixelOffset) {
        let current = offsets[target] ?? .zero
        offsets[target] = PixelOffset(dx: current.dx + step.dx, dy: current.dy + step.dy)
    }

    private func apply() {
        let pending = offsets
        run { await model.nudgeWallpaper(pending) }
    }

    private func resetToTable() {
        let style = model.state.widget.iconStyle ?? .labeled
        run { await model.setWallpaperIconStyle(style) }
    }

    private func run(_ work: @escaping @MainActor () async -> String?) {
        isWorking = true
        Task {
            failure = await work()
            offsets = [:]
            isWorking = false
        }
    }

    /// 下見の縮小の長辺（画素）。下見の高さ（約 400pt）に @3x で足りる大きさ。
    private static let previewPixelSize = 1200

    /// 下見に使う壁紙（ライトが無ければダーク）。
    private func loadPreview() -> CGImage? {
        let wallpaper = model.state.widget.wallpaper
        return (wallpaper.light ?? wallpaper.dark).flatMap {
            ImageStore.shared.thumbnail($0, maxPixelSize: Self.previewPixelSize)
        }
    }
}

/// 壁紙のスクショに、スロットの枠を重ねた下見。寄せている枠を目立たせる。
struct SlotFramesPreview: View {

    let image: CGImage?
    let frames: [WidgetSlot: PixelRect]
    let target: WidgetSlot

    /// 下見の高さ（ポイント）。枠を寄せるボタンと一緒に、1 画面に収まる大きさ。
    private static let height: Double = 400
    /// スクショの画素の高さ（1206×2622）。枠（画素）を下見の大きさへ写すのに使う。
    private static let screenshotHeight = Double(SlotGeometry.iPhone402x874.pixelHeight)
    private static let screenshotWidth = Double(SlotGeometry.iPhone402x874.pixelWidth)
    /// ウィジェットの角丸（画素。27.94pt の @3x）。
    private static let cornerRadiusPixels = WidgetStage.cornerRadius * SlotGeometry.iPhone402x874.scale
    /// 下見の角丸（ポイント）。
    private static let previewCornerRadius: Double = 12
    /// 枠の線の太さ（ポイント）。寄せている枠は太く、ほかは細く。
    private static let targetLineWidth: Double = 2
    private static let otherLineWidth: Double = 1

    var body: some View {
        let scale = Self.height / Self.screenshotHeight
        ZStack(alignment: .topLeading) {
            if let image {
                Image(decorative: image, scale: 1).resizable()
            } else {
                Color.secondary.opacity(0.15)
            }
            ForEach(Array(frames.keys), id: \.self) { slot in
                if let frame = frames[slot] { outline(frame, scale: scale, isTarget: slot == target) }
            }
        }
        .frame(width: Self.screenshotWidth * scale, height: Self.height)
        .clipShape(RoundedRectangle(cornerRadius: Self.previewCornerRadius))
    }

    private func outline(_ frame: PixelRect, scale: Double, isTarget: Bool) -> some View {
        RoundedRectangle(cornerRadius: Self.cornerRadiusPixels * scale, style: .continuous)
            .stroke(isTarget ? Color.accentColor : Color.white,
                    lineWidth: isTarget ? Self.targetLineWidth : Self.otherLineWidth)
            .frame(width: Double(frame.width) * scale, height: Double(frame.height) * scale)
            .offset(x: Double(frame.x) * scale, y: Double(frame.y) * scale)
    }
}

/// 上下左右に 1 画素ずつ寄せるボタン。
struct NudgePad: View {

    let onNudge: (PixelOffset) -> Void

    /// ボタンの矢印の枠（ポイント）。指で押し分けられる大きさ。
    private static let arrowSide: Double = 28
    /// 上下の矢印とのすき間と、左右の矢印のあいだ（ポイント）。十字に並んで見える間隔。
    private static let rowSpacing: Double = 6
    private static let columnSpacing: Double = 44

    var body: some View {
        VStack(spacing: Self.rowSpacing) {
            arrow("arrow.up", PixelOffset(dx: 0, dy: -1))
            HStack(spacing: Self.columnSpacing) {
                arrow("arrow.left", PixelOffset(dx: -1, dy: 0))
                arrow("arrow.right", PixelOffset(dx: 1, dy: 0))
            }
            arrow("arrow.down", PixelOffset(dx: 0, dy: 1))
        }
    }

    private func arrow(_ symbol: String, _ step: PixelOffset) -> some View {
        Button { onNudge(step) } label: {
            Image(systemName: symbol).frame(width: Self.arrowSide, height: Self.arrowSide)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(NudgeFormat.text(step))
    }
}
