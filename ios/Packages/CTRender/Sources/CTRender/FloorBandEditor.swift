import SwiftUI
import CTCore
import CTAssets

/// 歩ける帯を指で決める画面（プラン §4.4「床の範囲をユーザーがドラッグで指定する」）。
///
/// 写真やホーム画面のスクリーンショットを背景にすると、どこが「床」かは絵によって違う。
/// **アイコンの並びの下、ドックの上**といった帯をユーザーが自分で示す。
///
/// 左右は決めさせない。絵は足元を中心に置くので、端まで使うと体の半分が画面の外へ出る。
/// 必要な余白は画面の大きさから決まるので、こちらで計算する。
public struct FloorBandEditor: View {

    public let backdrop: RoomBackdrop
    public let world: SceneWorld
    public let onDone: (RoomRect) -> Void
    public let onCancel: () -> Void

    @State private var band: FloorBand
    @State private var dragging: FloorBand.Edge?

    public init(backdrop: RoomBackdrop, world: SceneWorld, initial: RoomRect,
                onDone: @escaping (RoomRect) -> Void, onCancel: @escaping () -> Void) {
        self.backdrop = backdrop
        self.world = world
        self.onDone = onDone
        self.onCancel = onCancel
        _band = State(initialValue: FloorBand(top: initial.minY, bottom: initial.maxY))
    }

    public var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let rect = floorRect(in: size)
            ZStack {
                BackdropView(backdrop: backdrop, floor: rect, palette: .day, isNight: false)
                FloorBandOverlay(band: band, size: size, dragging: dragging)
                preview(in: size, floor: rect)
                handles(in: size)
                FloorBandControls(onDone: { onDone(floorRect(in: size)) }, onCancel: onCancel)
            }
            .contentShape(Rectangle())
        }
        .ignoresSafeArea()
    }

    /// いまの帯から作る床の矩形。左右の余白は画面の大きさから決まる。
    private func floorRect(in size: CGSize) -> RoomRect {
        let inset = SceneLayout.safeHorizontalInset(in: size, geometry: world.spriteGeometry,
                                                    characterScale: world.character.scale)
        return RoomRect(x: inset, y: band.top, width: 1 - inset * 2, height: band.height)
    }

    /// 帯の奥と手前に立たせて見せる。**奥ほど小さく見える**ことが目で分かる。
    private func preview(in size: CGSize, floor: RoomRect) -> some View {
        let layout = SceneLayout(size: size, room: Room(background: .bundled(""), floor: floor),
                                 geometry: world.spriteGeometry)
        return ZStack {
            ghost(at: floor.at(0.22, 0), layout: layout, opacity: 0.55)
            ghost(at: floor.at(0.78, 1), layout: layout, opacity: 1.0)
        }
    }

    private func ghost(at position: RoomPoint, layout: SceneLayout, opacity: Double) -> some View {
        let state = SceneState(time: .distantPast, activity: .idle, position: position,
                               facing: .front, frame: 0)
        return ZStack {
            ShadowView(state: state, layout: layout, flourish: .still,
                       characterScale: world.character.scale)
            CharacterView(character: world.character, state: state,
                          layout: layout, flourish: .still)
        }
        .opacity(opacity)
        .allowsHitTesting(false)
    }

    private func handles(in size: CGSize) -> some View {
        ForEach(FloorBand.Edge.allCases, id: \.self) { edge in
            FloorBandHandle(title: edge.title, isActive: dragging == edge)
                .position(x: size.width / 2, y: band.value(of: edge) * size.height)
                .gesture(drag(edge, height: size.height))
        }
    }

    private func drag(_ edge: FloorBand.Edge, height: Double) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                dragging = edge
                band = band.moving(edge, to: value.location.y / height)
            }
            .onEnded { _ in dragging = nil }
    }
}
