import SwiftUI
import PhotosUI
import CTStore
import CTRender

/// 透過背景を用意する画面（プラン §9 Phase 3 の 3-3）。設定 →「透過背景」から開く。
///
/// ホーム画面の壁紙のスクショ（編集モードの空のページ）を、ライトとダークで 1 枚ずつ取り込む。
/// アプリは iOS 26 の実測の表の枠で切り抜き、ウィジェットの後ろに敷く。**写真アプリを開くので、
/// アプリの側に置く**（ウィジェット拡張と共有する CTRender は PhotosUI を使えない）。
struct TransparentBackgroundScreen: View {

    let model: StandbyModel

    /// 取り込む外観。写真アプリを閉じても忘れない（選んだ写真が届くのは、閉じたあとのこともある）。
    @State private var pickingAppearance = Appearance.light
    @State private var isPickerPresented = false
    @State private var pickedItem: PhotosPickerItem?
    /// まだ取り込んでいないときの、ラベルの有無の選び。取り込むときに使う。
    @State private var pendingIconStyle: SlotGeometry.IconStyle?
    @State private var isWorking = false
    @State private var failure: String?

    var body: some View {
        List {
            introSection
            wallpaperSection
            positionSection
            conditionsSection
            if isSetUp { removeSection }
        }
        .navigationTitle("透過背景")
        .navigationBarTitleDisplayMode(.inline)
        // 形式を変えずに受け取る（既定では JPEG などに変えられることがあり、画素が変わってしまう）。
        .photosPicker(isPresented: $isPickerPresented, selection: $pickedItem, matching: .screenshots,
                      preferredItemEncoding: .current, photoLibrary: .shared())
        .onChange(of: pickedItem) { _, item in if let item { load(item) } }
        .disabled(isWorking)
        .overlay { if isWorking { ProgressView() } }
        .alert("うまくいきませんでした", isPresented: isFailing) {
            Button("わかりました") { failure = nil }
        } message: {
            Text(failure ?? "")
        }
        .onAppear { model.reloadWidgetRecord() }
    }

    // MARK: - 説明

    private var introSection: some View {
        Section {
            Text("ウィジェットの後ろに、ホーム画面の壁紙を敷きます。キャラとアイテムが、壁紙の上にいるように見えます。")
                .font(.callout)
        }
    }

    private var conditionsSection: some View {
        Section("成り立つ条件") {
            ForEach(Self.conditions, id: \.self) { Text($0).font(.footnote) }
        }
    }

    /// 透過に見えるための条件（3-C ⑦ の 5）。
    private static let conditions = [
        "ホーム画面の外観がライトかダークのとき（着色・クリアでは、部屋の絵に戻ります）",
        "ページには、大を上に、中をその下に置き、ほかのアイコンを置かない",
        "壁紙を替えたら、撮り直して取り込む",
        "写真のシャッフルの壁紙では使えない",
    ]

    // MARK: - 壁紙のスクショ

    private var wallpaperSection: some View {
        Section {
            ForEach(Appearance.allCases, id: \.self) { wallpaperRow($0) }
        } header: {
            Text("壁紙のスクショ")
        } footer: {
            Text("撮り方: ホーム画面を長押しして編集モード（アイコンが揺れる）にし、いちばん右までめくると、"
                 + "何もないページがあります。そこでスクショを撮ります（サイドボタンと音量を上げるボタン）。"
                 + "ダークは、外観をダークにしてからもう一度。")
        }
    }

