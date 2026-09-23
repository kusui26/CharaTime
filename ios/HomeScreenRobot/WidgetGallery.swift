import XCTest

/// ウィジェットを置く（ギャラリーから選んで追加する）。
///
/// 手順は人が指でやるのと同じ: 編集モード → 「編集」→「ウィジェットを追加」→ アプリ名で検索 →
/// CharaTime を開く → 見本を横にめくって目当てのものを出す →「ウィジェットを追加」→「完了」。
/// **ギャラリーの検索はアプリの名前でしか引けない**（ウィジェットの表示名では出てこない）。
@MainActor
extension HomeScreen {

    /// 表示名が `name` で、大きさが `family`（「小」「中」「大」）のウィジェットを、いまのページに置く。
    func placeWidget(named name: String, family: String?) {
        openGallery()
        guard revealPreview(named: name, family: family) else {
            return fail("ギャラリーに「\(name)」\(family.map { "（\($0)）" } ?? "") がありません。"
                        + "scripts/home-screen.sh gallery で、置ける名前と大きさを確かめてください")
        }
        let add = springboard.buttons[SpringBoardText.addWidgetInGallery]
        guard require(add, "ギャラリーの「ウィジェットを追加」が出ません") else { return }
        add.tap()
        pause(RobotTiming.settleSeconds)
        finishEditing()
    }

    /// ギャラリーを開き、CharaTime のウィジェットの見本を出す。
    func openGallery() {
        enterEditMode()
        springboard.buttons[SpringBoardText.edit].tap()
        let add = springboard.buttons[SpringBoardText.addWidget]
        guard require(add, "「ウィジェットを追加」が出ません") else { return }
        add.tap()
        let search = springboard.searchFields[SpringBoardText.searchWidgets]
        guard require(search, "ギャラリーが開きません") else { return }
        search.tap()
        search.typeText(SpringBoardText.appName)
        let cell = springboard.cells[SpringBoardText.appName]
        guard require(cell, "ギャラリーの検索で CharaTime が出ません。アプリが入っているか確かめてください") else { return }
        cell.tap()
        pause(RobotTiming.settleSeconds)
    }

    /// ギャラリーの見本（CharaTime のもの）。表示は「CharaTime, <表示名>」、値は「ウィジェット, 大」の形。
    var galleryPreviews: XCUIElementQuery {
        springboard.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(SpringBoardText.appName), "))
    }

    /// 見本を横にめくって、目当てのウィジェットを前に出す。出せたら true。
    private func revealPreview(named name: String, family: String?) -> Bool {
        let target = galleryPreviews.matching(Self.previewPredicate(name: name, family: family)).firstMatch
        for _ in 0..<RobotTiming.maxGallerySwipes {
            if target.exists && target.isHittable { return true }
            swipeToNextPreview()
        }
        return false
    }

    /// 見本を 1 枚めくる。**いま見えている見本の上で**めくる。前後の見本も要素としては
    /// 並んでいるので、最初に見つかったものの上でめくると、画面の外をなでて空振りする。
    func swipeToNextPreview() {
        let current = galleryPreviews.allElementsBoundByIndex.first { $0.isHittable }
        (current ?? springboard).swipeLeft()
        pause(RobotTiming.settleSeconds / 2)
    }

    private static func previewPredicate(name: String, family: String?) -> NSPredicate {
        let byName = NSPredicate(format: "label == %@", "\(SpringBoardText.appName), \(name)")
        guard let family else { return byName }
        let byFamily = NSPredicate(format: "value ENDSWITH %@", ", \(family)")
        return NSCompoundPredicate(andPredicateWithSubpredicates: [byName, byFamily])
    }
}
