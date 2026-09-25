import XCTest

/// ホーム画面（SpringBoard）に出る表示。**iOS の版や言語が変わったら、ここを直す。**
/// アプリの置き方のガイド（`PlacementGuideScreen` の `GuideStep`）も同じ表示を書いているので、一緒に直す。
///
/// シミュレータ（iPhone 17 Pro / iOS 26.5、日本語）で実際に出た表示を写した（2026-09-23）。
/// 操作が「見つからない」で止まったら、`scripts/home-screen.sh dump` で今の表示を書き出して見比べる。
enum SpringBoardText {
    /// ホーム画面のアイコンとウィジェットは、どちらもアプリの表示名で呼ばれる。
    static let appName = "CharaTime"
    /// ウィジェットの要素に付く値。アイコンには付かないので、これで見分ける。
    static let widgetValue = "ウィジェット"
    static let edit = "編集"
    static let done = "完了"
    static let addWidget = "ウィジェットを追加"
    /// ギャラリーの詳細画面の追加ボタン。**頭に空白が 1 つ付く**（＋の記号の分）。
    static let addWidgetInGallery = " ウィジェットを追加"
    static let searchWidgets = "ウィジェットを検索"
    /// 長押しメニューの「ホーム画面を編集」。表示の文字ではなく識別子で引く。
    static let rearrange = "com.apple.springboardhome.application-shortcut-item.rearrange-icons"
    static let pageControl = "Page control"
    /// ウィジェットの長押しメニューの項目と、そのあとの確かめのボタン。
    static let removeWidget = "ウィジェットを削除"
    static let confirmRemove = "削除"
    /// 編集モードの「編集」メニューの項目。外観（デフォルト・ダーク・クリア・色合い調整）を選ぶ吹き出しが開く。
    static let customize = "カスタマイズ"
    /// カスタマイズの吹き出しの右上のボタン。表示は「押すとどうなるか」で、標準のときは「大きいアプリアイコン」、
    /// 大きいときは「標準のアプリアイコン」。大きくするとアイコンの名前のラベルが消え、ウィジェットの位置も変わる。
    static let largeIcons = "大きいアプリアイコン"
    static let standardIcons = "標準のアプリアイコン"
    /// 吹き出しの外側。押すと吹き出しが閉じる（表示の文字ではなく識別子で引く）。
    static let dismissPopover = "PopoverDismissRegion"
}

/// 操作の待ち時間。アニメーションが終わる前に次を押すと、押し損ねる。
enum RobotTiming {
    /// ページをめくる・編集モードを抜けるなどのアニメーションが落ち着くまで。
    static let settleSeconds = 1.5
    /// ボタンやシートが出てくるのを待つ上限。
    static let appearTimeoutSeconds: TimeInterval = 5
    /// 長押しメニューを出す長さ。短いとタップ扱いになり、アプリが開く。
    static let longPressSeconds = 1.2
    /// ホーム画面のページ数の上限。これだけめくって見つからなければ、無いものとする。
    static let maxPages = 8
    /// ギャラリーでウィジェットの見本をめくる回数の上限。スパイクがあったころは 20 枚ほどあった。
    static let maxGallerySwipes = 30
}

/// `scripts/home-screen.sh` から受け取る引数。
///
/// xcodebuild は `TEST_RUNNER_` で始まる環境変数を、頭を外してテストに渡す。
/// スクリプト側は `TEST_RUNNER_CT_ROBOT_WIDGETS=…` の形で渡す。
struct RobotInput {

    private let environment = ProcessInfo.processInfo.environment

    /// 置くウィジェット。`表示名@大きさ` を `|` でつなぐ（例「CharaTime@大|CharaTime@中」）。
    ///
    /// 表示名（`configurationDisplayName`）は**そのまま**書く。一部分では選ばない
    /// （スパイクの「F 1 本」と「F 14 本」のように、一部分が重なる名前がありうるため）。
    /// 大きさはギャラリーの表示に合わせて「小」「中」「大」。省くと最初に見つかったもの。
    /// **1 回の実行でまとめて置く。** xcodebuild の立ち上げに 1 分ほどかかるため。
    var widgets: [WidgetChoice] {
        (text("CT_ROBOT_WIDGETS") ?? "").split(separator: "|").map { WidgetChoice(String($0)) }
    }
    /// 置く前に、置いてある CharaTime のウィジェットを全部外すか。
    var clearsFirst: Bool { environment["CT_ROBOT_CLEAR_FIRST"] == "1" }
    /// ホーム画面の外観。カスタマイズの表示のまま（「デフォルト」「ダーク」「クリア」「色合い調整」）。
    var style: String? { text("CT_ROBOT_STYLE") }
    /// 「大きいアプリアイコン」を入にするか。「on」「off」。無ければ変えない。
    var largeIcons: Bool? { text("CT_ROBOT_LARGE_ICONS").map { $0 == "on" } }
    /// 行って戻る（他のアプリを開いてからホーム画面に戻る）回数。
    var cycles: Int { Int(environment["CT_ROBOT_CYCLES"] ?? "") ?? Self.defaultCycles }
    /// 他のアプリを開いておく秒数。
    var awaySeconds: Double { seconds("CT_ROBOT_AWAY_SECONDS", default: Self.defaultAwaySeconds) }
    /// ホーム画面に戻ってから、次に出ていくまでの秒数。戻った直後の様子を撮るための間。
    var homeSeconds: Double { seconds("CT_ROBOT_HOME_SECONDS", default: Self.defaultHomeSeconds) }
    /// 「用意ができた」と知らせてから、最初に出ていくまでの秒数。スクリプトが収録を始める間。
    var leadSeconds: Double { seconds("CT_ROBOT_LEAD_SECONDS", default: Self.defaultLeadSeconds) }

