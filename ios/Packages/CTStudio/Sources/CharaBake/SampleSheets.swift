import Foundation
import CoreGraphics
import CTStudio

/// いまの絵を、手引きの格子（B-2a・B-2b・B-3。P4 の 2 枚と W4）に並べた見本（2-3 の確かめ方）。
///
/// 「ピヨの SVG の絵を格子に並べて道具に通すと、いまの絵と同じ枠・接地線に戻る」を確かめるのに使う。生成 AI の格子の
/// ように、コマの位置を少しずつずらし、背景は透明にする。見上げる・驚くは、いまの絵に無いので立ち姿とよろこぶで
/// 代わりにする（予備のコマ。Asset Catalog には入らない）。
public enum SampleSheets {

    /// 生成 AI の絵に近い倍率。2-0 の歩く 4 コマ（2×2）で立ち姿は約 500 画素、いまの立ち姿（730 画素）の 0.68 倍。
    public static let realisticScale = 0.68

    /// 格子 1 枚ぶん（書き出す名前と、並べるコマ。行ごと・左から）。
    struct Plan {
        let fileName: String
        let frames: [String]
    }

    static let plans = [
        Plan(fileName: "poses-a", frames: ["idle_01", "sit_01", "sleep_01", "happy_01"]),
        Plan(fileName: "poses-b", frames: ["idle_01", "happy_02", "idle_01", "happy_01"]),
        Plan(fileName: "walk", frames: ["walk_01", "walk_02", "walk_03", "walk_04"]),
    ]
    /// 格子の列の数（P4 も W4 も 2×2）。
    static let columns = 2
    /// コマのまわりの余白（コマの幅に対する割合）。触れ合わない広さ（テンプレートの ④「広い余白」）。
    static let marginShare = 0.1
    /// コマごとの位置のずれ（画素）。生成 AI の格子は等間隔にならない（2-C ①）。
    static let jitter: [CGPoint] = [
        CGPoint(x: 0, y: 0), CGPoint(x: 9, y: -6), CGPoint(x: -7, y: 8), CGPoint(x: 5, y: 4),
    ]

    /// そのキャラの見本を `folder` に書く（`poses-a.png`・`poses-b.png`・`walk.png`）。
    public static func write(_ id: String, repository: Repository, to folder: URL,
                             scale: Double = realisticScale) throws(BakeError) -> [URL] {
        var written: [URL] = []
        for plan in plans {
            var images: [CGImage] = []
            for frame in plan.frames {
                images.append(try CatalogSheet.image(at: repository.bundledImage("\(id)_\(frame)")))
            }
            written.append(try ContactSheet.write(sheet(images, scale: scale),
                                                  to: folder.appending(path: "\(plan.fileName).png")))
        }
        return written
    }

    /// コマを 2×2 に並べた透明な絵。
    static func sheet(_ frames: [CGImage], scale: Double) -> Raster? {
        let cell = CGSize(width: CGFloat(FrameGeometry.hero.width) * scale,
                          height: CGFloat(FrameGeometry.hero.height) * scale)
        let margin = cell.width * marginShare
        let step = CGSize(width: cell.width + margin * 2, height: cell.height + margin * 2)
        let rows = (frames.count + columns - 1) / columns
        let size = CGSize(width: Int(step.width) * columns, height: Int(step.height) * rows)
        var canvas = Raster(width: Int(size.width), height: Int(size.height))
        let drawn = canvas.draw { context in
            let board = Board(context: context, height: size.height)
            for (index, frame) in frames.enumerated() {
                let shift = jitter[index % jitter.count]
                let origin = CGPoint(x: CGFloat(index % columns) * step.width + margin + shift.x,
                                     y: CGFloat(index / columns) * step.height + margin + shift.y)
                board.draw(frame, in: CGRect(origin: origin, size: cell))
            }
        }
        return drawn ? canvas : nil
    }
}
