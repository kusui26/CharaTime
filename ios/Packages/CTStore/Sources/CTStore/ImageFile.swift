import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// ImageIO での画像ファイルの読み書き。部屋の画像（`ImageStore`）と、取り込んだキャラの絵
/// （`CharacterStore`）が、同じ作法で読み書きする。UIKit を持ち込まない（ウィジェット拡張でも動く）。
enum ImageFile {

    /// 書けなかった理由。呼び出し側が、どのファイルかを添えて投げ直す。
    enum WriteFailure: Error, Equatable {
        case noDestination
        case notFinalized

        var reason: String {
            switch self {
            case .noDestination: "書き出し先を作れませんでした"
            case .notFinalized: "書き出しが終わりませんでした"
            }
        }
    }

    /// そのままの画素で読む。読めなければ nil。
    ///
    /// `decodesNow` なら、読んだときに展開しておく。待受モードは 60fps で描くので、描く途中で
    /// 展開してコマを落とさないようにする。
    static func read(at url: URL, decodesNow: Bool = false) -> CGImage? {
        guard let source = openSource(at: url) else { return nil }
        let options: [CFString: Any] = [kCGImageSourceShouldCacheImmediately: decodesNow]
        return CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary)
    }

    /// 長辺を `maxPixelSize` に収めて読む（縮めるだけで、引き伸ばさない）。読めなければ nil。
    static func thumbnail(at url: URL, maxPixelSize: Int, decodesNow: Bool = false) -> CGImage? {
        guard let source = openSource(at: url) else { return nil }
        return thumbnail(of: source, maxPixelSize: maxPixelSize, decodesNow: decodesNow)
    }

    /// 長辺が `maxPixelSize` 以下ならそのままの画素で、超えていれば縮めて、展開して読む。
    ///
    /// 大きさはファイルの見出しから読む（展開しない）。壊れて大きくなった絵を丸ごと展開して、
    /// メモリ（ウィジェット拡張は約 30 MB）を使い切らないようにする。
    static func read(at url: URL, fittingIn maxPixelSize: Int) -> CGImage? {
        guard let source = openSource(at: url), let size = pixelSize(of: source) else { return nil }
        guard size.longSide > maxPixelSize else {
            let options: [CFString: Any] = [kCGImageSourceShouldCacheImmediately: true]
            return CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary)
        }
        return thumbnail(of: source, maxPixelSize: maxPixelSize, decodesNow: true)
    }

    /// PNG で書く。透明を保ち、縁がにじまない（可逆）。
    static func writePNG(_ image: CGImage, to url: URL) throws(WriteFailure) {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw .noDestination }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw .notFinalized }
    }

    // MARK: - 道具

    private static func openSource(at url: URL) -> CGImageSource? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0 else { return nil }
        return source
    }

    private static func thumbnail(of source: CGImageSource, maxPixelSize: Int, decodesNow: Bool) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: decodesNow,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// 画素の数。見出しに無ければ nil。
    private static func pixelSize(of source: CGImageSource) -> PixelSize? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return PixelSize(width: width, height: height)
    }
}