    private func wallpaperRow(_ appearance: Appearance) -> some View {
        let name = model.state.widget.wallpaper[appearance]
        return HStack(spacing: 12) {
            WallpaperThumbnail(name: name)
            VStack(alignment: .leading, spacing: 2) {
                Text(appearance.label)
                Text(name == nil ? "まだ取り込んでいません" : "取り込みました")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(name == nil ? "取り込む" : "取り直す") {
                pickingAppearance = appearance
                isPickerPresented = true
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - ウィジェットの位置

    private var positionSection: some View {
        Section {
            LabeledContent("ページの型", value: "大（上）＋中（下）")
            LabeledContent("アプリ名のラベル") {
                Picker("アプリ名のラベル", selection: iconStyle) {
                    Text("あり").tag(SlotGeometry.IconStyle.labeled)
                    Text("なし").tag(SlotGeometry.IconStyle.labelFree)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            if isSetUp {
                NavigationLink("位置を確かめる・寄せる", value: SettingsRoute.transparentAlignment)
            }
        } header: {
            Text("ウィジェットの位置")
        } footer: {
            Text(iconStyleNote)
        }
    }

    /// ラベルの有無の選び方の説明。ウィジェットが知らせた大きさで見分けられたかで変える。
    private var iconStyleNote: String {
        let detected = model.detectedIconStyle.map { "ウィジェットの大きさから、ラベル「\($0.label)」と分かりました。" }
        return (detected ?? "大か中をホーム画面に置いてから開くと、ラベルの有無を自動で選びます。")
            + "「大きいアプリアイコン」にしているときは「なし」です。"
    }

    // MARK: - やめる

    private var removeSection: some View {
        Section {
            Button("透過をやめて、部屋の絵に戻す", role: .destructive) { model.removeWallpaper() }
        }
    }

    // MARK: - 取り込み

    /// 透過背景を用意してあるか（どちらかの外観を取り込んで、枠を作ってある）。
    private var isSetUp: Bool { model.state.widget.iconStyle != nil }

    private var isFailing: Binding<Bool> {
        Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })
    }

    /// いまのラベルの有無。取り込み済みなら枠を作った表、まだなら選んだもの、選んでいなければ見分けたもの。
    private var currentIconStyle: SlotGeometry.IconStyle {
        model.state.widget.iconStyle ?? pendingIconStyle ?? model.detectedIconStyle ?? .labeled
    }

    /// ラベルの有無。取り込み済みなら、選び直すと枠を作り直す。
    private var iconStyle: Binding<SlotGeometry.IconStyle> {
        Binding(get: { currentIconStyle }, set: { style in
            guard isSetUp else { return pendingIconStyle = style }
            run { await model.setWallpaperIconStyle(style) }
        })
    }

    private func load(_ item: PhotosPickerItem) {
        let appearance = pickingAppearance
        let style = currentIconStyle
        run {
            guard let data = try? await item.loadTransferable(type: Data.self) else {
                return "写真のデータを取り出せませんでした。"
            }
            return await model.importWallpaper(data, as: appearance, style: style)
        }
    }

    /// 裏の仕事を 1 つ走らせる。走っているあいだは操作を止め、失敗したら理由を出す。
    /// 選んだ写真は忘れる（同じ写真を選び直しても、取り込み直せるように）。
    private func run(_ work: @escaping @MainActor () async -> String?) {
        isWorking = true
        Task {
            failure = await work()
            isWorking = false
            pickedItem = nil
        }
    }
}

/// 取り込んだ壁紙のスクショの縮小。無ければ空の枠。
struct WallpaperThumbnail: View {

    let name: String?
    @State private var image: CGImage?

    /// 縮小の長辺（画素）。行の高さ（約 60pt）に @3x で足りる大きさ。
    private static let maxPixelSize = 180
    /// 行に置く大きさ（ポイント）。スクショの縦横比（1206×2622）に近い。
    private static let size = CGSize(width: 28, height: 60)
    private static let cornerRadius: Double = 6

    var body: some View {
        RoundedRectangle(cornerRadius: Self.cornerRadius)
            .fill(Color.secondary.opacity(0.15))
            .overlay {
                if let image {
                    Image(decorative: image, scale: 1).resizable().scaledToFill()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
            .frame(width: Self.size.width, height: Self.size.height)
            .task(id: name) {
                image = name.flatMap { ImageStore.shared.thumbnail($0, maxPixelSize: Self.maxPixelSize) }
            }
    }
}

extension Appearance {
    var label: String {
        switch self {
        case .light: "ライト"
        case .dark: "ダーク"
        }
    }
}

extension SlotGeometry.IconStyle {
    var label: String {
        switch self {
        case .labeled: "あり"
        case .labelFree: "なし"
        }
    }
}
