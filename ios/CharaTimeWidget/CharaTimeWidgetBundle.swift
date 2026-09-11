import WidgetKit
import SwiftUI

/// ウィジェット拡張の入口。Phase 3 で本番のウィジェットを、
/// Phase 4 で Live Activity をここに足していく。
@main
struct CharaTimeWidgetBundle: WidgetBundle {
    var body: some Widget {
        SkeletonWidget()
    }
}
