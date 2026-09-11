import WidgetKit
import SwiftUI
import CTCore
import CTAssets
import CTStore
import CTRender

/// 骨組みの確認用ウィジェット。
///
/// ここで確かめたいのは見た目ではなく、**別プロセスの拡張から
/// App Group と同梱データに届くか**の一点（プラン §7.6）。
/// Phase 3 で部屋とキャラの表示に置き換える。
struct SkeletonEntry: TimelineEntry, Sendable {
    let date: Date
    let characterName: String
    let seedDigest: String
    let storeOutcome: String
    let capability: RenderCapability
}

struct SkeletonProvider: TimelineProvider {

    func placeholder(in context: Context) -> SkeletonEntry {
        SkeletonEntry(date: .now, characterName: "ピヨ", seedDigest: "……",
                      storeOutcome: "読み込み中", capability: .timelineTransition)
    }

    func getSnapshot(in context: Context, completion: @escaping (SkeletonEntry) -> Void) {
        completion(Self.makeEntry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SkeletonEntry>) -> Void) {
        // 本番のタイムラインは 5 分刻み（プラン §7.5）。骨組みでは 1 件だけ作って、
        // 拡張が起動して App Group を読めたことが分かればよい。
        let entry = Self.makeEntry(at: .now)
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(15 * 60))))
    }

    /// 拡張側では **絶対に落とさない**。落ちるとその後の更新まで巻き添えで止まる。
    private static func makeEntry(at date: Date) -> SkeletonEntry {
        let loaded = StateStore.shared.load()
        let characters = Catalog.charactersOrEmpty()
        let selected = characters.first { $0.id == loaded.state.selectedCharacterID } ?? characters.first

        let outcome = switch loaded.outcome {
        case .loaded:            "読めた"
        case .notFound:          "まだ無い"
        case .noContainer:       "共有コンテナに届かない"
        case .corrupted:         "壊れていたので既定値"
        case .futureSchema(let version): "新しい版 \(version) なので既定値"
        }

        return SkeletonEntry(
            date: date,
            characterName: selected?.displayName ?? "（同梱データなし）",
            seedDigest: String(loaded.state.userSeed, radix: 16).suffix(6).description,
            storeOutcome: outcome,
            capability: RenderCapability.resolve(RenderContext(surface: .homeWidget)))
    }
}

struct SkeletonWidgetView: View {
    var entry: SkeletonEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("CharaTime")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.ink)
            Text(entry.characterName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Palette.accent)
            Spacer(minLength: 0)
            Text("App Group ・ \(entry.storeOutcome)")
                .font(.system(size: 10))
                .foregroundStyle(Palette.inkMuted)
            Text("種 …\(entry.seedDigest) ・ \(entry.capability.label)")
                .font(.system(size: 10))
                .foregroundStyle(Palette.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct SkeletonWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CharaTimeSkeleton", provider: SkeletonProvider()) { entry in
            SkeletonWidgetView(entry: entry)
                .containerBackground(Palette.background, for: .widget)
        }
        .configurationDisplayName("CharaTime（骨組み）")
        .description("パッケージと App Group がつながっているかの確認用。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
