import Foundation
import CTCore
import CTStore

extension CharacterStudio {

    /// 立ち姿（元の画像の外接矩形の高さ）がこれより低いと、待受で少しぼやける（2-C ⑤-7。待受の体は約 730 画素）。
    public static let sharpStandbyHeight = 400.0
    /// これより低いと、ウィジェットでもぼやける（mini の立ち姿は約 340 画素）。
    public static let sharpWidgetHeight = 300.0

    /// 確かめる画面で決めた割り当てから、キャラ 1 体ぶんの絵をそろえる（2-C ⑤-4〜6）。立ち姿が無ければ断る。
    public static func assemble(_ sheets: [AssignedSheet]) throws(StudioError) -> StudioResult {
        let measured = sheets.map(MeasuredSheet.init)
        guard let standing = measured.lazy.compactMap(\.standing).first else { throw .missingStandingPose }
        let plan = ScalePlan(standing: standing.metrics, sheets: measured.map(\.fit))
        let drawing = try Drawing(measured: measured, plan: plan)
        let poses = try PoseFrames(drawing)
        let notices = fittingNotices(plan: plan, standing: standing.metrics)
            + (poses.blinkless.isEmpty ? [] : [ImportNotice(.eyesNotFound, poses.blinklessDetail)])
        let record = ImportRecord(stage: stage(of: poses.frames), sources: sheets.map(\.source),
                                  guideVersion: PromptTemplate.version)
        return StudioResult(frames: poses.frames, eyelids: poses.eyelids, spares: try drawing.spares(),
                            sleepFrameCoversBase: poses.sleepFrameCoversBase, notices: notices,
                            record: record, standingHeight: plan.standingHeight)
    }

    /// 横に広い姿勢で縮めた・立ち姿が小さい、の知らせ。
    static func fittingNotices(plan: ScalePlan, standing: FigureMetrics) -> [ImportNotice] {
        let height = "立ち姿の高さ \(Int(standing.height.rounded())) 画素"
        let compact = plan.isCompacted
            ? [ImportNotice(.widePose, "本来の \(Int((plan.shrink * 100).rounded()))% の大きさ")] : []
        if standing.height < sharpWidgetHeight { return compact + [ImportNotice(.blurryOnWidget, height)] }
        if standing.height < sharpStandbyHeight { return compact + [ImportNotice(.blurryOnStandby, height)] }
        return compact
    }

    /// 取り込みの段（2-C ③ の表）。
    static func stage(of frames: [Pose: [StudioResult.Frame]]) -> ImportRecord.Stage {
        if frames[.walk] != nil { return .posesAndWalk }
        return frames.keys.contains { $0 != .idle } ? .poses : .single
    }
}

/// 寸法を測った 1 枚の画像（使わないコマは入れない）。
struct MeasuredSheet {

    struct Item {
        let figure: Figure
        let slot: FigureSlot
        let metrics: FigureMetrics
    }

    let source: ImportRecord.Source
    let items: [Item]

    init(_ sheet: AssignedSheet) {
        source = sheet.source
        items = sheet.placements.compactMap { placement in
            guard placement.slot != .unused,
                  let metrics = FigureMetrics(placement.figure.image) else { return nil }
            return Item(figure: placement.figure, slot: placement.slot, metrics: metrics)
        }
    }

    /// 立ち姿（目を開けた正面）。
    var standing: Item? { items.first { $0.slot == .frame(.idle, 0) } }

    /// 枠に描く姿勢のコマ（予備と背の基準は入れない。予備で全体を縮めない）。
    var frames: [Item] { items.filter { if case .frame = $0.slot { true } else { false } } }

    /// 倍率を決める材料。背の基準は立ち姿（P4 の 2 枚目は基準の立ち姿）、どちらも無ければコマの高さの中央値。
    var fit: ScalePlan.Sheet {
        let reference = standing ?? items.first { $0.slot == .heightReference }
        let pool = (frames.isEmpty ? items : frames).map(\.metrics)
        let height = reference?.metrics.height ?? ScalePlan.Sheet.medianHeight(of: pool)
        return ScalePlan.Sheet(referenceHeight: height, figures: frames.map(\.metrics))
    }
}

/// 枠に描いたコマ（役目ごと。同じ役目が 2 つあれば、先の画像・先のコマ）。
struct Drawing {

    struct Drawn {
        let item: MeasuredSheet.Item
        let scale: Double
        let hero: Raster
    }

    let bySlot: [FigureSlot: Drawn]

    init(measured: [MeasuredSheet], plan: ScalePlan) throws(StudioError) {
        var bySlot: [FigureSlot: Drawn] = [:]
        for sheet in measured {
            let scale = plan.scale(for: sheet.fit)
            for item in sheet.items where item.slot != .heightReference && bySlot[item.slot] == nil {
                guard let hero = FrameRenderer.hero(item.figure, metrics: item.metrics, scale: scale) else {
                    throw .drawingFailed
                }
                bySlot[item.slot] = Drawn(item: item, scale: scale, hero: hero)
            }
        }
        self.bySlot = bySlot
    }

    /// その姿勢の、描いたコマ（番号の順）。
    func frames(of pose: Pose) -> [Drawn] {
        bySlot.compactMap { slot, drawn -> (Int, Drawn)? in
            guard case .frame(pose, let index) = slot else { return nil }
            return (index, drawn)
        }.sorted { $0.0 < $1.0 }.map(\.1)
    }

    /// 予備のコマ（hero と mini）。
    func spares() throws(StudioError) -> [Pose: StudioResult.Frame] {
        var spares: [Pose: StudioResult.Frame] = [:]
        for (slot, drawn) in bySlot {
            guard case .spare(let pose) = slot else { continue }
            spares[pose] = try StudioResult.Frame(hero: drawn.hero)
        }
        return spares
    }
}

extension StudioResult.Frame {

    /// hero から mini を作って組にする。
    init(hero: Raster) throws(StudioError) {
        guard let mini = FrameRenderer.mini(from: hero) else { throw .drawingFailed }
        self.init(hero: hero, mini: mini)
    }
}
