import Testing
import Foundation
@testable import CTRender

/// 時刻をずらす仕組み。**確認のためだけのもの**だが、読み違えると
/// 「日課エンジンが壊れた」と誤診しかねないので、境界を押さえておく。
@Suite("見せかけの時刻")
struct TimeWarpTests {

    static var tokyo: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        return calendar
    }

    static func at(_ hour: Int, _ minute: Int, day: Int = 12) -> Date {
        var parts = DateComponents()
        parts.year = 2026; parts.month = 9; parts.day = day
        parts.hour = hour; parts.minute = minute
        return tokyo.date(from: parts) ?? .distantPast
    }

    @Test("指定が無ければ実時刻をそのまま返す")
    func realByDefault() {
        let now = Self.at(3, 0)
        #expect(TimeWarp.real.apply(to: now) == now)
        #expect(!TimeWarp.real.isActive)
        #expect(TimeWarp.fromArguments(["app"], now: now, calendar: Self.tokyo) == .real)
    }

    @Test("時刻だけ渡すと、きょうのその時刻で止まる")
    func fixesTimeOfDay() {
        let now = Self.at(3, 0)
        let warp = TimeWarp.fromArguments(["app", "-CTTime", "14:30"],
                                          now: now, calendar: Self.tokyo)
        #expect(warp.isActive)
        #expect(warp.scale == 0)
        // 実時間が進んでも、見せかけの時刻は動かない。
        #expect(warp.apply(to: now) == Self.at(14, 30))
        #expect(warp.apply(to: now.addingTimeInterval(600)) == Self.at(14, 30))
    }

    @Test("倍率を渡すと、その速さで進む")
    func fastForwards() {
        let now = Self.at(3, 0)
        let warp = TimeWarp.fromArguments(["app", "-CTTime", "07:00", "-CTSpeed", "240"],
                                          now: now, calendar: Self.tokyo)
        #expect(warp.apply(to: now) == Self.at(7, 0))
        // 実時間 1 分で 240 分（4 時間）進む。
        #expect(warp.apply(to: now.addingTimeInterval(60)) == Self.at(11, 0))
    }

    @Test("日付付きでも読める")
    func acceptsFullDate() {
        let warp = TimeWarp.fromArguments(["app", "-CTTime", "2026-12-31T23:59"],
                                          now: Self.at(3, 0), calendar: Self.tokyo)
        let expected = Self.tokyo.date(from: DateComponents(year: 2026, month: 12, day: 31,
                                                            hour: 23, minute: 59))
        #expect(warp.displayOrigin == expected)
    }

    @Test("読めない指定は実時刻に戻る")
    func fallsBackOnGarbage() {
        let now = Self.at(3, 0)
        for bad in ["", "ごご 2 時", "25", "abc:def", "2026-09T10:00"] {
            let warp = TimeWarp.fromArguments(["app", "-CTTime", bad],
                                              now: now, calendar: Self.tokyo)
            #expect(warp == .real, Comment(rawValue: "「\(bad)」を受け入れてしまった"))
        }
        // 値が無い指定も落ちない。
        #expect(TimeWarp.fromArguments(["app", "-CTTime"], now: now, calendar: Self.tokyo) == .real)
    }
}