    static let defaultCycles = 3
    static let defaultAwaySeconds = 3.0
    static let defaultHomeSeconds = 4.0
    /// 収録は「Recording started」まで 1 秒かからない。落ち着いたホーム画面を数秒撮っておくと、
    /// 数える側がそれを「ホーム画面の姿」の手本にできる。
    static let defaultLeadSeconds = 4.0

    private func text(_ key: String) -> String? {
        environment[key].flatMap { $0.isEmpty ? nil : $0 }
    }

    private func seconds(_ key: String, default fallback: Double) -> Double {
        Double(environment[key] ?? "") ?? fallback
    }
}

/// 置くウィジェット 1 つ。`表示名@大きさ` の形から読む。
struct WidgetChoice {
    let name: String
    let family: String?

    init(_ text: String) {
        let parts = text.split(separator: "@", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        name = parts.first ?? ""
        family = parts.count > 1 && !parts[1].isEmpty ? parts[1] : nil
    }
}

/// ロボットの出力。**1 行 1 件の JSON で、頭に `CTROBOT ` を付ける。**
///
/// xcodebuild の出力には大量のログが混ざる。スクリプトはこの頭の行だけを拾う。
enum RobotOutput {

    static let prefix = "CTROBOT "

    static func emit<Record: Encodable>(_ record: Record) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(record), let line = String(data: data, encoding: .utf8) else {
            print(prefix + #"{"kind":"error","message":"出力を JSON にできませんでした"}"#)
            return
        }
        print(prefix + line)
    }

    /// 画面の要素をまるごと書き出す。表示が変わって操作が止まったときに、ここを読んで直す。
    static func dump(_ tag: String, _ text: String) {
        print("CTROBOT-DUMP-BEGIN \(tag)")
        print(text)
        print("CTROBOT-DUMP-END \(tag)")
    }
}

/// ホーム画面に見えている CharaTime のウィジェット 1 つ。
struct WidgetRecord: Encodable {
    let kind = "widget"
    /// ウィジェットの本体の枠（pt）。下のラベルは含まない。[x, y, 幅, 高さ]。
    let frame: [Double]
    /// 大きさ（small / medium / large）。本体の枠から読む。
    let family: String
    /// ウィジェットの中の文字。表題でどれかを見分ける（`Text(timerInterval:)` の今の値も入る）。
    let texts: [String]
}

/// 画面とページの様子。ウィジェットの枠を画素に直すときの基準になる。
struct PageRecord: Encodable {
    let kind = "page"
    /// 画面の大きさ（pt）。
    let screen: [Double]
    /// 「全3ページ中の2ページ目」の 2 と 3。
    let page: Int?
    let pages: Int?
    /// 書き出した時刻（ISO 8601、ミリ秒まで）。撮った画像や動画の時刻と突き合わせる。
    let at: String
}

/// 「用意ができた」の知らせ。スクリプトはこれを見てから画面収録を始める。
struct ReadyRecord: Encodable {
    let kind = "ready"
    let at: String
}

/// 行って戻る 1 回ぶんの記録。戻った瞬間の時刻を、画面収録の読み取りと突き合わせる。
struct ResumeRecord: Encodable {
    let kind = "resume"
    let cycle: Int
    /// ホームボタンを押した時刻（ISO 8601、ミリ秒まで）。
    let homeAt: String
}

enum RobotClock {
    /// ミリ秒まで出す。画面収録の 1 コマ（60fps で約 17 ミリ秒）と比べられる細かさにする。
    static func now() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        // 人が読むので、その端末の時刻で出す（「+09:00」付き）。
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }
}

/// 待つ。XCTest の `sleep` は整数の秒しか取らないので、小数で待てるようにする。
func pause(_ seconds: Double) {
    Thread.sleep(forTimeInterval: seconds)
}
