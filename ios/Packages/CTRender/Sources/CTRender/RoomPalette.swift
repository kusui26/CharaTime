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

    /// 取り込んだ画像の上に置くときの配色。
    ///
    /// **写真やホーム画面の明るさは分からない。** 昼の配色の濃い文字だと暗い写真の上で
    /// 消えるので、文字は淡い色に固定して、後ろに薄い覆いを敷いて読ませる。
    public func overPicture() -> RoomPalette {
        var palette = self
        palette.clockInk = Color(hex: 0xFFF4DC)
        return palette
    }

    /// 暗い後ろの上に置くときの配色（StandBy。プラン §9 Phase 3 の 3-C ⑨）。
    ///
    /// StandBy は背景を外して黒の上に出し、夜は明るさだけを赤く残す。昼の配色の焦げ茶の字
    /// （昼寝の z）はどちらでも消えるので、夜の配色と同じ淡い色にする。
    public func overDarkness() -> RoomPalette {
        var palette = self
        palette.clockInk = Self.night.clockInk
        return palette
    }
}

/// 取り込んだ画像の上で時計を読ませるための下敷き。
///
/// アイコンや風景の上に文字を置くと、その写真によって読めたり読めなかったりする。
/// **画面の上半分を一様に暗くするのではなく、文字の後ろだけに敷く。**
/// 一様に暗くすると、せっかく選んだ写真やアイコンまで沈んでしまう。
struct ClockPlate<Content: View>: View {

    @ViewBuilder let content: Content

    private static var cornerRadius: Double { 26 }

    var body: some View {
        content
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .fill(.black.opacity(0.26))
                    .background(
                        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)))
            .allowsHitTesting(false)
    }
}

/// 夜モードに入る時刻（プラン §4.4「22 時以降は自動で暗く」）。
public enum NightMode {

    public static let startHour = 22
    public static let endHour = 6

    /// その時刻が夜か。境目は 22:00 ちょうどから、翌 6:00 の直前まで。
    public static func isNight(hour: Int) -> Bool {
        hour >= startHour || hour < endHour
    }

    /// その時刻が夜か。時はその暦で数える（待受モードとウィジェットで同じ規則）。
    public static func isNight(at date: Date, calendar: Calendar) -> Bool {
        isNight(hour: calendar.component(.hour, from: date))
    }
}
