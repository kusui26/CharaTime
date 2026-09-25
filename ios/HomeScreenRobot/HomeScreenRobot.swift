import XCTest

/// シミュレータのホーム画面を操作するロボット（プラン §9 Phase 3 の 3-0d、D-24）。
///
/// **テストではなく道具。** テストメソッド 1 つが操作 1 つに当たり、`scripts/home-screen.sh` が
/// `-only-testing` で選んで呼ぶ。確かめごと（assert）を足してテストを増やさないこと。
/// 見た目の判断は、スクリプトが撮った画像と画面収録を読んで行う。
///
/// **操作のあと、画面はそのままにして終わる。** 撮るのはスクリプトの側なので、
/// 「編集モードに入ったまま」「ロボットのページを出したまま」で終わることに意味がある。
@MainActor
final class HomeScreenRobot: XCTestCase {

    private let home = HomeScreen()
    private let input = RobotInput()

    /// ロボットのページ（CharaTime のウィジェットがあるページ）を出す。撮る前の準備。
    func testShow() {
        continueAfterFailure = false
        home.goToRobotPage()
        report()
    }

    /// ウィジェットを置く。`CT_ROBOT_WIDGETS`（`表示名@大きさ` を `|` でつないだもの）で選ぶ。
    ///
    /// あとから置いたものがページの左上に入り、先に置いたものは右・下へ押し出される（ホーム画面の決まり）。
    func testPlace() {
        continueAfterFailure = false
        let choices = input.widgets
        guard !choices.isEmpty else {
            return XCTFail("CT_ROBOT_WIDGETS に、置くウィジェットを「表示名@大きさ」で入れてください")
        }
        if input.clearsFirst { home.removeAllWidgets() }
        for choice in choices {
            home.goToRobotPage()
            home.placeWidget(named: choice.name, family: choice.family)
        }
        home.goToRobotPage()
        report()
    }

    /// 置いてある CharaTime のウィジェットを、すべてのページから外す。
    func testClear() {
        continueAfterFailure = false
        home.removeAllWidgets()
        home.goToRobotPage()
        report()
    }

    /// ロボットのページにある CharaTime のウィジェットの枠と文字を書き出す。
    func testReport() {
        continueAfterFailure = false
        home.goToRobotPage()
        report()
    }

    /// 他のアプリ（設定）を開いてからホーム画面へ戻る、を繰り返す。
    ///
    /// 戻った直後に疑似アニメがすぐ動き出すかを、画面収録で測るための操作（3-0b）。
    /// 実機のスパイク E（タイマー約 14 本）は、戻った直後に約 1 秒止まった（`docs/260912_spike.md` 3-6）。
    ///
    /// **ロボットのページを出してから「用意ができた」と知らせ、少し待ってから始める。**
    /// xcodebuild がテストを始めるとホーム画面は 1 ページ目に戻るので、先にめくっておかないと、
    /// 設定から戻る先が 1 ページ目になる。スクリプトは知らせを見てから収録を始めるので、
    /// ページをめくる動きは収録に入らない。
    func testResume() {
        continueAfterFailure = false
        home.goToRobotPage()
        report()
        RobotOutput.emit(ReadyRecord(at: RobotClock.now()))
        pause(input.leadSeconds)
        let settings = XCUIApplication(bundleIdentifier: Self.settingsBundleID)
        for cycle in 1...max(1, input.cycles) {
            settings.activate()
            pause(input.awaySeconds)
            XCUIDevice.shared.press(.home)
            RobotOutput.emit(ResumeRecord(cycle: cycle, homeAt: RobotClock.now()))
            pause(input.homeSeconds)
        }
    }

    /// ロボットのページで編集モードに入り、**そのまま終わる**。編集モードの画面を撮るため（3-0c）。
    func testEdit() {
        continueAfterFailure = false
        home.goToRobotPage()
        home.enterEditMode()
        report()
    }

    /// 編集モードで最後のページの先にある空のページへめくり、**そのまま終わる**（透過背景の材料。3-3）。
    ///
    /// 利用者が壁紙のスクショを撮るのと同じ手順。スクリプトが撮ったあと、`testSettle` で戻す。
    func testEmptyPage() {
        continueAfterFailure = false
        home.goToRobotPage()
        home.enterEditMode()
        home.goToEmptyPage()
        report()
    }

    /// ホーム画面の外観（編集 → カスタマイズ）を切り替える。
    ///
    /// `CT_ROBOT_STYLE` に「デフォルト」「ダーク」「クリア」「色合い調整」（＝着色）。クリアと着色では、
    /// ウィジェットは accented で描かれる（背景が外れ、中身が単色になる。プラン §9 Phase 3 の 3-C ⑤）。
    /// `CT_ROBOT_LARGE_ICONS` に「on」「off」で、「大きいアプリアイコン」（名前のラベルが消え、
    /// ウィジェットの位置も変わる）を合わせる。
    func testStyle() {
        continueAfterFailure = false
        home.goToRobotPage()
        home.customize(style: input.style, largeIcons: input.largeIcons)
        home.goToRobotPage()
        report()
    }

    /// 編集モードを抜け、ホーム画面の 1 ページ目に戻す。
    func testSettle() {
        home.settle()
    }

    /// ギャラリーにある CharaTime のウィジェットの見本を、すべて書き出す（置ける名前と大きさの一覧）。
    func testGallery() {
        continueAfterFailure = false
        home.goToRobotPage()
        for preview in home.listGallery() {
            RobotOutput.emit(preview)
        }
        home.settle()
    }

    /// 画面の要素をまるごと書き出す。表示が変わって操作が止まったときに読む。
    func testDump() {
        RobotOutput.dump("springboard", home.springboard.debugDescription)
    }

    /// 設定アプリ。どのシミュレータにも入っていて、開くと画面全体を覆う。
    private static let settingsBundleID = "com.apple.Preferences"

    private func report() {
        let screen = home.screenFrame
        let position = home.pagePosition()
        RobotOutput.emit(PageRecord(screen: [screen.width, screen.height], page: position?.current,
                                    pages: position?.total, at: RobotClock.now()))
        for widget in home.visibleWidgets() {
            RobotOutput.emit(home.record(of: widget))
        }
    }
}
