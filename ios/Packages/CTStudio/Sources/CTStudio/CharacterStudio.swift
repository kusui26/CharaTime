import Foundation
import CTCore
import CTStore

/// 取り込みの入口（プラン §9 Phase 2 の 2-C ⑤、D-35）。
///
/// 画像 1 枚ごとに `analyze`（読む・背景を外す・コマを見つける）し、確かめる画面（2-6）で並べ替え・反転・外したあと、
/// `assemble`（そろえる・hero と mini・まばたきと寝息）でキャラ 1 体ぶんの絵にする。**アプリの取り込みと、既定の 5 体を
/// 焼く Mac の道具（2-3）が同じ関数を呼ぶ。** 画素の処理は引数だけで答えが決まる（被写体の切り抜きだけは Vision）。
public enum CharacterStudio {

    /// 1 枚の画像を読み、背景を外し、コマを見つける。`service` は利用者が選んだサービス（背景の知らせに使う）。
    /// `lifter` は、地が 1 色でも透明でもないときの被写体の切り抜き（無ければ、そういう絵は断る）。
    public static func analyze(_ data: Data, layout: SheetLayout, service: PromptTemplate.Service? = nil,
                               lifter: (any SubjectLifting)? = nil)
        async throws(StudioError) -> SheetAnalysis {
        let raster = try ImageReading.raster(from: data)
        let (cutout, background) = try await removeBackground(raster, lifter: lifter)
        let found = FigureFinder.find(in: cutout, expected: layout.expectedCount)
        let oriented = orient(found.figures, layout: layout)
        let notices = serviceNotices(background, service: service) + found.notices
            + shadowNotices(found.figures, in: cutout) + oriented.notices
        let source = ImportRecord.Source(pixelWidth: raster.width, pixelHeight: raster.height,
                                         background: background)
        return SheetAnalysis(layout: layout, source: source, figures: oriented.figures, notices: notices)
    }

    /// 背景を外す。地が 1 色でも透明でもなければ、被写体の切り抜きに回す。
    static func removeBackground(_ raster: Raster, lifter: (any SubjectLifting)?)
        async throws(StudioError) -> (Raster, ImportRecord.Background) {
        if case .removed(let cutout, let method) = BackgroundRemoval.remove(from: raster) {
            return (cutout, method)
        }
        guard let lifter else { throw .needsSubjectLift }
        let lifted: Raster?
        do {
            lifted = try await lifter.lift(raster)
        } catch {
            throw .subjectLiftFailed(error.localizedDescription)
        }
        guard let lifted, case .removed(let cutout, let method) = BackgroundRemoval.lifted(lifted) else {
            throw .noSubject
        }
        return (cutout, method)
    }

    /// 選んだサービスと、背景の外し方が合わないときの知らせ（テンプレートの §4.4。F-BG・F-BG-WHITE）。
    static func serviceNotices(_ background: ImportRecord.Background,
                               service: PromptTemplate.Service?) -> [ImportNotice] {
        switch (service, background) {
        case (.chatGPT, .solidColor), (.chatGPT, .checkerboard), (.chatGPT, .subjectLift):
            [ImportNotice(.backgroundNotTransparent)]
        case (.gemini, .subjectLift):
            [ImportNotice(.backgroundNotSolid)]
        default:
            []
        }
    }

    /// 足元に影があるコマ（何コマ目か）。
    static func shadowNotices(_ figures: [Figure], in cutout: Raster) -> [ImportNotice] {
        let shadowed = figures.indices.filter { index in
            guard let metrics = FigureMetrics(figures[index].image) else { return false }
            return ShadowCheck.hasShadow(in: cutout, below: box(of: figures[index], metrics: metrics))
        }
        guard !shadowed.isEmpty else { return [] }
        return [ImportNotice(.shadowUnderFeet, shadowed.map { "\($0 + 1)" }.joined(separator: "・") + " コマ目")]
    }

    /// 歩く 4 コマが右を向いていれば、左右を反転する（2-C ⑤-7）。
    static func orient(_ figures: [Figure],
                       layout: SheetLayout) -> (figures: [Figure], notices: [ImportNotice]) {
        guard layout == .walk, WalkDirection.facesRight(figures) else { return (figures, []) }
        return (figures.map { $0.mirrored() }, [ImportNotice(.walkingRight)])
    }

    /// 元の絵の中での、体の外接矩形（画素）。
    static func box(of figure: Figure, metrics: FigureMetrics) -> PixelBox {
        PixelBox(left: figure.originX + Int(metrics.left), top: figure.originY + Int(metrics.top),
                 right: figure.originX + Int(metrics.right.rounded(.up)),
                 bottom: figure.originY + Int(metrics.bottom.rounded(.up)))
    }
}
