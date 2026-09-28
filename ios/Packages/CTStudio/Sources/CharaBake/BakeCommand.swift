import Foundation
import CTStudio

/// chara-bake の引数（リポジトリの根で `swift run --package-path ios/Packages/CTStudio chara-bake …`）。
public struct BakeCommand: Equatable, Sendable {

    public enum Action: Equatable, Sendable {
        /// 生の絵を整えて `final/` に書く（絵を省くと `raw/` の絵を使う）。
        case bake(id: String, files: [String])
        /// いまの絵を手引きの格子に並べた見本を書く。
        case sample(id: String, folder: String)
        /// 全キャラ × 全コマのコンタクトシートを書く。
        case contactSheet
        case help
    }

    public var action: Action
    /// リポジトリの根（無ければ今いる所）。
    public var root: String?
    /// 書く所（`final/` と `.shots/bake/`）の根。無ければリポジトリの根。試すときにリポジトリを書き換えないため。
    public var output: String?
    public var service: PromptTemplate.Service = .chatGPT
    /// 見本の、いまの絵に対する倍率。
    public var scale = SampleSheets.realisticScale

    public static let usage = """
        使い方（リポジトリの根で。swift run --package-path ios/Packages/CTStudio chara-bake …）:
          chara-bake <id> [生の絵…]      生の絵を整えて assets-src/characters/<id>/final/ に書く
                                        絵を省くと raw/ の絵を使う。名前は poses-a・poses-b・walk（B-2a・B-2b・B-3）で
                                        始める（作り直しは poses-a_2.png のように）。そろわなければ final/ に書かない
          chara-bake sample <id> <フォルダ>   いまの絵を手引きの格子に並べた見本を書く（道具の確かめ）
          chara-bake contact-sheet       全キャラ × 全コマのコンタクトシートを .shots/bake/ に書く
        オプション:
          --root <フォルダ>             リポジトリの根（既定は今いる所）
          --out <フォルダ>              書く所（final/ と .shots/bake/）の根（既定は --root。試すときに）
          --service chatgpt|gemini    絵を作ったサービス（既定 chatgpt。背景の知らせに使う）
          --scale <倍率>               見本の、いまの絵に対する倍率（既定 0.68。生成 AI の絵に近い大きさ）
        """

    /// 引数を読む。分からなければ、何が違うかを添えて断る。
    public static func parse(_ arguments: [String]) throws(BakeError) -> BakeCommand {
        var command = BakeCommand(action: .help)
        var positional: [String] = []
        var remaining = arguments[...]
        while let argument = remaining.popFirst() {
            if argument == "-h" || argument == "--help" { return BakeCommand(action: .help) }
            if argument.hasPrefix("--") {
                try command.apply(option: argument, value: remaining.popFirst())
            } else {
                positional.append(argument)
            }
        }
        command.action = try action(positional)
        return command
    }

    /// 値を取るオプション。
    static let options: Set<String> = ["--root", "--out", "--service", "--scale"]

    mutating func apply(option: String, value: String?) throws(BakeError) {
        guard Self.options.contains(option) else { throw .usage("\(option) は知らないオプションです") }
        guard let value else { throw .usage("\(option) のあとに値がありません") }
        switch option {
        case "--root": root = value
        case "--out": output = value
        case "--service": service = try Self.service(value)
        default: scale = try Self.scale(value)
        }
    }

    static func service(_ value: String) throws(BakeError) -> PromptTemplate.Service {
        let services = PromptTemplate.Service.allCases
        guard let chosen = services.first(where: { $0.rawValue.lowercased() == value }) else {
            throw .usage("--service は chatgpt か gemini です（\(value)）")
        }
        return chosen
    }

    static func scale(_ value: String) throws(BakeError) -> Double {
        guard let number = Double(value), number > 0 else { throw .usage("--scale は正の数です（\(value)）") }
        return number
    }

    static func action(_ positional: [String]) throws(BakeError) -> Action {
        switch positional.first {
        case nil: throw .usage("キャラの id か、sample・contact-sheet を指定してください")
        case "contact-sheet":
            guard positional.count == 1 else { throw .usage("contact-sheet に続けて書くものはありません") }
            return .contactSheet
        case "sample":
            guard positional.count == 3 else { throw .usage("sample <id> <フォルダ> の形で指定してください") }
            return .sample(id: positional[1], folder: positional[2])
        case .some(let id):
            return .bake(id: id, files: Array(positional.dropFirst()))
        }
    }
}
