import Testing
import Foundation
import CTCore
import CTAssets
@testable import CTRender

/// 帯は指で動かす。**指はどこへでも行く**ので、画面の外や上下逆でも壊れないこと。
@Suite("歩ける帯")
struct FloorBandTests {

    @Test("上辺と下辺が入れ替わらない")
    func edgesNeverCross() {
        let band = FloorBand(top: 0.6, bottom: 0.8)
        // 上辺を下辺より下へ引っぱっても、最小の厚みは残る。
        let squeezed = band.moving(.top, to: 0.95)
        #expect(squeezed.top < squeezed.bottom)
        #expect(abs(squeezed.height - FloorBand.minimumHeight) < 0.000_1)
        // 下辺を上辺より上へ引っぱっても同じ。
        let lifted = band.moving(.bottom, to: 0.1)
        #expect(lifted.top < lifted.bottom)
        #expect(abs(lifted.height - FloorBand.minimumHeight) < 0.000_1)
    }

    @Test("画面の外へ引っぱっても置ける範囲に収まる")
    func staysWithinTheScreen() {
        for position in [-5.0, -0.2, 0.0, 1.0, 3.4] {
            let band = FloorBand(top: 0.6, bottom: 0.8).moving(.top, to: position)
            #expect(FloorBand.allowed.contains(band.top))
            #expect(FloorBand.allowed.contains(band.bottom))
            let moved = FloorBand(top: 0.6, bottom: 0.8).moving(.bottom, to: position)
            #expect(FloorBand.allowed.contains(moved.top))
            #expect(FloorBand.allowed.contains(moved.bottom))
        }
    }

    /// 0.98 − 0.92 は小数で正確に表せないので、厚みの判定にはわずかな幅を持たせる。
    static let epsilon = 1e-9

    @Test("逆さに作っても正しい向きに直る")
    func upsideDownIsFixed() {
        let band = FloorBand(top: 0.9, bottom: 0.2)
        #expect(band.top < band.bottom)
        #expect(band.height >= FloorBand.minimumHeight - Self.epsilon)
    }

    @Test("片方を動かしても、もう片方は動かない")
    func movingOneEdgeKeepsTheOther() {
        let band = FloorBand(top: 0.50, bottom: 0.90)
        #expect(band.moving(.top, to: 0.30).bottom == band.bottom)
        #expect(band.moving(.bottom, to: 0.95).top == band.top)
    }

    @Test("矩形に直すと帯の高さになる")
    func rectMatchesTheBand() {
        let band = FloorBand(top: 0.62, bottom: 0.86)
        #expect(abs(band.rect.y - 0.62) < 0.000_1)
        #expect(abs(band.rect.height - 0.24) < 0.000_1)
    }

    @Test("選び方ごとの初期値は、置ける範囲に収まっている")
    func suggestedBandsAreValid() {
        for choice in RoomChoice.allCases {
            let band = choice.suggestedBand
            #expect(band.height >= FloorBand.minimumHeight - Self.epsilon,
                    Comment(rawValue: "\(choice.title) の帯が薄すぎる"))
            #expect(FloorBand.allowed.contains(band.top))
            #expect(FloorBand.allowed.contains(band.bottom))
        }
    }

    /// 端まで歩いても体が画面の外へ出ないだけの余白が要る。
    @Test("左右の余白は、いちばん大きく見えるキャラの体半分より広い")
    func horizontalInsetKeepsTheBodyOnScreen() {
        let geometry = SpriteGeometry(aspectRatio: 130.0 / 180.0, groundRatio: 168.0 / 180.0)
        for (width, height) in [(390.0, 844.0), (402.0, 874.0), (440.0, 956.0), (170.0, 170.0)] {
            let size = CGSize(width: width, height: height)
            let inset = SceneLayout.safeHorizontalInset(in: size, geometry: geometry)
            let bodyHalfWidth = height * SceneLayout.characterHeightRatio
                * geometry.aspectRatio * SceneLayout.bodyWidthRatio / 2
            let note = "\(width)x\(height): 余白 \(inset * width)pt / 体の半分 \(bodyHalfWidth)pt"
            #expect(inset * width >= bodyHalfWidth - 0.001, Comment(rawValue: note))
            #expect(inset < 0.5, Comment(rawValue: note))
        }
    }

    @Test("同梱の部屋の床は、その余白を守っている")
    func bundledFloorRespectsTheInset() {
        let geometry = SpriteGeometry(aspectRatio: 130.0 / 180.0, groundRatio: 168.0 / 180.0)
        let inset = SceneLayout.safeHorizontalInset(in: CGSize(width: 402, height: 874),
                                                    geometry: geometry)
        #expect(BundledRoom.floor.minX >= inset)
        #expect(BundledRoom.floor.maxX <= 1 - inset)
    }
}
