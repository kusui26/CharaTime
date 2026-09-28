import Foundation
import CTCore
import CTStore
import CTStudio

/// 既定のキャラ 1 体を整える（プラン §6.4 の ①、§9 Phase 2 の 2-C ⑦、2-3）。
///
/// 利用者の取り込み（キャラ工房、2-6）と同じ `CharacterStudio` を通す（D-35）。既定のキャラは、いまの絵と同じコマを
/// そろえる（`ExpectedShape`）。**そろわなければ `final/` に書かない**（Asset Catalog に欠けたキャラを入れない。
/// 同梱の 12 コマは CTAssets のテストが見張る）。確かめのコンタクトシートは、そろわなくても書く。
public struct CharacterBake: Sendable {

    public let repository: Repository
    /// 絵を作ったサービス（背景の知らせに使う。既定の 5 体は ChatGPT。テンプレート §3）。
    public let service: PromptTemplate.Service
    /// 地が 1 色でも透明でもない絵の、被写体の切り抜き（Mac では Vision）。
    public let lifter: (any SubjectLifting)?

    public init(repository: Repository, service: PromptTemplate.Service = .chatGPT,
                lifter: (any SubjectLifting)? = nil) {
        self.repository = repository
        self.service = service
        self.lifter = lifter
    }

    /// 生の絵から整える。そろえば `final/` に書く。
    public func bake(_ id: String, files: [URL]) async throws(BakeError) -> BakeOutcome {
        let catalog = try repository.bundledCatalog()
        let expected = ExpectedShape(try catalog.character(id))
        let inputs = try RawNaming.inputs(files)
        let analyses = try await analyze(inputs)
        let result = try assemble(id, analyses)
        let report = BakeReport(id: id, inputs: inputs, analyses: analyses, result: result)
        let picture = ContactSheet.character(id, result: result, geometry: catalog.spriteGeometry)
        let sheet = try ContactSheet.write(picture, to: repository.shots.appending(path: "\(id).png"))
        let sheets = zip(inputs, analyses).map { input, analysis in
            SheetNotices(file: input.file.lastPathComponent, layout: input.layout, notices: analysis.notices)
        }
        let missing = expected.missing(in: result)
        let final = missing.isEmpty ? repository.finalFolder(of: id) : nil
        if let final { try FinalFolder.write(result, report: report, to: final) }
        return BakeOutcome(report: report, sheets: sheets, notices: result.notices, missing: missing,
                           final: final, contactSheet: sheet)
    }

    /// 割り当てたコマから、1 体ぶんの絵をそろえる。
    func assemble(_ id: String, _ analyses: [SheetAnalysis]) throws(BakeError) -> StudioResult {
        do {
            return try CharacterStudio.assemble(analyses.map(\.defaultAssignment))
        } catch {
            throw .studio(id, error)
        }
    }

    /// 絵ごとに、読む・背景を外す・コマを見つける。
    func analyze(_ inputs: [RawInput]) async throws(BakeError) -> [SheetAnalysis] {
        var analyses: [SheetAnalysis] = []
        for input in inputs {
            let data: Data
            do {
                data = try Data(contentsOf: input.file)
            } catch {
                throw .unreadable(input.file.lastPathComponent, error.localizedDescription)
            }
            do {
                let analysis = try await CharacterStudio.analyze(data, layout: input.layout, service: service,
                                                                 lifter: lifter)
                analyses.append(analysis)
            } catch {
                throw .studio(input.file.lastPathComponent, error)
            }
        }
        return analyses
    }
}

/// 整えた結果。
public struct BakeOutcome: Sendable {
    public let report: BakeReport
    /// 絵ごとの知らせ（直しのプロンプトを添えるため、知らせの種類のまま持つ）。
    public let sheets: [SheetNotices]
    /// そろえたときの知らせ。
    public let notices: [ImportNotice]
    /// そろわなかったもの（空なら `final/` に書いた）。
    public let missing: [String]
    /// 書いた `final/`（そろわなければ nil）。
    public let final: URL?
    /// 確かめのコンタクトシート。
    public let contactSheet: URL
}

/// 生の絵 1 枚ぶんの知らせ。
public struct SheetNotices: Sendable {
    public let file: String
    public let layout: SheetLayout
    public let notices: [ImportNotice]
}

/// 既定のキャラがそろえるべきコマ。**いまの `characters.json` のそのキャラと同じ**（姿勢ごとの枚数と、まぶたの差分の
/// ある姿勢）。そこは `tools/pipeline` が `design/chara.py` の `FRAMES` から書くので、出どころは 1 つのまま。
struct ExpectedShape {

    let frameCounts: [Pose: Int]
    let eyelidPoses: Set<Pose>

    init(_ character: CTCore.Character) {
        frameCounts = character.poses.mapValues(\.count)
        eyelidPoses = Set(character.eyelids.keys)
    }

    /// 足りないもの・多すぎるもの（空ならそろっている）。
    func missing(in result: StudioResult) -> [String] {
        let frames = Pose.allCases.compactMap { pose -> String? in
            let expected = frameCounts[pose] ?? 0, actual = result.frames[pose]?.count ?? 0
            return expected == actual ? nil : "\(pose.displayName)が \(actual) コマ（\(expected) コマのはず）"
        }
        let eyelids = Pose.allCases.filter { eyelidPoses.contains($0) && result.eyelids[$0] == nil }
            .map { "\($0.displayName)のまぶたの差分（まばたきを作れなかった）" }
        return frames + eyelids
    }
}
