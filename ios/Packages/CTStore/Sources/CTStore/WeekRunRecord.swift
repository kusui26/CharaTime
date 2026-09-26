import Foundation

/// 1 週間の運用（プラン §9 Phase 3 の 3-7）の記録表のうち、利用者が毎日つける分。
///
/// 作り直した時刻やメモリは、ウィジェットの記録（`WidgetDiagnostics`）が自動で残す。こちらは人の目で
/// 見て分かること（キャラが見えていたか、まばたきしていたか、アプリと同じ姿か、電池）と、一度だけ
/// 確かめること（3-E の表）の結果を持つ。**書くのはアプリだけ**で、ウィジェットは読まない。
///
/// **1 か所が壊れても、ほかは生かす。** 1 週間かけてつけた記録を、1 つの値の壊れで失わない。
public struct WeekRunRecord: Codable, Sendable, Equatable {

    /// 始めた時刻。nil なら、まだ始めていない。
    public var startedAt: Date?
    /// 日ごとの記録（日の順）。つけていない日は入らない。
    public var days: [WeekRunDay]
    /// 一度だけ確かめることの結果。キーは項目の名前（CTRender の `WeekRunPlan` の項目が決める）。
    public var checks: [String: WeekRunCheck]

    public init(startedAt: Date? = nil, days: [WeekRunDay] = [], checks: [String: WeekRunCheck] = [:]) {
        self.startedAt = startedAt
        self.days = days
        self.checks = checks
    }

    /// その日の記録。まだつけていなければ空の記録。
    public func day(_ number: Int) -> WeekRunDay {
        days.first { $0.number == number } ?? WeekRunDay(number: number)
    }

    /// その日の記録を書き換えた記録表。日の順に並べ直す。
    public func updatingDay(_ number: Int, _ change: (inout WeekRunDay) -> Void) -> WeekRunRecord {
        var changed = day(number)
        change(&changed)
        var updated = self
        updated.days = (days.filter { $0.number != number } + [changed]).sorted { $0.number < $1.number }
        return updated
    }

    /// 一度だけ確かめることの結果。まだなら空。
    public func check(_ id: String) -> WeekRunCheck {
        checks[id] ?? WeekRunCheck()
    }

    /// その項目の結果を書き換えた記録表。
    public func updatingCheck(_ id: String, _ change: (inout WeekRunCheck) -> Void) -> WeekRunRecord {
        var changed = check(id)
        change(&changed)
        var updated = self
        updated.checks[id] = changed
        return updated
    }

    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        startedAt = try? box.decodeIfPresent(Date.self, forKey: .startedAt)
        days = (try? box.decodeIfPresent([Lossy<WeekRunDay>].self, forKey: .days))?.compactMap(\.value) ?? []
        checks = (try? box.decodeIfPresent([String: Lossy<WeekRunCheck>].self, forKey: .checks))?
            .compactMapValues(\.value) ?? [:]
    }
}

/// 答え。毎日の問いでは「はい／いいえ」、一度だけ確かめることでは「期待どおり／ちがった」と見せる。
public enum WeekRunAnswer: String, Codable, Sendable, CaseIterable {
    case yes
    case no
}

/// 1 日の記録。
public struct WeekRunDay: Codable, Sendable, Equatable {

    /// 何日目か（始めた日が 1）。
    public var number: Int
    /// キャラが見えていた（消えていない）。
    public var characterVisible: WeekRunAnswer?
    /// まばたき・寝息が動いていた（疑似アニメが入の日）。
    public var animating: WeekRunAnswer?
    /// 姿が切り替わった直後にアプリを開いて、同じ行動・同じ場所だった（R-20。Gate 3 は 5 回）。
    public var matchesApp: WeekRunAnswer?
    /// 設定 → バッテリーで読んだ値（Q-15）。読む日だけ。
    public var battery: BatteryUsage?
    public var note: String

    public init(number: Int, characterVisible: WeekRunAnswer? = nil, animating: WeekRunAnswer? = nil,
                matchesApp: WeekRunAnswer? = nil, battery: BatteryUsage? = nil, note: String = "") {
        self.number = number
        self.characterVisible = characterVisible
        self.animating = animating
        self.matchesApp = matchesApp
        self.battery = battery
        self.note = note
    }

    /// 何日目かが読めなければ、その日ごと捨てる（どの日の記録か分からない）。ほかの値は 1 つずつ読む。
    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        number = try box.decode(Int.self, forKey: .number)
        characterVisible = try? box.decodeIfPresent(WeekRunAnswer.self, forKey: .characterVisible)
        animating = try? box.decodeIfPresent(WeekRunAnswer.self, forKey: .animating)
        matchesApp = try? box.decodeIfPresent(WeekRunAnswer.self, forKey: .matchesApp)
        battery = try? box.decodeIfPresent(BatteryUsage.self, forKey: .battery)
        note = (try? box.decodeIfPresent(String.self, forKey: .note)) ?? ""
    }
}

/// 設定 → バッテリー →「過去 24 時間」で読んだ値（Q-15）。
public struct BatteryUsage: Codable, Sendable, Equatable {

    /// CharaTime の行（%）。一覧に出ていなければ 0 と書く。
    public var charaTimePercent: Int?
    /// 「ホーム画面とロック画面」の行（%）。タイマーの字を毎秒描き直すのは OS なので、こちらに付く恐れがある。
    public var homeAndLockPercent: Int?
    /// 読んだ時刻（書いたときに入る）。24 時間の窓が、入か切の時間にそろっていたかを後で確かめる。
    public var readAt: Date?

    public init(charaTimePercent: Int? = nil, homeAndLockPercent: Int? = nil, readAt: Date? = nil) {
        self.charaTimePercent = charaTimePercent
        self.homeAndLockPercent = homeAndLockPercent
        self.readAt = readAt
    }

    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        charaTimePercent = try? box.decodeIfPresent(Int.self, forKey: .charaTimePercent)
        homeAndLockPercent = try? box.decodeIfPresent(Int.self, forKey: .homeAndLockPercent)
        readAt = try? box.decodeIfPresent(Date.self, forKey: .readAt)
    }
}

/// 一度だけ確かめることの結果。
public struct WeekRunCheck: Codable, Sendable, Equatable {

    public var answer: WeekRunAnswer?
    public var note: String
    /// 答えた時刻。ウィジェットの記録（作り直した時刻）と見比べる。
    public var answeredAt: Date?

    public init(answer: WeekRunAnswer? = nil, note: String = "", answeredAt: Date? = nil) {
        self.answer = answer
        self.note = note
        self.answeredAt = answeredAt
    }

    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        answer = try? box.decodeIfPresent(WeekRunAnswer.self, forKey: .answer)
        note = (try? box.decodeIfPresent(String.self, forKey: .note)) ?? ""
        answeredAt = try? box.decodeIfPresent(Date.self, forKey: .answeredAt)
    }
}
