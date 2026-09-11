import Testing
import Foundation
@testable import CTCore

@Suite("部屋の座標")
struct GeometryTests {

    private let floor = RoomRect(x: 0.06, y: 0.62, width: 0.88, height: 0.24)

    @Test("JSON が人の読める形になる")
    func readableJSON() throws {
        let data = try JSONEncoder().encode(RoomPoint(x: 0.25, y: 0.5))
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["x"] as? Double == 0.25)
        #expect(object["y"] as? Double == 0.5)

        let rectData = try JSONEncoder().encode(floor)
        let rect = try #require(try JSONSerialization.jsonObject(with: rectData) as? [String: Any])
        #expect(rect["width"] as? Double == 0.88)
    }

    @Test("足りない項目は既定値で埋まる")
    func decodeWithDefaults() throws {
        let point = try JSONDecoder().decode(RoomPoint.self, from: Data(#"{"x": 0.4}"#.utf8))
        #expect(point == RoomPoint(x: 0.4, y: 0))
        let rect = try JSONDecoder().decode(RoomRect.self, from: Data(#"{}"#.utf8))
        #expect(rect == .unit)
    }

    @Test("床の内外を判定できる")
    func containment() {
        #expect(floor.contains(RoomPoint(x: 0.5, y: 0.7)))
        #expect(floor.contains(RoomPoint(x: 0.06, y: 0.62)))     // 縁も内側
        #expect(!floor.contains(RoomPoint(x: 0.5, y: 0.3)))
        #expect(!floor.contains(RoomPoint(x: 0.99, y: 0.7)))
    }

    /// 日課エンジンの不変条件「キャラは常に床の中にいる」を守る最後の網。
    @Test("外に出た点は必ず床の中に戻る")
    func clampingAlwaysLandsInside() {
        let outside = [RoomPoint(x: -5, y: -5), RoomPoint(x: 9, y: 9),
                       RoomPoint(x: 0.5, y: 0.1), RoomPoint(x: 0.0, y: 0.7)]
        for point in outside {
            #expect(floor.contains(floor.clamping(point)), "\(point) が床の外に残った")
        }
        // すでに中にある点は動かさない
        let inside = RoomPoint(x: 0.5, y: 0.7)
        #expect(floor.clamping(inside) == inside)
    }

    @Test("比率で床の中の点を指せる")
    func pointAtRatio() {
        #expect(floor.at(0, 0) == RoomPoint(x: 0.06, y: 0.62))
        #expect(floor.at(1, 1) == RoomPoint(x: 0.94, y: 0.86))
        let center = floor.at(0.5, 0.5)
        #expect(abs(center.x - 0.5) < 1e-12)
    }

    @Test("奥ほど小さく、手前ほど大きく見える")
    func depthScale() {
        let room = Room(background: .bundled("a"), floor: floor,
                        depthScaleFar: 0.85, depthScaleNear: 1.0)
        let far = room.scale(at: floor.at(0.5, 0))
        let near = room.scale(at: floor.at(0.5, 1))
        let middle = room.scale(at: floor.at(0.5, 0.5))
        #expect(abs(far - 0.85) < 1e-12)
        #expect(abs(near - 1.0) < 1e-12)
        #expect(middle > far && middle < near)
        // 床の外に出ても縮尺は 0.85〜1.0 に収まる
        #expect(room.scale(at: RoomPoint(x: 0.5, y: -3)) == 0.85)
        #expect(room.scale(at: RoomPoint(x: 0.5, y: 9)) == 1.0)
    }

    @Test("高さの無い床でも壊れない")
    func degenerateFloor() {
        let flat = RoomRect(x: 0, y: 0.5, width: 1, height: 0)
        #expect(flat.depthRatio(of: RoomPoint(x: 0.5, y: 0.5)) == 1)
        #expect(flat.contains(RoomPoint(x: 0.5, y: 0.5)))
    }
}
