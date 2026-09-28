import Foundation

/// 足元の影を見つける（プラン §9 Phase 2 の 2-C ⑤-7、テンプレートの F-SHADOW）。
///
/// 影は足元に広がる半透明の面になる（透明の PNG では薄い黒、白い地から抜くと薄い灰色が残る）。輪郭線のなめらかな縁も
/// 半透明だが、1〜2 画素の幅しかない。足元の帯（体の外接矩形の下 1 割と、その下の同じ高さ）の半透明の画素が、
/// 体の幅の 4 倍より多ければ影とみなす。半透明の影はコマの塊に入らない（不透明さ 0.5 未満）ので、背景を外した絵で数える。
enum ShadowCheck {

    /// 足元の帯の高さ（体の外接矩形の高さに対する割合。足元の上と下に同じだけ）。
    static let bandShare = 0.1
    /// 半透明とみなす不透明さ。そろえたあと（`AlphaSnap`）は 16 未満と 240 以上が無いので、その間の多くを数える。
    static let translucent: ClosedRange<UInt8> = 16...200
    /// 体の幅に対する、半透明の画素の数の上限。いまの 5 体を 0.45 倍にした絵で 1.7 まで（縁の画素は縮めても
    /// 1〜2 画素のまま、幅だけが縮む）。体の幅いっぱいの薄い影は、この何倍にもなる。
    static let translucentPerWidth = 4.0

    /// `box`（背景を外した絵の中の、体の外接矩形）の足元に、影があるか。
    static func hasShadow(in cutout: Raster, below box: PixelBox) -> Bool {
        let reach = Int((Double(box.height) * bandShare).rounded(.up))
        let band = PixelBox(left: box.left, top: box.bottom - reach, right: box.right,
                            bottom: box.bottom + reach)
        let frame = PixelBox(width: cutout.width, height: cutout.height)
        guard let area = band.intersection(frame) else { return false }
        var count = 0
        cutout.pixels.withUnsafeBufferPointer { pixels in
            eachIndex(area.area) { local in
                let x = area.left + local % area.width, y = area.top + local / area.width
                let alpha = pixels[(y * cutout.width + x) * Raster.bytesPerPixel + 3]
                if translucent.contains(alpha) { count += 1 }
            }
        }
        return Double(count) > Double(box.width) * translucentPerWidth
    }
}
