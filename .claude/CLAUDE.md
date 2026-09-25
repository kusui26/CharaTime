# CLAUDE.md — CharaTime 開発指針

このファイルは **CharaTime** リポジトリで Claude Code が作業するときの指針です。
全体の設計と根拠は `docs/260910_dev_plan.md`（v1.3）にあります。迷ったらそちらが正。

---

## 1. プロジェクトの本質

**iPhone の中に小さなキャラクターが住んでいて、見ていないあいだも勝手に生きている。**
au ガラケー時代の「ケータイパートナー」の再現です。

iOS はホーム画面に直接描画できないので、**複数の「面」で分担**します（プラン §4）。
面 0 待受モード（アプリ内・60fps）／面 1 ホーム画面ウィジェット（透過）／面 2 StandBy／
面 3 Live Activity「いっしょモード」／面 4 壁紙／面 5 PiP（実験枠）。

> **すべての面は CTCore の同じ `sceneState(at:)` を、同じ入力で呼ぶ。**
> 面ごとに違うのは「時刻をどう渡すか」と「どう描くか」だけ。

---

## 2. 最重要原則

**決定論を壊さない。** ここが崩れると、ウィジェットで見た姿とアプリを開いた姿が食い違い、
このアプリの価値（一匹が住んでいる感）が消えます。

- **`Date()` を CTCore の中で呼ばない。** 時刻は必ず引数で受け取る。
- **`Swift.Hasher` / `hashValue` / `Int.random` を状態の決定に使わない。**
  プロセスごとに値が変わる。乱数は必ず `Hash64` と `IndexedRandom` を通す。
  唯一の例外は `AppState.makeInitial` の `userSeed`。ここは「その人だけの種」を
  初回に 1 回決めて保存する場所で、以後の姿はすべてこの保存済みの種から引く。
- **連番の乱数生成器を使わない。** 添字で直接引けること（`rng.unit(segment, waypoint)`）が、
  ウィジェットが 3 時間後の姿を先読みできる理由。
- プロシージャルな動き（跳ねる・傾く・呼吸）も **時刻 t の関数**にする。状態を持たせない。
- 文脈（電池・歩数・天気）は日課表を差し替えず、`SceneState` の後段で合成する。

**ウィジェット拡張を落とさない。** 拡張が落ちると、その後の更新まで巻き添えで止まります。
読み込みは失敗しても既定値を返す（`StateStore.load` を参照）。

**依存の向きは一方向。** `CTCore ← CTAssets ← CTRender / CTStore ← アプリ / ウィジェット`。
- `CTCore` は Foundation だけ。UIKit・SwiftUI・CoreGraphics を入れない。
- `CTRender` は SwiftUI のみ。UIKit と SpriteKit を入れない（ウィジェットと共有するため）。
  WidgetKit は、ウィジェットの描き分けの修飾子と環境の値のためだけに使う（D-27）。
- ウィジェット拡張は約 30 MB のメモリ上限で動く。重い依存を足すときは必ず測る。

**画像とマスク書体はパイプライン経由でしか追加しない。** `tools/pipeline` が `characters.json` /
`items.json` / `mask_fonts.json` と Asset Catalog・`ios/Shared/Fonts` を書き換える。手で画像や書体を足さない。
書体の一族（D-29）を変えるときは、CTCore の `MaskFontFamily` と `project.yml` の `UIAppFonts` も合わせる
（テストとパイプラインの検査が食い違いを見つける）。

---

## 3. コーディング規約

**哲学: 人間が一目で理解できるコードを書く。** コードは物語のように読め、命名はストーリーを語る。

**小さく純粋に**
- **1 関数は 20 行未満・単一責務。** 超えたら分ける。分けにくいなら責務が混ざっている。
  数えるのはコメントと空行を除いた行（`swiftlint` の数え方。`.swiftlint.yml` が見張る）。
- 副作用を分離する。純粋な変換は専用ファイルへ置き、引数だけで答えが決まる形にする
  （`DayPlan` / `Motion` / `SceneEngine` がその形。だから 1 ミリ秒でテストできる）。
- 関数どうしの依存を減らし、疎結合に保つ。

**不変・関数型**
- `var` より `let`。変数を上書きしない。`var` を使うのは、組み立て途中の値を
  1 か所に閉じ込めるときだけ（`PlanBuilder` のような小さな型の中）。
- `for` より `map` / `filter` / `reduce` / `flatMap`。ただし
  **決定論に関わる並び順を変えない**こと（`weightedIndex` は添字の順に依存する）。
