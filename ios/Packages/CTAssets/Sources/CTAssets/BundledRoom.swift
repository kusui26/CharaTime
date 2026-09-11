import Foundation
import CTCore

/// Phase 1 の同梱の部屋。
///
/// **Phase 2 で部屋のデータと配置エディタに置き換わる**（プラン §9 Phase 2 の 2-4、2-6）。
/// それまでは、待受モードの動きを実機で確かめるための 1 部屋だけを持つ。
/// 配置はデザインキャンバス（`design/Main.dc.html`）の待受モードに合わせてある。
public enum BundledRoom {

    /// キャラが歩ける帯（画面に対する正規化座標）。
    ///
    /// 上辺が壁と床の境目になる。
    ///
    /// **左右は画面の端まで使わない。** 絵は足元を中心に置くので、端まで歩かせると
    /// 体の半分が画面の外へ出る。
    ///
    /// 必要な余白は画面の縦横比で決まる（`SceneLayout.safeHorizontalInset`）。
    /// キャラの背は画面の高さの 0.28、絵の幅は背の 0.72、体は絵の幅の 0.8 なので、
    /// 体の半分は画面の幅の `0.28 × (高さ ÷ 幅) × 0.72 × 0.8 ÷ 2`。
    /// いまの iPhone でいちばん縦長の 2.18 でも 0.177 なので、0.18 残せば足りる。
    public static let horizontalInset: Double = 0.18

    public static let floor = RoomRect(x: horizontalInset, y: 0.66,
                                       width: 1 - horizontalInset * 2, height: 0.20)

    public static let room = Room(
        background: .bundled("room-a"),
        floor: floor,
        items: [
            // 吊るすものは接地しないので、位置は絵の上端を指す。
            PlacedItem(id: "mirror-ball", kind: .mirrorBall,
                       position: RoomPoint(x: 0.80, y: 0.30)),
            PlacedItem(id: "bed", kind: .bed, position: RoomPoint(x: 0.26, y: 0.755)),
            PlacedItem(id: "cushion", kind: .cushion, position: RoomPoint(x: 0.42, y: 0.845)),
            PlacedItem(id: "plant", kind: .plant, position: RoomPoint(x: 0.90, y: 0.80))
        ])
}
