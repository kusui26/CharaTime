import Testing
import Foundation
import CTStudio
@testable import CharaBake

/// 生の絵の名前から割り方を決める（テンプレート §3.1 の raw/ の名前）。
@Suite("生の絵の名前")
struct RawNamingTests {

    static func files(_ names: [String]) -> [URL] {
        names.map { URL(fileURLWithPath: "/raw/\($0)") }
    }

    @Test("名前の頭で割り方が決まる。作り直しの番号と大文字は気にしない")
    func layoutFollowsThePrefix() {
        let cases: [(String, SheetLayout?)] = [
            ("poses-a.png", .poses4A), ("poses-b_2.png", .poses4B), ("walk-v3.PNG", .walk),
            ("Sheet_3.png", .sheet), ("poses6.png", .poses6), ("single.jpg", .single), ("ChatGPT Image.png", nil),
        ]
        for (name, layout) in cases {
            #expect(RawNaming.layout(of: URL(fileURLWithPath: "/raw/\(name)")) == layout, "\(name)")
        }
    }

    @Test("立ち姿のある絵があれば、キャラシート（参照の絵）は使わない。割り方の順に並ぶ")
    func sheetIsOnlyTheReferenceWhenPosesExist() throws {
        let inputs = try RawNaming.inputs(Self.files(["walk.png", "sheet_1.png", "sheet_2.png", "poses-b.png",
                                                      "poses-a.png"]))
        #expect(inputs.map(\.layout) == [.poses4A, .poses4B, .walk])
        let tierZero = try RawNaming.inputs(Self.files(["sheet_3.png", "walk.png"]))
        #expect(tierZero.map(\.layout) == [.sheet, .walk])
    }

    @Test("同じ割り方の絵が 2 枚あれば、どれを使うか決めてもらう。名前が決まりに合わなければ断る")
    func ambiguousOrUnknownNamesAreRejected() {
        #expect(throws: BakeError.duplicateLayout(.poses4A, ["poses-a_1.png", "poses-a_2.png"])) {
            _ = try RawNaming.inputs(Self.files(["poses-a_2.png", "poses-a_1.png", "walk.png"]))
        }
        #expect(throws: BakeError.unknownRawName("ChatGPT Image.png")) {
            _ = try RawNaming.inputs(Self.files(["poses-a.png", "ChatGPT Image.png"]))
        }
    }

    @Test("フォルダの中の絵だけを、名前の順に拾う")
    func imagesInFolderAreSortedImageFiles() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "raw-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for name in ["walk.png", "notes.txt", "poses-a.JPG", ".DS_Store", "poses-b.webp"] {
            try Data().write(to: folder.appending(path: name))
        }
        #expect(RawNaming.images(in: folder).map(\.lastPathComponent) == ["poses-a.JPG", "poses-b.webp", "walk.png"])
        #expect(RawNaming.images(in: folder.appending(path: "無い")).isEmpty)
    }
}

/// chara-bake の引数。
@Suite("道具の引数")
struct BakeCommandTests {

    @Test("整える・見本・コンタクトシート・使い方を読み分ける")
    func actionsAreParsed() throws {
        #expect(try BakeCommand.parse(["piyo"]).action == .bake(id: "piyo", files: []))
        #expect(try BakeCommand.parse(["piyo", "raw/poses-a.png", "raw/walk.png"]).action
                == .bake(id: "piyo", files: ["raw/poses-a.png", "raw/walk.png"]))
        #expect(try BakeCommand.parse(["sample", "chip", "/tmp/raw"]).action == .sample(id: "chip", folder: "/tmp/raw"))
        #expect(try BakeCommand.parse(["contact-sheet"]).action == .contactSheet)
        #expect(try BakeCommand.parse(["piyo", "--help"]).action == .help)
    }

    @Test("オプション（場所・サービス・倍率）を読む")
    func optionsAreParsed() throws {
        let command = try BakeCommand.parse(["--root", "/repo", "piyo", "--service", "gemini", "--out", "/tmp/out",
                                             "--scale", "0.5"])
        #expect(command.root == "/repo" && command.output == "/tmp/out")
        #expect(command.service == .gemini && command.scale == 0.5)
        #expect(try BakeCommand.parse(["piyo"]).service == .chatGPT)
    }

    @Test("知らないオプションは、値の有無より先に、知らないと知らせる")
    func unknownOptionIsNamedFirst() {
        #expect(throws: BakeError.usage("--bogus は知らないオプションです")) { _ = try BakeCommand.parse(["--bogus"]) }
        #expect(throws: BakeError.usage("--root のあとに値がありません")) { _ = try BakeCommand.parse(["piyo", "--root"]) }
    }

    @Test("足りない・知らない引数は、何が違うかを添えて断る")
    func mistakesAreExplained() {
        let mistakes: [[String]] = [
            [], ["sample", "piyo"], ["contact-sheet", "piyo"], ["piyo", "--root"],
            ["piyo", "--service", "midjourney"], ["piyo", "--scale", "-1"], ["piyo", "--fast", "1"],
        ]
        for arguments in mistakes {
            #expect(throws: BakeError.self, "\(arguments)") { _ = try BakeCommand.parse(arguments) }
        }
    }
}

/// chara-bake の入口（引数から、知らせと終了コードまで）。
@Suite("道具の入口")
struct CharaBakeMainTests {

    @Test("知らない id は、raw/ を探す前に、同梱の id を添えて断る（終了コード 1）")
    func unknownCharacterIsReportedBeforeLookingForRawImages() async {
        let output = FileManager.default.temporaryDirectory.appending(path: "chara-bake-\(UUID().uuidString)")
        let status = await CharaBakeMain.run(["nobody", "--root", CharacterBakeTests.root.path(percentEncoded: false),
                                              "--out", output.path(percentEncoded: false)],
                                             currentDirectory: output)
        #expect(status == 1)
    }

    @Test("引数の誤りは終了コード 2、使い方は 0")
    func usageErrorsExitWithTwo() async {
        let here = FileManager.default.temporaryDirectory
        #expect(await CharaBakeMain.run(["--bogus"], currentDirectory: here) == 2)
        #expect(await CharaBakeMain.run(["--help"], currentDirectory: here) == 0)
    }
}
