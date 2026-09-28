import Testing
import Foundation
import CTCore
import CTStore
@testable import CTStudio
@testable import CharaBake

/// 既定の 5 体を焼く道具（プラン §6.4 の ①、2-C ⑦、2-3）。**いまの絵を手引きの格子に並べて道具に通すと、
/// いまの絵と同じ枠・接地線に戻るか**（2-3 の確かめ方）。読むのはリポジトリ、書くのは一時フォルダ。
@Suite("既定の 5 体を焼く道具")
struct CharacterBakeTests {

    /// リポジトリの根（このファイルから 6 つ上）。
    static let root = (0..<6).reduce(URL(fileURLWithPath: #filePath)) { url, _ in url.deletingLastPathComponent() }
    /// 見本の倍率。生成 AI の絵より少し小さく（テストを速くする）、立ち姿は 438 画素（ぼやけの知らせは出ない）。
    static let scale = 0.6

    static func repository(writingTo output: URL = temporaryFolder()) -> Repository {
        Repository(root: root, output: output)
    }

    static func temporaryFolder() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "chara-bake-\(UUID().uuidString)")
    }

    /// いまの絵の見本を書いて、道具に通す。
    static func bakeSample(_ id: String, into repository: Repository,
                           scale: Double = scale) async throws -> BakeOutcome {
        let files = try SampleSheets.write(id, repository: repository, to: repository.output.appending(path: "raw"),
                                           scale: scale)
        return try await CharacterBake(repository: repository).bake(id, files: files)
    }

    static func metrics(_ url: URL) throws -> FigureMetrics {
        try #require(FigureMetrics(try ImageReading.raster(from: Data(contentsOf: url))))
    }

