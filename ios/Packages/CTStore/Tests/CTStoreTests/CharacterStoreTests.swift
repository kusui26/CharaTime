import Testing
import Foundation
import CoreGraphics
import CTCore
@testable import CTStore

/// 取り込んだキャラの置き場（プラン §9 Phase 2 の 2-C ③⑤-8⑪、2-1）。
///
/// 終わりの確かめ方: **壊れたフォルダ・書きかけ・id の重なり・App Group が無い**ときに、ほかのキャラが生きる。
@Suite("取り込んだキャラの置き場")
struct CharacterStoreTests {

    typealias Art = CharacterTestArt

    static func temporaryStore() -> CharacterStore {
        CharacterStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("ct-characters-\(UUID().uuidString)"))
    }

    static func folder(_ store: CharacterStore, _ name: String) -> URL {
        store.folderURL!.appendingPathComponent(name, isDirectory: true)
    }

    static func jsonURL(_ store: CharacterStore, _ id: String) -> URL {
        folder(store, id).appendingPathComponent(CharacterStore.fileName)
    }

    /// 置き場の中の名前（隠しフォルダも）。
    static func entries(_ store: CharacterStore) -> [String] {
        store.folderNames().sorted()
    }

    /// `read` の失敗の理由。読めたら nil。
    static func failure(_ store: CharacterStore, _ id: String) -> CharacterStore.StoreError? {
        if case .failure(let error) = store.read(id: id) { return error }
        return nil
    }

    // MARK: - 置いて読む

    @Test("置いたキャラを、同じ中身で読み返せる")
    func installAndRead() throws {
        let store = Self.temporaryStore()
        let package = Art.package()
        try store.install(package)
        let file = try store.read(id: package.file.character.id).get()
        #expect(file == package.file)
        #expect(file.character.origin == .user(createdAt: Art.createdAt))
        #expect(file.importRecord?.stage == .posesAndWalk)
        #expect(store.loadAll().files == [file])
        #expect(store.loadAll().skipped.isEmpty)
        #expect(Self.entries(store) == ["user-00000001"], "書きかけのフォルダが残らない")
    }

    /// 同梱の `characters.json` の 1 体と同じ項目が、同じ階層に並ぶ（D-34）。
    @Test("character.json は、Character と同じ形に、版と取り込みの記録を足したもの")
    func fileIsACharacterPlusTheRecord() throws {
        let store = Self.temporaryStore()
        let package = Art.package()
        try store.install(package)
        let data = try Data(contentsOf: Self.jsonURL(store, "user-00000001"))
        #expect(try JSONDecoder().decode(CTCore.Character.self, from: data) == package.file.character)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(object.keys) == ["id", "displayName", "scale", "personality", "poses", "miniPoses", "eyelids",
                                     "sleepFrameCoversBase", "origin", "schemaVersion", "importRecord"])
        #expect(object["schemaVersion"] as? Int == CharacterFile.currentSchemaVersion)
    }

    @Test("同梱の定義（版も記録も無い）も、取り込んだキャラのファイルとして読める")
    func plainCharacterJSONDecodes() throws {
        let character = Art.package().file.character
        let file = try JSONDecoder().decode(CharacterFile.self, from: JSONEncoder().encode(character))
        #expect(file.character == character)
        #expect(file.schemaVersion == 1)
        #expect(file.importRecord == nil)
    }

    /// 記録は描くのに使わない。壊れていても、キャラまで捨てない。
    @Test("取り込みの記録が壊れていても、キャラは読める（記録だけを捨てる）")
    func brokenRecordIsDropped() throws {
        let store = Self.temporaryStore()
        try store.install(Art.package(frames: Art.single))
        let url = Self.jsonURL(store, "user-00000001")
        var object = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        object["importRecord"] = ["stage": "まだ無い段", "sources": 3]
        try JSONSerialization.data(withJSONObject: object).write(to: url)
        let file = try store.read(id: "user-00000001").get()
        #expect(file.importRecord == nil)
        #expect(file.character == Art.package(frames: Art.single).file.character)
    }

    @Test("組み立てた定義は、同梱の絵と同じ並び（mini は hero と同じ枚数、まぶたは mini）")
    func assembledCharacterFollowsTheLayout() {
        let character = Art.package().file.character
        #expect(character.poses[.walk] == ["hero/walk_01", "hero/walk_02", "hero/walk_03", "hero/walk_04"])
        #expect(character.miniPoses[.walk] == ["mini/walk_01", "mini/walk_02", "mini/walk_03", "mini/walk_04"])
        #expect(character.eyelids == [.idle: "mini/idle_eyelid", .sit: "mini/sit_eyelid"])
        #expect(character.frameCounts == Art.tierOne)
        #expect(Art.package().images.count == 12 * 2 + 2)
    }

    // MARK: - 絵を読む

    @Test("絵を名前で読み返せる。大きさも画素も、置いたとおり")
    func imagesReadBack() throws {
        let store = Self.temporaryStore()
        let base = Art.package(frames: Art.single)
        let blink = Art.picture(CharacterImageKind.hero.pixelSize, gray: 17)
        let images = base.images.merging(["hero/idle_02": blink]) { $1 }
        try store.install(CharacterPackage(file: base.file, images: images))
        let hero = try #require(store.image("hero/idle_02", of: "user-00000001", maxPixelSize: 810))
        #expect(hero.width == 585 && hero.height == 810)
        #expect(Art.color(of: hero, x: 292, y: 405) == Art.color(of: blink, x: 292, y: 405))
        let mini = try #require(store.image("mini/idle_eyelid", of: "user-00000001", maxPixelSize: 378))
        #expect(mini.width == 273 && mini.height == 378)
    }

    /// 読み手の柵。置くときに大きさを確かめていても、あとから壊れたファイルで展開しすぎない。
    @Test("大きすぎる絵は、縮めて読む（壊れて大きくなった絵で、メモリを使い切らない）")
    func oversizedImagesAreScaledDown() throws {
        let store = Self.temporaryStore()
        try store.install(Art.package(frames: Art.single))
        let url = try #require(store.imageURL("mini/idle_01", of: "user-00000001"))
        try ImageFile.writePNG(Art.picture(PixelSize(width: 2000, height: 3000)), to: url)
        let image = try #require(store.image("mini/idle_01", of: "user-00000001", maxPixelSize: 378))
        #expect(Swift.max(image.width, image.height) == 378)
    }

    @Test("名前や id の形が違えば、フォルダの外を指さない")
    func namesNeverEscapeTheFolder() throws {
        let store = Self.temporaryStore()
        try store.install(Art.package(frames: Art.single))
        for name in ["../character", "hero/../../x", "/etc/passwd", "hero/", "mini/idle 01", "idle_01", "hero/a/b"] {
            #expect(store.imageURL(name, of: "user-00000001") == nil, "\(name)")
        }
        for id in ["piyo", "user-", "user-../x", "USER-00000001", "user-00000001/.."] {
            #expect(store.imageURL("hero/idle_01", of: id) == nil, "\(id)")
        }
        #expect(store.image("hero/idle_01", of: "user-00000002", maxPixelSize: 810) == nil, "いない子の絵は nil")
    }

    // MARK: - 壊れたフォルダ・書きかけ（ほかの子は生きる）

    @Test("壊れた character.json の子は読み飛ばし、ほかの子は生きる")
    func brokenJSONSkipsOnlyThatCharacter() throws {
        let store = Self.temporaryStore()
        try store.install(Art.package(id: "user-0000000a", frames: Art.single))
        try store.install(Art.package(id: "user-0000000b", frames: Art.single))
        try Data("{ これは JSON ではない".utf8).write(to: Self.jsonURL(store, "user-0000000b"))
        let shelf = store.loadAll()
        #expect(shelf.characters.map(\.id) == ["user-0000000a"])
        guard case .unreadable(let id, _) = shelf.skipped.first else {
            Issue.record("読めない理由がありません: \(shelf.skipped)")
            return
        }
        #expect(id == "user-0000000b")
        #expect(store.load(id: "user-0000000b") == nil)
        #expect(FileManager.default.fileExists(atPath: Self.folder(store, "user-0000000b").path),
                "読めないフォルダも消さない（利用者の子）")
    }

    @Test("絵が欠けた子は読み飛ばし、どの絵かを添える")
    func missingImageSkipsTheCharacter() throws {
        let store = Self.temporaryStore()
        try store.install(Art.package(id: "user-0000000a", frames: Art.single))
        try store.install(Art.package(id: "user-0000000b", frames: Art.single))
        try FileManager.default.removeItem(at: #require(store.imageURL("mini/idle_02", of: "user-0000000b")))
        #expect(store.loadAll().characters.map(\.id) == ["user-0000000a"])
        #expect(Self.failure(store, "user-0000000b")
                == .defective(id: "user-0000000b", CharacterDefect(.missingImage, "mini/idle_02")))
    }

    /// 書いている途中に落ちると、一時フォルダ（`.incoming-`）が残る。消している途中なら `.removing-`。
    @Test("書きかけ・消えかけのフォルダは読まず、片づけで消える。ほかの子は残る")
    func leftoversAreIgnoredAndCleaned() throws {
        let store = Self.temporaryStore()
        try store.install(Art.package(id: "user-0000000a", frames: Art.single))
        let source = Self.folder(store, "user-0000000a")
        try FileManager.default.copyItem(at: source, to: Self.folder(store, ".incoming-user-0000000b"))
        try FileManager.default.copyItem(at: source, to: Self.folder(store, ".removing-user-0000000c"))
        let shelf = store.loadAll()
        #expect(shelf.characters.map(\.id) == ["user-0000000a"])
        #expect(shelf.skipped.isEmpty, "書きかけ・消えかけは、読めない子にも数えない")
        store.removeLeftovers()
        #expect(Self.entries(store) == ["user-0000000a"])
        #expect(store.load(id: "user-0000000a") != nil)
    }

    @Test("character.json の無いフォルダは、見つからないとして読み飛ばす")
    func folderWithoutDefinitionIsNotFound() throws {
        let store = Self.temporaryStore()
        try store.install(Art.package(id: "user-0000000a", frames: Art.single))
        try FileManager.default.createDirectory(at: Self.folder(store, "user-0000000b").appendingPathComponent("hero"),
                                                withIntermediateDirectories: true)
        #expect(store.loadAll().characters.map(\.id) == ["user-0000000a"])
        #expect(store.loadAll().skipped == [.notFound(id: "user-0000000b")])
    }

    @Test("大きすぎる character.json は、読まずに読み飛ばす")
    func oversizedDefinitionIsNotRead() throws {
        let store = Self.temporaryStore()
        try store.install(Art.package(frames: Art.single))
        let url = Self.jsonURL(store, "user-00000001")
        // 後ろに空白を足しても、JSON としては正しい。大きさだけで断ることを見る。
        var data = try Data(contentsOf: url)
        data.append(Data(repeating: UInt8(ascii: " "), count: CharacterStore.maxFileBytes))
        try data.write(to: url)
        guard case .unreadable(let id, let reason) = Self.failure(store, "user-00000001") else {
            Issue.record("大きすぎるファイルを読んだ")
            return
        }
        #expect(id == "user-00000001")
        #expect(reason.contains("上限"))
    }

    @Test("新しい版のアプリが書いた定義は、読まずに既定のキャラに任せる")
    func futureSchemaIsNotTrusted() throws {
        let store = Self.temporaryStore()
        try store.install(Art.package(frames: Art.single))
        let url = Self.jsonURL(store, "user-00000001")
        var object = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        object["schemaVersion"] = CharacterFile.currentSchemaVersion + 1
        try JSONSerialization.data(withJSONObject: object).write(to: url)
        #expect(Self.failure(store, "user-00000001")?.defectKind == .futureSchema)
    }

    // MARK: - id の重なり

    @Test("同じ id の子を置こうとすると断り、置き換えを頼めば入れ替わる")
    func sameIDNeedsReplacing() throws {
        let store = Self.temporaryStore()
        try store.install(Art.package(name: "はじめの子", frames: Art.single))
        #expect(throws: CharacterStore.StoreError.alreadyExists(id: "user-00000001")) {
            try store.install(Art.package(name: "あとの子", frames: Art.single))
        }
        #expect(store.load(id: "user-00000001")?.character.displayName == "はじめの子")
        try store.install(Art.package(name: "あとの子", frames: Art.single), replacing: true)
        #expect(store.load(id: "user-00000001")?.character.displayName == "あとの子")
        #expect(Self.entries(store) == ["user-00000001"], "書きかけ・古いフォルダが残らない")
    }

    /// 置き換えは、フォルダごと入れ替える。古い子の絵が混ざると、どれが今の絵か分からなくなる。
    @Test("置き換えると、古い子の絵は残らない")
    func replacingLeavesNoOldPictures() throws {
        let store = Self.temporaryStore()
        try store.install(Art.package(frames: Art.tierOne))
        try store.install(Art.package(frames: Art.single), replacing: true)
        let heroes = try FileManager.default.contentsOfDirectory(atPath: Self.folder(store, "user-00000001")
            .appendingPathComponent("hero").path)
        #expect(heroes.sorted() == ["idle_01.png", "idle_02.png"])
        #expect(store.load(id: "user-00000001")?.character.frameCounts == Art.single)
    }

    /// 中の id がフォルダの名前と違う（フォルダを写した・書き換えた）と、2 つのフォルダが同じ子を名乗る。
    @Test("フォルダの名前と中の id が違う子は読まない（同じ子を 2 つのフォルダが名乗らない）")
    func folderAndIDMustMatch() throws {
        let store = Self.temporaryStore()
        try store.install(Art.package(id: "user-0000000a", frames: Art.single))
        try FileManager.default.copyItem(at: Self.folder(store, "user-0000000a"),
                                         to: Self.folder(store, "user-0000000b"))
        #expect(store.loadAll().characters.map(\.id) == ["user-0000000a"])
        #expect(Self.failure(store, "user-0000000b")
                == .defective(id: "user-0000000b", CharacterDefect(.mismatchedID, "user-0000000a")))
    }

    /// 同梱の子は `piyo` のような名前、取り込んだ子は `user-` で始まる。頭で見分けるので重ならない。
    @Test("取り込んだ子の id の形でないフォルダは読まない（同梱の子の id と重ならない）")
    func bundledIDsAreNeverRead() throws {
        let store = Self.temporaryStore()
        try store.install(Art.package(id: "user-0000000a", frames: Art.single))
        try FileManager.default.copyItem(at: Self.folder(store, "user-0000000a"), to: Self.folder(store, "piyo"))
        #expect(store.loadAll().characters.map(\.id) == ["user-0000000a"])
        #expect(Self.failure(store, "piyo") == .invalidID("piyo"))
        #expect(throws: CharacterStore.StoreError.invalidID("piyo")) { try store.remove(id: "piyo") }
    }

    @Test("新しい id は user- ＋ 16 進 8 桁で、いまいる子と重ならない")
    func newIDsAreFreshAndWellFormed() throws {
        #expect(CharacterID.makeUser(random: 0) == "user-00000000")
        #expect(CharacterID.makeUser(random: 0xDEAD_BEEF) == "user-deadbeef")
        let store = Self.temporaryStore()
        try store.install(Art.package(id: "user-00000001", frames: Art.single))
        var draws: [UInt32] = [1, 1, 2]
        let id = store.newID { draws.removeFirst() }
        #expect(id == "user-00000002", "重なった 1 を引き直す")
        #expect(CharacterID.isUser(store.newID()))
    }

    @Test("id の形: user- のあとが英小文字と数字だけ、32 字まで")
    func idShape() {
        for id in ["user-0", "user-deadbeef", "user-3f9a2c", "user-" + String(repeating: "a", count: 32)] {
            #expect(CharacterID.isUser(id), "\(id)")
        }
        for id in ["piyo", "user-", "User-abc", "user-ABC", "user-a/b", "user-..", "user-a b", "user-あ",
                   "user-" + String(repeating: "a", count: 33)] {
            #expect(!CharacterID.isUser(id), "\(id)")
        }
    }

    @Test("絵の名前: hero/idle_01 の形で、フォルダの外を指さない")
    func imageNameShape() {
        #expect(CharacterImageName.frame(.walk, 2, kind: .mini) == "mini/walk_03")
        #expect(CharacterImageName.frame(.lookUp, 0, kind: .hero) == "hero/lookUp_01")
        #expect(CharacterImageName.eyelid(.sit) == "mini/sit_eyelid")
        #expect(CharacterImageName.isValid("hero/idle_01", kind: .hero))
        #expect(!CharacterImageName.isValid("hero/idle_01", kind: .mini), "頭のフォルダが違う")
        for name in ["hero/", "hero/../x", "hero/a/b", "hero/idle-01", "/hero/idle_01", "hero/idle_01.png"] {
            #expect(!CharacterImageName.isValid(name, kind: .hero), "\(name)")
        }
    }

    // MARK: - 10 体まで

    @Test("取り込めるのは 10 体まで。どれかを消すと、新しい子を連れてこられる")
    func capacityIsTen() throws {
        let store = Self.temporaryStore()
        for index in 1...CharacterStore.capacity {
            try store.install(Art.package(id: CharacterID.makeUser(random: UInt32(index)), frames: Art.single))
        }
        let eleventh = Art.package(id: "user-000000ff", frames: Art.single)
        #expect(throws: CharacterStore.StoreError.full(capacity: 10)) { try store.install(eleventh) }
        // 置き換えは数を増やさない。
        try store.install(Art.package(id: "user-00000003", name: "描き直した子", frames: Art.single), replacing: true)
        try store.remove(id: "user-00000001")
        try store.install(eleventh)
        #expect(store.loadAll().files.count == 10)
    }

    @Test("一覧は連れてきた順")
    func shelfIsInArrivalOrder() throws {
        let store = Self.temporaryStore()
        let day: TimeInterval = 86_400
        try store.install(Art.package(id: "user-0000000c", frames: Art.single, createdAt: Art.createdAt + day * 2))
        try store.install(Art.package(id: "user-0000000a", frames: Art.single, createdAt: Art.createdAt))
        try store.install(Art.package(id: "user-0000000b", frames: Art.single, createdAt: Art.createdAt + day))
        #expect(store.loadAll().characters.map(\.id) == ["user-0000000a", "user-0000000b", "user-0000000c"])
    }

    // MARK: - 消す

    @Test("消すと一覧から消え、読めなくなる。消えかけのフォルダも残らない")
    func removeDeletesTheFolder() throws {
        let store = Self.temporaryStore()
        try store.install(Art.package(id: "user-0000000a", frames: Art.single))
        try store.install(Art.package(id: "user-0000000b", frames: Art.single))
        try store.remove(id: "user-0000000a")
        #expect(store.load(id: "user-0000000a") == nil)
        #expect(store.loadAll().characters.map(\.id) == ["user-0000000b"])
        #expect(Self.entries(store) == ["user-0000000b"])
    }

    @Test("いない子を消そうとすると、見つからないとして断る")
    func removingAMissingCharacterFails() {
        let store = Self.temporaryStore()
        #expect(throws: CharacterStore.StoreError.notFound(id: "user-00000009")) {
            try store.remove(id: "user-00000009")
        }
    }

    // MARK: - App Group が無い

    @Test("置き場が無いときは、読みは空か nil で、書きは App Group を添えて断る")
    func noContainer() {
        let store = CharacterStore(directory: nil)
        let noContainer = CharacterStore.StoreError.noContainer(appGroup: AppGroup.identifier)
        #expect(store.loadAll() == CharacterShelf())
        #expect(store.load(id: "user-00000001") == nil)
        #expect(Self.failure(store, "user-00000001") == noContainer)
        #expect(store.image("hero/idle_01", of: "user-00000001", maxPixelSize: 810) == nil)
        #expect(throws: noContainer) { try store.install(Art.package()) }
        #expect(throws: noContainer) { try store.remove(id: "user-00000001") }
        store.removeLeftovers()                                  // 片づけも落ちない
        #expect(CharacterID.isUser(store.newID()))
    }

    @Test("まだ 1 体も連れてきていない（フォルダが無い）ときは、空の一覧")
    func emptyStore() {
        let store = Self.temporaryStore()
        #expect(store.loadAll() == CharacterShelf())
        #expect(Self.failure(store, "user-00000001") == .notFound(id: "user-00000001"))
    }

    // MARK: - 書く側は厳しく（読む側が頼れるフォルダだけを置く）

    /// 形に問題のある包み 1 つと、断る理由の種類。
    struct DefectCase: Sendable, CustomTestStringConvertible {
        let label: String
        let package: CharacterPackage
        let kind: CharacterDefect.Kind

        var testDescription: String { label }
    }

    static func tampered(_ label: String, _ kind: CharacterDefect.Kind,
                         _ change: (inout CTCore.Character) -> Void) -> DefectCase {
        DefectCase(label: label, package: Art.altered(Art.package(), change), kind: kind)
    }

    static func reimaged(_ label: String, _ kind: CharacterDefect.Kind,
                         _ change: ([String: CGImage]) -> [String: CGImage]) -> DefectCase {
        let package = Art.package()
        return DefectCase(label: label, package: CharacterPackage(file: package.file, images: change(package.images)),
                          kind: kind)
    }

    static let defects: [DefectCase] = [
        tampered("取り込みの id でない", .invalidID) { $0.id = "piyo" },
        tampered("同梱のキャラ", .notImported) { $0.origin = .bundled },
        tampered("立ち姿が無い", .missingIdle) { $0.poses[.idle] = []; $0.miniPoses[.idle] = [] },
        tampered("体格が壊れている", .invalidScale) { $0.scale = .nan },
        tampered("mini の枚数が違う", .miniMismatch) { $0.miniPoses[.walk]?.removeLast() },
        tampered("まばたきの絵の無い姿勢のまぶた", .eyelidWithoutBlink) { $0.eyelids[.lookUp] = "mini/idle_eyelid" },
        tampered("フォルダの外を指す名前", .invalidImageName) { $0.poses[.walk]?[0] = "../walk_01" },
        tampered("hero に mini の名前", .invalidImageName) { $0.poses[.walk]?[0] = "mini/walk_01" },
        tampered("コマが多すぎる", .tooManyFrames) {
            $0.poses[.walk] = (0..<9).map { "hero/walk_\($0)" }
            $0.miniPoses[.walk] = (0..<9).map { "mini/walk_\($0)" }
        },
        reimaged("呼ぶ絵が無い", .missingImage) { $0.filter { $0.key != "hero/sit_02" } },
        reimaged("使われない絵がある", .unusedImage) { $0.merging(["hero/extra": Art.hero]) { $1 } },
        reimaged("絵の大きさが枠と違う", .wrongImageSize) { $0.merging(["mini/idle_01": Art.hero]) { $1 } },
    ]

    @Test("形に問題のある子は置かず、何がどこで違うかを添えて断る。書きかけも残さない", arguments: defects)
    func defectiveCharactersAreRefused(_ defect: DefectCase) throws {
        let store = Self.temporaryStore()
        do {
            try store.install(defect.package)
            Issue.record("\(defect.label): 置けてしまった")
        } catch let error as CharacterStore.StoreError {
            #expect(error.defectKind == defect.kind, "\(defect.label): \(error)")
        }
        #expect(Self.entries(store).isEmpty, "\(defect.label): 何も置かない")
    }

    /// 書けないときは、どのキャラのどのファイルかを添える（利用者に理由を見せ、黙って捨てない）。
    @Test("書けなかったら、どのファイルかを添えて断り、書きかけを残さない")
    func writeFailureNamesTheFile() throws {
        let store = Self.temporaryStore()
        try store.install(Art.package(id: "user-0000000a", frames: Art.single))
        let root = try #require(store.folderURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: root.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.path) }
        do {
            try store.install(Art.package(id: "user-0000000b", frames: Art.single))
            Issue.record("読み取り専用の置き場に書けてしまった")
        } catch CharacterStore.StoreError.writeFailed(let id, let name, let reason) {
            #expect(id == "user-0000000b")
            #expect(name == "hero")
            #expect(!reason.isEmpty)
        }
        #expect(Self.entries(store) == ["user-0000000a"])
    }
}

extension CharacterStore.StoreError {
    /// 形の問題なら、その種類。
    var defectKind: CharacterDefect.Kind? {
        if case .defective(_, let defect) = self { return defect.kind }
        return nil
    }
}
