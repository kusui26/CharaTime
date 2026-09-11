import Foundation

/// `state.json` の読み書き。
///
/// 設計の要は **読みが絶対に失敗しないこと**。ウィジェット拡張は落ちると
/// その後の更新まで巻き添えで止まるので、壊れた JSON を読んだときも既定値を返して
/// 描き続ける。何が起きたかは `LoadOutcome` で呼び出し側に伝える。
public struct StateStore: Sendable {

    public enum LoadOutcome: Sendable, Equatable {
        /// 読めた。
        case loaded
        /// ファイルがまだ無い（初回起動）。
        case notFound
        /// 共有コンテナに届かない（App Group が未設定など）。
        case noContainer
        /// JSON が壊れていた。
        case corrupted(String)
        /// 知らない将来の版だった。中身は信用せず既定値に落とした。
        case futureSchema(Int)
    }

    public struct Loaded: Sendable, Equatable {
        public var state: AppState
        public var outcome: LoadOutcome
    }

    public enum StoreError: Error, Sendable, Equatable, CustomStringConvertible {
        /// 書き込み先が無い。どの App Group を探して届かなかったかを添える。
        case noContainer(appGroup: String)

        public var description: String {
            switch self {
            case .noContainer(let appGroup):
                "共有コンテナに書けません（App Group \(appGroup) が未設定か、"
                    + "entitlements に入っていません）"
            }
        }
    }

    public static let fileName = "state.json"

    /// 書き込み先のディレクトリ。テストではテンポラリを渡す。
    public let directory: URL?

    public init(directory: URL?) {
        self.directory = directory
    }

    /// App Group の共有コンテナを使う既定の置き場。
    public static var shared: StateStore { StateStore(directory: AppGroup.containerURL) }

    public var fileURL: URL? { directory?.appendingPathComponent(Self.fileName) }

    // MARK: - 読み

    /// 何があっても使える状態を返す。
    public func load(fallbackSeed: UInt64 = 0) -> Loaded {
        guard let fileURL else {
            return Loaded(state: AppState(userSeed: fallbackSeed), outcome: .noContainer)
        }
        guard let data = try? Data(contentsOf: fileURL) else {
            return Loaded(state: AppState(userSeed: fallbackSeed), outcome: .notFound)
        }
        do {
            let decoded = try JSONDecoder().decode(AppState.self, from: data)
            if decoded.schemaVersion > AppState.currentSchemaVersion {
                // 新しいアプリが書いた JSON を古いウィジェットが読んだ場合。
                // 解釈できない項目を握ったまま描くより、既定値で描くほうが安全。
                return Loaded(state: AppState(userSeed: decoded.userSeed),
                              outcome: .futureSchema(decoded.schemaVersion))
            }
            return Loaded(state: decoded, outcome: .loaded)
        } catch {
            return Loaded(state: AppState(userSeed: fallbackSeed),
                          outcome: .corrupted(String(describing: error)))
        }
    }

    // MARK: - 書き

    /// 途中で落ちても壊れないように、一時ファイルへ書いてから差し替える。
    public func save(_ state: AppState) throws {
        guard let fileURL, let directory else {
            throw StoreError.noContainer(appGroup: AppGroup.identifier)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var stored = state
        stored.schemaVersion = AppState.currentSchemaVersion
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]   // 差分が読める形で残す
        let data = try encoder.encode(stored)

        #if os(iOS)
        // ロック中のウィジェット更新でも読めるようにする。既定より緩い保護だが、
        // ここに入るのは「どのキャラを選んだか」程度で、秘密は置かない。
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: fileURL, options: [.atomic])
        #endif
    }

    /// 無ければ作り、有ればそのまま返す。初回起動で種を確定させるために使う。
    @discardableResult
    public func loadOrCreate() throws -> AppState {
        let loaded = load()
        switch loaded.outcome {
        case .loaded:
            return loaded.state
        case .noContainer:
            throw StoreError.noContainer(appGroup: AppGroup.identifier)
        case .notFound, .corrupted, .futureSchema:
            let fresh = AppState.makeInitial()
            try save(fresh)
            return fresh
        }
    }
}
