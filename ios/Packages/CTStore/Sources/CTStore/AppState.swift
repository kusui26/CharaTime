import Foundation

/// 端末に 1 つだけ持つ状態。アプリが書き、ウィジェットは読むだけ。
///
/// **前方後方の両方に互換であること。** アプリとウィジェット拡張は別々に更新され得るので、
/// 新しいアプリが書いた JSON を古いウィジェットが読む場面も、その逆も起こる。
/// 知らない項目は捨て、足りない項目は既定値で埋める（プラン §7.4）。
public struct AppState: Codable, Sendable, Equatable {

    /// この構造体が理解できるスキーマの版。
    public static let currentSchemaVersion = 1

    /// 書いた側の版。これより新しい JSON を読んだときは既定値に落とす。
    public var schemaVersion: Int

    /// 端末ごとに一度だけ決める種。日課はここから決まるので、変えると別人になる。
    public var userSeed: UInt64

    public var selectedCharacterID: String

    public var settings: Settings

    public init(schemaVersion: Int = AppState.currentSchemaVersion,
                userSeed: UInt64,
                selectedCharacterID: String = "piyo",
                settings: Settings = Settings()) {
        self.schemaVersion = schemaVersion
        self.userSeed = userSeed
        self.selectedCharacterID = selectedCharacterID
        self.settings = settings
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
        settings = try box.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
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
    /// ウィジェットの疑似アニメ。Phase 0 のスパイクで Go が出るまで切のまま（プラン D-11）。
    public var widgetPseudoAnimation: Bool

    public init(showsClock: Bool = true,
                clockStyle: ClockStyle = .retro,
                nightMode: Bool = true,
                soundEnabled: Bool = false,
                widgetPseudoAnimation: Bool = false) {
        self.showsClock = showsClock
        self.clockStyle = clockStyle
        self.nightMode = nightMode
        self.soundEnabled = soundEnabled
        self.widgetPseudoAnimation = widgetPseudoAnimation
    }

    public init(from decoder: any Decoder) throws {
        let box = try decoder.container(keyedBy: CodingKeys.self)
        showsClock = try box.decodeIfPresent(Bool.self, forKey: .showsClock) ?? true
        clockStyle = try box.decodeIfPresent(ClockStyle.self, forKey: .clockStyle) ?? .retro
        nightMode = try box.decodeIfPresent(Bool.self, forKey: .nightMode) ?? true
        soundEnabled = try box.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? false
        widgetPseudoAnimation = try box.decodeIfPresent(Bool.self, forKey: .widgetPseudoAnimation) ?? false
    }
}