- 完了ハンドラより `async`/`await`。
- 文字列の組み立ては `+=` でなく、配列に貯めて `joined()`。

**型を厳格に**
- `Any` / `AnyObject` を使わない。
- **`as!` / `try!` 禁止。** `as?` + `guard let`、または `Result` と既定値で受ける。
- **強制アンラップ（`!`）はテストとプレビューだけ。** 本体コードでは `if let` / `map` を使う。
- 公開 API には型を明記する（`public` の返り値型は省略しない）。
- JSON の形は `Codable` の型ひとつから導く。同じ形を 2 か所に書かない。

**DRY・定数・単位**
- **マジックナンバー禁止。** 名前付き定数にして、なぜその値かをコメントに書く。
  調整値は 1 か所に集める（`Schedule` / `ActivityWeight` / `Motion`）。
- **単位を名前に**: `intervalSeconds`、`widthRatio`、`bedtimeMinutes`、`thresholdRatio`。
- 定義の出どころはひとつ。キャラとアイテムは `characters.json` / `items.json` だけが正で、
  アプリ・ウィジェット・Python パイプラインがそれを共有する。

**堅牢性**
- 失敗しうる処理には**文脈付きのエラー**を付ける（どのファイル・どの ID で失敗したか）。
  `CatalogError` がその形。`String(describing:)` だけで捨てない。
- **ウィジェット拡張から呼ぶ経路は、失敗しても既定値を返す**（`load` / `charactersOrEmpty`）。
- ネットワーク（将来の WeatherKit）には**必ずタイムアウト**を入れる。
  `URLSession` の `timeoutIntervalForRequest` か `Task` のキャンセルで打ち切る。
  ウィジェットの更新予算を待ち時間で使い切らせない。

**品質ゲート**（3 つとも回す）
- `swiftlint --strict`（lint。設定は `.swiftlint.yml` と `.swiftlint-tests.yml`）
- `swift build`（typecheck。**警告を 1 件も残さない**）
- `swift test`（単体テスト）
- 3 つまとめて `scripts/check.sh`。**コミット前に必ず通す。**
- **境界値とエッジケースを厚く**: 0:00 と 24:00、うるう年、空の配列、重み全 0、
  壊れた JSON、App Group が無い場合。

**落とし穴**
- **依存パッケージにファイルを増やすと、SwiftPM が取りこぼす。** 使った側で
  「value of type 'X' has no member 'y'」という、原因から遠い形で落ちる。
  `scripts/check.sh` がファイルの顔ぶれを見て作り直すので、まずそれを通す。
- **SwiftUI の `View` は `@MainActor`。** 純粋な計算を View の静的メソッドに置くと、
  メインスレッド以外から呼んだときに隔離の検査で落ちる（`ItemOrder` がその教訓）。
- **`Text` の `foregroundStyle` は `Canvas` の中で効かない。** `GraphicsContext.resolve` を
  通した文字の色は `shading` で指定する。
- **ウィジェットの `Text(timerInterval:)` に `.fixedSize()` を当てない。** アプリの中では字に
  ぴったりの枠になるが、ウィジェットの中では枠の幅が有限にならず、字が描かれない。
  その幅に `GeometryReader` を当てると拡張ごと落ちる（スパイク C・D・E の教訓）。
  `.frame(width:)` で最長の字数ぶんの枠を決め、寄せは `multilineTextAlignment` で指定する。
- **マスクに使う `Text(timerInterval:)` には `.contentTransition(.identity)` を当てる。** 当てないと、
  エントリ切替のアニメのあいだ OS が字の入れ替わりまで溶かして重ね、0.25 秒のまばたきが
  半透明のまぶたになる（3-2b。`MidnightTimerText` が当てている）。
- **ウィジェットの `configurationDisplayName` / `description` に文字列補間を直接書かない。**
  `"… \(n) …"` は書式付きの文字列になり、WidgetKit が実行時に止める（拡張ごと落ちる）。`String` に組み立ててから渡す。
- **UI テストを走らせても、アプリは入れ直されない。** ウィジェットを足したら `scripts/home-screen.sh build` で
  入れ直す。入れ直さないと、足したウィジェットがギャラリーに出てこない。
- **シミュレータのホーム画面は、15 分ほど触らずにおくと休み、まばたき（0.25 秒の窓）が出なくなる。**
  収録の前に `scripts/home-screen.sh shot` で 1 回触る。収録を始めた直後の 5 秒ほどは描き直しが走るので、
  頭だけ見て「動いている」と判断しない（3-2b）。
