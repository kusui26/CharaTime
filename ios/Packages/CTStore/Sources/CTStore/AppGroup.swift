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

/// ホーム画面ウィジェットの種類の名前（WidgetKit の kind）。
///
/// 拡張が名乗るときと、アプリが作り直しを頼むとき（`WidgetCenter.reloadTimelines(ofKind:)`）に
/// 同じ名前を使う。**変えると、置いてあるウィジェットは別のものとして扱われ、置き直しになる。**
/// 名前を指して頼むのは、この名前のウィジェットだけを作り直すため（ほかの種類を足しても巻き込まない）。
public enum WidgetKind {
    public static let home = "CharaTimeHome"
}
