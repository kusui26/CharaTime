import Foundation

/// `widget-diagnostics.json`（ウィジェットの記録）の読み書き（プラン §9 Phase 3 の 3-2c）。
///
/// **書くのはウィジェット拡張、読むのはアプリ。** `state.json` とは別のファイルにして、
/// 「`state.json` はアプリだけが書く」という約束を崩さない（書く側が 2 つになると、書き込みが
/// 重なったときに設定が消えうる）。
///
/// **読みも書きも失敗しない。** 記録のために拡張を落とさない（CLAUDE.md §2）。読めなければ空、
/// 書けなければ何もしない。記録は測定の手がかりで、無くても描画には関わらない。
public struct DiagnosticsStore: Sendable {

    public static let fileName = "widget-diagnostics.json"

    /// 書き込み先のディレクトリ。テストではテンポラリを渡す。
    public let directory: URL?

    public init(directory: URL?) {
        self.directory = directory
    }

    /// App Group の共有コンテナを使う既定の置き場。
    public static var shared: DiagnosticsStore { DiagnosticsStore(directory: AppGroup.containerURL) }

    public var fileURL: URL? { directory?.appendingPathComponent(Self.fileName) }

    /// 拡張は大きさごとのタイムラインを並行して作ることがある。読んで足して書く間に、ほかの書き込みが
    /// 割り込まないようにする（同じプロセスの中だけで足りる。アプリは読むだけ）。
    private static let writeLock = NSLock()

    /// 何があっても記録を返す（無ければ空）。
    public func load() -> WidgetDiagnostics {
        guard let fileURL, let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(WidgetDiagnostics.self, from: data) else {
            return WidgetDiagnostics()
        }
        return decoded
    }

    /// 記録を読み、`change` で作り替えて書き戻す。書けなければ何もしない。
    public func update(_ change: (WidgetDiagnostics) -> WidgetDiagnostics) {
        guard let fileURL, let directory else { return }
        Self.writeLock.withLock {
            let changed = change(load())
            guard let data = try? JSONEncoder().encode(changed) else { return }
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            #if os(iOS)
            // ロック中のタイムラインの作り直しでも書けるようにする（`state.json` と同じ保護）。
            try? data.write(to: fileURL,
                            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            #else
            try? data.write(to: fileURL, options: [.atomic])
            #endif
        }
    }
}
