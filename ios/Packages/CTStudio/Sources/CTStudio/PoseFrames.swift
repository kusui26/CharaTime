import Foundation
import CTCore

/// 姿勢ごとのコマ。まばたき（立つ・すわる）と寝息（寝る）の 2 コマ目を足す（プラン §9 Phase 2 の 2-C ⑤-6、D-38）。
struct PoseFrames {

    /// まばたきを作る姿勢（目を開けた正面の絵がある姿勢。同梱の 5 体と同じ）。
    static let blinkingPoses: [Pose] = [.idle, .sit]

    private(set) var frames: [Pose: [StudioResult.Frame]] = [:]
    private(set) var eyelids: [Pose: Raster] = [:]
    /// 目が見つからず、まばたきを作れなかった姿勢。
    private(set) var blinkless: [Pose] = []
    private(set) var sleepFrameCoversBase = false

    init(_ drawing: Drawing) throws(StudioError) {
        for pose in Pose.allCases {
            let drawn = drawing.frames(of: pose)
            guard let first = drawn.first else { continue }
            if Self.blinkingPoses.contains(pose) {
                try addBlinking(pose, open: first.hero)
            } else if pose == .sleep {
                try addSleeping(first)
            } else {
                frames[pose] = try drawn.map { drawn throws(StudioError) in
                    try StudioResult.Frame(hero: drawn.hero)
                }
            }
        }
    }

    /// 知らせに添える、まばたきを作れなかった姿勢の名前。
    var blinklessDetail: String {
        blinkless.map { $0 == .idle ? "立ち姿" : "すわる姿" }.joined(separator: "・")
    }

    /// 目を開けた絵と、アプリが作ったまばたきの絵。目が見つからなければ 1 コマだけ（まばたき無し）。
    private mutating func addBlinking(_ pose: Pose, open: Raster) throws(StudioError) {
        let opened = try StudioResult.Frame(hero: open)
        guard let blink = Self.blink(open), let closed = FrameRenderer.mini(from: blink.image),
              let eyelid = EyelidOverlay.make(open: opened.mini, blink: closed,
                                              heroRegions: blink.regions) else {
            frames[pose] = [opened]
            blinkless.append(pose)
            return
        }
        frames[pose] = [opened, StudioResult.Frame(hero: blink.image, mini: closed)]
        eyelids[pose] = eyelid
    }

    /// 寝姿と、足元を軸に縦へ伸ばした寝息の 2 コマ目（元の絵から描き直す。hero を伸ばすと 2 度ぼける）。
    private mutating func addSleeping(_ drawn: Drawing.Drawn) throws(StudioError) {
        let base = try StudioResult.Frame(hero: drawn.hero)
        let item = drawn.item
        guard let stretched = FrameRenderer.hero(item.figure, metrics: item.metrics, scale: drawn.scale,
                                                 stretch: Breath.stretch) else { throw .drawingFailed }
        let breath = try StudioResult.Frame(hero: stretched)
        frames[.sleep] = [base, breath]
        sleepFrameCoversBase = Breath.covers(base: base.mini, top: breath.mini)
    }

    /// まばたきの絵と、描き変えた範囲。目が見つからない・まわりが 1 色でなければ nil。
    static func blink(_ open: Raster) -> (image: Raster, regions: [PixelBox])? {
        let scan = FaceScan(open)
        guard let metrics = FigureMetrics(open), let eyes = EyeFinder.find(in: scan, figure: metrics) else {
            return nil
        }
        return BlinkPainter.blinked(open, eyes: eyes, scan: scan)
    }
}
