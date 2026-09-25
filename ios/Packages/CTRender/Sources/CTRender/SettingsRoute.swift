import CTStore

/// 設定画面から進む先。画面はアプリの側が `navigationDestination(for:)` で用意する。
///
/// 透過背景の画面は写真アプリを開く（PhotosUI）ので、ウィジェット拡張と共有する CTRender には置けない
/// （部屋を選ぶ画面と同じ理由）。値で進む先を伝え、CTRender がアプリの画面を知らずに済むようにする。
public enum SettingsRoute: Hashable, Sendable {
    /// 透過背景（プラン §9 Phase 3 の 3-3）。
    case transparentBackground
    /// 透過背景の枠を確かめて、寄せる画面（3-3）。
    case transparentAlignment
    /// 置き方のガイド（ウィジェットのページの作り方。3-4）。
    case placementGuide
}

/// 透過背景のいまの様子。設定画面の行に出す（3-3）。
enum TransparentStatus {

    static func label(_ widget: WidgetSettings) -> String {
        switch (widget.wallpaper.light != nil, widget.wallpaper.dark != nil) {
        case (true, true): "ライト・ダーク"
        case (true, false): "ライトだけ"
        case (false, true): "ダークだけ"
        case (false, false): "使っていない"
        }
    }
}

/// 透過背景の枠を寄せた量の見せ方（3-3）。画素の数で、横と縦を分けて書く。
public enum NudgeFormat {

    public static func text(_ offset: PixelOffset) -> String {
        let parts = [part(offset.dx, positive: "右", negative: "左"),
                     part(offset.dy, positive: "下", negative: "上")].compactMap { $0 }
        return parts.isEmpty ? "寄せていません" : parts.joined(separator: "・")
    }

    private static func part(_ value: Int, positive: String, negative: String) -> String? {
        guard value != 0 else { return nil }
        return "\(value > 0 ? positive : negative)に \(abs(value))"
    }
}

public extension WidgetSlot.Family {
    /// 画面に出す名前（小・中・大）。
    var displayName: String {
        switch self {
        case .small: "小"
        case .medium: "中"
        case .large: "大"
        }
    }
}