- **写真アプリから画像を受け取るときは `preferredItemEncoding: .current`。** 既定では形式を変えられることがあり
  （JPEG など）、画素が変わる。透過背景の壁紙のスクショは `ImageStore.decodeExact` で縮めずに読む
  （`decodeScaled` は縮小の仕組みを通り、画素と色がずれうる。3-3）。
- **実行中のスクリプトを書き換えない。** bash は実行しながら読むので、構文エラーになる。
- **`#expect` の中で `CGFloat` と `Double` を直接比べない。** 同じ値でも等しくならない。
  `Double(...)` にそろえてから比べる（3-2 で、差が 0 なのに落ちた）。

**import**
- `import` はファイル先頭に置く。条件付きは `#if os(iOS)` で囲む。
- 正当な理由なく再エクスポート（`@_exported`）しない。
- 標準ライブラリにあるものを自作しない（`reduce`・`binarySearch` 相当・`ClosedRange`）。
- 依存の版を上げるときは、対象版の API 署名を実際に確かめる（CI の Swift 版検査が例）。

**書き方**
- **コメントは「なぜ」を書く**: 「何を」はコードが語る。制約（Apple の仕様、プランの決定、
  調整の経緯）を残す。
- **日本語で書く**: コメントも、テスト名も、コミットメッセージも。

---

## 4. Git / 変更範囲 / デバッグ（ガードレール）

**Git（ユーザーの明示的許可なしに書き込み系 git を実行しない）**
- 作業前に必ず `git status` / `git branch` で現在地を確認。想定と違えば確認する。
- **`main` に直接 push しない** → フィーチャーブランチを切って PR。実装開始前にブランチ作成。
- `git commit` / `push` / `merge` / `rebase` 前に必ず確認を取る。読み取り系（status/diff/log）は自由。
- **`git add .` 禁止**（ファイルは個別に add）。**未追跡ファイルを削除しない**。
- **`push --force` 禁止・`rebase` 禁止**。**未 push のコミットでも rebase しない**
  （著者名の付け替えのような「きれいにする」目的も含む）。歴史を整えたくなったら、
  直さずに次のコミットから正す。
- マージは **merge commit** で、**squash 禁止**。
- プレフィックス: `feat:` / `fix:` / `refactor:` / `docs:` / `chore:` / `test:`
- 「PR を作って」＝ **PR 作成**（マージではない）。**作成前にターゲットブランチを確認**する。
  マージはユーザーが行う。

**変更範囲**
- **明示的に依頼された変更のみ**行う。機能・ツール・パッケージ・コンテンツを
  自律的に追加しない。必要そうならまず確認。
- プランの決定（D-xx）に反する変更をするときは、先にプランを直す。
- **ドキュメントとコミットメッセージは簡潔に。**

**デバッグ**
- 修正前に**根本原因を診断**。値のハードコードや場当たりの回避策は禁止。
- **リグレッションは git 履歴と diff を確認**してから直す（いつ壊れたかを先に特定する）。

**日付**
- 今日の日付が必要なら**必ず `date` コマンドで取得**する（モデル内部の知識に頼らない）。

---

## 5. 環境（2026-09-11 確定・プラン D-15）

| | 値 | 注意 |
|---|---|---|
| macOS | 26.5.2（**据え置き**） | 上げない。Xcode 27 は入れない |
| Xcode | 26.6（iOS 26.5 SDK） | deployment target は iOS 26.0 |
| 実機 | iPhone 17 Pro / **iOS 26.1** | **iOS 27 に上げない**。上げると実機に入らなくなる |
| メモリ | 8 GB（スワップ逼迫） | Xcode.app を常用しない。`xcodebuild` と `swift test` で回す |

**メモリ 8 GB での作法**: シミュレータは 1 台だけ（iPhone 17 Pro）。重いビルドの前に
Chrome と Docker を閉じる。ロジックは `swift test`（数十ミリ秒）で検証し、
アプリのビルドは見た目を確かめるときだけ。

---

## 6. 検証ループ

