import SwiftUI
import PhotosUI
import CTCore
import CTAssets
import CTRender
import CTStore

/// 背景を選んで、歩ける帯を決めるまでの流れ。
///
/// **写真アプリを開くのは本体アプリの仕事**なので、この画面だけは CTRender に置かない
/// （ウィジェット拡張は PhotosUI を使えない）。選び方の一覧と帯の編集は CTRender にある。
struct RoomSetupSheet: View {

    let current: Room
    let world: SceneWorld
    /// 同梱の部屋に戻す。
    let onChooseBundled: () -> Void
    /// 選んだ画像と帯で部屋を作り直す。
    let onApplyPicture: (RoomChoice, Data, RoomRect) -> Void
    /// 背景はそのままで、帯だけ直す。
    let onApplyBand: (RoomRect) -> Void
    let onClose: () -> Void
    /// 最初に出す画面。確認用に、帯を直すところから開けるようにしてある。
    var start: Start = .choosing

    @State private var stage: Stage
    @State private var pickedItem: PhotosPickerItem?
    @State private var isPickingPhoto = false
    @State private var failure: String?

    /// 最初に出す画面。
    enum Start { case choosing, adjustingBand }

    private enum Stage: Equatable {
        case choosing
        /// 画像を読み込んでいる。
        case loading(RoomChoice)
        /// 選んだ画像の上で帯を決めている。
        case placing(RoomChoice, Data)
        /// いまの背景のまま帯だけ直している。
        case adjusting
    }

    init(current: Room, world: SceneWorld,
         onChooseBundled: @escaping () -> Void,
         onApplyPicture: @escaping (RoomChoice, Data, RoomRect) -> Void,
         onApplyBand: @escaping (RoomRect) -> Void,
         onClose: @escaping () -> Void,
         start: Start = .choosing) {
        self.current = current
        self.world = world
        self.onChooseBundled = onChooseBundled
        self.onApplyPicture = onApplyPicture
        self.onApplyBand = onApplyBand
        self.onClose = onClose
        self.start = start
        _stage = State(initialValue: start == .adjustingBand ? .adjusting : .choosing)
    }

    var body: some View {
        content
            .photosPicker(isPresented: $isPickingPhoto, selection: $pickedItem,
                          matching: .images, photoLibrary: .shared())
            .onChange(of: pickedItem) { _, item in load(item) }
            .alert("画像を読めませんでした", isPresented: .constant(failure != nil)) {
                Button("わかりました") { failure = nil; stage = .choosing }
            } message: {
                Text(failure ?? "")
            }
    }

    @ViewBuilder
    private var content: some View {
        switch stage {
        case .choosing:
            NavigationStack {
                RoomPickerView(current: current.background, onChoose: choose,
                               onEditBand: { stage = .adjusting })
                    .navigationTitle("へや")
                    .toolbar { ToolbarItem(placement: .cancellationAction) {
                        Button("とじる", action: onClose)
                    } }
            }
        case .loading:
            ProgressView("読み込んでいます").frame(maxWidth: .infinity, maxHeight: .infinity)
        case .placing(let choice, let data):
            placing(choice, data)
        case .adjusting:
            FloorBandEditor(
                backdrop: world.backdrop, world: world, initial: current.floor,
                onDone: onApplyBand,
                onCancel: { stage = .choosing })
                .interactiveDismissDisabled()
        }
    }

    @ViewBuilder
    private func placing(_ choice: RoomChoice, _ data: Data) -> some View {
        if let image = try? ImageStore.decodeScaled(data) {
            FloorBandEditor(
                backdrop: .picture(image), world: world,
                initial: choice.suggestedBand.rect,
                onDone: { rect in onApplyPicture(choice, data, rect) },
                onCancel: { stage = .choosing })
                .interactiveDismissDisabled()
        } else {
            Color.clear.onAppear { failure = "この画像は読み込めませんでした。" }
        }
    }

    private func choose(_ choice: RoomChoice) {
        switch choice {
        case .bundled:
            onChooseBundled()
        case .photo, .homeScreenShot:
            stage = .loading(choice)
            isPickingPhoto = true
        }
    }

    private func load(_ item: PhotosPickerItem?) {
        guard case .loading(let choice) = stage else { return }
        guard let item else { stage = .choosing; return }   // 選ばずに閉じた
        Task {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    failure = "写真のデータを取り出せませんでした。"
                    return
                }
                stage = .placing(choice, data)
            } catch {
                failure = String(describing: error)
            }
        }
    }
}
