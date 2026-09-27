import Foundation
import CTCore

// 取り込んだキャラのフォルダの決まり（プラン §9 Phase 2 の 2-C ③⑪）。id・絵の名前・絵の大きさ・形の検査。
// 置くとき（`CharacterStore.install`）も読むとき（`CharacterStore.read`）も、ここの決まりで確かめる。

/// 取り込んだキャラの id。`user-` ＋ 16 進 8 桁の乱数。
///
/// **取り込んだときに 1 回だけ決めて保存する**（`AppState.userSeed` と同じ扱い）。以後の姿は、この id から
/// 決定論で引く（日課の種は id を含む。§5.4）。同梱のキャラ（`piyo` など）とは頭の `user-` で見分けるので、
/// 重ならない。フォルダの名前にも使うので、英小文字と数字だけにする。
public enum CharacterID {

    public static let userPrefix = "user-"
    /// 乱数の桁数（16 進）。取り込めるのは 10 体まで（Q-19）なので、8 桁（約 43 億通り）なら重なる見込みは
    /// 無いに等しい。引っ越し（2-8）で別の端末の子を迎えるときも同じ。
    static let randomDigits = 8
    /// `user-` のあとの長さの上限。引っ越しで迎える子の id も、この形なら受ける。
    static let maxSuffixLength = 32

    /// 新しい id。**乱数を使うのは、ここと `AppState.makeInitial` の種だけ**（CLAUDE.md §2）。
    public static func makeUser(random: UInt32 = .random(in: .min ... .max)) -> String {
        let digits = String(random, radix: 16)
        return userPrefix + String(repeating: "0", count: randomDigits - digits.count) + digits
    }

    /// 取り込んだキャラの id の形か。`user-` のあとが英小文字と数字だけ（フォルダの外を指させない）。
    public static func isUser(_ id: String) -> Bool {
        guard id.hasPrefix(userPrefix) else { return false }
        let suffix = id.dropFirst(userPrefix.count)
        return (1...maxSuffixLength).contains(suffix.count)
            && suffix.allSatisfy { $0.isASCII && ($0.isLowercase || $0.isNumber) }
    }
}

/// 取り込んだキャラの絵の種類。待受用（hero）とウィジェット用（mini）で、フォルダを分ける。
public enum CharacterImageKind: String, Sendable, CaseIterable {
    case hero, mini

    /// 絵の大きさ（@3x の画素）。**同梱の絵と同じ枠**（`tools/pipeline/pipeline.py` が焼く大きさ。D-34）。
    /// 取り込んだキャラは @3x だけを持つ（@2x の機種では OS が縮めて描く。2-C ③）。
    public var pixelSize: PixelSize {
        switch self {
        // 枠 130:180 を 1.5 倍（195×270pt）にして @3x。待受モードで、ほぼ等倍に描かれる。
        case .hero: PixelSize(width: 585, height: 810)
        // 枠を 0.7 倍（91×126pt）にして @3x。ウィジェットでいちばん大きく描く絵に合わせた（D-20・D-26）。
        case .mini: PixelSize(width: 273, height: 378)
        }
    }
}

/// 取り込んだキャラの絵の名前。フォルダの中の相対パス（拡張子なし）で、`hero/idle_01` の形。
///
/// `Character.poses` は hero の名前だけ、`miniPoses` と `eyelids` は mini の名前だけを持つ
/// （ウィジェットが誤って大きな絵を読まない）。コマの番号は 1 から 2 桁（同梱の絵と同じ）。
public enum CharacterImageName {

    /// 名前の長さの上限（頭のフォルダを除く）。
    static let maxStemLength = 48

    /// その姿勢の `index` 番目（0 から）のコマ。
    public static func frame(_ pose: Pose, _ index: Int, kind: CharacterImageKind) -> String {
        "\(kind.rawValue)/\(pose.rawValue)_" + String(format: "%02d", index + 1)
    }

    /// まぶたの差分（mini だけ）。
    public static func eyelid(_ pose: Pose) -> String {
        "\(CharacterImageKind.mini.rawValue)/\(pose.rawValue)_eyelid"
    }

    /// `kind` のフォルダの中の、正しい形の名前か。英字・数字・下線だけ（`..` でフォルダの外を指させない）。
    public static func isValid(_ name: String, kind: CharacterImageKind) -> Bool {
        let head = kind.rawValue + "/"
        guard name.hasPrefix(head) else { return false }
        let stem = name.dropFirst(head.count)
        return (1...maxStemLength).contains(stem.count)
            && stem.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }
    }
}

/// 取り込んだキャラの形の問題。何が（`kind`）と、どこが（`detail`：id・姿勢・絵の名前・大きさ）。
public struct CharacterDefect: Error, Sendable, Equatable, CustomStringConvertible {

