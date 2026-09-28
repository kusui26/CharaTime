import Testing
import Foundation
import CoreGraphics
import CTCore
import CTStore
@testable import CTStudio

/// 取り込みの全体（プラン §9 Phase 2 の 2-C ⑤）。同梱のピヨを手引きの並びに縮めて並べた PNG を、`analyze` → 既定の
/// 割り当て → `assemble` に通し、置き場（CTStore）に書いて読み返すまで。
@Suite("取り込みの全体")
struct CharacterStudioTests {

    /// 見本の倍率。立ち姿が 438 画素（生成 AI の P6 の 449 画素に近い）。
    static let scale: CGFloat = 0.6
    /// 1 コマの枠（hero 585×810 の 0.6 倍に余白）。
    static let cell = CGSize(width: 372, height: 500)

    /// 名前を行ごと・左から並べた PNG（位置を少しずつずらす。生成 AI の格子は等間隔にならない）。
    static func sheet(_ names: [String], columns: Int, ground: Samples.Ground = .transparent,
                      scale: CGFloat = scale, mirrored: Bool = false) throws -> Data {
        let rows = (names.count + columns - 1) / columns
        let placements = names.enumerated().map { index, name in
            let column = CGFloat(index % columns), row = CGFloat(index / columns)
            let origin = CGPoint(x: 16 + column * cell.width + CGFloat(index % 3) * 5,
                                 y: 12 + row * cell.height + CGFloat(index % 2) * 7)
            return Samples.Placement(name: name, origin: origin, scale: scale)
        }
        var raster = Samples.sheet(width: 32 + columns * Int(cell.width), height: 24 + rows * Int(cell.height),
                                   ground: ground, placements: placements)
        if mirrored { raster = Figure(image: raster, originX: 0, originY: 0).mirrored().image }
        return try #require(raster.pngData())
    }

    /// P6 の並び（立つ・すわる・寝る / よろこぶ 2 つ・見上げる）。見上げるは、いまの絵に無いので立ち姿で代わりにする。
    static let posesSix = ["piyo_idle_01", "piyo_sit_01", "piyo_sleep_01",
                           "piyo_happy_01", "piyo_happy_02", "piyo_idle_01"]

    static func assembled(_ analyses: [SheetAnalysis]) throws -> StudioResult {
        try CharacterStudio.assemble(analyses.map(\.defaultAssignment))
    }

    static func measure(_ raster: Raster) throws -> FigureMetrics {
        try #require(FigureMetrics(raster))
    }

    @Test("P6 を通すと、立ち姿は元の枠と 1 画素以内に戻り、まばたき・寝息の 2 コマ目とまぶたの差分がそろう")
    func poseSheetBecomesACharacter() async throws {
        let analysis = try await CharacterStudio.analyze(try Self.sheet(Self.posesSix, columns: 3), layout: .poses6)
        #expect(analysis.figures.count == 6)
        #expect(analysis.notices.isEmpty)
        let result = try Self.assembled([analysis])
        #expect(result.frames.mapValues(\.count) == [.idle: 2, .sit: 2, .sleep: 2, .happy: 2])
        #expect(Set(result.eyelids.keys) == [.idle, .sit])
        #expect(Set(result.spares.keys) == [.lookUp])
        #expect(result.notices.isEmpty)
        let idle = try Self.measure(try #require(result.frames[.idle]?.first).hero)
        FrameFittingTests.expectClose(idle, try Self.measure(FrameFittingTests.bundledRaster("piyo_idle_01")),
                                      within: 1, "立ち姿")
        for (pose, list) in result.frames {
            for frame in list {
                #expect(abs(try Self.measure(frame.hero).bottom - 767.25) <= 0.6, "\(pose)")
                #expect(frame.hero.size == CharacterImageKind.hero.pixelSize)
                #expect(frame.mini.size == CharacterImageKind.mini.pixelSize)
            }
        }
        #expect(result.record == ImportRecord(stage: .poses, sources: [analysis.source], guideVersion: "v2"))
        #expect(!result.sleepFrameCoversBase)
    }

    @Test("整えたキャラは、置き場の厳しい検査を通って置け、同じ形で読み返せる")
    func assembledCharacterInstalls() async throws {
        let analysis = try await CharacterStudio.analyze(try Self.sheet(Self.posesSix, columns: 3), layout: .poses6)
        let result = try Self.assembled([analysis])
        let personality = Personality(activity: 0.6, nightOwl: 0.4, napiness: 0.3, favorites: [.cushion])
        let profile = CharacterProfile(id: "user-0000abcd", displayName: "ピヨ", personality: personality,
                                       createdAt: Date(timeIntervalSince1970: 0))
        let store = CharacterStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("ct-studio-\(UUID().uuidString)"))
        try store.install(try result.package(profile))
        let file = try store.read(id: profile.id).get()
        #expect(file.character.frameCounts == [.idle: 2, .sit: 2, .sleep: 2, .happy: 2])
        #expect(file.character.eyelids == [.idle: "mini/idle_eyelid", .sit: "mini/sit_eyelid"])
        #expect(file.importRecord?.guideVersion == PromptTemplate.version)
    }

