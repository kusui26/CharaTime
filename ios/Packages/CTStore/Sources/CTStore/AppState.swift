import Foundation
import CTCore

/// 端末に 1 つだけ持つ状態。アプリが書き、ウィジェットは読むだけ。
///
/// **前方後方の両方に互換であること。** アプリとウィジェット拡張は別々に更新され得るので、
/// 新しいアプリが書いた JSON を古いウィジェットが読む場面も、その逆も起こる。
/// 知らない項目は捨て、足りない項目は既定値で埋める（プラン §7.4）。
public struct AppState: Codable, Sendable, Equatable {

    /// この構造体が理解できるスキーマの版。
    ///
    /// **項目を足すだけなら上げない**（プラン §9 Phase 3 の 3-C ⑪）。古い側は知らない項目を捨て、
    /// 新しい側は無い項目を既定で埋めるので、足すだけなら両方が読める。版を上げると、古い側は
    /// 種のほかを既定値に戻す（`StateStore.load` の未来の版の扱い）。上げるのは、古い側が
    /// 読み違える変更（項目の意味や形を変える）のときだけ。
    public static let currentSchemaVersion = 1

    /// 書いた側の版。これより新しい JSON を読んだときは既定値に落とす。
    public var schemaVersion: Int

    /// 端末ごとに一度だけ決める種。日課はここから決まるので、変えると別人になる。
    public var userSeed: UInt64

    public var selectedCharacterID: String

    /// ユーザーが選んだ部屋。**nil は「同梱の部屋のまま」** という意味。
    ///
    /// 既定の部屋そのものをここに書き写さないのは、同梱の部屋を後で直したときに、
    /// 何も選んでいない人の画面も一緒に新しくなるようにするため。
    public var room: Room?

    public var settings: Settings

    /// 本体アプリが最後に読んだ文脈（電池・充電）。ウィジェットはこれを日課エンジンに渡す
    /// （3-C ⑩）。nil は「まだ読んでいない」で、文脈の割り込みは起きない。
    public var context: ContextSnapshot?

    /// ウィジェットの設定（3-C ⑪）。
    public var widget: WidgetSettings

    public init(schemaVersion: Int = AppState.currentSchemaVersion,
                userSeed: UInt64,
                selectedCharacterID: String = "piyo",
                room: Room? = nil,
                settings: Settings = Settings(),
                context: ContextSnapshot? = nil,
                widget: WidgetSettings = WidgetSettings()) {
        self.schemaVersion = schemaVersion
        self.userSeed = userSeed
        self.selectedCharacterID = selectedCharacterID
        self.room = room
        self.settings = settings
        self.context = context
        self.widget = widget
    }

    /// `state.json` が参照している画像の名前（`ImageStore` の名前）。
    ///
    /// 片づけ（`ImageStore.removeAll(keeping:)`）は、これに入らない画像を消す。部屋の背景・
    /// 壁紙のスクリーンショット・スロットの切り抜きを、ここ 1 か所で集める（3-C ⑦）。
    /// **画像を参照する項目を足したら、ここにも足す。** 足し忘れると、部屋を選び直したときに消える。
    public var referencedImageNames: Set<String> {
        Set([room?.background.imageFileName].compactMap { $0 } + widget.imageNames)
    }

    /// 初回起動用。種だけ乱数で決めて、あとは既定値。
    public static func makeInitial(
        userSeed: UInt64 = UInt64.random(in: UInt64.min...UInt64.max)
    ) -> AppState {
        AppState(userSeed: userSeed)
    }

    // 足りない項目は既定値で埋める。知らない項目は JSONDecoder が黙って捨てる。
    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try box.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        userSeed = try box.decodeIfPresent(UInt64.self, forKey: .userSeed) ?? 0
        selectedCharacterID = try box.decodeIfPresent(String.self, forKey: .selectedCharacterID) ?? "piyo"
        // 部屋が壊れていても、同梱の部屋に戻すだけで済ませる（画面が出ないより良い）。
        room = try? box.decodeIfPresent(Room.self, forKey: .room)
        settings = try box.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
        // 文脈とウィジェットの設定も、壊れていたら無かったことにする。全体を読めなくすると
        // 種まで既定値に戻り、別のキャラの一日になってしまう。
        context = try? box.decodeIfPresent(ContextSnapshot.self, forKey: .context)
        widget = (try? box.decodeIfPresent(WidgetSettings.self, forKey: .widget)) ?? WidgetSettings()
    }
}

/// 待受モードの時計の見た目（プラン §9 Phase 1 の 1-3、Q-5）。
public enum ClockStyle: String, Codable, Sendable, CaseIterable {
    /// ガラケー風の大きな数字。既定。
    case retro
    /// 細身で控えめ。部屋の絵を主役にしたいとき。
    case modern

    public var displayName: String {
        switch self {
        case .retro: "ガラケー風"
        case .modern: "すっきり"
        }
    }
}

public struct Settings: Codable, Sendable, Equatable {

    /// 待受モードに時計を出すか。ガラケー待受の再現なので既定は出す。
    public var showsClock: Bool
    /// 時計の見た目。
    public var clockStyle: ClockStyle
    /// 夜は画面を暗くするか。
    public var nightMode: Bool
    /// 音。当時の「消せない BGM」への不満を踏まえて既定は切（プラン §2.5）。
    public var soundEnabled: Bool

    // ウィジェットの疑似アニメの入／切は `WidgetSettings.pseudoAnimation` へ移した（3-C ⑪）。
    // ここにあった値（`widgetPseudoAnimation`）は引き継がない。読むだけの設定画面が書いた
    // 既定の false で、利用者が選んだ値ではないため。古い JSON に残っていても、知らない項目として捨てる。

    public init(showsClock: Bool = true,
                clockStyle: ClockStyle = .retro,
                nightMode: Bool = true,
                soundEnabled: Bool = false) {
        self.showsClock = showsClock
        self.clockStyle = clockStyle
        self.nightMode = nightMode
        self.soundEnabled = soundEnabled
    }

    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        showsClock = try box.decodeIfPresent(Bool.self, forKey: .showsClock) ?? true
        clockStyle = try box.decodeIfPresent(ClockStyle.self, forKey: .clockStyle) ?? .retro
        nightMode = try box.decodeIfPresent(Bool.self, forKey: .nightMode) ?? true
        soundEnabled = try box.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? false
    }
}
