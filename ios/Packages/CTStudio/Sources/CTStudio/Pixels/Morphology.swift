import Foundation
import Accelerate

/// 白黒の印（0 か 255 の 1 バイト）を太らせる（膨張）。vImage に任せる（調査 H §2。最適化しないビルドでも速い）。
///
/// 背景を抜いたあとの境の輪（2-C ⑤-2）、コマを見つける前に線の切れ目を閉じる（⑤-3）、まばたきで目のまわりを
/// 塗る範囲とまぶたの差分を広げる（⑤-6）のに使う。
enum Morphology {

    /// 印の「ある」値。
    static let marked: UInt8 = 255

    /// 半径 `radius` の正方形で太らせる（8 近傍の膨張を `radius` 回くり返したのと同じ）。
    static func dilated(_ mask: [UInt8], width: Int, height: Int, radius: Int) -> [UInt8] {
        guard radius > 0, width > 0, height > 0 else { return mask }
        var source = mask
        var output = [UInt8](repeating: 0, count: mask.count)
        let side = vImagePixelCount(radius * 2 + 1)
        source.withUnsafeMutableBytes { sourceBytes in
            output.withUnsafeMutableBytes { outputBytes in
                var input = buffer(sourceBytes, width: width, height: height)
                var result = buffer(outputBytes, width: width, height: height)
                _ = vImageMax_Planar8(&input, &result, nil, 0, 0, side, side, vImage_Flags(kvImageNoFlags))
            }
        }
        return output
    }

    private static func buffer(_ bytes: UnsafeMutableRawBufferPointer,
                               width: Int, height: Int) -> vImage_Buffer {
        vImage_Buffer(data: bytes.baseAddress, height: vImagePixelCount(height),
                      width: vImagePixelCount(width), rowBytes: width)
    }
}
