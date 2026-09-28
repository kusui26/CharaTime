import Testing
import Foundation
import CoreGraphics
@testable import CTStudio

/// 取り込みの知らせのための見分け（プラン §9 Phase 2 の 2-C ⑤-7）: 歩く向き・足元の影。
@Suite("歩く向きと足元の影")
struct SheetChecksTests {

    static func figure(_ name: String, scale: CGFloat = 0.45) -> Figure {
        let image = Samples.alone(Samples.Placement(name: name, origin: .zero, scale: scale), width: 270, height: 370)
        return Figure(image: image, originX: 0, originY: 0)
    }

    @Test("いまの歩く絵は左向き。左右を反転すると右向きと分かる", arguments: ["piyo", "mochi", "fuwa", "chip"])
    func walkingDirectionFollowsTheEye(id: String) {
        let frames = (1...4).map { Self.figure("\(id)_walk_0\($0)") }
        #expect(!WalkDirection.facesRight(frames))
        #expect(WalkDirection.facesRight(frames.map { $0.mirrored() }))
    }

    @Test("目が見つからない絵（正面の閉じた目）は向きを決めず、そのまま使う")
    func unknownDirectionKeepsTheDrawing() {
        #expect(WalkDirection.facesRight(Self.figure("piyo_sleep_01")) == nil)
        #expect(!WalkDirection.facesRight([Self.figure("chip_happy_01")]))
    }

    @Test("いまの 5 体のどの姿勢も、縮めて並べても影とみなさない")
    func bundledPosesHaveNoShadow() throws {
        for id in ["piyo", "mochi", "kumao", "fuwa", "chip"] {
            for pose in ["idle_01", "walk_01", "sit_01", "sleep_01", "happy_01"] {
                let image = Self.figure("\(id)_\(pose)").image
                let box = try #require(Samples.opaqueBox(image))
                #expect(!ShadowCheck.hasShadow(in: image, below: box), "\(id)_\(pose)")
            }
        }
    }

    @Test("足元に薄い影（半透明の楕円）があれば見つける")
    func translucentShadowIsFound() throws {
        var image = Self.figure("piyo_idle_01").image
        let box = try #require(Samples.opaqueBox(image))
        let imageHeight = image.height
        _ = image.draw { context in
            context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.3))
            // Core Graphics は左下が原点。足元（外接矩形の下端）を中心に、体の幅の 8 割の楕円。
            let width = CGFloat(box.width) * 0.8, height = CGFloat(box.height) * 0.08
            context.fillEllipse(in: CGRect(x: CGFloat(box.centerX) - width / 2,
                                           y: CGFloat(imageHeight - box.bottom) - height / 2,
                                           width: width, height: height))
        }
        #expect(ShadowCheck.hasShadow(in: image, below: box))
    }
}
