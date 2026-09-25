import SwiftUI
import PhotosUI
import CTStore
import CTRender

/// 透過背景を用意する画面（プラン §9 Phase 3 の 3-3）。設定 →「透過背景」から開く。
///
/// ホーム画面の壁紙のスクショ（編集モードの空のページ）を、ライトとダークで 1 枚ずつ取り込む。
/// アプリは iOS 26 の実測の表の枠で切り抜き、ページのいちばん上の大の後ろに敷く（D-31）。**写真アプリを開くので、
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
            Text("大の後ろに、ホーム画面の壁紙を敷きます。キャラとアイテムが、壁紙の上にいるように見えます。")
                .font(.callout)
            // 透過は、大をページのいちばん上に置いてから。まだなら先にガイドへ。
            NavigationLink("大の置き方（置き方のガイド）", value: SettingsRoute.placementGuide)
        }
    }

    private var conditionsSection: some View {
        Section("成り立つ条件") {
            ForEach(Self.conditions, id: \.self) { Text($0).font(.footnote) }
        }
    }

    /// 透過に見えるための条件（3-C ⑦ の 5）。「クリア」「色合い調整」では OS が背景を外すので、壁紙も部屋も
    /// 描かない（D-28）。中と小は置き場所が決まらないので敷かない（D-31）。
    private static let conditions = [
        "ホーム画面の外観が「デフォルト」か「ダーク」のとき（「クリア」「色合い調整」では敷かず、"
            + "キャラとアイテムだけになります）",
        "大を 1 つ、ページのいちばん上に置く（中と小には敷きません。置き場所が決まらず、壁紙がずれるため）",
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
            Text("撮り方: ホーム画面を長押しして編集モード（アイコンが揺れる）にし、最後のページの次に増える"
                 + "何もないページまでめくって、スクショを撮ります（サイドボタンと音量を上げるボタン）。"
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
            LabeledContent("敷くところ", value: "ページのいちばん上の大")
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
        let reading = switch model.iconStyleReading {
        case .detected(let style): "ウィジェットの大きさから、ラベル「\(style.label)」と分かりました。"
        case .notYetPlaced: "大をホーム画面に置いてから開くと、ラベルの有無を自動で選びます。"
        // 表の枠で切り抜いても、ウィジェットの大きさと合わないので敷かれない（部屋の絵のまま）。
        case .unknownSize: "ウィジェットが表に無い大きさです（画面の表示を拡大しているときなど）。透過背景は使えません。"
        }
        return reading + "「大きいアプリアイコン」にしているときは「なし」です。"
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
