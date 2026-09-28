import Testing
import Foundation
@testable import CTStudio

/// プロンプトの組み立て（プラン §9 Phase 2 の 2-C ④、D-37）。**組み上げた文が、テンプレートの版と 1 文字も違わないか**を、
/// テンプレートの文書（`docs/260926_prompt_templates.md`）の本文と比べて守る。
@Suite("プロンプトの組み立て")
struct PromptTemplateTests {

    /// テンプレートの文書（このファイルから 6 つ上がリポジトリの根）。
    static let document: String = {
        let root = (0..<6).reduce(URL(fileURLWithPath: #filePath)) { url, _ in url.deletingLastPathComponent() }
        return (try? String(contentsOf: root.appending(path: "docs/260926_prompt_templates.md"), encoding: .utf8)) ?? ""
    }()

    /// 見出しのあとに最初に出てくる ```text の中身。
    static func block(after heading: String) -> String? {
        guard let title = document.range(of: heading),
              let open = document.range(of: "```text\n", range: title.upperBound..<document.endIndex),
              let close = document.range(of: "\n```", range: open.upperBound..<document.endIndex) else { return nil }
        return String(document[open.upperBound..<close.lowerBound])
    }

    /// テンプレートのピヨのキャラカード（フェーズ A・B）。
    static let piyo = CharacterCard(
        name: "Piyo", what: "a round chick-like creature",
        colors: "body soft yellow #FFE066, wings a slightly deeper yellow #FFCF4D, beak and feet orange #FF9F43, "
            + "cheeks pink #FFB3C6",
        features: "one small curved crest feather on top of the head; two small black dot eyes with a tiny white "
            + "highlight; a small triangle beak; small rounded wings; short orange feet",
        mainColorHex: "#FFE066")

    @Test("ピヨのポーズ 6 コマ（羽）は、テンプレートの A-7 と 1 文字も違わない")
    func poses6MatchesTheTrialPrompt() throws {
        let expected = try #require(Self.block(after: "**A-7 ポーズ 6 コマ（v2）**"))
        #expect(PromptTemplate.prompt(.poses6, card: Self.piyo, service: .chatGPT, limbs: .wings,
                                      reference: true) == expected)
    }

    @Test("既定の 5 体のプロンプト（ピヨの B-2a・B-2b・B-3）も、同じ部品から組み上がる")
    func defaultCharacterPromptsMatch() throws {
        let stages: [(String, SheetLayout)] = [("**B-2a ポーズ 4 コマ（1 枚目）**", .poses4A),
                                               ("**B-2b ポーズ 4 コマ（2 枚目）**", .poses4B),
                                               ("**B-3 歩く 4 コマ**", .walk)]
        for (heading, layout) in stages {
            let expected = try #require(Self.block(after: heading), "\(heading)")
            #expect(PromptTemplate.prompt(layout, card: Self.piyo, service: .chatGPT, limbs: .wings,
                                          reference: true) == expected, "\(heading)")
        }
    }

    @Test("サービスで違うのは、背景の 1 行（最後の行）だけ")
    func servicesDifferOnlyInTheBackgroundLine() throws {
        for layout in SheetLayout.allCases where layout != .single {
            let transparent = try #require(PromptTemplate.prompt(layout, card: Self.piyo, service: .chatGPT,
                                                                 reference: false)).components(separatedBy: "\n")
            let white = try #require(PromptTemplate.prompt(layout, card: Self.piyo, service: .gemini,
                                                           reference: false)).components(separatedBy: "\n")
            #expect(transparent.dropLast() == white.dropLast(), "\(layout)")
            #expect(transparent.last != white.last, "\(layout)")
        }
    }

    @Test("どの段にも、取り込みの条件（変えない行）と、コマの数・並びが入る")
    func everyStageCarriesTheRulesAndTheCount() throws {
        for layout in SheetLayout.allCases where layout != .single {
            let prompt = try #require(PromptTemplate.prompt(layout, card: Self.piyo, service: .chatGPT,
                                                            reference: true))
            #expect(prompt.contains(PromptTemplate.rules), "\(layout)")
            #expect(prompt.contains(layout == .sheet ? "Three full-body views" : "exactly \(layout.expectedCount)"),
                    "\(layout)")
            let numbered = (1...layout.expectedCount).map { "(\($0))" }
            let positions = numbered.compactMap { prompt.range(of: $0)?.lowerBound }
            #expect(layout == .sheet || (positions.count == numbered.count && positions == positions.sorted()),
                    "\(layout)")
        }
        #expect(PromptTemplate.prompt(.single, card: Self.piyo, service: .chatGPT, reference: false) == nil)
    }

    @Test("利用者の入力からキャラカードを組み立てる。任意の欄は、空なら入れない（テンプレートの §4.1）")
    func userCardFromInputs() {
        let full = CharacterCard.user(name: "ピヨ", creature: "ひよこ", main: NamedColor(name: "yellow", hex: "#FFE066"),
                                      second: NamedColor(name: "orange", hex: "#FF9F43"), feature: "頭に 1 本の羽")
        #expect(full.text == """
            Character: "ピヨ", a cute round creature based on: ひよこ. An original character, not based on any existing \
            character or brand.
            Colors: main color yellow #FFE066, second color orange #FF9F43 for small parts. Outline: dark brown #3B2B2B.
            Keep these features exactly: 頭に 1 本の羽; two small black dot eyes with a tiny white highlight; small \
            rounded arms and feet.
            """)
        let bare = CharacterCard.user(name: "モチ", creature: "ねこ", main: NamedColor(name: "white", hex: "#FFF6EE"),
                                      feature: "  ")
        #expect(bare.colors == "main color white #FFF6EE")
        #expect(bare.features == CharacterCard.defaultFeatures)
    }

    @Test("Gemini の地は、からだの色がごく淡ければ緑、そうでなければ白")
    func geminiGroundFollowsTheBodyColor() {
        #expect(PromptTemplate.backgroundLine(.gemini, mainColorHex: "#FFF6EE").contains("#00FF00"))
        #expect(PromptTemplate.backgroundLine(.gemini, mainColorHex: "#FFE066").contains("#FFFFFF"))
        #expect(PromptTemplate.backgroundLine(.gemini, mainColorHex: "わからない").contains("#FFFFFF"))
        #expect(PromptTemplate.backgroundLine(.chatGPT, mainColorHex: "#FFF6EE").contains("transparent"))
    }

    @Test("知らせごとの直し（テンプレートの §4.4）。F-COUNT には、その段のコマの数と並びが入る")
    func noticesMapToFixes() {
        #expect(ImportNotice(.figuresTouching).remedy == .fix(.space))
        #expect(ImportNotice(.widePose).remedy == .fix(.compact))
        #expect(ImportNotice(.eyesNotFound).remedy == .fix(.eyes))
        #expect(ImportNotice(.blurryOnWidget).remedy == .sharperPoses)
        #expect(ImportNotice(.walkingRight).remedy == nil)
        #expect(FixPrompt.count.text(for: .poses6).hasPrefix("There must be exactly 6 drawings in 2 rows x 3 columns"))
        for fix in FixPrompt.allCases {
            #expect(Self.document.contains(fix.text(for: .poses6)) || fix == .count, "\(fix.rawValue)")
        }
    }
}
