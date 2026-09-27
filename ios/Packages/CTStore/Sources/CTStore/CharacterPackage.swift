import Foundation
import CoreGraphics
import CTCore

/// 取り込んだキャラの、絵のほかの中身。キャラ工房で決める（プラン §9 Phase 2 の 2-C ③⑤-7）。
public struct CharacterProfile: Sendable, Equatable {
    /// `CharacterID.makeUser` か `CharacterStore.newID` で作った id。
    public var id: String
    public var displayName: String
    /// 体格（小さめ・ふつう・大きめ = 0.9 / 1.0 / 1.1。2-C ③）。
    public var scale: Double
    public var personality: Personality
    /// 連れてきた日時。一覧の並び（連れてきた順）に使う。
    public var createdAt: Date

    public init(id: String, displayName: String, scale: Double = 1.0, personality: Personality,
                createdAt: Date) {
        self.id = id
        self.displayName = displayName
        self.scale = scale
        self.personality = personality
        self.createdAt = createdAt
    }
}

/// 取り込んだキャラ 1 体ぶんの、置く前の中身（`CharacterStore.install` に渡す）。
public struct CharacterPackage: Sendable {

    /// 1 コマぶんの絵。待受用（hero）と、ウィジェット用の小さい絵（mini）。
    public struct Frame: Sendable {
        public let hero: CGImage
        public let mini: CGImage

        public init(hero: CGImage, mini: CGImage) {
            self.hero = hero
            self.mini = mini
        }
    }

    public let file: CharacterFile
    /// 絵。名前（`CharacterImageName`）→ 画像。
    public let images: [String: CGImage]

    public init(file: CharacterFile, images: [String: CGImage]) {
        self.file = file
        self.images = images
    }

    /// 姿勢ごとの絵から組み立てる。名前は置き場の決まり（`CharacterImageName`）で付けるので、
    /// 呼び出し側（キャラ工房）は名前を知らなくてよい。
    ///
    /// - `frames`: 姿勢ごとのコマ（並びはコマ送りの順。立ち姿と、すわる姿の 2 コマ目はまばたきの絵）
    /// - `eyelids`: まぶたの差分（mini）。まばたきの絵のある姿勢だけ
    public static func assemble(_ profile: CharacterProfile, frames: [Pose: [Frame]],
                                eyelids: [Pose: CGImage] = [:], sleepFrameCoversBase: Bool = false,
                                record: ImportRecord? = nil) -> CharacterPackage {
        let character = CTCore.Character(
            id: profile.id, displayName: profile.displayName, scale: profile.scale,
            personality: profile.personality,
            poses: names(of: frames, kind: .hero), miniPoses: names(of: frames, kind: .mini),
            eyelids: eyelidNames(of: eyelids),
            sleepFrameCoversBase: sleepFrameCoversBase, origin: .user(createdAt: profile.createdAt))
        return CharacterPackage(file: CharacterFile(character: character, importRecord: record),
                                images: images(of: frames, eyelids: eyelids))
    }

    private static func names(of frames: [Pose: [Frame]], kind: CharacterImageKind) -> [Pose: [String]] {
        Dictionary(uniqueKeysWithValues: frames.map { pose, list in
            (pose, list.indices.map { CharacterImageName.frame(pose, $0, kind: kind) })
        })
    }

    private static func eyelidNames(of eyelids: [Pose: CGImage]) -> [Pose: String] {
        Dictionary(uniqueKeysWithValues: eyelids.keys.map { ($0, CharacterImageName.eyelid($0)) })
    }

    private static func images(of frames: [Pose: [Frame]], eyelids: [Pose: CGImage]) -> [String: CGImage] {
        let pictures = frames.flatMap { pose, list in
            list.enumerated().flatMap { index, frame in
                [(CharacterImageName.frame(pose, index, kind: .hero), frame.hero),
                 (CharacterImageName.frame(pose, index, kind: .mini), frame.mini)]
            }
        }
        let lids = eyelids.map { pose, image in (CharacterImageName.eyelid(pose), image) }
        return Dictionary(pictures + lids, uniquingKeysWith: { first, _ in first })
    }
}

extension CharacterPackage {

    /// 置く前の検査。形（`CharacterCheck`）と、絵のそろい（呼ぶ絵が全部ある・使われない絵が無い・
    /// 大きさが枠と同じ）。**書く側は厳しく**して、読む側（ウィジェット）が頼れるフォルダだけを置く。
    var defect: CharacterDefect? {
        CharacterCheck.defect(in: file.character) ?? imageDefect
    }

    private var imageDefect: CharacterDefect? {
        let referenced = CharacterCheck.referencedImages(of: file.character)
        if let missing = referenced.first(where: { images[$0.name] == nil }) {
            return CharacterDefect(.missingImage, missing.name)
        }
        let used = Set(referenced.map(\.name))
        if let unused = images.keys.sorted().first(where: { !used.contains($0) }) {
            return CharacterDefect(.unusedImage, unused)
        }
        return referenced.lazy.compactMap { sizeDefect(of: $0.name, kind: $0.kind) }.first
    }

    private func sizeDefect(of name: String, kind: CharacterImageKind) -> CharacterDefect? {
        guard let image = images[name] else { return nil }
        let size = PixelSize(width: image.width, height: image.height)
        guard size != kind.pixelSize else { return nil }
        return CharacterDefect(.wrongImageSize, "\(name): \(size.width)×\(size.height)"
                               + "（\(kind.pixelSize.width)×\(kind.pixelSize.height) のはず）")
    }
}
