import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// ユーザーが選んだ写真とホーム画面のスクリーンショットを置く場所。
///
/// **App Group の中に置く。** Phase 3 でウィジェットが同じファイルを読むため、
/// アプリのサンドボックスではなく共有コンテナに入れる。
///
/// 読み書きには ImageIO を使い、UIKit を持ち込まない。ウィジェット拡張でも
/// 同じコードが動くようにしておく。
public struct ImageStore: Sendable {

    public enum StoreError: Error, Sendable, Equatable, CustomStringConvertible {
        case noContainer(appGroup: String)
        case notAnImage
        case writeFailed(name: String, reason: String)

        public var description: String {
            switch self {
            case .noContainer(let appGroup):
                "画像を置けません（App Group \(appGroup) が未設定です）"
            case .notAnImage:
                "画像として読めませんでした"
            case .writeFailed(let name, let reason):
                "\(name) を書けませんでした（\(reason)）"
            }
        }
    }

    /// 画像を置くフォルダ名。`state.json` と並べず、まとめて消せるように分ける。
    public static let folderName = "images"

    /// 保存する長辺の上限（画素）。
    ///
    /// iPhone 17 Pro の実画素は 1206×2622。これより大きく持っても画面では見えず、
    /// 読み込みの時間とメモリだけが増える。少し余裕を見て 2800 にしてある。
    public static let maxPixelSize = 2800

    public let directory: URL?

    public init(directory: URL?) {
        self.directory = directory
    }

    /// App Group の共有コンテナを使う既定の置き場。
    public static var shared: ImageStore { ImageStore(directory: AppGroup.containerURL) }

    public var folderURL: URL? {
        directory?.appendingPathComponent(Self.folderName, isDirectory: true)
    }

    public func url(for name: String) -> URL? {
        folderURL?.appendingPathComponent("\(name).png")
    }

    public func exists(_ name: String) -> Bool {
        guard let url = url(for: name) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    // MARK: - 書き

    /// 画像を取り込む。長辺が上限を超えていたら縮めてから置く。
    ///
    /// 形式は PNG にそろえる。ホーム画面のスクリーンショットはアイコンの縁が
    /// はっきりしているので、非可逆だと縁に滲みが出る。
    @discardableResult
    public func store(_ data: Data, as name: String) throws -> URL {
        guard let folderURL, let target = url(for: name) else {
            throw StoreError.noContainer(appGroup: AppGroup.identifier)
        }
        let image = try Self.decodeScaled(data)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try Self.writePNG(image, to: target, name: name)
        return target
    }

    /// 縮小しながら読む。向きの情報（Exif）もここで解いておく。
    ///
    /// 取り込む前に見せたいことがあるので公開する（帯を決める画面がそう）。
    public static func decodeScaled(_ data: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0 else { throw StoreError.notAnImage }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { throw StoreError.notAnImage }
        return image
    }

    /// 画像を縮めずに置く。透過背景の壁紙と切り抜きは、1 画素もずらせないので縮めない（3-3）。
    public func storeExact(_ image: CGImage, as name: String) throws {
        guard let folderURL, let target = url(for: name) else {
            throw StoreError.noContainer(appGroup: AppGroup.identifier)
        }
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        try Self.writePNG(image, to: target, name: name)
    }

    /// 縮めずに、そのままの画素で読む。色の情報（Display P3 など）も保つ。
    ///
    /// `decodeScaled` は縮小の仕組みを通るので、色の変換や画素のならしが入りうる。壁紙のスクショは
    /// 本物の壁紙と画素でそろえたいので、こちらで読む。
    public static func decodeExact(_ data: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw StoreError.notAnImage }
        return image
    }

    static func writePNG(_ image: CGImage, to url: URL, name: String) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw StoreError.writeFailed(name: name, reason: "書き出し先を作れませんでした")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw StoreError.writeFailed(name: name, reason: "書き出しが終わりませんでした")
        }
    }

    // MARK: - 読み

    /// 画像を読む。**読めなければ nil を返す。**
    /// ウィジェット拡張は落ちるとその後の更新まで止まるので、例外を投げない。
    public func load(_ name: String) -> CGImage? {
        guard let url = url(for: name),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0 else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// 縮めた画像を読む（画面に小さく見せるため）。長辺を `maxPixelSize` に収める。読めなければ nil。
    ///
    /// 壁紙のスクショ（1206×2622、展開して約 12.6 MB）を、見せるたびに丸ごと展開しないようにする。
    public func thumbnail(_ name: String, maxPixelSize: Int) -> CGImage? {
        guard let url = url(for: name),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0 else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    // MARK: - 片づけ

    public func remove(_ name: String) {
        guard let url = url(for: name) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// 使われていない画像を消す。
    ///
    /// 背景を選び直すたびに古いファイルが残ると、共有コンテナが太っていく。
    /// いま参照されている名前だけを残す。
    public func removeAll(keeping names: Set<String>) {
        guard let folderURL,
              let files = try? FileManager.default.contentsOfDirectory(atPath: folderURL.path)
        else { return }
        for file in files where file.hasSuffix(".png") {
            let name = String(file.dropLast(".png".count))
            if !names.contains(name) { remove(name) }
        }
    }
}
