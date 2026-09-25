import XCTest

/// シミュレータのホーム画面（SpringBoard）。見る・めくる・編集モード・カスタマイズを受け持つ。
/// 置く（`WidgetGallery.swift`）と外す（`WidgetRemoval.swift`）は別のファイル。
///
/// **ロボットの作業場所は「CharaTime のウィジェットがあるページ」。** まだ 1 つも無ければ、
/// アプリのアイコンがあるページ。ウィジェットを置くとアイコンが次のページへ押し出されることが
/// あるので、アイコンよりウィジェットを先に探す。
@MainActor
struct HomeScreen {

    let springboard: XCUIApplication

    init() {
        springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        Self.skipQuiescenceWaits(of: springboard)
    }

    /// XCTest の「アプリが静かになるまで待つ」を外す。
    ///
    /// ホーム画面は静かにならない。編集モードではアイコンが揺れ続け、疑似アニメのウィジェットは
    /// 毎秒描き直される。XCTest は操作のたびに最大 60 秒待ってから諦めるので、1 回置くだけで
    /// 2 分かかっていた（2026-09-23、シミュレータで計測）。
    ///
    /// **非公開の設定**（`XCUIApplication` の `currentInteractionOptions`。Xcode 26.6 の XCUIAutomation にある）。
    /// 設定が無い版では何もしない（遅くなるだけで、動きは変わらない）。待ちを外した代わりに、
    /// 操作のあとは `RobotTiming` の時間だけ待ち、次に押す要素は出てくるのを待ってから押す。
    private static func skipQuiescenceWaits(of app: XCUIApplication) {
        guard app.responds(to: NSSelectorFromString("setCurrentInteractionOptions:")) else { return }
        app.setValue(skipPreAndPostEventQuiescence, forKey: "currentInteractionOptions")
    }

    /// `XCUIApplicationInteractionOptionSkipPreEventQuiescence`（1）と
    /// `…SkipPostEventQuiescence`（2）を合わせたもの。
    private static let skipPreAndPostEventQuiescence: UInt = 3

    // MARK: - 見る

    /// 画面の大きさ（pt）。ページの外にある要素を見分けるのに使う。
    var screenFrame: CGRect { springboard.windows.firstMatch.frame }

