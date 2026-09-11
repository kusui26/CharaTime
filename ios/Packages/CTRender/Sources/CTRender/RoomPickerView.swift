import SwiftUI
import CTCore

/// 背景の選び方（プラン §4.4「部屋 3 系統」）。
public enum RoomChoice: String, Sendable, Equatable, CaseIterable, Identifiable {

    /// 同梱の部屋。
    case bundled
    /// 写真アプリから選んだ 1 枚。
    case photo
    /// ホーム画面のスクリーンショット。**メモの「アプリが並んでいる画面」の再現。**
    case homeScreenShot

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .bundled: "同梱のへや"
        case .photo: "写真"
        case .homeScreenShot: "ホーム画面"
        }
    }

    public var detail: String {
        switch self {
        case .bundled: "はじめから入っているへや。何も用意しなくてよい"
        case .photo: "好きな写真の上を歩かせる"
        case .homeScreenShot: "アイコンが並んだ画面のスクリーンショットの上を歩かせる"
        }
    }

    public var symbol: String {
        switch self {
        case .bundled: "house"
        case .photo: "photo"
        case .homeScreenShot: "square.grid.2x2"
        }
    }

    /// 選び直したときに最初に見せる帯。**あとから指で動かせる。**
    ///
    /// ホーム画面はドックのすぐ上を、写真は下寄りの中ほどを初期値にする。
    /// どちらもいちばん「床らしい」場所なので、そのまま決めても収まりがよい。
    public var suggestedBand: FloorBand {
        switch self {
        case .bundled: FloorBand(top: 0.66, bottom: 0.86)
        case .photo: FloorBand(top: 0.62, bottom: 0.86)
        case .homeScreenShot: FloorBand(top: 0.70, bottom: 0.88)
        }
    }

    /// その背景に対応する `Background`。画像は取り込んだファイル名で指す。
    public func background(imageName: String) -> Background {
        switch self {
        case .bundled: .bundled("room-a")
        case .photo: .photo(fileName: imageName)
        case .homeScreenShot: .homeScreenShot(fileName: imageName)
        }
    }

    /// いまの背景がどの選び方か。
    public static func of(_ background: Background) -> RoomChoice {
        switch background {
        case .bundled: .bundled
        case .photo: .photo
        case .homeScreenShot: .homeScreenShot
        }
    }
}

/// 背景を選ぶ画面。**画像を選ぶ操作そのものは持たない**（写真アプリを開くのは
/// 本体アプリの仕事で、ウィジェット拡張と共有するこの層には置かない）。
public struct RoomPickerView: View {

    public let current: Background
    public let onChoose: (RoomChoice) -> Void
    /// いまの背景のまま、歩ける帯だけを直す。写真を選び直さずに調整できる。
    public let onEditBand: (() -> Void)?

    public init(current: Background, onChoose: @escaping (RoomChoice) -> Void,
                onEditBand: (() -> Void)? = nil) {
        self.current = current
        self.onChoose = onChoose
        self.onEditBand = onEditBand
    }

    public var body: some View {
        List {
            Section {
                ForEach(RoomChoice.allCases) { choice in
                    Button { onChoose(choice) } label: { row(choice) }
                        .buttonStyle(.plain)
                }
            }
            if let onEditBand {
                Section {
                    Button("歩ける帯を直す", action: onEditBand)
                }
            }
            Section {
                Text("ホーム画面のスクリーンショットは、アイコンを 1 ページぶん空けてから"
                     + "撮ると、キャラクターが広く歩けます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func row(_ choice: RoomChoice) -> some View {
        HStack(spacing: 13) {
            Image(systemName: choice.symbol)
                .font(.system(size: 19))
                .frame(width: 28)
                .foregroundStyle(Palette.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(choice.title).font(.body)
                Text(choice.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if RoomChoice.of(current) == choice {
                Image(systemName: "checkmark").font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.accent)
            }
        }
        .contentShape(Rectangle())
    }
}
