import Foundation

/// 部屋の中の位置。**0.0〜1.0 の正規化座標**で、原点は左上。
///
/// `CGPoint` を使わないのは 2 つの理由による。`CGPoint` の JSON は `[0.25, 0.5]` と
/// いう配列で、手で読む manifest や Python のパイプラインから見て何の値か分からない。
/// もう一つは、CTCore を CoreGraphics に依存させないため（プラン §7.3 の
/// 「CTCore は UIKit・SwiftUI に依存させない」の延長）。
public struct RoomPoint: Codable, Sendable, Equatable {
    public var x: Double
    public var y: Double

    public static let zero = RoomPoint(x: 0, y: 0)

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        x = try box.decodeIfPresent(Double.self, forKey: .x) ?? 0
        y = try box.decodeIfPresent(Double.self, forKey: .y) ?? 0
    }
}

/// 部屋の中の矩形（正規化座標）。キャラが歩ける床を表すのに使う。
public struct RoomRect: Codable, Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public static let unit = RoomRect(x: 0, y: 0, width: 1, height: 1)

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        x = try box.decodeIfPresent(Double.self, forKey: .x) ?? 0
        y = try box.decodeIfPresent(Double.self, forKey: .y) ?? 0
        width = try box.decodeIfPresent(Double.self, forKey: .width) ?? 1
        height = try box.decodeIfPresent(Double.self, forKey: .height) ?? 1
    }

    public var minX: Double { Swift.min(x, x + width) }
    public var maxX: Double { Swift.max(x, x + width) }
    public var minY: Double { Swift.min(y, y + height) }
    public var maxY: Double { Swift.max(y, y + height) }

    public func contains(_ point: RoomPoint) -> Bool {
        point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }

    /// 矩形の外に出た点を、いちばん近い縁に引き戻す。
    ///
    /// 日課エンジンの不変条件「キャラは常に床の中にいる」を、呼び出し側の
    /// 計算が多少ずれても守れるようにするための最後の網。
    public func clamping(_ point: RoomPoint) -> RoomPoint {
        RoomPoint(x: Swift.min(Swift.max(point.x, minX), maxX),
                  y: Swift.min(Swift.max(point.y, minY), maxY))
    }

    /// 0.0〜1.0 の比率で矩形の中の点を指す。`at(0.5, 0.5)` は中心。
    public func at(_ horizontal: Double, _ vertical: Double) -> RoomPoint {
        RoomPoint(x: minX + (maxX - minX) * horizontal,
                  y: minY + (maxY - minY) * vertical)
    }

    /// 点が縦方向のどのあたりにあるか（0.0 が奥、1.0 が手前）。奥行きの縮尺に使う。
    public func depthRatio(of point: RoomPoint) -> Double {
        let span = maxY - minY
        guard span > 0 else { return 1 }
        return Swift.min(1, Swift.max(0, (point.y - minY) / span))
    }
}