    public enum Kind: String, Sendable, CaseIterable {
        case invalidID = "id の形が違います"
        case mismatchedID = "フォルダの名前と id が違います"
        case futureSchema = "新しい版のアプリが書いたファイルです"
        case notImported = "取り込んだキャラではありません"
        case invalidScale = "体格の値が壊れています"
        case missingIdle = "立ち姿の絵がありません"
        case tooManyFrames = "コマが多すぎます"
        case miniMismatch = "ウィジェット用の絵の枚数が、待受用と違います"
        case eyelidWithoutBlink = "まぶたの差分の姿勢に、まばたきの絵（2 コマ目）がありません"
        case invalidImageName = "絵の名前の形が違います"
        case missingImage = "絵がありません"
        case unusedImage = "どこからも使われない絵があります"
        case wrongImageSize = "絵の大きさが枠と違います"
    }

    public let kind: Kind
    public let detail: String

    public init(_ kind: Kind, _ detail: String) {
        self.kind = kind
        self.detail = detail
    }

    public var description: String { "\(kind.rawValue)（\(detail)）" }
}

/// 形の検査。描くのに要る約束だけを見る（立ち姿がある・mini が hero とそろう・名前がフォルダの外を指さない など）。
enum CharacterCheck {

    /// 1 つの姿勢のコマの上限。整える処理が作るのは多くて 4 コマ（歩く）なので、その倍。
    /// 壊れた定義で、待受モードが何十枚もの絵を展開しないようにする。
    static let maxFramesPerPose = 8
    /// 体格として受ける範囲。選べるのは 0.9〜1.1（2-C ③）で、これを大きく外れる値は壊れている。
    static let plausibleScale: ClosedRange<Double> = 0.5...2.0

    /// 最初に見つかった問題。無ければ nil。
    static func defect(in character: CTCore.Character) -> CharacterDefect? {
        let checks: [(CTCore.Character) -> CharacterDefect?] = [
            idDefect, originDefect, scaleDefect, idleDefect, frameCountDefect, miniDefect, eyelidDefect,
            nameDefect,
        ]
        return checks.lazy.compactMap { $0(character) }.first
    }

    /// 定義が呼ぶ絵 1 枚。名前と、その種類（hero か mini か）。
    struct ImageReference: Equatable {
        let name: String
        let kind: CharacterImageKind

        var isValid: Bool { CharacterImageName.isValid(name, kind: kind) }
    }

    /// 定義が呼ぶ絵。並びは姿勢の順（見つけた問題の報告を、毎回同じにする）。
    static func referencedImages(of character: CTCore.Character) -> [ImageReference] {
        let heroes = Pose.allCases.flatMap { character.poses[$0] ?? [] }
        let minis = Pose.allCases.flatMap { pose in
            (character.miniPoses[pose] ?? []) + [character.eyelids[pose]].compactMap { $0 }
        }
        return heroes.map { ImageReference(name: $0, kind: .hero) }
            + minis.map { ImageReference(name: $0, kind: .mini) }
    }

    private static func idDefect(_ character: CTCore.Character) -> CharacterDefect? {
        CharacterID.isUser(character.id) ? nil : CharacterDefect(.invalidID, character.id)
    }

    private static func originDefect(_ character: CTCore.Character) -> CharacterDefect? {
        if case .user = character.origin { return nil }
        return CharacterDefect(.notImported, character.id)
    }

    private static func scaleDefect(_ character: CTCore.Character) -> CharacterDefect? {
        plausibleScale.contains(character.scale) ? nil : CharacterDefect(.invalidScale, "\(character.scale)")
    }

    private static func idleDefect(_ character: CTCore.Character) -> CharacterDefect? {
        character.frameCount(.idle) > 0 ? nil : CharacterDefect(.missingIdle, character.id)
    }

    private static func frameCountDefect(_ character: CTCore.Character) -> CharacterDefect? {
        let crowded = Pose.allCases.first { character.frameCount($0) > maxFramesPerPose }
        return crowded.map { CharacterDefect(.tooManyFrames, "\($0.rawValue) \(character.frameCount($0)) 枚") }
    }

    private static func miniDefect(_ character: CTCore.Character) -> CharacterDefect? {
        let miniCount = { (pose: Pose) in character.miniPoses[pose]?.count ?? 0 }
        let uneven = Pose.allCases.first { character.frameCount($0) != miniCount($0) }
        return uneven.map {
            CharacterDefect(.miniMismatch, "\($0.rawValue): 待受用 \(character.frameCount($0)) 枚・"
                            + "ウィジェット用 \(miniCount($0)) 枚")
        }
    }

    /// まぶたの差分は、まばたきの絵（2 コマ目）と目を開けた絵の違い。まばたきの絵の無い姿勢に差分があると、
    /// ウィジェットだけがまばたき、待受モードはまばたかない（面によって姿が違う）。
    private static func eyelidDefect(_ character: CTCore.Character) -> CharacterDefect? {
        let orphan = Pose.allCases.first { character.eyelids[$0] != nil && character.frameCount($0) < 2 }
        return orphan.map { CharacterDefect(.eyelidWithoutBlink, $0.rawValue) }
    }

    private static func nameDefect(_ character: CTCore.Character) -> CharacterDefect? {
        let bad = referencedImages(of: character).first { !$0.isValid }
        return bad.map { CharacterDefect(.invalidImageName, $0.name) }
    }
}
