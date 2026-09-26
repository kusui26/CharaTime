import Foundation

/// `week-run.json`（1 週間の運用の記録表。プラン §9 Phase 3 の 3-7）の読み書き。
///
/// **書くのも読むのもアプリだけ。** ウィジェットが毎回読む `state.json` とは別のファイルにして、
/// そちらを大きくしない。読みは失敗しない（無い・壊れていれば、まだ始めていない記録表）。
/// 書きは、書けなければどこに書けないかを添えて投げる（利用者がつけた記録なので、黙って捨てない）。
public struct WeekRunStore: Sendable {

    public static let fileName = "week-run.json"

    /// 書き込み先のディレクトリ。テストではテンポラリを渡す。
    public let directory: URL?

    public init(directory: URL?) {
        self.directory = directory
    }

    /// App Group の共有コンテナを使う既定の置き場（`state.json` と同じ所）。
    public static var shared: WeekRunStore { WeekRunStore(directory: AppGroup.containerURL) }

    public var fileURL: URL? { directory?.appendingPathComponent(Self.fileName) }

    /// 何があっても記録表を返す。
    public func load() -> WeekRunRecord {
        guard let fileURL, let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(WeekRunRecord.self, from: data) else {
            return WeekRunRecord()
        }
        return decoded
    }

    /// 途中で落ちても壊れないように、一時ファイルへ書いてから差し替える。
    public func save(_ record: WeekRunRecord) throws {
        guard let fileURL, let directory else {
            throw StateStore.StoreError.noContainer(appGroup: AppGroup.identifier)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]   // 差分が読める形で残す
        try encoder.encode(record).write(to: fileURL, options: [.atomic])
    }
}