```bash
scripts/check.sh                 # lint → ビルド（警告ゼロ）→ テスト。いちばん軽い品質ゲート
scripts/ios-loop.sh              # 上記 → 生成 → ビルド → 起動 → スクショ
scripts/ios-loop.sh --skip-test  # テストを飛ばす（描画だけ見たいとき）
scripts/ios-loop.sh --shot-only  # スクショだけ
scripts/ios-loop.sh --test-only  # scripts/check.sh と同じ（パッケージだけ）
scripts/ios-loop.sh --screen widgets --time 21:05   # ウィジェットの下見（大・中・小）を撮る
scripts/ios-loop.sh --screen standBy --time 23:00   # StandBy の下見（昼と、夜の赤のまね）を撮る
scripts/ios-loop.sh --screen transparent            # 設定の「透過背景」を開いて撮る（alignment で「位置を寄せる」）
```

**コミット前には必ず `scripts/check.sh` を通す。** 3 つの品質ゲート（lint・
警告ゼロのビルド・テスト）をこれ 1 つで回す。CI も同じものを見る。

**核心は「スクリーンショットを撮って、Claude 自身がそれを見る」こと。** `.shots/latest.png` を
Read すれば、自分が書いた UI を目で確認して直せます。

**ホーム画面のウィジェットも、シミュレータで置いて撮って数えられる**（`scripts/home-screen.sh`、プラン D-24）。

```bash
scripts/home-screen.sh build                         # アプリを入れ直す（ウィジェットを直したら毎回）
scripts/home-screen.sh place --clear "CharaTime@大|CharaTime@中"   # 置く（名前の一覧は gallery）
scripts/home-screen.sh shot                          # ウィジェットのページを撮る → .shots/home/latest.png
scripts/home-screen.sh wallpaper wallpaper-light     # 編集モードの空のページ（壁紙だけ）を撮る（透過背景の材料）
scripts/home-screen.sh record --resume 5             # 行って戻るを挟んで収録し、点滅を数える
scripts/home-screen.sh count <実機の動画> --slots small6   # 実機の画面収録も同じ物差しで数える
```

ロボットの操作は 1 回 30 秒〜1 分半（xcodebuild の立ち上げ込み）。止まったら `.shots/home/robot.log` と
`dump-failure.txt` を読み、表示の文字が変わっていれば `HomeScreenRobot/RobotSupport.swift` の `SpringBoardText` を直す。
「ウィジェットもアイコンも見つかりません」で止まるのは、たいていロボットがつながるときに SpringBoard が
落ちたせい（クラッシュ報告は `XCTAutomationSupport` の中で、ウィジェットとは関係ない）。もう一度走らせれば通る。

**シミュレータで確認できること**: レイアウト、配色、Dynamic Type、ダークモード、
ウィジェットのプレビュー（`#Preview(as:)`）、ホーム画面のウィジェットの見た目と点滅（上の道具）、
StandBy のまね（`--screen standBy`。シミュレータに StandBy は無いので、背景を外して拡大し、夜の赤は近似で描く）。

**実機でしか確認できないこと**: ウィジェットの実際の更新間隔、透過ウィジェットのずれ、
StandBy、常時表示、電池と発熱、拡張のメモリ（設定画面の「ウィジェットの記録」で読む。3-2c）、
疑似アニメが放置や再起動のあとも続くか（プラン 3-E の表）。

---

## 7. いま立っている場所

**待受モード（面 0）が動いています。** 日課エンジンが返す姿を `SceneView` が描き、
`ProceduralMotion` が呼吸と弾みを足し、時計と夜モードが乗っています（プラン §9 Phase 1）。
背景は 3 系統（同梱のへや／写真／ホーム画面のスクリーンショット）から選べ、
歩ける帯は指で決められます。

**スパイクの判定は Go**（2026-09-23、D-11。記録は `docs/260912_spike.md` §4）。
面 1 は「**動く窓**」です。拡張が止まっていても、ウィジェットの絵を 1 秒ごと（`ambient1fps`）、
さらに 1 秒に 4 回（`ambient4fps`）まで入れ替えられることを、実機（iOS 26.1）で確かめました。
組むときは、タイマー文字に `.fixedSize()` を当てないこと（§3 の落とし穴。C・D はこれで点かなかった）。

疑似アニメの入／切（`state.json` の `widget.pseudoAnimation`）は、選んでいなければ既定の切です。
設定画面で入にできます。既定を入にするかは、入と切で丸 1 日ずつ電池を測ってから決めます（Q-15）。
低電力・着色・常時表示などでどう落ちるかは、本番のウィジェットで測ります（3-0a を 3-E の表に置き換えた）。