    /// フォルダの中のファイルと中身（`.` で始まるものも含む）。
    static func snapshot(_ folder: URL) throws -> [String: Data] {
        let paths = FileManager.default.subpaths(atPath: folder.path(percentEncoded: false)) ?? []
        var files: [String: Data] = [:]
        for path in paths where !path.hasSuffix("/") {
            let url = folder.appending(path: path)
            var isFolder: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isFolder)
            if !isFolder.boolValue { files[path] = try Data(contentsOf: url) }
        }
        return files
    }

    @Test("ピヨの絵を格子に並べて通すと、いまの絵と同じ枠・接地線に戻る（2-3 の確かめ方）")
    func sampleRoundTripsToTheBundledFrame() async throws {
        let repository = Self.repository()
        let outcome = try await Self.bakeSample("piyo", into: repository)
        let final = try #require(outcome.final, "\(outcome.missing)")
        let baked = try Self.metrics(final.appending(path: "hero/idle_01.png"))
        let bundled = try Self.metrics(repository.bundledImage("piyo_idle_01"))
        let pairs = [(baked.left, bundled.left), (baked.right, bundled.right), (baked.top, bundled.top),
                     (baked.bottom, bundled.bottom), (baked.anchorX, bundled.anchorX)]
        for (found, truth) in pairs { #expect(abs(found - truth) <= 1, "\(found) と \(truth)") }
        for pose in Pose.allCases {
            for index in 0..<(outcome.report.frames[pose] ?? 0) {
                let hero = final.appending(path: CharacterImageName.frame(pose, index, kind: .hero) + ".png")
                #expect(abs(try Self.metrics(hero).bottom - 767.25) <= 0.6, "\(pose) \(index)")
            }
        }
    }

    @Test("final/ に 12 コマ・mini・まぶたの差分・予備と記録を書き、コンタクトシートを書く")
    func finalFolderHoldsEverything() async throws {
        let repository = Self.repository()
        let outcome = try await Self.bakeSample("piyo", into: repository)
        let final = try #require(outcome.final)
        let files = try Self.snapshot(final)
        #expect(files.keys.filter { $0.hasPrefix("hero/") }.count == 12)
        #expect(files.keys.filter { $0.hasPrefix("mini/") }.count == 14)
        #expect(Set(files.keys.filter { $0.hasPrefix("spare/") })
                == ["spare/hero/lookUp_01.png", "spare/mini/lookUp_01.png",
                    "spare/hero/surprised_01.png", "spare/mini/surprised_01.png"])
        let report = try JSONDecoder().decode(BakeReport.self, from: try #require(files[FinalFolder.reportName]))
        #expect(report.frames == [.idle: 2, .walk: 4, .sit: 2, .sleep: 2, .happy: 2])
        #expect(report.eyelids == [.idle, .sit] && report.spares == [.lookUp, .surprised])
        #expect(report.sources.map(\.layout) == [.poses4A, .poses4B, .walk])
        #expect(report.guideVersion == PromptTemplate.version && report.notices.isEmpty)
        #expect(FileManager.default.fileExists(atPath: outcome.contactSheet.path(percentEncoded: false)))
    }

    @Test("焼き直すと final/ を丸ごと入れ替え、同じ絵なら同じバイトになる（git の差分を出さない）")
    func rebakingReplacesTheFolderWithTheSameBytes() async throws {
        let repository = Self.repository()
        let baked = try await Self.bakeSample("piyo", into: repository, scale: 0.5)
        let first = try Self.snapshot(try #require(baked.final))
        let final = repository.finalFolder(of: "piyo")
        try Data().write(to: final.appending(path: "hero/old.png"))
        _ = try await Self.bakeSample("piyo", into: repository, scale: 0.5)
        #expect(try Self.snapshot(final) == first)
        let siblings = try FileManager.default.contentsOfDirectory(atPath: final.deletingLastPathComponent().path())
        #expect(siblings == ["final"])
    }

    @Test("まばたきを作れない子（いまのクマオ）は final/ に書かず、足りないものを知らせる。コンタクトシートは書く")
    func incompleteCharacterIsNotWritten() async throws {
        let repository = Self.repository()
        let outcome = try await Self.bakeSample("kumao", into: repository, scale: 0.5)
        #expect(outcome.final == nil)
        #expect(outcome.missing.contains("立ち姿のまぶたの差分（まばたきを作れなかった）"))
        #expect(outcome.missing.contains("すわるが 1 コマ（2 コマのはず）"))
        let final = repository.finalFolder(of: "kumao").path(percentEncoded: false)
        #expect(!FileManager.default.fileExists(atPath: final))
        #expect(FileManager.default.fileExists(atPath: outcome.contactSheet.path(percentEncoded: false)))
    }

    @Test("同梱のキャラでない id は、同梱の id を添えて断る")
    func unknownCharacterIsRejected() async {
        await #expect(throws: BakeError.unknownCharacter("user-1234", ["piyo", "mochi", "kumao", "fuwa", "chip"])) {
            _ = try await CharacterBake(repository: Self.repository()).bake("user-1234", files: [])
        }
    }

    @Test("全キャラ × 全コマの一覧は、final/ があるキャラだけ final/ の絵を使う")
    func catalogSheetPrefersTheFinalFolder() async throws {
        let repository = Self.repository()
        _ = try await Self.bakeSample("piyo", into: repository, scale: 0.5)
        let catalog = try repository.bundledCatalog()
        let rows = try CatalogSheet.rows(repository, catalog: catalog)
        #expect(rows.map(\.id) == ["piyo", "mochi", "kumao", "fuwa", "chip"])
        #expect(rows.map(\.source) == ["final/", "いまの絵", "いまの絵", "いまの絵", "いまの絵"])
        #expect(rows.allSatisfy { $0.cells.count == 12 })
        let sheet = try #require(CatalogSheet.render(rows, groundRatio: catalog.spriteGeometry.groundRatio))
        let layout = CatalogSheetLayout(rows: 5, columns: 12)
        #expect(sheet.width == layout.width && sheet.height == layout.height)
    }
}
