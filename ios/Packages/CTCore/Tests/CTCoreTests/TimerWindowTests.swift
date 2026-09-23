import Testing
import Foundation
@testable import CTCore

/// 疑似アニメの「いつ見せるか」。OS がタイマーの文字を描くときの数え方を、ここでなぞれているか。
@Suite("タイマーの窓")
struct TimerWindowTests {

    private let calendar = TestClock.tokyo

    private func opens(_ window: TimerWindow, at time: Date) -> Bool {
        window.isOpen(at: time, calendar: calendar)
    }

    // MARK: - 数字の集まり

    @Test("0〜9 の外の数字と重複は捨て、小さい順に並べる")
    func normalizesDigits() {
        let set = DigitSet([7, 2, 2, 11, -1])
        #expect(set.digits == [2, 7])
        #expect(set.key == "27")
        #expect(set.contains(7) && !set.contains(3))
    }

    @Test("残りの数字は、元の集まりと重ならず、合わせると 0〜9 になる")
    func complementCoversTheRest() {
        let breath = DigitSet.sleepBreath
        #expect(breath.complement.digits == [2, 3, 4, 7, 8, 9])
        #expect(Set(breath.digits).isDisjoint(with: breath.complement.digits))
        #expect((breath.digits + breath.complement.digits).sorted() == Array(0...9))
    }

    // MARK: - 桁

    /// 「15:32:11」なら、秒の一の位 1・十の位 1、分の一の位 2・十の位 3。
    @Test("0 時からの経過秒から、各桁の数字が出る")
    func digitsOfElapsedSeconds() {
        let elapsed = 15 * 3600 + 32 * 60 + 11
        #expect(ClockDigit.secondOnes.digit(ofElapsedSeconds: elapsed) == 1)
        #expect(ClockDigit.secondTens.digit(ofElapsedSeconds: elapsed) == 1)
        #expect(ClockDigit.minuteOnes.digit(ofElapsedSeconds: elapsed) == 2)
        #expect(ClockDigit.minuteTens.digit(ofElapsedSeconds: elapsed) == 3)
    }

    /// 描き手は右から数えて切り出す。時の桁の字数（「9:…」「10:…」）に左右されない位置だけを使う。
    @Test("右から数えた位置は、`:` を 1 字に数える")
    func glyphPositions() {
        #expect(ClockDigit.allCases.map(\.glyphIndexFromRight) == [0, 1, 3, 4])
    }

    // MARK: - 窓

    @Test("偶数の窓は、偶数の秒のあいだ開く")
    func evenSeconds() {
        let window = TimerWindow.when(.even)
        #expect(opens(window, at: TestClock.today(12, 0, 2)))
        #expect(opens(window, at: TestClock.today(12, 0, 2.99)))
        #expect(!opens(window, at: TestClock.today(12, 0, 3)))
        #expect(opens(window, at: TestClock.today(12, 0, 4)))
    }

    @Test("進めた窓は、進めたぶんだけ早く開く")
    func advancedWindowOpensEarlier() {
        let window = TimerWindow.when(.even, advancedBy: 0.25)
        #expect(opens(window, at: TestClock.today(12, 0, 1.75)))
        #expect(!opens(window, at: TestClock.today(12, 0, 1.74)))
        #expect(!opens(window, at: TestClock.today(12, 0, 2.75)))
    }

    /// {2, 7} を 2 本で「かつ」にすると、x2 秒と x7 秒の頭 0.25 秒だけ開く（3-C ④ 原則 3）。
    @Test("0.75 秒進めた窓との「かつ」は、頭の 0.25 秒だけ開く")
    func andNarrowsToQuarterSecond() {
        let set = DigitSet([2, 7])
        let window = TimerWindow.when(set).and(.when(set, advancedBy: 0.75))
        #expect(window.timerCount == 2)
        let spans = TestClock.openSpans(of: { opens(window, at: $0) },
                                        from: TestClock.today(12, 0, 0), seconds: 20)
        #expect(spans.count == 4)
        for (span, expectedStart) in zip(spans, [2.0, 7.0, 12.0, 17.0]) {
            #expect(abs(span.start - expectedStart) < 0.02, "開いた時刻 \(span.start)")
            #expect(abs(span.length - 0.25) < 0.02, "開いていた長さ \(span.length)")
        }
    }

    /// 時報のエントリは :00 から 5 分続く。そのあいだ吹き出しが出るのは最初の 30 秒だけ。
    @Test("分の一の位と秒の十の位の「かつ」は、:00 からの 30 秒だけ開く")
    func clockBubbleWindow() {
        let window = TimerWindow.when(.zero, at: .minuteOnes)
            .and(.when(.firstHalfMinute, at: .secondTens))
        let spans = TestClock.openSpans(of: { opens(window, at: $0) },
                                        from: TestClock.today(13, 0, 0), seconds: 300, step: 0.1)
        #expect(spans.count == 1)
        #expect(spans.first.map { abs($0.start) < 0.01 && abs($0.length - 30) < 0.11 } == true)
    }

    @Test("0 時ちょうども、日付の境目で数え直して正しく開く")
    func midnight() {
        let window = TimerWindow.when(.zero, at: .minuteOnes)
        #expect(opens(window, at: TestClock.today(0, 0, 0.1)))
        #expect(opens(window, at: TestClock.today(23, 50, 59.9)))
        #expect(!opens(window, at: TestClock.today(23, 59, 59.9)))
    }

    /// 夏時間に切り替わる日は、0 時から数えた時刻と壁時計の時刻が 1 時間ずれる。
    /// ずれは 1 時間ちょうどなので、秒と分の桁は壁時計と同じ数字になる。
    @Test("夏時間の日も、秒と分の桁は壁時計と一致する")
    func daylightSavingDay() {
        let newYork = TestClock.newYork
        let afterJump = TestClock.date(2026, 3, 8, 3, 7, 2, in: newYork)     // 2:00 → 3:00 の日
        #expect(TimerWindow.when(DigitSet([2])).isOpen(at: afterJump, calendar: newYork))
        #expect(TimerWindow.when(DigitSet([7]), at: .minuteOnes).isOpen(at: afterJump, calendar: newYork))
        let repeated = TestClock.date(2026, 11, 1, 1, 30, 9, in: newYork)    // 2:00 → 1:00 の日
        #expect(TimerWindow.when(DigitSet([9])).isOpen(at: repeated, calendar: newYork))
    }
}
