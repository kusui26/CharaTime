import Foundation
import CoreGraphics
import CoreText
import CTStudio

/// コンタクトシートを上からの座標で描く道具（Core Graphics は左下が原点なので、ここで直す）。
struct Board {

    let context: CGContext
    /// 描く絵の高さ（座標を上下に直すのに使う）。
    let height: CGFloat

    /// 市松の升目（画素）。透明な所が分かる細かさ。
    static let checkerSquare: CGFloat = 12
    /// 字の書体。日本語も描ける（macOS に入っている）。
    static let fontName = "HiraginoSans-W3"

    func flipped(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height)
    }

    func fill(_ rect: CGRect, _ color: CGColor) {
        context.setFillColor(color)
        context.fill(flipped(rect))
    }

    /// 明るい市松模様（透明な画素を見分ける）。
    func checker(_ rect: CGRect) {
        fill(rect, Palette.checkerLight)
        context.saveGState()
        context.clip(to: flipped(rect))
        context.setFillColor(Palette.checkerDark)
        let columns = Int((rect.width / Self.checkerSquare).rounded(.up))
        let rows = Int((rect.height / Self.checkerSquare).rounded(.up))
        for row in 0..<rows {
            for column in 0..<columns where (row + column).isMultiple(of: 2) {
                context.fill(flipped(CGRect(x: rect.minX + CGFloat(column) * Self.checkerSquare,
                                            y: rect.minY + CGFloat(row) * Self.checkerSquare,
                                            width: Self.checkerSquare, height: Self.checkerSquare)))
            }
        }
        context.restoreGState()
    }

    func draw(_ image: CGImage, in rect: CGRect) {
        context.interpolationQuality = .high
        context.draw(image, in: flipped(rect))
    }

    func line(_ from: CGPoint, _ to: CGPoint, _ color: CGColor, width: CGFloat = 1) {
        context.setStrokeColor(color)
        context.setLineWidth(width)
        context.move(to: CGPoint(x: from.x, y: height - from.y))
        context.addLine(to: CGPoint(x: to.x, y: height - to.y))
        context.strokePath()
    }

    func stroke(_ rect: CGRect, _ color: CGColor) {
        context.setStrokeColor(color)
        context.setLineWidth(1)
        context.stroke(flipped(rect))
    }

    /// 字を描く（`point` は左端と、字の下の線）。書式の辞書（`Any` の値）を使わずに、字形を直接描く。
    func label(_ text: String, at point: CGPoint, size: CGFloat, color: CGColor = Palette.ink) {
        let font = CTFontCreateWithName(Self.fontName as CFString, size, nil)
        let characters = Array(text.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: characters.count)
        CTFontGetGlyphsForCharacters(font, characters, &glyphs, characters.count)
        var advances = [CGSize](repeating: .zero, count: glyphs.count)
        CTFontGetAdvancesForGlyphs(font, .horizontal, glyphs, &advances, glyphs.count)
        let starts = advances.reduce(into: [CGFloat]()) { starts, advance in
            starts.append((starts.last ?? 0) + advance.width)
        }
        let positions = zip([0] + starts.dropLast(), advances).map { start, _ in
            CGPoint(x: point.x + start, y: height - point.y)
        }
        context.setFillColor(color)
        CTFontDrawGlyphs(font, glyphs, positions, glyphs.count, context)
    }

    /// 枠の中に絵を描き、補助線を引く（赤 = 足元〈輪郭線のいちばん下〉、青 = 接地線、緑 = 横の中央）。
    func frame(_ image: CGImage, in rect: CGRect, groundRatio: Double) {
        checker(rect)
        draw(image, in: rect)
        let feet = rect.minY + rect.height * FrameGeometry.outlineBottomShare
        let ground = rect.minY + rect.height * groundRatio
        line(CGPoint(x: rect.minX, y: feet), CGPoint(x: rect.maxX, y: feet), Palette.feet)
        line(CGPoint(x: rect.minX, y: ground), CGPoint(x: rect.maxX, y: ground), Palette.ground)
        line(CGPoint(x: rect.midX, y: rect.minY), CGPoint(x: rect.midX, y: rect.maxY), Palette.center)
        stroke(rect, Palette.border)
    }
}

/// コンタクトシートの色。
enum Palette {
    static let paper = color(0.97, 0.96, 0.93)
    static let ink = color(0.23, 0.17, 0.17)
    static let checkerLight = color(0.94, 0.94, 0.94)
    static let checkerDark = color(0.86, 0.86, 0.86)
    /// 縁のにじみ（白・緑の縁取り）が目立つ暗い地（§6.5「暗い背景と明るい背景の両方で確認」）。
    static let dark = color(0.16, 0.17, 0.2)
    /// 小さな姿の地（待受の部屋の壁に近い、明るい色）。
    static let room = color(0.93, 0.89, 0.82)
    static let feet = color(0.9, 0.2, 0.2)
    static let ground = color(0.2, 0.45, 0.9)
    static let center = color(0.2, 0.7, 0.3)
    static let border = color(0.6, 0.6, 0.6)

    static func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> CGColor {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
}
