import UIKit
import CTStore
import CTRender

// アプリとウィジェット拡張の両方に入れる（ios/project.yml）。同じ規則で「動かしてよいか」を決めるため。

/// マスク書体が登録されているか（両方のターゲットの `UIAppFonts`。プラン §9 Phase 3 の 3-2b）。
enum MaskFontRegistry {

    /// 一族の書体がすべて登録されているか。1 本でも無ければ、疑似アニメを使わない。
    ///
    /// 登録されていない書体を `Font.custom` で指すと、黙ってシステムの字に落ちる。マスクが数字の形になり、
    /// 絵が数字の形の穴から覗いてしまう（スパイクの教訓。docs/260912_spike.md §5 ②）。
    static let isComplete: Bool = MaskFont.familyNames.allSatisfy {
        UIFont(name: $0, size: probeSize) != nil
    }

    /// 確かめるのに使う字の大きさ。登録されているかだけを見るので、何でもよい。
    private static let probeSize: Double = 12
}

extension WidgetMotion {

    /// この端末でいま、ホーム画面ウィジェットを動かしてよいか（3-C ⑤）。
    ///
    /// 設定が入で、書体がそろっていれば疑似アニメを使う。低電力モードは、タイムラインを作った
    /// ときの状態で決める（そのあいだに切り替わったら、次に作り直すときに合わせる）。
    static func current(for widget: WidgetSettings) -> WidgetMotion {
        WidgetMotion(pseudoAnimation: widget.usesPseudoAnimation && MaskFontRegistry.isComplete,
                     lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled)
    }
}
