import SwiftUI
import CTCore
import CTAssets

/// 部屋に置いたアイテム 1 つ。
struct ItemView: View {

    let item: PlacedItem
    let definition: ItemDefinition
    let layout: SceneLayout
    let palette: RoomPalette
    /// 天井から吊るす紐を描くか。壁紙の上（透過背景）では描かない（`SceneLook.overWallpaper`）。
    var showsCord = true

    /// 吊るす紐の太さ（基準のポイント。ウィジェットでは舞台と一緒に細くなる）。
    private static let cordWidth: Double = 3

    var body: some View {
        let frame = layout.itemFrame(item, definition: definition)
        ZStack {
            if definition.hangsFromCeiling && showsCord { cord(to: frame) }
            SpriteView(assetName: definition.assetName)
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
        }
    }

    /// 天井から絵まで引く紐。アイテムの絵には紐を含めていないので、
    /// 置く高さが変わっても長さが合う。
    private func cord(to frame: CGRect) -> some View {
        let ends = layout.cord(for: frame)
        return Path { path in
            path.move(to: ends.from)
            path.addLine(to: ends.to)
        }
        .stroke(palette.outline,
                style: StrokeStyle(lineWidth: Self.cordWidth * layout.unit, lineCap: .round))
    }
}
