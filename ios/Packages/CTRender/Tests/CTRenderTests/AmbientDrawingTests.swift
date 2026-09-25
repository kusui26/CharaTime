import Testing
import Foundation
import CTCore
import CTAssets
@testable import CTRender

/// 疑似アニメを描くときの決まり（プラン §9 Phase 3 の 3-2b）。
@Suite("疑似アニメの描き方")
struct AmbientDrawingTests {

    /// Swift の側とパイプライン（tools/pipeline/masks.py）が、同じ規則で書体の名前を作る。
    @Test("マスク書体の名前は、CTMask に数字の並びを付けたもの")
    func maskFontNames() {
        #expect(MaskFont.name(for: DigitSet([0, 5])) == "CTMask05")
        #expect(MaskFont.name(for: .even) == "CTMask02468")
    }

    @Test("書体の一族の名前は、パイプラインが焼いた書体の一覧と同じ")
    func familyNamesMatchTheCatalog() {
        #expect(MaskFont.familyNames == Catalog.maskFontsOrEmpty().map(\.name))
        #expect(MaskFont.familyNames.count == MaskFontFamily.digitSets.count)
    }

    static let ball = CGRect(x: 100, y: 40, width: 20, height: 20)

    @Test("光の粒は、ボールのまわりの 4 か所に、ボールと重ならずに散る")
    func sparklesScatterAroundTheBall() {
        let frames = (0..<4).map { SparkleLayout.frame($0, around: Self.ball) }
        let centers = frames.map { CGPoint(x: $0.midX, y: $0.midY) }
        #expect(Set(centers.map { "\(Int($0.x)),\(Int($0.y))" }).count == 4)
        for frame in frames {
            let distance = hypot(frame.midX - Self.ball.midX, frame.midY - Self.ball.midY)
            #expect(distance - frame.width / 2 > Self.ball.width / 2, "粒がボールに重なる: \(frame)")
            #expect(abs(frame.width - Self.ball.width * SparkleLayout.sizeRatio) < 0.001)
        }
    }

    /// 待受モードの z は道筋を浮かんでいき、ウィジェットの z はその道筋の 3 か所に置く（2026-09-25）。
    @Test("寝ている z は、道筋を右上へ進むほど大きく、薄くなる")
    func sleepMarksRiseGrowAndFade() {
        let origin = CGPoint(x: 100, y: 200)
        let marks = (0..<SleepMarkLayout.count).map {
            SleepMarkLayout.mark(phase: SleepMarkLayout.widgetPhase($0), origin: origin, height: 100)
        }
        #expect(marks.count == 3)
        for (lower, upper) in zip(marks, marks.dropFirst()) {
            #expect(upper.center.x > lower.center.x && upper.center.y < lower.center.y)
            #expect(upper.fontSize > lower.fontSize && upper.opacity < lower.opacity)
        }
        #expect(marks.allSatisfy { $0.center.y < origin.y && $0.center.x > origin.x })
        #expect(marks[0].opacity > 0.5, "1 つ目の z（出したまま）は、はっきり見える濃さ")
    }

    /// ボールの上下左右に偏らない（上は天井の紐、下は床で、見えにくくなる）。
    @Test("光の粒は、ボールの左右と上下の両側に出る")
    func sparklesSpreadOnBothSides() {
        let frames = (0..<4).map { SparkleLayout.frame($0, around: Self.ball) }
        #expect(frames.contains { $0.midX < Self.ball.midX } && frames.contains { $0.midX > Self.ball.midX })
        #expect(frames.contains { $0.midY < Self.ball.midY } && frames.contains { $0.midY > Self.ball.midY })
    }
}
