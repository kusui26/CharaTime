import Foundation

/// 絵の中のコマ 1 つ（背景を外したあとの、キャラ 1 体ぶんの姿）。プラン §9 Phase 2 の 2-C ⑤-3。
///
/// 確かめる画面（2-6）は、コマを並べ替え・左右反転・外してから、枠にそろえる（`CharacterStudio.assemble`）。
public struct Figure: Sendable, Equatable {

    /// このコマの絵。ほかのコマの画素は透明にしてある。
    public let image: Raster
    /// 元の絵の中での、`image` の左上の位置（画素）。
    public let originX: Int
    public let originY: Int

    public init(image: Raster, originX: Int, originY: Int) {
        self.image = image
        self.originX = originX
        self.originY = originY
    }

    /// 左右を反転した姿（右を向いて歩く絵を、左向きにそろえる。2-C ⑤-7）。
    public func mirrored() -> Figure {
        var flipped = image
        let width = image.width
        flipped.pixels.withUnsafeMutableBufferPointer { target in
            image.pixels.withUnsafeBufferPointer { source in
                eachIndex(image.pixelCount) { index in
                    let column = index % width
                    let mirror = index - column + width - 1 - column
                    Raster.copyPixel(from: source, at: index * Raster.bytesPerPixel,
                                     to: target, at: mirror * Raster.bytesPerPixel)
                }
            }
        }
        return Figure(image: flipped, originX: originX, originY: originY)
    }
}
