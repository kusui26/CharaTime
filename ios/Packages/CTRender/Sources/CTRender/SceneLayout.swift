import SwiftUI
import CTCore
import CTAssets

/// 正規化座標（0〜1）を画面のポイントに直す。
///
/// **View から切り離した純粋な計算にしてある。** 面ごとに画面の大きさは違うが
/// 置き方の理屈は同じなので、ここだけをテストすれば全部の面で確かめたことになる。
public struct SceneLayout: Sendable, Equatable {

    /// キャラの背の高さ（画面の高さに対する比）。奥行きの倍率を掛ける前の値。
    ///
    /// 390x844 の画面で約 236pt。デザインキャンバスの待受モードと同じ大きさ。
    public static let characterHeightRatio: Double = 0.28
    /// 足元の影の幅（キャラの背の高さに対する比）。
    public static let shadowWidthRatio: Double = 0.34
    /// 影の高さは幅に対するこの比（横長の楕円）。
    public static let shadowFlatness: Double = 0.30
    /// 影の濃さ。
    public static let shadowOpacity: Double = 0.18

    public let size: CGSize
    public let room: Room
    public let geometry: SpriteGeometry

    public init(size: CGSize, room: Room, geometry: SpriteGeometry) {
        self.size = size
        self.room = room
        self.geometry = geometry
    }

    /// キャラの体が絵の幅に占める割合。
    ///
    /// 焼いた絵には左右に透明な余白がある（とさかや羽が切れないように四方を広げたぶん）。
    /// 体そのものはおよそ 8 割で、はみ出してよいのは残りの余白だけ。
    public static let bodyWidthRatio: Double = 0.8

    /// 床の左右に空けるべき余白（画面の幅に対する比）。
    ///
    /// **絵は足元を中心に置く。** 端まで歩かせると体の半分が画面の外へ出るので、
    /// いちばん大きく見える手前でも体が収まるだけの余白を残す。
    public static func safeHorizontalInset(in size: CGSize, geometry: SpriteGeometry,
                                           characterScale: Double = 1) -> Double {
        guard size.width > 0 else { return 0 }
        let height = size.height * characterHeightRatio * characterScale
        let bodyWidth = height * geometry.aspectRatio * bodyWidthRatio
        return Swift.min(0.4, bodyWidth / 2 / size.width)
    }

    /// 正規化座標を画面の位置へ。
    public func point(_ position: RoomPoint) -> CGPoint {
        CGPoint(x: position.x * size.width, y: position.y * size.height)
    }

    /// その位置に立ったときのキャラの背の高さ（ポイント）。奥ほど小さい。
    public func characterHeight(at position: RoomPoint, characterScale: Double) -> Double {
        size.height * Self.characterHeightRatio * room.scale(at: position) * characterScale
    }

    /// 絵を置く枠。接地線が `position` に来るように、浮いたぶんだけ持ち上げる。
    ///
    /// 絵の中で接地線は上から `groundRatio` の位置にある。枠の中心はそこから
    /// `(0.5 - groundRatio) * 高さ` だけ上にずれる。
    public func spriteFrame(footAt position: RoomPoint, height: Double,
                            liftRatio: Double) -> CGRect {
        let width = height * geometry.aspectRatio
        let foot = point(position)
        let centerY = foot.y - liftRatio * height + height * (0.5 - geometry.groundRatio)
        return CGRect(x: foot.x - width / 2, y: centerY - height / 2,
                      width: width, height: height)
    }

    /// 足元の影。浮くと小さく薄くなる。
    public func shadowFrame(at position: RoomPoint, height: Double, scale: Double) -> CGRect {
        let width = height * Self.shadowWidthRatio * scale
        let foot = point(position)
        return CGRect(x: foot.x - width / 2, y: foot.y - width * Self.shadowFlatness / 2,
                      width: width, height: width * Self.shadowFlatness)
    }

    /// アイテムを置く枠。床に置くものは下端を、吊るすものは上端を `position` に合わせる。
    public func itemFrame(_ item: PlacedItem, definition: ItemDefinition) -> CGRect {
        let width = room.floor.width * size.width * definition.widthRatio
            * room.scale(at: item.position)
        let height = width / Swift.max(definition.aspectRatio, 0.01)
        let anchor = point(item.position)
        let top = definition.hangsFromCeiling ? anchor.y : anchor.y - height
        return CGRect(x: anchor.x - width / 2, y: top, width: width, height: height)
    }

    /// 吊るすアイテムの紐。天井から絵の上端まで引く。
    public func cord(for frame: CGRect) -> (from: CGPoint, to: CGPoint) {
        (CGPoint(x: frame.midX, y: 0), CGPoint(x: frame.midX, y: frame.minY + frame.height * 0.1))
    }
}
