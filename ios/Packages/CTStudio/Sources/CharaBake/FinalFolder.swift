import Foundation
import CTCore
import CTStore
import CTStudio

/// 整えた絵の置き場（`assets-src/characters/<id>/final/`。プラン §6.4）。`tools/pipeline` がここから Asset Catalog に入れる。
///
/// 中身は、取り込んだキャラのフォルダ（2-1）と同じ名前の決まり: `hero/idle_01.png`（@3x 585×810）、`mini/idle_01.png`
/// （@3x 273×378）、`mini/idle_eyelid.png`（まぶたの差分）。予備のコマ（見上げる・驚く）は `spare/` に持っておき
/// （Phase 4 の Tier 2 で使う。Asset Catalog には入れない）、`bake.json` に整えたときの記録を残す。
/// **書くときは丸ごと入れ替える**（前の絵と混ざらない・書きかけのフォルダを残さない）。
public enum FinalFolder {

    public static let reportName = "bake.json"
    /// 予備のコマのフォルダ。
    public static let spareFolder = "spare"
    /// 書きかけのフォルダ（書き終えてから `final` と入れ替える）。
    static let incomingName = ".final-incoming"

    /// 書く絵（フォルダの中の場所と、絵）。
    typealias Picture = (path: String, image: Raster)

    static func pictures(of result: StudioResult) -> [Picture] {
        framePictures(result) + eyelidPictures(result) + sparePictures(result)
    }

    static func framePictures(_ result: StudioResult) -> [Picture] {
        Pose.allCases.flatMap { pose -> [Picture] in
            (result.frames[pose] ?? []).enumerated().flatMap { index, frame -> [Picture] in
                pair(pose, index, frame, folder: "")
            }
        }
    }

    static func eyelidPictures(_ result: StudioResult) -> [Picture] {
        Pose.allCases.compactMap { pose -> Picture? in
            guard let eyelid = result.eyelids[pose] else { return nil }
            return (CharacterImageName.eyelid(pose) + ".png", eyelid)
        }
    }

    static func sparePictures(_ result: StudioResult) -> [Picture] {
        Pose.allCases.flatMap { pose -> [Picture] in
            guard let frame = result.spares[pose] else { return [] }
            return pair(pose, 0, frame, folder: spareFolder + "/")
        }
    }

    /// 1 コマぶんの hero と mini。
    static func pair(_ pose: Pose, _ index: Int, _ frame: StudioResult.Frame, folder: String) -> [Picture] {
        [(folder + CharacterImageName.frame(pose, index, kind: .hero) + ".png", frame.hero),
         (folder + CharacterImageName.frame(pose, index, kind: .mini) + ".png", frame.mini)]
    }

    /// 書く。前の中身は丸ごと入れ替える。
    static func write(_ result: StudioResult, report: BakeReport, to folder: URL) throws(BakeError) {
        let incoming = folder.deletingLastPathComponent().appending(path: incomingName)
        do {
            try? FileManager.default.removeItem(at: incoming)
            try writePictures(of: result, into: incoming)
            try report.encoded().write(to: incoming.appending(path: reportName))
            try swap(incoming, into: folder)
        } catch let error as BakeError {
            throw error
        } catch {
            throw .writeFailed(folder.path(percentEncoded: false), error.localizedDescription)
        }
    }

    static func writePictures(of result: StudioResult, into folder: URL) throws {
        for (path, image) in pictures(of: result) {
            let url = folder.appending(path: path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            guard let data = image.pngData() else {
                throw BakeError.writeFailed(url.path(percentEncoded: false), "PNG にできません")
            }
            try data.write(to: url)
        }
    }

    /// 書き終えたフォルダを `final` にする。前の `final` があれば入れ替える。
    static func swap(_ incoming: URL, into folder: URL) throws {
        let manager = FileManager.default
        if manager.fileExists(atPath: folder.path(percentEncoded: false)) {
            _ = try manager.replaceItemAt(folder, withItemAt: incoming)
        } else {
            try manager.moveItem(at: incoming, to: folder)
        }
    }
}
