import Foundation

/// ② キャラカード（名前・何の生き物か・色・守る特徴。**毎回そのまま貼る**。テンプレートの §1.3）。
public struct CharacterCard: Sendable, Equatable {

    /// `{NAME}`（日本語のままでよい）。
    public var name: String
    /// `{WHAT}`（例: a round chick-like creature）。
    public var what: String
    /// `{COLORS}`（例: body soft yellow #FFE066, …）。
    public var colors: String
    /// `{FEATURES}`（「;」でつないだ守る特徴）。
    public var features: String
    /// からだの色（Gemini の地を白にするか緑にするかに使う）。
    public var mainColorHex: String?

    public init(name: String, what: String, colors: String, features: String, mainColorHex: String? = nil) {
        self.name = name
        self.what = what
        self.colors = colors
        self.features = features
        self.mainColorHex = mainColorHex
    }

    /// 本文の ② の 3 行。
    public var text: String {
        [
            "Character: \"\(name)\", \(what). "
                + "An original character, not based on any existing character or brand.",
            "Colors: \(colors). Outline: dark brown #3B2B2B.",
            "Keep these features exactly: \(features).",
        ].joined(separator: "\n")
    }
}

/// 名前の付いた色（色の名前はアプリが HEX から付ける。テンプレートの §4.1）。
public struct NamedColor: Sendable, Equatable {
    public var name: String
    public var hex: String

    public init(name: String, hex: String) {
        self.name = name
        self.hex = hex
    }
}

extension CharacterCard {

    /// 目と手足の既定。**目を小さな点にしておくと、まばたきをアプリが作れる**（2-C ⑤-6。ほかの目にすると、
    /// 目が見つからないことがある）。
    public static let defaultFeatures = "two small black dot eyes with a tiny white highlight; "
        + "small rounded arms and feet"

    /// 利用者の入力から組み立てる（キャラ工房。テンプレートの §4.1）。任意の欄は、空なら入れない。
    public static func user(name: String, creature: String, main: NamedColor, second: NamedColor? = nil,
                            feature: String = "") -> CharacterCard {
        let colors = "main color \(main.name) \(main.hex)"
            + (second.map { ", second color \($0.name) \($0.hex) for small parts" } ?? "")
        let trimmed = feature.trimmingCharacters(in: .whitespacesAndNewlines)
        let features = trimmed.isEmpty ? defaultFeatures : "\(trimmed); \(defaultFeatures)"
        return CharacterCard(name: name, what: "a cute round creature based on: \(creature)", colors: colors,
                             features: features, mainColorHex: main.hex)
    }
}
