import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import CTStore

/// 取り込みで起きうる失敗。どの絵かは呼び出し側が知っているので、ここでは何が起きたかを添える。
public enum StudioError: Error, Sendable, Equatable, CustomStringConvertible {
    /// 画像として読めない（壊れている・形式が違う）。
    case notAnImage
    /// 大きすぎて読まない（長辺が `ImageReading.maxSourceLongSide` を超える）。
    case tooLarge(PixelSize)
    /// 絵を描く場所（`CGContext`）を作れなかった。
    case drawingFailed
    /// 地が 1 色でも透明でもなく、被写体の切り抜き（Vision）が要るのに、切り抜く道具が無い（シミュレータ・テスト）。
    case needsSubjectLift
    /// 被写体の切り抜きで、何も見つからなかった（「無地の背景で作り直す」案内を出す。2-C ⑤-2）。
    case noSubject
    /// 被写体の切り抜きが失敗した（Vision の失敗の理由を添える）。
    case subjectLiftFailed(String)
    /// 立ち姿（目を開けた正面）が割り当てられていない。どのキャラも立ち姿から作る（2-C ③）。
    case missingStandingPose

    public var description: String {
        switch self {
        case .notAnImage: "画像として読めませんでした"
        case .tooLarge(let size):
            "画像が大きすぎます（\(size.width)×\(size.height)。長辺 \(ImageReading.maxSourceLongSide) 画素まで）"
        case .drawingFailed: "絵を描く場所を作れませんでした"
        case .needsSubjectLift: "背景が 1 色ではないので、被写体の切り抜きが要ります（この環境では使えません）"
        case .noSubject: "キャラが見つかりませんでした。無地の背景で作り直してください"
        case .subjectLiftFailed(let reason): "被写体の切り抜きに失敗しました（\(reason)）"
        case .missingStandingPose: "立ち姿（目を開けた正面）のコマがありません"
        }
    }
}

/// 取り込んだ画像のデータを、作業の形（`Raster`）にする（2-C ⑤-1）。
///
/// ImageIO が読める形式（PNG・JPEG・HEIC・WebP など）は、ここで sRGB・8bit・乗算済みの 1 つの形にそろう。
/// 向きの情報（Exif）も解く（写真アプリから来る絵は、向きの情報だけで横を向いていることがある）。
public enum ImageReading {

    /// 断る大きさ（長辺の画素）。これを超えると、展開しただけで 256 MB になる（調査 H §3）。
    public static let maxSourceLongSide = 8192
    /// 作業する大きさの上限（長辺）。超える絵は縮めて読む（展開して 64 MB。H §3）。
    /// 生成 AI の絵は約 157 万画素（1254×1254 など。2-0）なので、ふつうは縮めない。
    public static let maxWorkingLongSide = 4096
    /// Exif の「向きはそのまま」。
    static let uprightOrientation = 1
    /// Exif の向きのうち、縦と横が入れ替わるもの（5〜8）の最初。
    static let firstTransposedOrientation = 5

    /// 読む。画像でない・大きすぎるときは、理由を添えて断る。
    public static func raster(from data: Data) throws(StudioError) -> Raster {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0, let facts = facts(of: source) else { throw .notAnImage }
        guard facts.size.longSide <= maxSourceLongSide else { throw .tooLarge(facts.size) }
        guard let image = decode(source, facts: facts) else { throw .notAnImage }
        guard let raster = Raster(cgImage: image) else { throw .drawingFailed }
        return raster
    }

    /// 画素の数（向きを解いたあとの縦横）と、向き。展開せずに見出しから読む。
    static func facts(of source: CGImageSource) -> (size: PixelSize, orientation: Int)? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? uprightOrientation
        let transposed = orientation >= firstTransposedOrientation
        let size = PixelSize(width: transposed ? height : width, height: transposed ? width : height)
        return (size, orientation)
    }

    /// 向きを解き、作業する大きさまで縮めて展開する。向きがそのままで縮めなくてよければ、画素をそのまま読む。
    static func decode(_ source: CGImageSource, facts: (size: PixelSize, orientation: Int)) -> CGImage? {
        guard facts.orientation != uprightOrientation || facts.size.longSide > maxWorkingLongSide else {
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Swift.min(facts.size.longSide, maxWorkingLongSide),
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

public extension Raster {

    /// PNG のデータにする（Mac の道具が書き出す・テストで見比べる）。作れなければ nil。
    func pngData() -> Data? {
        guard let image = cgImage else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
