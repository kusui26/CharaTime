import Foundation

// ウィジェットの疑似アニメで、重ねた絵を「いつ見せるか」（プラン §9 Phase 3 の 3-C ④）。
//
// 描き手は `Text(timerInterval:)` の 1 字を、数字ごとに「塗りつぶし」か「空」になる書体で描き、
// それをマスクにして絵を出し入れする。タイマーは**その日の 0 時から数える**（D-18）ので、
// 表示は時刻そのもの（「15:32:11」）になり、桁の数字は壁時計の数字と一致する。
// ここはその仕掛けを、描き方から切り離した値として持つ。同じ値から、描き手は書体とマスクを組み、
// テストは `isOpen(at:calendar:)` で「その時刻に見えているか」を確かめる。

/// 1 桁の数字の集まり。この数字のときに窓が開く（マスク書体の「数字の集まり」）。
///
/// 集まりごとに書体が 1 本要る（3-2b でパイプラインが作る）。
public struct DigitSet: Hashable, Sendable {

    /// 開く数字。0〜9 のうち、小さい順に重複なく並ぶ。
    public let digits: [Int]

    /// 0〜9 の外の数字と重複は捨てる。
    public init(_ digits: [Int]) {
        self.digits = Array(Set(digits.filter { Self.allDigits.contains($0) })).sorted()
    }

    public func contains(_ digit: Int) -> Bool { digits.contains(digit) }

    /// 残りの数字。2 枚の絵を出し分けるとき、片方をこれで開く。
    public var complement: DigitSet { DigitSet(Self.allDigits.filter { !contains($0) }) }

    /// 書体の名前などに使う短い名前。{2, 7} なら「27」。
    public var key: String { digits.map(String.init).joined() }

    /// どの数字にも `seconds` を足した集まり（10 で一周する）。{2, 7} を 3 ずらすと {0, 5}。
    public func shifted(by seconds: Int) -> DigitSet {
        let digitCount = Self.allDigits.count
        return DigitSet(digits.map { (($0 + seconds) % digitCount + digitCount) % digitCount })
    }

    static let allDigits = Array(0...9)

    /// 偶数の秒だけ開く。よろこぶの 2 コマの出し分けと、光の粒に使う。
    public static let even = DigitSet([0, 2, 4, 6, 8])
    /// 奇数の秒だけ開く。
    public static let odd = DigitSet([1, 3, 5, 7, 9])
    /// 分の一の位に当てて、毎正時からの 1 分だけ開く（時報の窓の片方）。
    public static let zero = DigitSet([0])
    /// 秒の十の位に当てて、毎分の前半 30 秒だけ開く（時報の窓の片方）。
    public static let firstHalfMinute = DigitSet([0, 1, 2])
    /// 秒の一の位に当てて、5 秒のうち 2 秒だけ開く（寝息。2 秒吸って 3 秒吐く）。
    ///
    /// アプリの待受モードの寝息の周期（`ProceduralMotion.sleepBreathPeriodSeconds` 5.2 秒）に
    /// いちばん近い。秒の一の位は 10 秒で一周するので、5 秒の周期なら 10 秒に 2 回くり返せる。
    public static let sleepBreath = DigitSet([0, 1, 5, 6])
    /// 秒の一の位に当てて、寝ている「z」の 2 つ目を出す秒（5 秒のうち後ろの 3 秒）。
    ///
    /// 1 つ目の z は出したままなので、`thirdSleepMark` と合わせて、5 秒ごとに z（2 秒）→ zz（1 秒）→
    /// zzz（2 秒）と増えていく。回した形は一族の {0, 1, 2, 5, 6, 7} の書体で描ける（D-29）。
    public static let secondSleepMark = DigitSet([2, 3, 4, 7, 8, 9])
    /// 寝ている「z」の 3 つ目を出す秒（5 秒のうち後ろの 2 秒）。回した形は {0, 1, 5, 6}（寝息と同じ書体）。
    public static let thirdSleepMark = DigitSet([3, 4, 8, 9])
}

/// 0 時から数えるタイマーの文字（「15:32:11」）の、どの桁か。
///
/// 描き手は、右から `glyphIndexFromRight` 字目の 1 字を切り出す（`:` も 1 字に数える）。
/// 時の桁は、0 時台の「0:05:03」と 10 時台の「10:05:03」で字数が変わるので使わない。
/// 右から数える限り、秒と分の桁の位置は字数に左右されない。
public enum ClockDigit: Int, Sendable, CaseIterable {
    case secondOnes = 0
    case secondTens = 1
    case minuteOnes = 3
    case minuteTens = 4

