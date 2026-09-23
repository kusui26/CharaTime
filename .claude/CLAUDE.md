# CLAUDE.md — CharaTime 開発指針

このファイルは **CharaTime** リポジトリで Claude Code が作業するときの指針です。
全体の設計と根拠は `docs/260910_dev_plan.md`（v1.2）にあります。迷ったらそちらが正。

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
- ウィジェット拡張は約 30 MB のメモリ上限で動く。重い依存を足すときは必ず測る。

**画像はパイプライン経由でしか追加しない。** `tools/pipeline` が `characters.json` /
`items.json` と Asset Catalog を書き換える。手で画像を足さない。

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
- **実行中のスクリプトを書き換えない。** bash は実行しながら読むので、構文エラーになる。

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
```

**コミット前には必ず `scripts/check.sh` を通す。** 3 つの品質ゲート（lint・
警告ゼロのビルド・テスト）をこれ 1 つで回す。CI も同じものを見る。

**核心は「スクリーンショットを撮って、Claude 自身がそれを見る」こと。** `.shots/latest.png` を
Read すれば、自分が書いた UI を目で確認して直せます。

**シミュレータで確認できること**: レイアウト、配色、Dynamic Type、ダークモード、
ウィジェットのプレビュー（`#Preview(as:)`）。

**実機でしか確認できないこと**: ウィジェットの実際の更新間隔、透過ウィジェットのずれ、
StandBy、常時表示、電池と発熱、疑似アニメの成立（Phase 0 のスパイク）。

---

## 7. いま立っている場所

**待受モード（面 0）が動いています。** 日課エンジンが返す姿を `SceneView` が描き、
`ProceduralMotion` が呼吸と弾みを足し、時計と夜モードが乗っています（プラン §9 Phase 1）。
背景は 3 系統（同梱のへや／写真／ホーム画面のスクリーンショット）から選べ、
歩ける帯は指で決められます。

**スパイクの判定は Conditional Go（暫定）**（D-11。記録は `docs/260912_spike.md` §4）。
面 1 は当面「**様子が変わる窓**」で、`timelineTransition` が既定、
**`Settings.widgetPseudoAnimation` は切のまま**。

**ただし Go の候補に上がっています。** C・D が点かなかったのは手法のせいではなく、
タイマー文字に当てた `.fixedSize()` のせいでした（§3 の落とし穴）。枠の幅を決めて組み直した
スパイク E の α は、シミュレータでも実機（iOS 26.1）でも 1 秒ごとに点滅しました（同 3-6）。
**次にやるのは、同 3-6 の「E で測り直すマトリクス」を埋めること**（とくにロック解除後と kill 後）。
それで Go か Conditional Go かを確定し、Go なら `Settings.widgetPseudoAnimation` の既定を決め直します。

いずれにしても、拡張が動いていないあいだの描き直しは生きています。`Text(timerInterval:)` を
**素の文字として使う**見せ方（残り時間・秒の出る時計）は、面 1 でも面 3 でも使えます。

次の山は **Phase 2**（キャラ 5 体・部屋・アイテム）と **Phase 3**（ホーム画面ウィジェット）。
スパイクのターゲット（`ios/CharaTimeSpikeWidget/`、`tools/spike/`）は Phase 3 の 3-2 に
入るときに消します。

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
