import Testing
import Foundation
import CTCore
@testable import CTStore

/// 使わない画像の片づけ（プラン §9 Phase 3 の 3-C ⑦）。
///
/// 部屋の背景・壁紙のスクリーンショット・スロットの切り抜きは、同じ `images/` に置く。
/// 片づけは `state.json` が参照する名前だけを残すので、その名前の一覧に漏れがあると、
/// 部屋を選び直したときに壁紙や切り抜きまで消えてしまう。
@Suite("画像の片づけ")
struct ImageCleanupTests {

    private static let photoRoom = Room(background: .photo(fileName: "bg-old"), floor: .unit)

    private static func state(room: Room?) -> AppState {
        AppState(userSeed: 1, room: room, widget: WidgetSettingsTests.sample)
    }

    @Test("参照している画像は、部屋・壁紙・切り抜きのすべて")
    func referencedNamesCoverEveryImage() {
        #expect(Self.state(room: Self.photoRoom).referencedImageNames == [
            "bg-old", "wallpaper-light", "wallpaper-dark",
            "crop-large-0-0-light", "crop-large-0-0-dark", "crop-medium-0-2-light",
        ])
    }

    @Test("同梱の部屋は、画像を参照しない")
    func bundledRoomHasNoImage() {
        let bundled = Room(background: .bundled("room"), floor: .unit)
        #expect(AppState(userSeed: 1, room: bundled).referencedImageNames.isEmpty)
        #expect(AppState(userSeed: 1).referencedImageNames.isEmpty)
    }

    @Test("ホーム画面のスクリーンショットの部屋も、その画像を参照する")
    func homeScreenRoomReferencesItsImage() {
        let home = Room(background: .homeScreenShot(fileName: "bg-home"), floor: .unit)
        #expect(AppState(userSeed: 1, room: home).referencedImageNames == ["bg-home"])
    }

    /// 3-1 より前の片づけは「部屋が使う画像」だけを残していたので、ここで壁紙と切り抜きが消えた。
    @Test("同梱の部屋に選び直しても、壁紙と切り抜きは残り、古い写真だけが消える")
    func choosingBundledRoomKeepsWallpaper() throws {
        let store = try Self.storeWithEveryImage()
        let chosen = Self.state(room: nil)
        store.removeAll(keeping: chosen.referencedImageNames)
        #expect(!store.exists("bg-old"))
        #expect(!store.exists("stray"))
        for name in WidgetSettingsTests.sample.imageNames {
            #expect(store.exists(name), "\(name) が消えた")
        }
    }

    @Test("別の写真に選び直すと、新しい写真と壁紙と切り抜きが残る")
    func choosingAnotherPhotoKeepsWallpaper() throws {
        let store = try Self.storeWithEveryImage()
        let data = try #require(ImageStoreTests.makePNG(width: 8, height: 8))
        try store.store(data, as: "bg-new")
        let chosen = Self.state(room: Room(background: .photo(fileName: "bg-new"), floor: .unit))
        store.removeAll(keeping: chosen.referencedImageNames)
        #expect(store.exists("bg-new"))
        #expect(!store.exists("bg-old"))
        #expect(WidgetSettingsTests.sample.imageNames.allSatisfy(store.exists))
    }

    /// 古い写真・壁紙・切り抜きと、どこからも参照されない 1 枚を置いた置き場。
    private static func storeWithEveryImage() throws -> ImageStore {
        let store = ImageStoreTests.temporaryStore()
        let data = try #require(ImageStoreTests.makePNG(width: 8, height: 8))
        for name in ["bg-old", "stray"] + WidgetSettingsTests.sample.imageNames {
            try store.store(data, as: name)
        }
        return store
    }
}
