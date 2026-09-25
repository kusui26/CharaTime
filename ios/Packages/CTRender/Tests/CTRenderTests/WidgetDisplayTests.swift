import Testing
import SwiftUI
@testable import CTRender

/// ウィジェットの見え方ごとの描き方（プラン §9 Phase 3 の 3-C ⑨、3-5 StandBy）。
@Suite("ウィジェットの見え方")
struct WidgetDisplayTests {

    /// 着色・クリアの外観（OS が背景を外し、透明度だけで描く）。
    static let tinted = WidgetDisplay(tone: .accented, showsBackground: false)

    @Test("部屋を描くのは、ふつうのホーム画面だけ（D-28）")
    func drawsRoomOnlyOnHomeScreen() {
        #expect(WidgetDisplay.homeScreen.drawsRoom)
        #expect(!WidgetDisplay.standByDay.drawsRoom)
        #expect(!WidgetDisplay.standByNight.drawsRoom)
        #expect(!Self.tinted.drawsRoom)
    }

    /// StandBy の昼は黒の上、夜は明るさだけの赤。どちらも濃い字や線が消える。
    /// 着色・クリアは透明度だけで描かれるので、色を変えなくても読める。
    @Test("後ろが暗いのは StandBy の昼と夜だけ")
    func darkBackdropOnlyInStandBy() {
        #expect(!WidgetDisplay.homeScreen.hasDarkBackdrop)
        #expect(!Self.tinted.hasDarkBackdrop)
        #expect(WidgetDisplay.standByDay.hasDarkBackdrop)
        #expect(WidgetDisplay.standByNight.hasDarkBackdrop)
    }

    @Test("吹き出しの塗り方は描き分けで決まる（夜の赤は地なしで淡い字）")
    func bubblePaintFollowsTone() {
        #expect(BubblePaint(.fullColor) == .paper)
        #expect(BubblePaint(.accented) == .faint)
        #expect(BubblePaint(.vibrant) == .glow)
    }

    /// 昼寝の z は昼の配色だと焦げ茶で、StandBy の黒の上では見えない。
    @Test("後ろが暗いときは、z や時計の字を淡い色にする。ほかの色はそのまま")
    func lightInkOverDarkness() {
        let day = RoomPalette.day
        let over = WidgetDisplay.standByDay.palette(day)
        #expect(over.clockInk == RoomPalette.night.clockInk)
        #expect(over.outline == day.outline)
        #expect(over.wall == day.wall)
        #expect(WidgetDisplay.homeScreen.palette(day) == day)
        #expect(Self.tinted.palette(day) == day)
        #expect(WidgetDisplay.standByNight.palette(.night) == .night)
    }

    /// StandBy の夜は単色で細かい動きが読めないので、5 分ごとの切り替え（3-C ⑤）。
    /// 昼は背景が外れるだけなので、ホーム画面と同じだけ動かす。
    @Test("StandBy の夜は 5 分ごとの切り替え、昼はホーム画面と同じ段")
    func standByCapability() {
        let moving = WidgetMotion(pseudoAnimation: true, lowPowerMode: false)
        let system = SystemVersion(major: 26, minor: 1)
        #expect(WidgetDisplay.standByNight.capability(motion: moving, system: system) == .timelineTransition)
        #expect(WidgetDisplay.standByDay.capability(motion: moving, system: system)
                == WidgetDisplay.homeScreen.capability(motion: moving, system: system))
        #expect(WidgetDisplay.standByDay.capability(motion: .still, system: system) == .timelineTransition)
    }

    @Test("減光中と Reduce Motion は、環境から読んだとおりに段へ効く")
    func deviceStateReachesCapability() {
        let moving = WidgetMotion(pseudoAnimation: true, lowPowerMode: false)
        let system = SystemVersion(major: 26, minor: 1)
        var dimmed = WidgetDisplay.standByDay
        dimmed.luminanceReduced = true
        #expect(dimmed.capability(motion: moving, system: system) == .staticOnly)
        var calm = WidgetDisplay.standByDay
        calm.reduceMotion = true
        #expect(calm.capability(motion: moving, system: system) == .ambient1fps)
    }
}
