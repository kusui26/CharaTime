import SwiftUI
import CTCore
import CTStore

/// 待受の時計・日付・電池（プラン §4.4）。
///
/// ガラケーの待受は時計が主役だった。**キャラの上に大きく置く**のがこのアプリの
/// 顔になる（§2.5「時計・電波・電池すら見えない占拠感」への答えでもある）。
public struct ClockView: View {

    public let date: Date
    public let style: ClockStyle
    public let palette: RoomPalette
    public let battery: BatteryReading?
    public let calendar: Calendar

    public init(date: Date, style: ClockStyle, palette: RoomPalette,
                battery: BatteryReading? = nil, calendar: Calendar = .current) {
        self.date = date
        self.style = style
        self.palette = palette
        self.battery = battery
        self.calendar = calendar
    }

    /// 画面の高さに対する数字の大きさ。
    private static let retroSizeRatio: Double = 0.076
    private static let modernSizeRatio: Double = 0.058
    private static let dateSizeRatio: Double = 0.018
    private static let batterySizeRatio: Double = 0.0145

    public var body: some View {
        GeometryReader { geometry in
            let height = geometry.size.height
            VStack(spacing: height * 0.016) {
                time(height: height)
                Text(ClockFormat.date(date, calendar: calendar))
                    .font(.system(size: height * Self.dateSizeRatio, weight: .medium,
                                  design: .rounded))
                    .tracking(height * 0.004)
                    .foregroundStyle(palette.clockInk.opacity(0.80))
                // 読めないときは出さない。「--%」は電池切れと紛らわしい。
                if let battery, battery.level != nil { batteryLine(battery, height: height) }
            }
            .frame(maxWidth: .infinity)
        }
        .allowsHitTesting(false)
    }

    private func time(height: Double) -> some View {
        // 秒は出さない。1 秒ごとに数字が変わると、据え置きの待受としてうるさい。
        Text(ClockFormat.time(date, calendar: calendar))
            .font(.system(size: height * sizeRatio,
                          weight: style == .retro ? .bold : .light,
                          design: style == .retro ? .monospaced : .rounded))
            .tracking(height * (style == .retro ? 0.008 : 0.002))
            .foregroundStyle(palette.clockInk)
            .shadow(color: .black.opacity(0.18), radius: height * 0.006, y: height * 0.002)
    }

    private var sizeRatio: Double {
        style == .retro ? Self.retroSizeRatio : Self.modernSizeRatio
    }

    private func batteryLine(_ reading: BatteryReading, height: Double) -> some View {
        HStack(spacing: height * 0.008) {
            BatteryGauge(reading: reading, color: palette.clockInk)
                .frame(width: height * 0.033, height: height * 0.0165)
            Text(reading.label)
                .font(.system(size: height * Self.batterySizeRatio, weight: .medium,
                              design: .rounded))
                .foregroundStyle(palette.clockInk.opacity(0.70))
        }
    }
}

/// 電池の読み。本体アプリが測って渡す（CTRender は UIKit を持たないため）。
public struct BatteryReading: Sendable, Equatable {

    /// 0.0〜1.0。読めないときは nil。
    public var level: Double?
    public var isCharging: Bool

    public init(level: Double?, isCharging: Bool) {
        self.level = level
        self.isCharging = isCharging
    }

    /// `ContextSnapshot` から。日課エンジンに渡すのと同じ値を表示に使う。
    public init(_ context: ContextSnapshot) {
        self.init(level: context.batteryLevel, isCharging: context.isCharging == true)
    }

    public var label: String {
        let percent = level.map { "\(Int(($0 * 100).rounded()))%" } ?? "--%"
        return isCharging ? "\(percent) ・ 充電中" : percent
    }
}

/// 電池の絵。
struct BatteryGauge: View {

    let reading: BatteryReading
    let color: Color

    /// 端子のぶんだけ本体を短くする割合。
    private static let bodyWidthRatio: Double = 0.84

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let bodyWidth = size.width * Self.bodyWidthRatio
            let stroke = size.height * 0.14
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: size.height * 0.3)
                    .stroke(color.opacity(0.85), lineWidth: stroke)
                    .frame(width: bodyWidth, height: size.height)
                RoundedRectangle(cornerRadius: size.height * 0.18)
                    .fill(color.opacity(0.85))
                    .frame(width: (bodyWidth - stroke * 3) * (reading.level ?? 0),
                           height: size.height - stroke * 3)
                    .offset(x: stroke * 1.5)
                Capsule()
                    .fill(color.opacity(0.6))
                    .frame(width: stroke * 1.6, height: size.height * 0.42)
                    .offset(x: bodyWidth + stroke * 0.6)
            }
            .frame(height: size.height)
        }
    }
}

/// 時刻と日付の文字づくり。ロケールに引きずられないよう自前で組む。
public enum ClockFormat {

    static let weekdayNames = ["日", "月", "火", "水", "木", "金", "土"]

    public static func time(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    public static func date(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.month, .day, .weekday], from: date)
        let weekday = weekdayNames[((parts.weekday ?? 1) - 1) % weekdayNames.count]
        return "\(parts.month ?? 0)月\(parts.day ?? 0)日（\(weekday)）"
    }
}
