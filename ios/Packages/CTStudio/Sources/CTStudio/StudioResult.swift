import Foundation
import CoreGraphics
import CTCore
import CTStore

/// キャラ 1 体ぶんの、整えた絵（プラン §9 Phase 2 の 2-C ⑤-4〜6）。確かめる画面の下見と、保存（`package`）に使う。
public struct StudioResult: Sendable {

    /// 1 コマぶん。待受用（hero、@3x 585×810）とウィジェット用（mini、@3x 273×378）。
    public struct Frame: Sendable, Equatable {
        public let hero: Raster
        public let mini: Raster
    }

    /// 姿勢ごとのコマ（コマ送りの順）。立つ・すわるの 2 コマ目はまばたき、寝るの 2 コマ目は寝息（アプリが作った）。
    public let frames: [Pose: [Frame]]
    /// まぶたの差分（mini）。まばたきの絵のある姿勢だけ。
    public let eyelids: [Pose: Raster]
    /// 予備のコマ（見上げる・驚く）。Phase 4 の Tier 2 で使う（いまは保存しない。2-C ③）。
    public let spares: [Pose: Frame]
    /// 寝息の 2 コマ目が、1 コマ目の見える画素をすべて覆うか（`Breath.covers`）。
    public let sleepFrameCoversBase: Bool
    /// そろえるときに気づいたこと（横に広い姿勢・ぼやけ・まばたき）。コマを見つけたときの知らせは `SheetAnalysis`。
    public let notices: [ImportNotice]
    /// 取り込みの記録（段・元の画像・手引きの版）。
    public let record: ImportRecord
    /// 立ち姿の、枠の中での外接矩形の高さ（hero の画素）。あとからコマを足すとき、この背にそろえる（2-C ⑤-9）。
    public let standingHeight: Double

    /// 置く前の中身にする（`CharacterStore.install` に渡す）。予備のコマは入れない。
    public func package(_ profile: CharacterProfile) throws(StudioError) -> CharacterPackage {
        var pictures: [Pose: [CharacterPackage.Frame]] = [:]
        for (pose, list) in frames {
            pictures[pose] = try list.map { frame throws(StudioError) in
                CharacterPackage.Frame(hero: try Self.image(frame.hero), mini: try Self.image(frame.mini))
            }
        }
        var lids: [Pose: CGImage] = [:]
        for (pose, overlay) in eyelids { lids[pose] = try Self.image(overlay) }
        return .assemble(profile, frames: pictures, eyelids: lids, sleepFrameCoversBase: sleepFrameCoversBase,
                         record: record)
    }

    static func image(_ raster: Raster) throws(StudioError) -> CGImage {
        guard let image = raster.cgImage else { throw .drawingFailed }
        return image
    }
}