    @Test("右向きに描かれた歩く 4 コマは左向きにそろえ、背の中央値を立ち姿の背につなぐ")
    func walkingSheetJoinsThePoses() async throws {
        let poses = try await CharacterStudio.analyze(try Self.sheet(Self.posesSix, columns: 3), layout: .poses6)
        let walkNames = (1...4).map { "piyo_walk_0\($0)" }
        let walk = try await CharacterStudio.analyze(try Self.sheet(walkNames, columns: 2, scale: 0.7, mirrored: true),
                                                     layout: .walk)
        #expect(walk.notices == [ImportNotice(.walkingRight)])
        #expect(!WalkDirection.facesRight(walk.figures))
        let result = try Self.assembled([poses, walk])
        #expect(result.frames[.walk]?.count == 4)
        #expect(result.record.stage == .posesAndWalk)
        let heights = try (result.frames[.walk] ?? []).map { try Self.measure($0.hero).height }.sorted()
        #expect(abs((heights[1] + heights[2]) / 2 - result.standingHeight) <= 1)
    }

    @Test("P4 の 2 枚は、2 枚目の立ち姿（背の基準）で背をそろえる。2 枚目は大きさが違っても同じ背になる")
    func twoPoseSheetsShareTheHeight() async throws {
        let firstNames = ["piyo_idle_01", "piyo_sit_01", "piyo_sleep_01", "piyo_happy_01"]
        let first = try await CharacterStudio.analyze(try Self.sheet(firstNames, columns: 2), layout: .poses4A)
        let second = try await CharacterStudio.analyze(
            try Self.sheet(["piyo_idle_01", "piyo_happy_02", "piyo_idle_01", "piyo_sit_01"], columns: 2, scale: 0.5),
            layout: .poses4B)
        let result = try Self.assembled([first, second])
        let happy = try #require(result.frames[.happy])
        #expect(happy.count == 2)
        let truth = try Self.measure(FrameFittingTests.bundledRaster("piyo_happy_02"))
        #expect(abs(try Self.measure(happy[1].hero).height - truth.height) <= 1)
        #expect(Set(result.spares.keys) == [.lookUp, .surprised])
    }

    @Test("1 枚の絵（Tier 0）は立ち姿とまばたきだけ。ほかの姿勢は描かず、立ち姿の代わりに任せる")
    func singleDrawingIsTierZero() async throws {
        let analysis = try await CharacterStudio.analyze(try Self.sheet(["chip_idle_01"], columns: 1), layout: .single)
        let result = try Self.assembled([analysis])
        #expect(result.frames.mapValues(\.count) == [.idle: 2])
        #expect(result.record.stage == .single)
    }

    @Test("目がほかの線に重なる子（いまのクマオ）は、まばたき無しにして F-EYES を勧める")
    func overlappingEyesSkipTheBlink() async throws {
        let analysis = try await CharacterStudio.analyze(try Self.sheet(["kumao_idle_01", "kumao_sit_01"], columns: 2),
                                                         layout: .poses4A)
        let result = try Self.assembled([analysis])
        #expect(result.frames[.idle]?.count == 1 && result.frames[.sit]?.count == 1)
        #expect(result.eyelids.isEmpty)
        #expect(result.notices.contains(ImportNotice(.eyesNotFound, "立ち姿・すわる姿")))
        #expect(result.notices.first { $0.kind == .eyesNotFound }?.remedy == .fix(.eyes))
    }

    @Test("立ち姿が小さいと、ぼやけを知らせる（400 画素未満は待受、300 画素未満はウィジェット）")
    func smallStandingPoseIsBlurry() async throws {
        let standby = try await CharacterStudio.analyze(try Self.sheet(["fuwa_idle_01"], columns: 1, scale: 0.5),
                                                        layout: .single)
        #expect(try Self.assembled([standby]).notices.map(\.kind) == [.blurryOnStandby])
        let widget = try await CharacterStudio.analyze(try Self.sheet(["fuwa_idle_01"], columns: 1, scale: 0.35),
                                                       layout: .single)
        #expect(try Self.assembled([widget]).notices.map(\.kind) == [.blurryOnWidget])
    }

