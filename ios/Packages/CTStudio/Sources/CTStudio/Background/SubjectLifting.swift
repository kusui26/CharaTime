import Foundation
import CoreImage
import Vision

/// 被写体の切り抜き（プラン §9 Phase 2 の 2-C ⑤-2、D-36）。地が 1 色でも透明でもない絵（模様・写真・絵の背景）に使う。
///
/// **Vision はシミュレータで動かない**（CPU では動かない。2-C ①）。取り込みの処理はこのプロトコルの向こうに置き、
/// テストでは差し替える。アプリ（実機）と Mac の道具は `VisionSubjectLifter` を渡す。
public protocol SubjectLifting: Sendable {
    /// 被写体だけを残した絵（同じ大きさ。背景は透明）。被写体が見つからなければ nil。
    func lift(_ image: Raster) async throws -> Raster?
}

/// Vision の「前景の切り抜き」（`VNGenerateForegroundInstanceMaskRequest`）。見つけた被写体をすべて残す。
///
/// 触れ合う・重なるキャラは 1 つにまとめ、浮いた部品（とさか）を落とすことがある（2-C ①）。コマを分けるのは
/// 自前の切り分け（`FigureFinder`）に任せ、ここでは背景を透明にするだけにする。
public struct VisionSubjectLifter: SubjectLifting {

    public init() {}

    public func lift(_ image: Raster) async throws -> Raster? {
        guard let picture = image.cgImage else { return nil }
        let handler = VNImageRequestHandler(cgImage: picture)
        let request = VNGenerateForegroundInstanceMaskRequest()
        try handler.perform([request])
        guard let observation = request.results?.first, !observation.allInstances.isEmpty else { return nil }
        let masked = try observation.generateMaskedImage(ofInstances: observation.allInstances, from: handler,
                                                         croppedToInstancesExtent: false)
        let ciImage = CIImage(cvPixelBuffer: masked)
        guard let lifted = CIContext().createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return Raster(cgImage: lifted)
    }
}
