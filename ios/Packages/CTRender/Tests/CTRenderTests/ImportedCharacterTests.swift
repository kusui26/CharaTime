import Testing
import Foundation
import CoreGraphics
import ImageIO
import CTCore
import CTAssets
import CTStore
@testable import CTRender

/// 取り込んだキャラの描き方（プラン §9 Phase 2 の 2-C ⑥、D-34、2-1）。
///
/// 終わりの確かめ方: **取り込んだ子（テスト用の絵）で、日課と疑似アニメの答えが既定の子と同じ形で出る**。
/// テスト用の絵には、同梱のピヨの絵そのもの（パイプラインが焼いた @3x の PNG）を使う。絵も性格も同じにすれば、
/// 違うのは id と出どころだけになり、既定の子と取り込んだ子を並べて比べられる。
@Suite("取り込んだキャラの描き方")
struct ImportedCharacterTests {

    static let tokyo: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }()

    static let twinID = "user-5a4e0001"

    /// 同梱のピヨ。
    static func piyo() throws -> CTCore.Character {
        try #require(Catalog.characters().first { $0.id == "piyo" })
    }

    static func temporaryStore() -> CharacterStore {
        CharacterStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("ct-render-characters-\(UUID().uuidString)"))
    }

    /// パイプラインが焼いた @3x の PNG（macOS の `swift test` では、Asset Catalog がそのまま置かれる）。
    static func bundledPNG(_ name: String) throws -> CGImage {
        let catalog = try #require(AssetBundle.value.url(forResource: "Characters", withExtension: "xcassets"))
        let url = catalog.appending(path: "\(name).imageset/\(name)@3x.png")
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    /// 同梱の子の絵で作った、取り込んだ子の包み。`poses` を渡すと、その姿勢の絵だけを持つ。
    static func twinPackage(of bundled: CTCore.Character, id: String = twinID,
                            poses: [Pose]? = nil) throws -> CharacterPackage {
        let kept = poses ?? Pose.allCases.filter { bundled.frameCount($0) > 0 }
        let frames = try Dictionary(uniqueKeysWithValues: kept.map { pose in
            (pose, try zip(bundled.poses[pose] ?? [], bundled.miniPoses[pose] ?? []).map { hero, mini in
                CharacterPackage.Frame(hero: try bundledPNG(hero), mini: try bundledPNG(mini))
            })
        })
        let eyelids = try Dictionary(uniqueKeysWithValues: bundled.eyelids.filter { kept.contains($0.key) }
            .map { pose, name in (pose, try bundledPNG(name)) })
        let profile = CharacterProfile(id: id, displayName: bundled.displayName, scale: bundled.scale,
                                       personality: bundled.personality,
                                       createdAt: Date(timeIntervalSince1970: 1_790_000_000))
        return .assemble(profile, frames: frames, eyelids: eyelids,
                         sleepFrameCoversBase: bundled.sleepFrameCoversBase)
    }

    /// 取り込んで、読み返したキャラ（`AppState.chooseCharacter` が読むのと同じ道）。
    static func installed(_ package: CharacterPackage, in store: CharacterStore) throws -> CTCore.Character {
        try store.install(package)
        return try store.read(id: package.file.character.id).get().character
    }

    static func input(_ character: CTCore.Character) -> WorldInput {
        let ball = PlacedItem(id: "ball", kind: .mirrorBall, position: RoomPoint(x: 0.5, y: 0.3))
        let room = Room(background: .bundled("room"), floor: BundledRoom.floor,
                        items: BundledRoom.room.items + [ball])
        return WorldInput(character: character, room: room, userSeed: 0x2_1ACE, calendar: tokyo)
    }

    /// 1 日を 31.37 秒刻みで（約 2,750 の時刻）。刻みに端数を付け、コマ送りとまばたきのどの位相にも当たるようにする。
    static let day: [Date] = stride(from: 0.37, to: 24 * 3600, by: 31.37).map {
        tokyo.date(from: DateComponents(year: 2026, month: 9, day: 28))!.addingTimeInterval($0)
    }

    /// ウィジェットのエントリの時刻（5 分ごと、1 日ぶん）。
    static let entries: [Date] = (0..<(24 * 12)).map {
        tokyo.date(from: DateComponents(year: 2026, month: 9, day: 28))!.addingTimeInterval(Double($0) * 300)
    }

    static let layout = WidgetStage.stage(for: .large).layout(
        size: WidgetStage.referenceSize(for: .large), room: BundledRoom.room,
        geometry: SpriteGeometry(aspectRatio: 130.0 / 180.0, groundRatio: 168.0 / 180.0))

    // MARK: - 既定の子と同じ形で暮らす

    /// 日課エンジンは絵の出どころを知らない（2-C ⑥）。id と性格と絵の枚数が同じなら、同じ一日になる。
    @Test("ピヨの絵で取り込んだ子は、同じ id の既定のピヨと同じ一日を過ごし、ウィジェットでも同じに動く")
    func importedTwinLivesLikeTheBundledOne() throws {
        let piyo = try Self.piyo()
        let imported = try Self.installed(Self.twinPackage(of: piyo), in: Self.temporaryStore())
        var bundled = piyo
        bundled.id = Self.twinID
        #expect(imported.frameCounts == piyo.frameCounts)
        #expect(imported.ambientArt == piyo.ambientArt)
        #expect(SceneEngine.sceneStates(at: Self.day, input: Self.input(imported))
                == SceneEngine.sceneStates(at: Self.day, input: Self.input(bundled)))
        let moments = { (character: CTCore.Character) in
            WidgetMoments.make(at: Self.entries, input: Self.input(character), settings: CTStore.Settings(),
                               layout: Self.layout)
        }
        #expect(moments(imported) == moments(bundled))
    }

    /// 取り込んだ子は、待受では hero、ウィジェットでは mini とまぶたの差分を、読み込んだ絵から描く。
    @Test("取り込んだ子は、1 日のどの姿でも、描く絵が読み込んだ絵の中にある（待受・止めた 1 枚・疑似アニメ）")
    func everyPictureOfTheDayIsLoaded() throws {
        let store = Self.temporaryStore()
        let imported = try Self.installed(Self.twinPackage(of: Self.piyo()), in: store)
        let hero = try #require(SpriteSource.loading(imported, size: .hero, from: store))
        let mini = try #require(SpriteSource.loading(imported, size: .mini, from: store))
        try Self.expectEveryPictureIsLoaded(imported, hero: hero, mini: mini)
    }

    /// 取り込みの段（2-C ③）。立ち姿 1 枚でも、ポーズの格子だけでも、日課のどの姿も描ける。
    @Test("立ち姿 1 枚の子も、歩く絵の無い子も、1 日のどの姿でも描く絵がある", arguments: [
        [Pose.idle], [.idle, .sit, .sleep, .happy],
    ])
    func partialCharactersAlwaysHaveAPicture(poses: [Pose]) throws {
        let store = Self.temporaryStore()
        let imported = try Self.installed(Self.twinPackage(of: Self.piyo(), poses: poses), in: store)
        let hero = try #require(SpriteSource.loading(imported, size: .hero, from: store))
        let mini = try #require(SpriteSource.loading(imported, size: .mini, from: store))
        try Self.expectEveryPictureIsLoaded(imported, hero: hero, mini: mini)
    }

    @Test("立ち姿 1 枚の子は、寝ているあいだ、目を閉じた立ち姿で描く（待受もウィジェットも）")
    func singlePictureSleepsWithEyesClosed() throws {
        let imported = try Self.installed(Self.twinPackage(of: Self.piyo(), poses: [.idle]), in: Self.temporaryStore())
        let asleep = SceneEngine.sceneStates(at: Self.day, input: Self.input(imported)).filter(\.activity.isAsleep)
        #expect(!asleep.isEmpty)
        for state in asleep {
            #expect(imported.spriteName(for: .live(state, character: imported)) == "hero/idle_02")
            #expect(imported.spriteName(for: .still(state, character: imported)) == "mini/idle_02")
        }
    }

    /// 描き方の段が変わっても（止めた 1 枚 ⇄ 疑似アニメ）、同じ絵の同じコマ。
    @Test("止めた 1 枚と、疑似アニメの土台は、同じ絵の同じコマ（足りない姿勢も）", arguments: [
        nil, [Pose.idle], [.idle, .sit, .sleep, .happy],
    ])
    func stillPickMatchesTheAmbientBase(poses: [Pose]?) throws {
        let piyo = try Self.piyo()
        let character = try Self.twinPackage(of: piyo, poses: poses).file.character
        let input = Self.input(character)
        for moment in WidgetMoments.make(at: Self.entries, input: input, settings: CTStore.Settings(),
                                         layout: Self.layout) {
            let still = SpritePick.still(moment.state, character: character)
            #expect(still.pose == moment.cue.pose, "\(moment.state.activity)")
            if let base = moment.cue.baseFrame { #expect(still.frame == base, "\(moment.state.activity)") }
        }
    }

    // MARK: - 絵

    @Test("取り込んだ子の絵は、置いたとおりの画素で読める（同梱の絵と同じ）")
    func loadedPicturesKeepTheirPixels() throws {
        let store = Self.temporaryStore()
        let imported = try Self.installed(Self.twinPackage(of: Self.piyo()), in: store)
        guard case .loaded(let images) = SpriteSource.loading(imported, size: .hero, from: store) else {
            Issue.record("読み込んだ絵になっていない")
            return
        }
        let loaded = try #require(images["hero/idle_01"])
        let original = try Self.bundledPNG("piyo_idle_01")
        for (x, y) in [(292, 405), (292, 700), (150, 300), (0, 0), (584, 809)] {
            #expect(Self.color(of: loaded, x: x, y: y) == Self.color(of: original, x: x, y: y), "(\(x), \(y))")
        }
    }

    /// 取り込んだ子を同じ枠で描くための約束（D-34）。パイプラインが絵の大きさを変えたら、ここで気づく。
    @Test("取り込んだ子の絵の大きさは、パイプラインが焼いた同梱の絵（@3x）と同じ")
    func canvasMatchesThePipeline() throws {
        let hero = try Self.bundledPNG("piyo_idle_01")
        let mini = try Self.bundledPNG("piyo_idle_01_mini")
        #expect(PixelSize(width: hero.width, height: hero.height) == CharacterImageKind.hero.pixelSize)
        #expect(PixelSize(width: mini.width, height: mini.height) == CharacterImageKind.mini.pixelSize)
        let geometry = Catalog.spriteGeometry()
        #expect(abs(Double(hero.width) / Double(hero.height) - geometry.aspectRatio) < 0.001)
    }

    @Test("同梱の子の id は、取り込んだ子の形（user-）にならない。重ならない")
    func bundledIDsNeverLookImported() {
        let characters = Catalog.charactersOrEmpty()
        #expect(characters.count == 5)
        #expect(characters.allSatisfy { !CharacterID.isUser($0.id) })
    }

    @Test("絵の出どころ: 同梱は名前で、読み込んだ絵は画像で引く。読み込んだ絵に無い名前は描かない")
    func sourcesResolveNames() throws {
        let image = try Self.bundledPNG("piyo_idle_01")
        #expect(SpriteSource.catalog.art(named: "piyo_idle_01") == .catalog("piyo_idle_01"))
        let loaded = SpriteSource.loaded(SpriteImages(["hero/idle_01": image]))
        #expect(loaded.art(named: "hero/idle_01") == .loaded(image))
        #expect(loaded.art(named: "hero/idle_02") == .missing)
        // 同梱の子は、置き場を見ずに Asset Catalog。
        let bundledSprites = SpriteSource.loading(try Self.piyo(), size: .hero, from: CharacterStore(directory: nil))
        #expect(Self.isCatalog(bundledSprites))
    }

    // MARK: - 選んだキャラ（読めなければ同梱の先頭）

    static func chosen(_ selected: String, store: CharacterStore,
                       bundled: [CTCore.Character] = Catalog.charactersOrEmpty()) -> ChosenCharacter? {
        AppState(userSeed: 1, selectedCharacterID: selected).chooseCharacter(bundled: bundled, store: store,
                                                                              size: .hero)
    }

    static func isCatalog(_ sprites: SpriteSource?) -> Bool {
        if case .catalog = sprites { return true }
        return false
    }

    @Test("選んだ取り込みの子が読めれば、その子を、読み込んだ待受用の絵と一緒に返す")
    func chosenImportedCharacter() throws {
        let store = Self.temporaryStore()
        let imported = try Self.installed(Self.twinPackage(of: Self.piyo()), in: store)
        let chosen = try #require(Self.chosen(Self.twinID, store: store))
        #expect(chosen.character == imported)
        guard case .loaded(let images) = chosen.sprites else {
            Issue.record("読み込んだ絵になっていない")
            return
        }
        #expect(images.names == Set(Pose.allCases.flatMap { imported.poses[$0] ?? [] }))
    }

    /// 2-B の Gate: 取り込んだ子が壊れても落ちず、既定のキャラに戻る。
    @Test("選んだ取り込みの子が読めなければ（消えた・壊れた・書きかけ・絵が読めない）、同梱の先頭に戻る",
          arguments: ["消えた", "壊れた", "書きかけ", "絵が読めない"])
    func brokenChoiceFallsBackToTheFirstBundled(breakage: String) throws {
        let store = Self.temporaryStore()
        try store.install(Self.twinPackage(of: Self.piyo(), poses: [.idle]))
        let folder = try #require(store.folderURL).appendingPathComponent(Self.twinID)
        switch breakage {
        case "消えた": try FileManager.default.removeItem(at: folder)
        case "壊れた": try Data("{".utf8).write(to: folder.appendingPathComponent(CharacterStore.fileName))
        case "書きかけ":
            try FileManager.default.moveItem(at: folder, to: folder.deletingLastPathComponent()
                .appendingPathComponent(".incoming-" + Self.twinID))
        default: try Data("これは PNG ではない".utf8).write(to: folder.appendingPathComponent("hero/idle_02.png"))
        }
        let chosen = try #require(Self.chosen(Self.twinID, store: store))
        #expect(chosen.character.id == Catalog.charactersOrEmpty().first?.id)
        #expect(Self.isCatalog(chosen.sprites))
    }

    @Test("App Group が無くても、同梱の子を選んでいればその子、取り込んだ子を選んでいれば同梱の先頭")
    func noContainerKeepsTheBundledCharacters() throws {
        let store = CharacterStore(directory: nil)
        #expect(Self.chosen("mochi", store: store)?.character.id == "mochi")
        #expect(Self.chosen(Self.twinID, store: store)?.character.id == Catalog.charactersOrEmpty().first?.id)
        #expect(Self.isCatalog(Self.chosen(Self.twinID, store: store)?.sprites))
        #expect(Self.chosen(Self.twinID, store: store, bundled: []) == nil, "同梱も無ければ nil（落とさない）")
    }

    // MARK: - 選べるキャラの一覧

    @Test("選べる一覧は、既定の 5 体のあとに、読めた取り込みの子。壊れた子・書きかけは並ばない")
    func rosterKeepsTheBundledFiveAndTheGoodOnes() throws {
        let store = Self.temporaryStore()
        let piyo = try Self.piyo()
        try store.install(Self.twinPackage(of: piyo, id: "user-00000001", poses: [.idle]))
        try store.install(Self.twinPackage(of: piyo, id: "user-00000002", poses: [.idle]))
        let root = try #require(store.folderURL)
        try Data("{".utf8).write(to: root.appendingPathComponent("user-00000002/\(CharacterStore.fileName)"))
        try FileManager.default.copyItem(at: root.appendingPathComponent("user-00000001"),
                                         to: root.appendingPathComponent(".incoming-user-00000003"))
        let bundled = Catalog.charactersOrEmpty()
        let roster = CharacterRoster.characters(bundled: bundled, shelf: store.loadAll())
        #expect(roster.map(\.id) == bundled.map(\.id) + ["user-00000001"])
        #expect(CharacterRoster.characters(bundled: bundled, shelf: CharacterStore(directory: nil).loadAll())
                .map(\.id) == bundled.map(\.id))
    }

    // MARK: - 道具

    /// その子の 1 日のどの姿でも、待受の絵（hero）・止めた 1 枚（mini）・疑似アニメの絵（mini とまぶた）が、
    /// 読み込んだ絵の中にある。
    static func expectEveryPictureIsLoaded(_ character: CTCore.Character, hero: SpriteSource, mini: SpriteSource,
                                           sourceLocation: SourceLocation = #_sourceLocation) throws {
        for state in SceneEngine.sceneStates(at: day, input: input(character)) {
            let live = character.spriteName(for: .live(state, character: character))
            #expect(hero.art(named: live) != .missing, "\(state.activity): \(live)", sourceLocation: sourceLocation)
        }
        for moment in WidgetMoments.make(at: entries, input: input(character), settings: CTStore.Settings(),
                                         layout: layout) {
            let names = ambientNames(moment.cue, of: character)
                + [character.spriteName(for: .still(moment.state, character: character))]
            for name in names {
                #expect(mini.art(named: name) != .missing, "\(moment.state.activity): \(name)",
                        sourceLocation: sourceLocation)
            }
        }
    }

    /// 疑似アニメが描く絵の名前（土台・重ねるコマ・まぶた）。`AmbientCharacterView` と同じ引き方。
    static func ambientNames(_ cue: AmbientCue, of character: CTCore.Character) -> [String] {
        let frame = { (index: Int) in
            character.spriteName(for: SpritePick(pose: cue.pose, frame: index, facing: .front, size: .mini))
        }
        let overlays = cue.overlays.compactMap { overlay -> String? in
            switch overlay.layer {
            case .eyelid: character.eyelids[cue.pose]
            case .frame(let index): frame(index)
            case .clockBubble, .sparkle, .sleepMark: nil
            }
        }
        return [cue.baseFrame.map(frame)].compactMap { $0 } + overlays
    }

    /// 画像の (x, y) の色（上から数えた y。RGBA）。
    static func color(of image: CGImage, x: Int, y: Int) -> [UInt8] {
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: -x, y: y - image.height + 1, width: image.width, height: image.height))
        return pixel
    }
}
