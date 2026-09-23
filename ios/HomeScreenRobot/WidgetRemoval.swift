import XCTest

/// ウィジェットを外す、ギャラリーの見本を数える。
@MainActor
extension HomeScreen {

    /// 置いてある CharaTime のウィジェットを、すべてのページから外す。
    ///
    /// 1 つ外すたびにページの並びが変わる（あとの要素が詰まる）ので、毎回 1 ページ目から探し直す。
    func removeAllWidgets() {
        for _ in 0..<Self.maxRemovals {
            settle()
            guard goToPageWithWidgets(), let widget = visibleWidgets().first else { return }
            remove(widget)
        }
        fail("\(Self.maxRemovals) 個外しても、まだ CharaTime のウィジェットが残っています")
    }

    /// 長押しメニューの「ウィジェットを削除」から外す。確かめの「削除」まで押す。
    private func remove(_ widget: XCUIElement) {
        widget.press(forDuration: RobotTiming.longPressSeconds)
        let item = springboard.buttons[SpringBoardText.removeWidget]
        guard require(item, "長押しメニューに「ウィジェットを削除」が出ません") else { return }
        item.tap()
        let confirm = springboard.alerts.buttons[SpringBoardText.confirmRemove]
        guard require(confirm, "削除の確かめが出ません") else { return }
        confirm.tap()
        pause(RobotTiming.settleSeconds)
    }

    /// 1 ページ目から順にめくり、CharaTime のウィジェットがあるページで止まる。無ければ false。
    private func goToPageWithWidgets() -> Bool {
        for _ in 0..<RobotTiming.maxPages {
            if !visibleWidgets().isEmpty { return true }
            guard let position = pagePosition(), position.current < position.total, nextPage() else { return false }
        }
        return false
    }

    /// 外す数の上限。ページをまたいで置きすぎていても、ここで止める。
    private static let maxRemovals = 24

    /// ギャラリーにある CharaTime のウィジェットの見本を、すべて数える。
    ///
    /// 見本は横にめくる並びで、画面の要素に出てくるのは前後の数枚だけ。めくりながら集め、
    /// 2 回めくっても新しいものが出てこなくなったら終わりとする。
    func listGallery() -> [PreviewRecord] {
        openGallery()
        var found: [PreviewRecord] = []   // 見つけた順に貯める（めくるたびに増える）
        var quietSwipes = 0
        for _ in 0..<RobotTiming.maxGallerySwipes where quietSwipes < Self.quietSwipesToStop {
            let fresh = galleryPreviews.allElementsBoundByIndex
                .map { PreviewRecord(label: $0.label, value: $0.value as? String) }
                .filter { !found.contains($0) }
            found += fresh
            quietSwipes = fresh.isEmpty ? quietSwipes + 1 : 0
            swipeToNextPreview()
        }
        return found
    }

    /// 新しい見本が出ないままめくった回数が、これに達したら端まで来たとみなす。
    private static let quietSwipesToStop = 2
}

/// ギャラリーの見本 1 つ。`label` は「CharaTime, <表示名>」、`value` は「ウィジェット, 大」の形。
struct PreviewRecord: Encodable, Equatable {
    let kind = "preview"
    let name: String
    let family: String?

    init(label: String, value: String?) {
        name = label.components(separatedBy: ", ").dropFirst().joined(separator: ", ")
        family = value?.components(separatedBy: ", ").last
    }
}
