import Foundation

/// まぶたの差分（mini）。まばたきの絵のうち、目を開けた絵と違う画素だけを残した絵（プラン §9 Phase 3 の 3-2b、
/// Phase 2 の 2-C ⑤-6）。ウィジェットは目を開けた絵の上に重ねて、まばたきを見せる（土台＋差分。D-17）。
///
/// 作り方は `tools/pipeline/art.py` の `eyelid` と同じ: 違う画素を 1pt（@3x で 3 画素）広げ、目を描き変えた範囲の中に
/// 限る。縮めて描くときの補間で、差分の縁に土台が透けて細い輪が出るのを、土台と同じ色の画素まで広げて防ぐ。
enum EyelidOverlay {

    /// 違う画素を広げる幅（mini の画素）。`art.py` の `EYELID_DILATION_POINTS`（1pt）を @3x にした値。
    static let growth = 3
    /// hero で描き変えた範囲を mini に写すときの余白（mini の画素）。縮めるときの補間が、まわりへ届く幅。
    static let resamplingMargin = 2

    /// 差分。違う画素が無ければ nil（その姿勢はまばたき無し）。
    static func make(open: Raster, blink: Raster, heroRegions: [PixelBox]) -> Raster? {
        let inside = regionMask(heroRegions.map(miniBox), width: open.width, height: open.height)
        let differing = differingPixels(open, blink)
        var changed = [UInt8](repeating: 0, count: open.pixelCount)
        eachIndex(changed.count) { if differing[$0] && inside[$0] { changed[$0] = Morphology.marked } }
        guard changed.contains(Morphology.marked) else { return nil }
        let grown = Morphology.dilated(changed, width: open.width, height: open.height, radius: growth)
        var kept: [Int] = []
        eachIndex(grown.count) { if grown[$0] != 0 && inside[$0] { kept.append($0) } }
        var overlay = Raster(width: open.width, height: open.height)
        overlay.fill(kept, from: blink)
        return overlay
    }

    /// 色か不透明さが 1 でも違う画素。
    static func differingPixels(_ first: Raster, _ second: Raster) -> [Bool] {
        var differing = [Bool](repeating: false, count: first.pixelCount)
        first.pixels.withUnsafeBufferPointer { first in
            second.pixels.withUnsafeBufferPointer { second in
                eachIndex(differing.count) { index in
                    let offset = index &* Raster.bytesPerPixel
                    differing[index] = first[offset] != second[offset]
                        || first[offset + 1] != second[offset + 1]
                        || first[offset + 2] != second[offset + 2]
                        || first[offset + 3] != second[offset + 3]
                }
            }
        }
        return differing
    }

    /// hero の矩形を、mini の矩形へ（外側へ丸め、補間の余白を足す）。
    static func miniBox(_ box: PixelBox) -> PixelBox {
        let ratio = Double(FrameGeometry.mini.width) / Double(FrameGeometry.hero.width)
        return PixelBox(left: Int((Double(box.left) * ratio).rounded(.down)) - resamplingMargin,
                        top: Int((Double(box.top) * ratio).rounded(.down)) - resamplingMargin,
                        right: Int((Double(box.right) * ratio).rounded(.up)) + resamplingMargin,
                        bottom: Int((Double(box.bottom) * ratio).rounded(.up)) + resamplingMargin)
    }

    static func regionMask(_ boxes: [PixelBox], width: Int, height: Int) -> [Bool] {
        let frame = PixelBox(width: width, height: height)
        var mask = [Bool](repeating: false, count: width * height)
        for box in boxes.compactMap({ $0.intersection(frame) }) {
            for index in box.indices(imageWidth: width) { mask[index] = true }
        }
        return mask
    }
}