次の山は **Phase 3**（ホーム画面ウィジェット）。**Phase 2**（キャラ 5 体・部屋・アイテム）より先に行います（D-16）。
作業の順番・設計・確かめ方は、プラン §9 の Phase 3（3-A〜3-I）にあります。
**3-0 は、道具（D-24）とスパイク F・G での測定（シミュレータと実機）まで済み**（`docs/260912_spike.md` 3-7）。
タイマーの本数は、1 つのウィジェットに**原則 4 本・最大 8 本**で確定しました（D-17）。実機では 14 本でも、
ホーム画面に戻った直後に止まりません（止まるのはコントロールセンターを閉じた直後だけで、本数に依らない）。
実機の画面収録やスクリーンショットは `iPhone/` に置かれます。**git に入れない**（`.gitignore` 済み。壁紙に人物が写る）。
スパイクのターゲットは、E・F の作り（マスク書体、右から k 字目の切り出し `GlyphWindow`、
0 時起点 `MidnightClock`）を本番へ移し終えたので、消しました（3-2c。記録は `docs/260912_spike.md` に残る）。
Developer Program に登録済みで、実機の署名の期限は 1 年です（3-6 済み）。
**3-1（CTCore と CTStore）も済み**: エントリの時刻（`WidgetTimeline`）、動かし方（`AmbientCue`・
`BlinkRhythm`・`TimerWindow`）、`state.json` の `context` と `widget`。
**3-2（静止のウィジェット）も済み**: 本番の `HomeWidget`（kind `CharaTimeHome`、小・中・大）が骨組みに代わった。
大きさごとの写し方は `WidgetStage`（D-26）、絵は `WidgetScene`（ウィジェット用の小さい絵 mini を読む）。
ホーム画面は実時刻でしか動かないので、好きな時刻の姿は下見の画面（`--screen widgets`）で見る。
拡張のメモリ（大で 15 MB 以下）は実機で測る。
**3-2b（疑似アニメ）も済み**: マスク書体の一族 7 本（D-29）とまぶたの差分で、まばたき・寝息・よろこぶ・
時報の 30 秒・光の粒が、拡張を動かさずに動く（`MaskedTimer.swift`・`AmbientViews.swift`）。
書体がそろわない・設定が切・梯子が 1fps に届かないときは、止めた 1 枚に落ちる。
Reduce Motion（視差効果を減らす）でも、設定が入なら 1fps の小さな動き（まばたき・寝息・z）は続ける
（D-19 を 2026-09-25 に改めた。横すべりと光の粒は止める）。
**3-2c（実機の測定の準備）も済み**: 拡張が作り直すたびにメモリと時刻を自分で測り（`ReloadRecorder`）、
設定画面の「ウィジェットの記録」に出す。メモリは大きさごとでなく拡張 1 つぶんの値で、最大はタイムラインを
渡したあとの絵を作るあいだに出る（実機の最初の値は 13.7 MB）。
**3-5（StandBy）も済み**: 見え方（`WidgetDisplay`）を判定し、背景が外れた黒の上と夜の赤では、
字を淡く、床の帯の端をぼかし、夜の吹き出しを黒い地に白い字にする。実機の StandBy で昼も夜の赤も
見分けられた（小は 2.2 倍に拡大され、夜は明るさがそのまま赤の濃さになる）。下見は `--screen standBy`。
CarPlay には勧めない（D-30）。
**3-3（透過背景）も済み**: 設定 →「透過背景」で、編集モードの空のページのスクショ（ライト・ダーク）を
取り込むと、大と中の枠（`SlotGeometry`。iOS 26 の実測を画素で）で切り抜き（`WallpaperStore`）、ウィジェットが部屋の
代わりに敷く。ずれはシミュレータでも実機でも 0 画素。iOS 26 はウィジェットの縁に細いガラスの縁取りを必ず描く（消せない）。
シミュレータでは `-CTImportWallpaper <ライト> <ダーク>`（App Group の images に置いたスクショ）で取り込める。
次は 3-4（置き方のガイド）。

アセットは併走方針: Phase 0〜1 は `design/` の SVG を `tools/pipeline` で PNG に焼いて動かし、
生成 AI の制作フローは Phase 2 の本番アセットで通します。

**見た目を直すときの回し方**:

```bash
python3 tools/pipeline/pipeline.py        # 絵を焼き直す（design/ を触ったとき）
scripts/ios-loop.sh --time 20:30          # その時刻の姿を撮る
scripts/ios-loop.sh --time 07:00 --speed 240   # 7:00 から 240 倍速で動かす
```

`.shots/latest.png` を Read すれば、自分が書いた画面を目で見て直せます。
**時刻を変えられないと、夜中に起動したら寝ている姿しか確かめられません。**
