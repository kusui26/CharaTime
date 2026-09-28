import Foundation

/// キャラを作るプロンプトを組み立てる（プラン §9 Phase 2 の 2-C ④、D-37、`docs/260926_prompt_templates.md` §1.3・§4）。
///
/// 本文は 5 つの部品を上からつないだもの: （参照の 1 行）→ ① 段の指示 → ② キャラカード → ③ 画風 → ④ 取り込みの
/// 条件 → ⑤ 背景の 1 行。**④⑤ とコマの数・並びは変えさせない**（取り込みのコマの割り当てと知らせが頼る）。
/// サービスで違うのは ⑤ だけ。2-6 でキャラ工房に載せたら、この型を正本にする（テンプレートの §4.5）。
public enum PromptTemplate {

    /// 手引きの版。取り込んだキャラの記録（`ImportRecord.guideVersion`）に残す（テンプレートの §4.5）。
    public static let version = "v2"

    /// 絵を作るサービス。背景の 1 行だけが変わる（テンプレートの §4.2）。
    public enum Service: String, Sendable, CaseIterable {
        /// 透明の背景で作れる（おすすめ）。
        case chatGPT
        /// 透明を出せないので、白い地（白いキャラは緑の地）で作る。
        case gemini
    }

    /// 腕か羽か（段の指示の言い回し。ピヨは羽。テンプレートの A-7）。
    public enum Limbs: String, Sendable, CaseIterable {
        case arms, wings
    }

    /// プロンプトの全文。`reference` は参照の 1 行を付けるか（ポーズ・歩くの段で、シートの絵を添えるとき）。
    /// 1 枚の絵（`single`）には段の指示が無いので nil。
    public static func prompt(_ layout: SheetLayout, card: CharacterCard, service: Service,
                              limbs: Limbs = .arms, reference: Bool) -> String? {
        guard let stage = stageText(layout, limbs: limbs) else { return nil }
        let background = backgroundLine(service, mainColorHex: card.mainColorHex)
        let parts = (reference ? [referenceLine] : []) + [stage, card.text, style, rules, background]
        return parts.joined(separator: "\n\n")
    }

    /// 参照の 1 行（ポーズ・歩く・直しの段で、先頭に付ける）。
    public static let referenceLine = "Image 1 is the reference sheet of this character. "
        + "Keep the design exactly the same: shapes, colors, face and proportions. Do not redesign it."

    /// ③ 画風（変えてよい。既定はこのまま）。
    public static let style = [
        "Style: cute, simple mascot art. "
            + "About two heads tall, big round head, short rounded limbs, no fingers.",
        "Thick, even dark-brown outline around every shape. Flat colors with at most one soft shade. "
            + "No gradients, no texture, no glow.",
    ].joined(separator: "\n")

    /// ④ 取り込みの条件（**変えない**。アプリが頼る約束）。
    public static let rules = [
        "Rules: every drawing is full body and the same size; "
            + "in each row, all drawings rest on the same ground line.",
        "Keep every pose compact: arms stay close to the body or point up, never spread out to the sides, "
            + "and no pose is wider than the standing pose.",
        "Leave wide empty space around every drawing; "
            + "nothing touches another drawing or the edge of the image.",
        "No shadows at all (not even under the feet). No text, letters, numbers or labels. "
            + "No grid lines, dividers, frames or borders. No watermark or signature.",
    ].joined(separator: "\n")
}

// MARK: - ① 段の指示と ⑤ 背景の 1 行

extension PromptTemplate {

    /// ① 段の指示。コマの数と並びは `SheetLayout.slots` と同じ順に頼む。
    public static func stageText(_ layout: SheetLayout, limbs: Limbs) -> String? {
        let limb = limbs.rawValue
        switch layout {
        case .single: return nil
        case .sheet: return sheetText
        case .poses6: return poses6Text(limb)
        case .poses4A: return poses4AText(limb)
        case .poses4B: return poses4BText(limb)
        case .walk: return walkText(limb)
        }
    }

    static let sheetText = """
        Make a character reference sheet of this character. Square image (1:1).
        Three full-body views side by side, left to right: FRONT, SIDE (facing left), BACK.
        """

    static func poses6Text(_ limb: String) -> String {
        """
        Make ONE square image (1:1) with exactly 6 poses of this character in 2 rows x 3 columns:
        Row 1: (1) standing, front view, \(limb) at the sides, eyes open. \
        (2) sitting on the floor, front view, feet forward, eyes open. \
        (3) asleep, curled up in a round ball on its belly, side view facing left, eyes closed.
        Row 2: (4) happy, eyes closed in a big smile, both \(limb) raised straight up beside the head, \
        feet on the ground. (5) happy, eyes closed in a big smile, \(limb) bent up next to the cheeks, \
        feet on the ground. (6) standing, front view, looking up.
        """
    }

    static func poses4AText(_ limb: String) -> String {
        """
        Make ONE portrait image (3:4) with exactly 4 poses of this character in 2 rows x 2 columns:
        (1) standing, front view, \(limb) at the sides, eyes open. \
        (2) sitting on the floor, front view, feet forward, eyes open.
        (3) asleep, curled up in a round ball on its belly, side view facing left, eyes closed. \
        (4) happy, eyes closed in a big smile, both \(limb) raised straight up beside the head, \
        feet on the ground.
        """
    }

    static func poses4BText(_ limb: String) -> String {
        """
        Make ONE portrait image (3:4) with exactly 4 poses of this character in 2 rows x 2 columns:
        (1) standing, front view, \(limb) at the sides, eyes open (the same as the FRONT view in Image 1). \
        (2) happy, eyes closed in a big smile, \(limb) bent up next to the cheeks, feet on the ground.
        (3) standing, front view, looking up. \
        (4) surprised, front view, eyes wide open, \(limb) slightly raised.
        """
    }

    static func walkText(_ limb: String) -> String {
        """
        Make ONE portrait image (3:4) with exactly 4 walking frames of this character in 2 rows x 2 columns. \
        Side view facing LEFT in every frame.
        (1) front foot forward, back foot back. (2) feet together under the body. \
        (3) the other foot forward. (4) feet together under the body.
        Only the feet and \(limb) move. \
        The head and body keep the same size and the same height in all 4 frames.
        """
    }

    /// からだの色がこれより明るければ、Gemini の地を緑にする 🔷（白・クリーム・ごく淡いピンク。テンプレートの §4.2）。
    public static let lightBodyLuminance = 0.9

    /// ⑤ 背景の 1 行。
    public static func backgroundLine(_ service: Service, mainColorHex: String?) -> String {
        switch service {
        case .chatGPT:
            return "Background: fully transparent (real alpha, PNG). "
                + "No background color, no checkerboard, no floor."
        case .gemini where (mainColorHex.flatMap(Self.luminance) ?? 0) > lightBodyLuminance:
            return "Background: solid pure green #00FF00 everywhere. No gradient, no texture, no floor. "
                + "Do not use any green on the character."
        case .gemini:
            return "Background: solid pure white #FFFFFF everywhere. No gradient, no texture, no floor."
        }
    }

    /// `#RRGGBB` の明るさ（Rec. 709 の係数。0〜1）。読めなければ nil。
    static func luminance(ofHex hex: String) -> Double? {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        let channels = [16, 8, 0].map { Double((value >> UInt32($0)) & 0xFF) / 255 }
        return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
    }
}
