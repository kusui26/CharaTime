import Foundation
import CoreGraphics
import CTCore
@testable import CTStore

/// 取り込んだキャラのテスト用の絵と中身（プラン §9 Phase 2 の 2-1）。
enum CharacterTestArt {

    /// Tier 1（§5.3 の 12 枚）。同梱の 5 体と同じ。
    static let tierOne: [Pose: Int] = [.idle: 2, .walk: 4, .sit: 2, .sleep: 2, .happy: 2]
    /// 立ち姿 1 枚（Tier 0）。まばたきの絵（2 コマ目）はアプリが作る。
    static let single: [Pose: Int] = [.idle: 2]

    static let createdAt = Date(timeIntervalSince1970: 1_790_000_000)

    /// 単色の絵。`gray` で塗り分けて、どの名前の絵を読んだかを見分ける。
    static func picture(_ size: PixelSize, gray: UInt8 = 200) -> CGImage {
        let context = CGContext(data: nil, width: size.width, height: size.height, bitsPerComponent: 8,
                                bytesPerRow: size.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(srgbRed: Double(gray) / 255, green: 0.5, blue: 0.25, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        return context.makeImage()!
    }

    static let hero = picture(CharacterImageKind.hero.pixelSize)
    static let mini = picture(CharacterImageKind.mini.pixelSize)

    static func profile(id: String, name: String = "テストの子", createdAt: Date = createdAt) -> CharacterProfile {
        CharacterProfile(id: id, displayName: name, scale: 1.0,
                         personality: Personality(activity: 0.6, nightOwl: 0.4, napiness: 0.3, favorites: [.cushion]),
                         createdAt: createdAt)
    }

    /// 取り込んだキャラ 1 体ぶん。まぶたは、まばたきの絵のある姿勢（立ち姿・すわる姿）に付ける。
    static func package(id: String = "user-00000001", name: String = "テストの子",
                        frames: [Pose: Int] = tierOne, createdAt: Date = createdAt) -> CharacterPackage {
        let pictures = frames.mapValues { Array(repeating: CharacterPackage.Frame(hero: hero, mini: mini), count: $0) }
        let blinking = [Pose.idle, .sit].filter { (frames[$0] ?? 0) >= 2 }
        let eyelids = Dictionary(uniqueKeysWithValues: blinking.map { ($0, mini) })
        let stage: ImportRecord.Stage = frames[.walk] == nil ? .single : .posesAndWalk
        let record = ImportRecord(stage: stage, sources: [
            ImportRecord.Source(pixelWidth: 1254, pixelHeight: 1254, background: .transparent),
        ])
        return .assemble(profile(id: id, name: name, createdAt: createdAt), frames: pictures, eyelids: eyelids,
                         sleepFrameCoversBase: false, record: record)
    }

    /// 中身を少し変えた包み（形の問題を作るため）。絵はそのまま。
    static func altered(_ package: CharacterPackage, _ change: (inout CTCore.Character) -> Void) -> CharacterPackage {
        var character = package.file.character
        change(&character)
        return CharacterPackage(file: CharacterFile(character: character, importRecord: package.file.importRecord),
                                images: package.images)
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
