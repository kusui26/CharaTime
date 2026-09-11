import SwiftUI

extension Color {
    /// `#RRGGBB` の 16 進から作る。
    ///
    /// デザインキャンバス（`design/`）は色を 16 進で持っているので、
    /// 同じ字面のまま Swift へ持ってこられるようにする。写し間違いが起きにくい。
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// 部屋の配色。昼と夜で総入れ替えする（プラン §4.4 の夜モード）。
///
/// 値は `design/scene.py` の DAY / NITE と同じもの。
public struct RoomPalette: Sendable, Equatable {

    public var wall: Color
    /// 幅木（壁と床の境の帯）。
    public var baseboard: Color
    public var floor: Color
    /// 床の手前側。奥より少し濃くして奥行きを出す。
    public var floorNear: Color
    /// 窓の外。
    public var sky: Color
    /// 月・電球の光。
    public var glow: Color
    public var rug: Color
    public var rugInner: Color
    /// 輪郭線。キャラの輪郭と同じ色にして、画面全体を 1 枚の絵に見せる。
    public var outline: Color
    /// 時計・日付の文字。
    public var clockInk: Color

    public static let day = RoomPalette(
        wall: Color(hex: 0xF7E7D0), baseboard: Color(hex: 0xF2DDC0),
        floor: Color(hex: 0xE5C79E), floorNear: Color(hex: 0xD9B587),
        sky: Color(hex: 0xBFE3F2), glow: Color(hex: 0xFFF3D6),
        rug: Color(hex: 0xEFC9A8), rugInner: Color(hex: 0xF6DCC4),
        outline: Color(hex: 0x3B2B2B), clockInk: Color(hex: 0x5A4636))

    public static let night = RoomPalette(
        wall: Color(hex: 0x4A4160), baseboard: Color(hex: 0x3E3653),
        floor: Color(hex: 0x574A6B), floorNear: Color(hex: 0x4A3E5D),
        sky: Color(hex: 0x2A2440), glow: Color(hex: 0xFFE9A8),
        rug: Color(hex: 0x6E6088), rugInner: Color(hex: 0x7E6F9A),
        outline: Color(hex: 0x3B2B2B), clockInk: Color(hex: 0xFFF4DC))

    public static func forNight(_ isNight: Bool) -> RoomPalette { isNight ? .night : .day }
}

/// 夜モードに入る時刻（プラン §4.4「22 時以降は自動で暗く」）。
public enum NightMode {

    public static let startHour = 22
    public static let endHour = 6

    /// その時刻が夜か。境目は 22:00 ちょうどから、翌 6:00 の直前まで。
    public static func isNight(hour: Int) -> Bool {
        hour >= startHour || hour < endHour
    }
}
