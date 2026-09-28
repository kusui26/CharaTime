import Foundation
import CTStore

/// 整えた絵の枠の決まり（プラン §9 Phase 2 の 2-C ③⑤-4）。**いまの 5 体（`design/chara.py` を焼いた絵）に合わせる。**
///
/// 取り込んだキャラも、同じ枠・同じ接地線・同じ背で暮らす（D-34）。割合は、同梱の @3x の絵を画素より細かく
/// 測って決めた（2026-09-28。縁の画素の不透明さで端を求める。`FigureMetrics`）。
enum FrameGeometry {

    /// 待受用（hero）の枠（@3x の画素）。
    static let hero = CharacterImageKind.hero.pixelSize
    /// ウィジェット用（mini）の枠。hero を縮めて作る（`FrameRenderer.mini`）。
    static let mini = CharacterImageKind.mini.pixelSize

    /// 輪郭線のいちばん下（枠の上からの割合）。接地線 y=163 に線の太さの半分 2.5 と枠の余白 5 を足し、
    /// 枠の高さ 180 で割る（`design/chara.py`）。いまの絵の立ち姿は、ここで床に触れる（hero で 767.25 画素）。
    static let outlineBottomShare = (163.0 + 2.5 + 5.0) / 180.0
    /// 立ち姿の外接矩形の高さの上限（枠の高さに対する割合）。いまの 5 体でいちばん背の高いチップ（753.7 / 810）。
    static let standingHeightShare = 0.9305
    /// 立ち姿の外接矩形の幅の上限（枠の幅に対する割合）。いまの 5 体はどれも同じ幅（466.9 / 585）。
    /// 待受の床の端の余白（`SceneLayout.bodyWidthRatio` の 0.8）の内側に収まる。
    static let standingWidthShare = 0.7981
    /// どのコマも、枠の中央から左右それぞれ、この割合の半分までに収める（枠の縁に 2.5% ずつ余白を残す）。
    static let figureWidthShare = 0.95
    /// 横の位置を決める、体の上の部分（外接矩形の上からの割合）。足・しっぽ（下の部分）は姿勢で動くので、
    /// 頭と胴の中心を枠の中央に置く。いまの絵の立つ・すわる・よろこぶは、どれも 0.01 画素以内で中央にある。
    static let upperBodyShare = 0.6
    /// 全コマを収めるための縮めがこれを下回ったら知らせる（本来の大きさから 1 割以上縮めた。F-COMPACT）。
    static let compactWarningRatio = 0.9

    /// 輪郭線のいちばん下の位置（上からの画素）。
    static func outlineBottom(in size: PixelSize) -> Double {
        Double(size.height) * outlineBottomShare
    }

    /// 枠の横の中央（左からの画素）。
    static func centerX(of size: PixelSize) -> Double {
        Double(size.width) / 2
    }
}