    /// いま見えているページにある CharaTime のウィジェット。上から、左から順に並べる。
    func visibleWidgets() -> [XCUIElement] {
        let screen = screenFrame
        return charaTimeIcons()
            .filter { isWidget($0) && !$0.frame.isEmpty && screen.intersects($0.frame) }
            .sorted { ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX) }
    }

    /// いま見えているページにある CharaTime のアイコン。無ければ nil。
    func visibleAppIcon() -> XCUIElement? {
        charaTimeIcons().first { !isWidget($0) && $0.isHittable }
    }

    /// ページの表示（「全3ページ中の2ページ目」）から、いまのページと全体のページ数を読む。
    func pagePosition() -> (current: Int, total: Int)? {
        let control = springboard.pageIndicators[SpringBoardText.pageControl]
        guard control.exists, let value = control.value as? String else { return nil }
        let numbers = value.split { !$0.isNumber }.compactMap { Int($0) }
        guard numbers.count == 2 else { return nil }
        return (current: numbers[1], total: numbers[0])
    }

    /// ウィジェットの本体の枠。アイコンの要素はラベルまで含むので、中の「CharaTime」と
    /// 名乗る要素の枠を使う。見つからなければ要素の枠で代用する。
    func bodyFrame(of widget: XCUIElement) -> CGRect {
        let body = widget.otherElements.matching(NSPredicate(format: "label == %@", SpringBoardText.appName))
            .firstMatch
        return body.exists ? body.frame : widget.frame
    }

    /// ウィジェット 1 つを書き出す形にする。
    func record(of widget: XCUIElement) -> WidgetRecord {
        let frame = bodyFrame(of: widget)
        return WidgetRecord(frame: [frame.minX, frame.minY, frame.width, frame.height],
                            family: Self.family(of: frame.size),
                            texts: widget.staticTexts.allElementsBoundByIndex.map(\.label))
    }

    /// 本体の大きさから、小・中・大を読む。小は 164pt 角、中は幅 350pt、大は高さ 365pt
    /// （402×874pt の iPhone、iOS 26.5 の実測。ラベルなしでは 170pt 角・幅 360pt・高さ 359pt。
    /// プラン §9 Phase 3 の 3-C ①）。境目はそのあいだに取る。
    static func family(of size: CGSize) -> String {
        if size.height > familyBoundaryPoints { return "large" }
        return size.width > familyBoundaryPoints ? "medium" : "small"
    }

    private static let familyBoundaryPoints: CGFloat = 250

    private func charaTimeIcons() -> [XCUIElement] {
        springboard.icons.matching(identifier: SpringBoardText.appName).allElementsBoundByIndex
    }

    private func isWidget(_ icon: XCUIElement) -> Bool {
        (icon.value as? String)?.contains(SpringBoardText.widgetValue) == true
    }

    // MARK: - めくる

    /// 編集モードやシートを畳み、ホーム画面の 1 ページ目に戻す。
    func settle() {
        let done = springboard.buttons[SpringBoardText.done]
        if done.exists && done.isHittable {
            done.tap()
            pause(RobotTiming.settleSeconds)
        }
        // アプリの中からは 1 回目でホーム画面へ、2 回目で 1 ページ目へ戻る。
        XCUIDevice.shared.press(.home)
        pause(RobotTiming.settleSeconds)
        XCUIDevice.shared.press(.home)
        pause(RobotTiming.settleSeconds)
    }

    /// ロボットの作業場所になるページへ行く。
    ///
    /// 1 ページ目から 1 回だけめくっていき、ウィジェットがあるページで止まる。無ければ最後まで見て、
    /// アイコンがあったページへ戻る。
    func goToRobotPage() {
        settle()
        var iconPage: Int?   // 見て回るあいだに、アイコンがあったページを覚えておく
        for _ in 0..<RobotTiming.maxPages {
            if !visibleWidgets().isEmpty { return }
            let position = pagePosition()
            if iconPage == nil, visibleAppIcon() != nil { iconPage = position?.current ?? 1 }
            guard let position, position.current < position.total, nextPage() else { break }
        }
        guard let iconPage else {
            return fail("CharaTime のウィジェットもアイコンも見つかりません。アプリが入っているか確かめてください")
        }
        settle()
        for _ in 1..<iconPage { nextPage() }
    }

    /// 次のページへめくる。めくれたら true。
    ///
    /// ページの表示の数字で、本当に 1 ページ進んだかを確かめる。springboard が落ち着く前にめくると
    /// 空振りすることがあるので、進まなければもう 1 回だけめくる。
    @discardableResult
    func nextPage() -> Bool {
        let before = pagePosition()?.current
        for _ in 0..<Self.swipeAttempts {
            springboard.swipeLeft()
            pause(RobotTiming.settleSeconds)
            if let before, let after = pagePosition()?.current, after > before { return true }
        }
        return false
    }

    /// めくりを試す回数。1 回目が空振りしても、2 回目はまず通る。
    private static let swipeAttempts = 2

    /// 要素が見つからないときに、画面の要素を書き出してから止める。
    /// 表示の文字が変わったのか、画面が違うのかを、あとで書き出しを読んで見分ける。
    func fail(_ message: String) {
        RobotOutput.dump("failure", springboard.debugDescription)
        XCTFail(message)
    }

    /// 要素が出てくるのを待つ。出てこなければ、画面を書き出して止める。
    @discardableResult
    func require(_ element: XCUIElement, _ message: String) -> Bool {
        if element.waitForExistence(timeout: RobotTiming.appearTimeoutSeconds) { return true }
        fail(message)
        return false
    }

    // MARK: - 編集モード

    /// ホーム画面の編集モード（アイコンが揺れる状態）に入る。
    ///
    /// 空き地を長押しする代わりに、このページにある CharaTime のウィジェットかアイコンを長押しし、
    /// 出てきたメニューの「ホーム画面を編集」を押す。空き地の位置はページごとに違うため。
    func enterEditMode() {
        guard let handle = visibleWidgets().first ?? visibleAppIcon() else {
            return fail("このページに CharaTime のウィジェットもアイコンも無いので、編集モードに入れません")
        }
        handle.press(forDuration: RobotTiming.longPressSeconds)
        let rearrange = springboard.buttons[SpringBoardText.rearrange]
        guard require(rearrange, "長押しメニューに「ホーム画面を編集」が出ません") else { return }
        rearrange.tap()
        require(springboard.buttons[SpringBoardText.edit], "編集モードに入れません")
    }

    /// 編集モードのまま、最後のページまでめくる。その先に空のページがあれば、そこで止まる（3-3）。
    ///
    /// アイコンもウィジェットも無いページ（Dock より上に何も無い）でなければ、止めて画面を書き出す。
    func goToEmptyPage() {
        // 最後のページで止める。その先へめくると、アプリライブラリに入ってしまう。
        for _ in 0..<RobotTiming.maxPages {
            guard let position = pagePosition(), position.current < position.total, nextPage() else { break }
        }
        if !pageAboveDockIsEmpty() {
            fail("編集モードで最後までめくっても、空のページがありません")
        }
    }

    /// いま見えているページの、Dock より上にアイコンもウィジェットも無いか。
    private func pageAboveDockIsEmpty() -> Bool {
        let screen = screenFrame
        let dockTop = screen.height * Self.dockTopRatio
        return springboard.icons.allElementsBoundByIndex.allSatisfy { icon in
            let frame = icon.frame
            return frame.isEmpty || !screen.intersects(frame) || frame.midY > dockTop
        }
    }

    /// Dock の上端（画面の高さに対する比）。402×874pt で Dock のアイコンは y = 770pt あたりから下にある。
    private static let dockTopRatio: CGFloat = 0.85

    /// 「カスタマイズ」で外観と、アプリアイコンの大きさを変える。どちらも nil なら変えない。
    func customize(style: String?, largeIcons: Bool?) {
        enterEditMode()
        springboard.buttons[SpringBoardText.edit].tap()
        let item = springboard.buttons[SpringBoardText.customize]
        guard require(item, "「カスタマイズ」が出ません") else { return }
        item.tap()
        if let style {
            let button = springboard.buttons[style]
            guard require(button, "外観「\(style)」が出ません") else { return }
            button.tap()
            pause(RobotTiming.settleSeconds)
        }
        if let largeIcons {
            // ボタンの表示は「押すとどうなるか」。標準のときは「大きいアプリアイコン」、
            // 大きいときは「標準のアプリアイコン」と出る。欲しい側の表示が出ていれば押す。
            let toggle = springboard.buttons.matching(NSPredicate(
                format: "label IN %@", [SpringBoardText.largeIcons, SpringBoardText.standardIcons])).firstMatch
            guard require(toggle, "アイコンの大きさを変えるボタンが出ません") else { return }
            if toggle.label == (largeIcons ? SpringBoardText.largeIcons : SpringBoardText.standardIcons) {
                toggle.tap()
                pause(RobotTiming.settleSeconds)
            }
        }
        // カスタマイズは吹き出しで出る。外側（閉じるための領域）を押して閉じる。
        springboard.otherElements[SpringBoardText.dismissPopover].tap()
        pause(RobotTiming.settleSeconds)
        finishEditing()
    }

    /// 編集モードを抜ける。
    func finishEditing() {
        let done = springboard.buttons[SpringBoardText.done]
        if done.waitForExistence(timeout: RobotTiming.appearTimeoutSeconds) { done.tap() }
        pause(RobotTiming.settleSeconds)
    }
}