    public var glyphIndexFromRight: Int { rawValue }

    /// 0 時からの経過秒（切り捨て）のとき、この桁に出る数字。
    func digit(ofElapsedSeconds seconds: Int) -> Int {
        switch self {
        case .secondOnes: seconds % 10
        case .secondTens: seconds % 60 / 10
        case .minuteOnes: seconds / 60 % 10
        case .minuteTens: seconds / 60 % 60 / 10
        }
    }
}

/// 窓の 1 項。タイマー 1 本の、ある桁が `digits` に入っているあいだ開く。
public struct WindowTerm: Hashable, Sendable {

    public let digits: DigitSet
    public let position: ClockDigit
    /// 起点を前へずらす秒数。表示がそのぶん進み、窓の開く時刻がそのぶん早まる。
    /// 1 秒より細かい動きは、これを 0.25 秒ずつ変えて作る（3-C ④ 原則 3）。
    public let advanceSeconds: Double

    public init(digits: DigitSet, position: ClockDigit, advanceSeconds: Double) {
        self.digits = digits
        self.position = position
        self.advanceSeconds = advanceSeconds
    }

    /// 同じ時刻に開き、書体の少なくて済む形（プラン §9 Phase 3 の 3-2b）。
    ///
    /// 秒の一の位は、表示を k 秒進めると、開く数字の集まりが k だけずれる。だから集まりを
    /// k だけ回して、そのぶん k 秒進めても、開く時刻は変わらない（{2, 7} は {0, 5} を 3 秒進めた形）。
    /// 回した集まりのうち、数字の並びがいちばん小さいものを選ぶ（同じなら回す量の小さいほう）。
    /// こうすると、まばたきの 15 通りが {0, 5} と {0, 3, 6} の 2 本の書体で足りる。
    /// ほかの桁は 10 で一周しないので、そのまま返す。
    public var canonical: WindowTerm {
        guard position == .secondOnes else { return self }
        let rotations = DigitSet.allDigits.map { shift in (shift: shift, set: digits.shifted(by: shift)) }
        guard let best = rotations.min(by: { $0.set.digits.lexicographicallyPrecedes($1.set.digits) })
        else { return self }
        return WindowTerm(digits: best.set, position: position,
                          advanceSeconds: advanceSeconds + Double(best.shift))
    }
}

/// いつ見せるか。項が 1 つならタイマー 1 本。2 つなら、マスクを入れ子にした「かつ」で 2 本。
public struct TimerWindow: Hashable, Sendable {

    public let terms: [WindowTerm]

    public init(terms: [WindowTerm]) {
        self.terms = terms
    }

    /// この窓に使うタイマーの本数。1 つのウィジェットの本数には上限がある（D-17）。
    public var timerCount: Int { terms.count }

    /// タイマー 1 本の窓。
    public static func when(_ digits: DigitSet, at position: ClockDigit = .secondOnes,
                            advancedBy seconds: Double = 0) -> TimerWindow {
        TimerWindow(terms: [WindowTerm(digits: digits, position: position, advanceSeconds: seconds)])
    }

    /// ほかの窓と「かつ」で重ねる。両方が開いているあいだだけ開く。
    public func and(_ other: TimerWindow) -> TimerWindow {
        TimerWindow(terms: terms + other.terms)
    }

    /// 同じ時刻に開き、書体の少なくて済む形（`WindowTerm.canonical`）。描き手はこちらを描く。
    public var canonical: TimerWindow { TimerWindow(terms: terms.map(\.canonical)) }

    /// その時刻に開いているか。
    ///
    /// OS がタイマーの文字を描くのと同じ数え方をなぞる: その日の 0 時からの経過秒に
    /// 進めた秒を足し、切り捨てた値の、その桁の数字が集まりに入っているか。
    /// ウィジェットはエントリの日付の 0 時から数えるので、0 時をまたいだエントリでは表示が
    /// 「24:00:05」になる。1 日の長さは夏時間の日も 10 分の倍数なので、秒の桁と分の一の位は
    /// 同じ数字になり、答えは変わらない（分の十の位は、30 分ずれる夏時間の日だけ変わりうる）。
    public func isOpen(at time: Date, calendar: Calendar) -> Bool {
        let elapsed = time.timeIntervalSince(calendar.startOfDay(for: time))
        return terms.allSatisfy { term in
            let shown = Int((elapsed + term.advanceSeconds).rounded(.down))
            return term.digits.contains(term.position.digit(ofElapsedSeconds: shown))
        }
    }
}
