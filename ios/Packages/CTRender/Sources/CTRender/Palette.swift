import SwiftUI

/// CharaTime の配色。design/ のデザインキャンバスで決めた値をそのまま持つ。
///
/// 輪郭線の色（`ink`）はキャラクターの輪郭と同じ #3B2B2B。画面とキャラが同じ
/// 濃さの線でつながるので、アプリ全体が 1 枚の絵として見える。
public enum Palette {
    public static let background = Color(red: 0.984, green: 0.961, blue: 0.925)   // #FBF5EC
    public static let card       = Color.white
    public static let ink        = Color(red: 0.231, green: 0.169, blue: 0.169)   // #3B2B2B
    public static let inkMuted   = Color(red: 0.545, green: 0.482, blue: 0.447)   // #8B7B72
    public static let line       = Color(red: 0.902, green: 0.855, blue: 0.788)   // #E6DAC9
    public static let accent     = Color(red: 0.878, green: 0.541, blue: 0.306)   // #E08A4E
    public static let accentAlt  = Color(red: 0.431, green: 0.655, blue: 0.612)   // #6EA79C
    public static let ok         = Color(red: 0.353, green: 0.608, blue: 0.443)   // #5A9B71
    public static let ng         = Color(red: 0.800, green: 0.333, blue: 0.333)   // #CC5555
}
