import SwiftUI
import CTCore
import CTAssets

/// 正規化座標（0〜1）を画面のポイントに直す。
///
/// **View から切り離した純粋な計算にしてある。** 面ごとに画面の大きさは違うが
/// 置き方の理屈は同じなので、ここだけをテストすれば全部の面で確かめたことになる。
///
/// 決めることは 2 つに分かれる。
/// - **居場所**: 部屋の座標を枠のどこへ写すか（`projection`）
/// - **絵の大きさ**: キャラ・アイテム・窓・線の太さ（`stage` と `unit`）
///
/// 待受モードは画面いっぱいに写すので、どちらも画面の大きさで決まる。ウィジェットは
/// 横長・正方形の枠に縦長の部屋を写すので、2 つを別々に決める（`WidgetStage`）。
public struct SceneLayout: Sendable, Equatable {

    /// キャラの背の高さ（舞台の高さに対する比）。奥行きの倍率を掛ける前の値。
    ///
    /// 390x844 の画面で約 236pt。デザインキャンバスの待受モードと同じ大きさ。
    public static let characterHeightRatio: Double = 0.28
    /// 足元の影の幅（キャラの背の高さに対する比）。
    public static let shadowWidthRatio: Double = 0.34
    /// 影の高さは幅に対するこの比（横長の楕円）。
    public static let shadowFlatness: Double = 0.30
    /// 影の濃さ。
    public static let shadowOpacity: Double = 0.18

    /// 部屋を決めた画面（iPhone 17 Pro の縦画面、ポイント）。
    ///
    /// 同梱の部屋も、指で決めた帯も、縦長の画面の上で決めてある。ウィジェットは、この画面を
    /// キャラの大きさに合わせて縮めた「舞台」を基準に、アイテムや窓の大きさを決める。
    public static let referenceScreen = CGSize(width: 402, height: 874)

    public let size: CGSize
    public let room: Room
    public let geometry: SpriteGeometry
    /// 部屋の座標から、この枠のポイントへの写し方。
    public let projection: RoomProjection
    /// 絵の大きさの基準にする舞台（ポイント）。待受モードは画面そのもの。
    public let stage: CGSize
    /// 基準の 1pt が、この枠で何 pt か（線の太さなど）。待受モードは 1。
    public let unit: Double

    /// 待受モード（画面いっぱい）の置き方。
    public init(size: CGSize, room: Room, geometry: SpriteGeometry) {
        self.init(size: size, room: room, geometry: geometry,
                  projection: RoomProjection(xScale: size.width, xOffset: 0,
                                             yScale: size.height, yOffset: 0),
                  stage: size, unit: 1)
    }

    public init(size: CGSize, room: Room, geometry: SpriteGeometry,
                projection: RoomProjection, stage: CGSize, unit: Double) {
        self.size = size
        self.room = room
        self.geometry = geometry
        self.projection = projection
        self.stage = stage
        self.unit = unit
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

    /// 正規化座標を枠の位置へ。
    public func point(_ position: RoomPoint) -> CGPoint {
        projection.point(position)
    }

    /// 奥行きの倍率を掛ける前の、キャラの背の高さ（ポイント）。
    public var characterBaseHeight: Double { stage.height * Self.characterHeightRatio }

    /// その位置に立ったときのキャラの背の高さ（ポイント）。奥ほど小さい。
    public func characterHeight(at position: RoomPoint, characterScale: Double) -> Double {
        characterBaseHeight * room.scale(at: position) * characterScale
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
    ///
    /// 幅は床の幅（舞台の上での）に対する比で決める。舞台はキャラと同じ割合で縮むので、
    /// どの面でもアイテムとキャラの大きさの釣り合いが変わらない。
    public func itemFrame(_ item: PlacedItem, definition: ItemDefinition) -> CGRect {
        let width = room.floor.width * stage.width * definition.widthRatio
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

    /// 壁と床の境目（ポイント）。床の帯の上辺に置く（壁の中を歩かせないため）。
    public var horizonY: Double { projection.y(room.floor.minY) }

    /// 部屋に作り付けのもの（窓など）の枠。左上は写し方で、大きさは舞台で決める。
    public func fixtureFrame(_ rect: RoomRect) -> CGRect {
        let origin = point(RoomPoint(x: rect.x, y: rect.y))
        return CGRect(x: origin.x, y: origin.y,
                      width: rect.width * stage.width, height: rect.height * stage.height)
    }
}

/// 部屋の正規化座標（0〜1）を、描く枠のポイントに写す。x と y は別々の一次式。
///
/// 待受モードは画面の幅と高さを掛けるだけ。ウィジェットは、床の帯を決めた高さへ、
/// 左右を幅いっぱいへ写すので、x と y で倍率が違う（絵の大きさは `SceneLayout.stage` が別に持つ）。
public struct RoomProjection: Sendable, Equatable {
    public var xScale: Double
    public var xOffset: Double
    public var yScale: Double
    public var yOffset: Double

    public init(xScale: Double, xOffset: Double, yScale: Double, yOffset: Double) {
        self.xScale = xScale
        self.xOffset = xOffset
        self.yScale = yScale
        self.yOffset = yOffset
    }

    public func x(_ value: Double) -> Double { value * xScale + xOffset }
    public func y(_ value: Double) -> Double { value * yScale + yOffset }

    public func point(_ position: RoomPoint) -> CGPoint {
        CGPoint(x: x(position.x), y: y(position.y))
    }
}
