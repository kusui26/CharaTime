import Foundation

/// アプリ本体とウィジェット拡張が共有する入れ物。
///
/// 両ターゲットの entitlements に同じ識別子を書いてある（`ios/project.yml`）。
/// ここを変えるときは project.yml も一緒に変えること。
public enum AppGroup {

    public static let identifier = "group.app.charatime"

    /// 共有コンテナの場所。App Group が設定されていない環境では nil。
    ///
    /// `swift test` は素の macOS プロセスとして動くので、ここは必ず nil になる。
    /// だからテストは実際のコンテナを使わず、テンポラリのディレクトリを渡す
    /// （`StateStore(directory:)`）。
    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
