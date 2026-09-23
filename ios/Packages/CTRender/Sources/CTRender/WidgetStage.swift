import SwiftUI
import CTCore
import CTAssets
import CTStore

/// ウィジェットの大きさごとの、部屋の写し方（プラン §9 Phase 3 の 3-C ⑥）。
///
/// 部屋は縦長の画面の上で決めてある。そのまま縮めると横長・正方形の枠に収まらないので、
/// 2 つを別々に決める。
/// - **絵の大きさ**（キャラ・アイテム・窓）は、キャラの背の高さに合わせて一様に縮める。歪まない
/// - **居場所**は、床の帯を大きさごとに決めた高さ（`band`）へ、左右を幅いっぱいへ写す
///
/// 日課エンジンが返す位置はそのまま使う（アプリと同じ `sceneState(at:)` の答え）。
/// 変えるのは写し方だけなので、キャラは床の帯の中だけを歩き、アイテムとの前後も崩れない。
public struct WidgetStage: Sendable, Equatable {

    public let family: WidgetSlot.Family
    /// キャラの背の高さ（奥行きを掛ける前）の、ウィジェットの幅に対する比。
    public let characterWidthRatio: Double
    /// 床の帯の上辺と下辺（ウィジェットの高さに対する比）。上辺が壁と床の境目になる。
    public let band: ClosedRange<Double>
    /// 壁の窓を描くか。小は窓を置く壁の高さが足りない。
    public let showsWindow: Bool

    /// 大と中のキャラの背の高さ（幅に対する比）。iPhone 17 Pro で約 110pt、大の高さの約 3 割。
    ///
    /// **大と中は同じ値にする。** 幅が同じなので、キャラも同じ大きさになる（ページの部屋で
    /// ウィジェットの間を行き来しても、大きさが変わらない。3-C ⑧）。
    static let roomCharacterWidthRatio: Double = 0.315
    /// 小のキャラの背の高さ（幅に対する比）。約 126pt の近影。ウィジェット用の絵（mini）は
    /// この大きさに合わせて焼いてあり、引き伸ばさない（tools/pipeline の MINI_SCALE）。
    static let closeUpCharacterWidthRatio: Double = 0.766
    /// 体の端とウィジェットの縁のあいだに残す余白（ポイント）。
    static let edgeMarginPoints: Double = 4
    /// 帯の厚み・幅がこれより小さい部屋でも、写し方の倍率が無限にならないようにする下限。
    static let minimumFloorExtent: Double = 0.01

    public static func stage(for family: WidgetSlot.Family) -> WidgetStage {
        switch family {
        case .large:
            // 床を深めにとって壁を短くする。0.66 から始めると、上の 4 割が何も無い壁になった。
            WidgetStage(family: family, characterWidthRatio: roomCharacterWidthRatio,
                        band: 0.60...0.88, showsWindow: true)
        case .medium:
            // 高さが大の半分もないので、帯を薄く、下へ寄せる。奥に立っても頭が切れない。
            WidgetStage(family: family, characterWidthRatio: roomCharacterWidthRatio,
                        band: 0.63...0.92, showsWindow: true)
        case .small:
            WidgetStage(family: family, characterWidthRatio: closeUpCharacterWidthRatio,
                        band: 0.70...0.93, showsWindow: false)
        }
    }

    /// その大きさの枠での置き方。
    ///
    /// `characterScale` はキャラの体格差（`Character.scale`）。大きいキャラほど体が幅を取るので、
    /// 左右の余白をそのぶん見込む。
    public func layout(size: CGSize, room: Room, geometry: SpriteGeometry,
                       characterScale: Double = 1) -> SceneLayout {
        let characterBase = size.width * characterWidthRatio
        let reference = SceneLayout.referenceScreen
        let unit = characterBase / (reference.height * SceneLayout.characterHeightRatio)
        let stage = CGSize(width: reference.width * unit, height: reference.height * unit)
        let halfBody = characterBase * room.depthScaleNear * characterScale
            * geometry.aspectRatio * SceneLayout.bodyWidthRatio / 2
        return SceneLayout(size: size, room: room, geometry: geometry,
                           projection: projection(size: size, floor: room.floor, halfBody: halfBody),
                           stage: stage, unit: unit)
    }

    /// 左右は、床の帯の真ん中をウィジェットの真ん中に置き、幅いっぱいに広げる。
    /// 帯の端でキャラの体がはみ出すなら、はみ出さない倍率まで縮める。
    /// 上下は、床の帯を `band` の高さへ写す。
    private func projection(size: CGSize, floor: RoomRect, halfBody: Double) -> RoomProjection {
        let floorWidth = Swift.max(floor.maxX - floor.minX, Self.minimumFloorExtent)
        let floorHeight = Swift.max(floor.maxY - floor.minY, Self.minimumFloorExtent)
        let usableWidth = size.width - 2 * (Self.edgeMarginPoints + halfBody)
        let xScale = Swift.max(Swift.min(size.width, usableWidth / floorWidth), 0)
        let top = band.lowerBound * size.height
        let bottom = band.upperBound * size.height
        let yScale = (bottom - top) / floorHeight
        let floorCenterX = (floor.minX + floor.maxX) / 2
        return RoomProjection(xScale: xScale, xOffset: size.width / 2 - floorCenterX * xScale,
                              yScale: yScale, yOffset: top - floor.minY * yScale)
    }
}

public extension WidgetStage {

    /// iOS 26 のウィジェットの大きさ（ポイント。402x874 の iPhone 17 / 17 Pro、ラベルあり）。
    ///
    /// シミュレータ（iOS 26.5）で測り、実機（26.1）でも同じ位置と確かめた（プラン 3-C ①）。
    /// 実際の描画では OS が渡す大きさを使う。ここはテストと、アプリ内の下見のための値。
    static func referenceSize(for family: WidgetSlot.Family) -> CGSize {
        switch family {
        case .small:  CGSize(width: 164.33, height: 164.33)
        case .medium: CGSize(width: 349.67, height: 164.33)
        case .large:  CGSize(width: 349.67, height: 365.00)
        }
    }

    /// 同じ機種で、アプリのアイコンを大きく（ラベルなし）したときの大きさ。
    static func labelFreeSize(for family: WidgetSlot.Family) -> CGSize {
        switch family {
        case .small:  CGSize(width: 169.67, height: 169.67)
        case .medium: CGSize(width: 359.67, height: 169.67)
        case .large:  CGSize(width: 359.67, height: 359.00)
        }
    }

    /// ウィジェットの角丸（ポイント）。アプリ内の下見で枠を描くのに使う。
    static let cornerRadius: Double = 27.94
}

public extension SceneLayout {

    /// 2 つの居場所のあいだを、左右に何ポイント動くか。
    func horizontalTravel(from start: RoomPoint, to end: RoomPoint) -> Double {
        abs(projection.x(end.x) - projection.x(start.x))
    }
}
