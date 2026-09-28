import Foundation
import CTStore

/// 背景を外す（プラン §9 Phase 2 の 2-C ⑤-2、D-36）。
///
/// 透明 → 不透明さだけそろえる。1 色の地・市松模様 → 縁からつながる地だけを抜く（自前の処理。シミュレータと
/// `swift test` でも同じ結果になる）。それ以外（模様・写真・絵の背景）→ Vision の被写体の切り抜きに回す
/// （`needsSubjectLift`。Vision はシミュレータで動かないので、呼び出し側が実機か Mac で行う）。
public enum BackgroundRemoval {

    public enum Outcome: Sendable, Equatable {
        /// 背景を外した絵と、その外し方（取り込みの記録に残す）。
        case removed(Raster, ImportRecord.Background)
        /// 地が 1 色でも透明でもない。Vision の被写体の切り抜きが要る。
        case needsSubjectLift
    }

    public static func remove(from raster: Raster) -> Outcome {
        var result = raster
        switch BackgroundKind.classify(BorderBand(raster)) {
        case .transparent:
            AlphaSnap.apply(to: &result)
            return .removed(result, .transparent)
        case .solid(let key):
            ColorKey.remove(keys: [key], from: &result)
            AlphaSnap.apply(to: &result)
            return .removed(result, .solidColor)
        case .checkerboard(let first, let second):
            ColorKey.remove(keys: [first, second], from: &result)
            AlphaSnap.apply(to: &result)
            return .removed(result, .checkerboard)
        case .complex:
            return .needsSubjectLift
        }
    }

    /// Vision などで被写体だけを残した絵を受け取る。透明の地と同じに、不透明さだけそろえる。
    public static func lifted(_ raster: Raster) -> Outcome {
        var result = raster
        AlphaSnap.apply(to: &result)
        return .removed(result, .subjectLift)
    }
}