    @Test("立ち姿の無い割り当ては断る")
    func assemblyNeedsTheStandingPose() async throws {
        let walk = try await CharacterStudio.analyze(try Self.sheet((1...4).map { "piyo_walk_0\($0)" }, columns: 2),
                                                     layout: .walk)
        #expect(throws: StudioError.missingStandingPose) { try Self.assembled([walk]) }
    }

    @Test("選んだサービスと背景が合わなければ知らせる（ChatGPT なのに透明でない）")
    func serviceMismatchIsReported() async throws {
        let white = try Self.sheet(["mochi_idle_01"], columns: 1, ground: Samples.white)
        let fromGemini = try await CharacterStudio.analyze(white, layout: .single, service: .gemini)
        #expect(fromGemini.source.background == .solidColor)
        #expect(fromGemini.notices.isEmpty)
        let fromChatGPT = try await CharacterStudio.analyze(white, layout: .single, service: .chatGPT)
        #expect(fromChatGPT.notices == [ImportNotice(.backgroundNotTransparent)])
    }
}

/// 被写体の切り抜き（Vision）を差し替えた取り込み。Vision はシミュレータと `swift test` の既定では使わない。
@Suite("被写体の切り抜きへ回す道")
struct SubjectLiftTests {

    /// 決まった絵を返す切り抜き（Vision の代わり）。
    struct FixedLifter: SubjectLifting {
        let result: Raster?
        func lift(_ image: Raster) async throws -> Raster? { result }
    }

    struct FailingLifter: SubjectLifting {
        func lift(_ image: Raster) async throws -> Raster? { throw CocoaError(.featureUnsupported) }
    }

    static func stripes() throws -> Data {
        try CharacterStudioTests.sheet(["piyo_idle_01"], columns: 1, ground: .stripes)
    }

    @Test("模様の地は、切り抜く道具が無ければ断り、あれば切り抜いた絵からコマを見つける")
    func patternedGroundGoesToTheLifter() async throws {
        await #expect(throws: StudioError.needsSubjectLift) {
            _ = try await CharacterStudio.analyze(try Self.stripes(), layout: .single)
        }
        let lifted = Samples.sheet(width: 404, height: 524, ground: .transparent, placements: [
            Samples.Placement(name: "piyo_idle_01", origin: CGPoint(x: 16, y: 12), scale: CharacterStudioTests.scale),
        ])
        let analysis = try await CharacterStudio.analyze(try Self.stripes(), layout: .single, service: .gemini,
                                                         lifter: FixedLifter(result: lifted))
        #expect(analysis.source.background == .subjectLift)
        #expect(analysis.figures.count == 1)
        #expect(analysis.notices == [ImportNotice(.backgroundNotSolid)])
    }

    /// Vision はシミュレータと GitHub Actions では動かないので、Mac で手で確かめる（`CTSTUDIO_VISION=1 swift test`）。
    /// 2026-09-28 に M1 で: 重なりの割合 0.980、2 回目から 0.03 秒（この Mac で初めて使ったときだけ、モデルの用意に 87 秒）。
    @Test("Vision の被写体の切り抜きで、模様の地から 2 体を切り抜く（Mac で手で確かめる）",
          .enabled(if: ProcessInfo.processInfo.environment["CTSTUDIO_VISION"] == "1"))
    func visionLiftsSubjectsFromAPattern() async throws {
        let placements = [Samples.Placement(name: "piyo_idle_01", origin: CGPoint(x: 30, y: 40), scale: 0.5),
                          Samples.Placement(name: "mochi_sit_01", origin: CGPoint(x: 360, y: 60), scale: 0.5)]
        let sheet = Samples.sheet(width: 700, height: 500, ground: .stripes, placements: placements)
        let truth = Samples.mask(Samples.sheet(width: 700, height: 500, ground: .transparent, placements: placements))
        let lifted = try #require(try await VisionSubjectLifter().lift(sheet))
        #expect(Samples.intersectionOverUnion(truth, Samples.mask(lifted)) >= 0.95)
        let analysis = try await CharacterStudio.analyze(try #require(sheet.pngData()), layout: .poses4A,
                                                         lifter: VisionSubjectLifter())
        #expect(analysis.figures.count == 2)
        #expect(analysis.source.background == .subjectLift)
    }

    @Test("切り抜いて何も無ければ「無地で作り直す」、切り抜きが失敗すれば理由を添えて断る")
    func liftFailuresAreExplained() async throws {
        await #expect(throws: StudioError.noSubject) {
            _ = try await CharacterStudio.analyze(try Self.stripes(), layout: .single, lifter: FixedLifter(result: nil))
        }
        await #expect(throws: StudioError.self) {
            _ = try await CharacterStudio.analyze(try Self.stripes(), layout: .single, lifter: FailingLifter())
        }
    }
}
