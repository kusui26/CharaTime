# 担当 B: iOS プラットフォーム上で「動くキャラ」を出せる面（surface）の技術調査

- 作成日: 2026-09-10（すべての出典の確認日は 2026-09-10）
- 対象: iPhone 17 Pro / iOS 26.x（iOS 27 は 2026-09-14 公開予定）、Xcode 26.6（ローカル）/ Xcode 27 RC
- 確信度の凡例: ✅ 一次情報（Apple 公式ドキュメント・Apple サポート・Apple エンジニアのフォーラム回答・当事者のブログ）で確認 / 🔶 二次情報（報道・開発者ブログ・フォーラムの一般開発者の投稿）/ 🔷 推測（根拠から導いた見込み。未検証）
- 出典は本文中に [S番号] で示し、12 章にまとめた。

---

## 0. 要約（結論を先に）

1. iOS には「ホーム画面上に自由描画する」手段は存在しない。ホーム画面で唯一動かせるのはウィジェット（WidgetKit）と Live Activity（Dynamic Island）だが、どちらも「アプリが継続的に描画する」モデルではなく、静的スナップショットを OS が差し替えるモデル。✅
2. ウィジェットの通常更新予算は 1 日 40〜70 回（15〜60 分に 1 回）。アニメーションはタイムライン差し替え時の最大 2 秒のトランジションのみ。「秒刻みで動くキャラ」はタイマー Text + カスタムフォントの非公式ハックでしか作れず、Apple DTS は「サポート外・バッテリー消費・推奨しない」と明言している。✅
3. Live Activity は 8 時間で自動終了（ロック画面には最大 12 時間残る）。Dynamic Island 内でのペットは Pixel Pals（2022〜、App Store に現存）で実証済みだが、同じハック（タイマー Text）に依存する。✅/🔷
4. 本当に「自律的に動き回る」キャラ（30〜60fps、任意の位置）を他アプリ上・ホーム画面上に出せる唯一の公開 API は PiP（`AVSampleBufferDisplayLayer` + `AVPictureInPictureController.ContentSource`、iOS 15+）。非動画コンテンツの PiP は Mirrativ（2021〜）や複数の「PiP メモ」アプリが App Store に現存しており、審査で一律却下される類ではない。ただし背景は不透明で、ホーム画面の壁紙の上を歩かせる演出はできない（偽壁紙で疑似化）。✅/🔶
5. 「ガラケーの待受」に最も近い面は (a) アプリ内フルスクリーン待受モード（`isIdleTimerDisabled`、制約なし・常駐性なし）と (b) StandBy（充電中・横置き・ロック時のみ。ウィジェットは背景除去、Live Activity はフルスクリーンで 2 倍表示。iPhone 17 Pro は常時表示対応）。✅
6. 壁紙はアプリから直接設定できない。写真シャッフル（タップ時/ロック時/1 時間ごと/1 日ごと、アルバム指定可）とショートカットの時刻オートメーション（毎日/毎週/毎月、確認なし実行可）で「時間帯ごとにキャラの位置が変わる壁紙」は 1 時間〜数時間粒度なら実現可能。✅
7. 「透明ウィジェット」（壁紙のスクショを機種別座標で切り抜いて背景にする手法）は iPhone 16 Pro と同じ 2622×1206px の iPhone 17 Pro でも座標表が流用できる見込みだが、iOS 26 Liquid Glass 下での計測値は未確認。さらに iOS 18/26 の「着色/クリア」外観ではシステムがウィジェット背景を強制的に除去して Liquid Glass に置き換えるため、疑似透過は「ライト/ダーク」外観でしか成立しない。✅/🔶
8. 開発者アカウント: 無料 Personal Team でも App Groups・Background Modes・Widget Extension・ローカル Live Activity は使える（Apple 公式の capability 表で App groups は無料枠 ✓）。Push Notifications（Live Activity/WidgetKit の push 更新）、TestFlight、7 日を超える実機インストールには 99 USD/年の Program が必要。✅
9. 推奨アーキテクチャは多層: 【L0】アプリ内フル待受（本命の動き）→【L1】PiP フローティング（他アプリ上でも動く、任意）→【L2】Live Activity（Dynamic Island/ロック画面/StandBy/Mac メニューバー、8h ごと再開）→【L3】ウィジェット（15〜60 分ごとの「様子」+ タイマー Text による軽い動き、透明ウィジェット併用）→【L4】壁紙シャッフル/ショートカット（時間帯で位置が変わる背景）。
10. iOS 27（2026-09-14 公開）にウィジェット/Live Activity のアニメーション新 API は確認できなかった。新要素は `systemExtraLargePortrait`、Dynamic Island の横向き対応（`isDynamicIslandLimitedInWidth`）、StandBy 用 `activityBackgroundTint`、`LiveActivityIntent`。✅

---

## 1. OS・ツールの最新状況（2026-09-10 時点）

| 項目 | 状況 | 確信度 / 出典 |
|---|---|---|
| iOS 26 の最新版 | iOS 26.6.2 (23G90)。Apple の「About iOS 26 Updates」でも 26.6.2 が最新（26.6.1 はセキュリティ修正、26.6 は 2026-07 公開） | ✅ [S1][S2] 🔶 [S3] |
| iOS 27 | WWDC26（2026-06-08、同日 Xcode 27 beta 27A5194q 公開）で発表。iOS 27.0 RC (24A435) 配布中。公開日は 2026-09-14（Apple 発表を 9to5Mac が報道。同日 iPhone 18 Pro / iPhone Duo 発表イベント 2026-09-09） | ✅ [S1][S4] 🔶 [S5] |
| Xcode 27 | Xcode 27 RC (27A266a)。Swift 6.4、iOS 27 SDK 同梱。**macOS Tahoe 26.6 以降が必須、Apple シリコン専用**。iOS 17 以降の実機デバッグ対応 | ✅ [S1][S6] |
| Xcode 26.6 | 17F113（2026-08 ごろ RC 2 → 正式）。ローカル環境はこれ | ✅ [S1] |
| iOS 27 の WidgetKit 新要素 | `systemExtraLargePortrait` が iOS/iPadOS/macOS 27 で利用可（visionOS 26 で先行）。「各ウィジェットには更新予算があり、閲覧習慣に強く影響される」と再確認。**アニメーション新 API の言及なし** | ✅ [S7] |
| iOS 27 の Live Activity 新要素 | Dynamic Island のコンパクト/ミニマル表示が横向きでも表示（`isDynamicIslandLimitedInWidth` 環境値で幅制約時に切替）、StandBy で Lock Screen ビューを 200% 拡大、`showsWidgetContainerBackground` / `activityBackgroundTint`、Apple Watch/CarPlay 向け `.supplementalActivityFamilies([.small])`、`LiveActivityIntent` によるボタン操作、macOS メニューバー表示 | ✅ [S8][S9] |
| iOS 27 のユーザー向け新機能（ロック画面/壁紙） | Apple Intelligence による壁紙の「拡張（Extend）」、Image Playground で壁紙生成、コンパクト時計レイアウト、Liquid Glass 不透明度スライダー、Siri が Dynamic Island 内でアニメーション | 🔶 [S10][S11] |
| iOS 27 の StandBy 変更 | 報道・セッションともに StandBy 固有の変更は見つからず | 未確認 |
| iOS 26 の WidgetKit 変更（2025-06） | WidgetKit push 通知（`WidgetPushHandler`）、Liquid Glass 用 accented レンダリング、CarPlay 全車種でウィジェット、visionOS ウィジェット、watchOS/macOS の Controls | ✅ [S12] |
| iOS 26 の ActivityKit 変更（2025-06） | Live Activity が Mac のメニューバーと CarPlay に自動表示、指定時刻に開始する「スケジュール」API `request(attributes:content:pushType:style:alertConfiguration:start:)` | ✅ [S13] |
| iOS 26 のユーザー向け（ホーム/ロック） | Liquid Glass、アイコンとウィジェットの「クリア」外観、ロック画面の時刻が写真に合わせて伸縮、空間シーン壁紙（iPhone 12 以降） | ✅ [S14][S15] |

WWDC26 でウィジェット/Live Activity を扱うセッションは「WidgetKit foundations (277)」と「Live Activities essentials (223)」の 2 本のみ ✅ [S16]。

---

## 2. WidgetKit（ホーム画面ウィジェット）

### 2.1 制約（公式の記述）

- **実行モデル**: 「WidgetKit はあなたの代わりに別プロセスでビューをレンダリングする。したがってウィジェット拡張は、画面に表示中でも継続的にアクティブではない」 ✅ [S17]
- **更新予算**: 「ユーザーが頻繁に見るウィジェットの 1 日の予算は通常 40〜70 回のリフレッシュ。これは 15〜60 分ごとの再読み込みに相当するが、多くの要因で変動する」。予算は 24 時間単位でユーザーの使用パターンに合わせて調整され、真夜中にリセットされるとは限らない。予算はウィジェットインスタンスごと ✅ [S17]
- **予算にカウントされないケース**: 親アプリがフォアグラウンド／アプリがオーディオまたはナビゲーションセッション中／ウィジェットが App Intent を実行（ボタン・トグル）／ウィジェットがアニメーションを実行／ロケール・Dynamic Type 変更。「StandBy ではシステム定義のレートで表示が更新され、予算にはカウントされない」 ✅ [S17]
- **タイムラインの最小間隔**: 「エントリは少なくとも約 5 分間隔にすること」「WidgetKit は再読み込み前に最小時間を課す」 ✅ [S17]
- **WidgetKit push（iOS 26）**: 「タイムライン更新と同様にシステムが予算管理し、機会的に配信する。タイムライン更新を置き換えるものではない」。ブロードキャスト push は不可 ✅ [S18]
- **アニメーション**: 「以前の OS ではウィジェットはアニメーションしない」（= iOS 17 未満）。iOS 17 以降はタイムラインエントリ間の差分をシステムがアニメーション。「ウィジェットと Live Activity のアニメーションは最大 2 秒」。`Transaction` は使えない。常時表示（Always On）ではバッテリー保護のためアニメーションを行わない ✅ [S19]
- WWDC23「Bring widgets to life」: 「ウィジェットは状態を持たない。タイムラインのエントリ間で何が同じで何が違うかを SwiftUI が判定し、変化した部分をアニメーションする」「インタラクティブウィジェットで使えるのは AppIntent 付きの Button と Toggle のみ」 ✅ [S20]
- **動的な日時**: `Text(date, style: .timer/.relative/.offset)` と `Text(timerInterval:pauseTime:countsDown:showsHours:)`（iOS 16+）は「ウィジェット拡張が動いていなくても表示中は更新され続ける」 ✅ [S21][S22]
- **インタラクティブ（iOS 17）**: Button/Toggle + AppIntent。「ボタン・トグル操作は常にタイムライン再読み込みを保証する」（かつ予算外）。ロック中は動作しない。`contentTransition(.numericText())` 等の遷移が使える ✅ [S23][S19]
- **メモリ上限**: 実機で `EXC_RESOURCE RESOURCE_TYPE_MEMORY (limit=30 MB, unused=0x0)` でクラッシュ。Apple エンジニア（halleygen）は「画像は timeline provider で URLSession によりダウンロードし、`UIImage.preparingThumbnail(of:)` で縮小してから表示せよ」「`Data(contentsOf:)` を使うな」と回答 ✅ [S24]。30 MB はウィジェット拡張プロセス全体で共有（開発者の報告） 🔶 [S25][S26]
- **サイズ（HIG）**: 430×932pt 画面で Small 170×170 / Medium 364×170 / Large 364×382、ロック画面 Circular 76×76 / Rectangular 172×76 / Inline 257×26。**iPhone 16 Pro/17 Pro の 402×874pt は HIG 表に未掲載** ✅ [S27]。Widget-Blur の実測（2622px 高さ端末、iOS 18）から換算すると Small ≈ 162×162pt、Medium ≈ 344×162pt、Large ≈ 344×366pt 🔶 [S28]
- **ウィジェットの余白・角丸**: 標準余白 16pt（最小 11pt）、角丸は `ContainerRelativeShape` で追従させる ✅ [S27]

### 2.2 背景（透明化）に関する公式仕様 — 追加項目 3 への回答

- iOS 17 以降は `containerBackground(for: .widget) { ... }` で背景を宣言し、「削除可能（removable）」として扱う。**削除されるコンテキスト**: vibrant レンダリング（iPhone/iPad のロック画面、StandBy 夜間モード）、iPhone の StandBy、iPad ロック画面。`containerBackgroundRemovable(false)` で削除を拒否できるが、「その場合 iPad ロック画面や StandBy のギャラリーから除外される」「背景は色あせ/彩度低下して描画されることがある」 ✅ [S29][S30]
- **iOS 18 の「着色（Tinted）」/ iOS 26 の「クリア（Clear）」外観**: 公式ドキュメント「ユーザーがホーム画面で tinted または clear を選ぶと、システムはウィジェットを accented モードで描画し、コンテンツを白に着色し、**背景を削除して、テーマ付きガラスまたは着色効果に置き換える**」 ✅ [S31]。HIG: 「clear 外観ではウィジェットを脱色し、透過・ハイライト・Liquid Glass 素材を加える」「accented モードではシステムが背景を削除し、tinted なら着色効果、clear なら Liquid Glass 背景に置き換える」 ✅ [S27]
- 画像背景が tinted で消える件の Apple フォーラム: Apple エンジニア（jordi）は `containerBackgroundRemovable(false)` を案内 ✅ [S32]。ただしそれを付けると背景画像が `widgetAccentedRenderingMode(.fullColor)` を無視して常に着色される、という報告あり（Apple 回答なし） 🔶 [S33]
- **`Color.clear` / `EmptyView()` を背景にしたときのホーム画面（ライト/ダーク外観）の見え方**: Apple 公式の明文はない（未確認）。透明ウィジェット手法（後述）が 2020 年から現在まで必要とされ続けていること、Widget-Blur が「透過ブラーに *見える* 背景を作る」と表現していることから、**本当に壁紙が透ける描画にはならない**（ウィジェットは別プロセスで画像として描画され、SpringBoard が背景プレートを載せる）と判断 🔶 [S28][S34]。iOS 17 でロック画面円形ウィジェットの背景を `EmptyView()` にする例はあるが、これは vibrant 文脈の話 🔶 [S35]。→ **実機で 10 分の検証を推奨**（`Color.clear`、`EmptyView`、`Color.white.opacity(0.0000001)` の 3 パターン × ライト/ダーク/クリア/着色）。

### 2.3 「疑似アニメーション」ハック（タイマー Text + カスタムフォント）

- 仕組み（🔶 一般に知られている構成）: `Text(timerInterval:)` / `Text(_, style: .timer)` はシステムが 1 秒ごとに文字列を再描画する。数字グリフをコマ絵に置き換えたカスタムフォントを当てると、秒の 1 の位が 0〜9 → 10 コマの連番アニメになる。他の桁は幅ゼロの空グリフにして隠す。
- **Apple DTS の公式見解（Frameworks Engineer, Apple フォーラム）**: 「一部の開発者が見つけたハックがあるが、システムにサポートされておらず推奨できない」「カスタムフォントとカウントダウンタイマーを組み合わせて毎秒のアニメーションのようなものは作れるが、（Top Widgets のような）アニメーションはサポート外で、バッテリー消費やパフォーマンス問題を引き起こしうる」 ✅ [S36]
- 実測報告: 「UI 更新は最速でも 2 秒ごとに見える」「タイムラインエントリが約 400 を超えると更新が止まる」（一般開発者、iOS 16 時点）🔶 [S37]。Apple 公式は「タイムライン再読み込みではなく `Text(_:style:)` の相対表示で補間せよ」が推奨 ✅ [S37][S21]
- 実例: 「秒時計 for Widget」（iOS 17+、v1.2.2）はロック/ホームウィジェットに秒だけを表示（「最大 1 秒程度の誤差」） ✅ [S38]。Pixel Pals は「ホーム画面とロック画面のウィジェットでもアニメーションさせている」🔶 [S39][S40]。GitHub の WidgetAnimationSample（フォント法の実装例）は 2026-09-10 時点で 404 🔶。
- 審査事例: このハックが理由でリジェクトされた公開事例は見つからなかった（未確認）。Pixel Pals が 2022 年から App Store に存在し、2025-11-11 の v2.0.21 まで更新されている（iOS 18.3+）ことから、「フォント + タイマー」自体は審査を通過しうる 🔶 [S41]
- **常時表示（AOD）**: 減光時はシステムがアニメーションを行わない ✅ [S19]。Live Activity のタイマーは AOD 中に秒が `--` になり分単位でしか更新されない（開発者報告、Apple 回答なし）🔶 [S42]

### 2.4 追加項目 1: 「透明ウィジェット」手法の詳細

- **仕組み**: ホーム画面を編集モードにして空のページを表示 → スクリーンショット → 端末のピクセル高さで機種を判定 → ウィジェットのサイズ・位置ごとの矩形で切り抜き → その画像を `containerBackground` に敷く。Scriptable の Widget-Blur / no-background（MIT）が座標表を公開 ✅ [S28][S34]
- **座標表（Widget-Blur、iOS 18 で確認済みと明記）**: 高さ 2622px（「16 Pro」）: 文字ラベルあり: small 486 / medium 1032 / large 1098、left 87 / right 633、top 261 / middle 872 / bottom 1485。ラベルなし（Large アイコン設定）: small 495 / medium 1037 / large 1035、left 84 / right 626、top 270 / middle 810 / bottom 1350。2868（16 Pro Max）、2796、2556 等も収録 ✅ [S28]
- **iPhone 17 Pro への適用**: Apple 公式仕様で iPhone 17 Pro は 2622×1206px（460ppi）= iPhone 16 Pro と同一 ✅ [S43]。したがって「2622」の表がそのまま候補になる。ただし **iOS 26（Liquid Glass）でのグリッド計測は未確認** — 座標表は「iOS 18 で確認」と記載。→ CharaTime では機種固定表に頼らず、**アプリ内でユーザーのスクショを表示して 2 本のガイド線をドラッグさせるキャリブレーション UI**（または 6 個の小ウィジェットを置いた状態のスクショから自動検出）を持つ設計を推奨 🔷
- **座標の算出方法**: 「小ウィジェットを 6 個置いたホーム画面のスクショ 1 枚から、小ウィジェットの高さ・左右列の x・上中下段の y を測る」 ✅ [S28]
- **成立条件と限界**: (1) ライト/ダーク外観でのみ成立（tinted/clear ではシステムが背景を除去 → 疑似透過が崩れる。`containerBackgroundRemovable(false)` で保持しても着色される）✅/🔶 [S31][S33]；(2) 壁紙を変えるたびに再取得が必要（写真シャッフルとは両立しない）🔷；(3) 壁紙の視差/被写界深度効果とはずれる 🔷；(4) ライト/ダーク壁紙の 2 枚が必要 🔶 [S34]
- **iOS 26 Liquid Glass による見た目の変化**: Home 画面のウィジェットは Light/Dark（フルカラー）/Clear/Tinted の 4 外観。Clear では脱色 + 透過 + Liquid Glass ✅ [S27]。角丸・余白の具体的な数値変更は公式に見つからず（未確認）。

### 2.5 追加項目 2: ウィジェットだけのホーム画面ページ

- App アイコンは「Remove from Home Screen」で App ライブラリに残したまま外せる ✅ [S44]。ページは一時的に非表示にでき、iOS 18 以降はアプリ/ウィジェットを「壁紙の写真を額装するように」任意位置に置ける ✅ [S45]。→ **アイコン 0 個・ウィジェットのみのページは作れる**（Apple の文言で「ページからすべてのアプリを外せる」と明示はないが、上記 2 機能の組み合わせで成立。自分の端末でも確認可能）🔶
- **グリッド**: Widget-Blur の実測は「小ウィジェット 2 列 × 3 段」 ✅ [S28] → iPhone のホーム画面は小 2×2 / 中 4×2 / 大 4×4 アイコン相当、ページは 4 列 × 6 行。**Large（4 行）+ Medium（2 行）で 1 ページが埋まる** 🔶。iOS 18 の「Large アイコン（ラベルなし）」設定でもウィジェットは 2 列 × 3 段のまま（ピクセル座標が変わるだけ） ✅ [S28]
- iOS 27 の `systemExtraLargePortrait` は iPhone でも利用可能と WWDC26 で説明（「macOS, iOS, iPadOS 27 で利用可」）✅ [S7]。iPhone のホーム画面で実際に配置できるか（iPad の 4×4 大型の縦版に相当）は未確認。

### 2.6 CharaTime での使い方案

- 「15〜60 分に 1 回の *様子* の更新」（位置・ポーズ・セリフ）を timeline で先読み生成（例: 12 時間分を 30 分刻み = 24 エントリ）。`reloadTimelines` は 1 日 40〜70 回の枠内で、アプリ起動時・設定変更時だけ。
- Large + Medium で 1 ページを占有し、透明ウィジェット（ユーザーのスクショから切り抜き）を背景にして「壁紙の上を歩いている」ように見せる。ライト/ダーク外観限定で案内。
- 動きは `Text(timerInterval:)` + コマフォントで「まばたき・呼吸」程度の 1〜2 秒ループに限定（DTS の警告どおりバッテリー影響を最小に）。ユーザー設定で OFF にできるようにする。
- Button（AppIntent）で「なでる」「餌」→ 即時 reload（予算外）。
- 画像は 30 MB 制限に合わせ、ウィジェット表示サイズにダウンサンプルした PNG を App Group コンテナに保存。

---

## 3. Live Activities / Dynamic Island

### 3.1 制約（公式）

- **持続時間**: 「Live Activity は最長 8 時間アクティブでいられる（アプリまたはユーザーが終了しない限り）。8 時間後、システムは自動終了し、Dynamic Island から即座に除去する。ロック画面には最大 4 時間追加で残る（ユーザー削除か 4 時間の早い方）。結果として最長 12 時間ロック画面に残る」 ✅ [S46]。Apple DTS（Argun Tekant）も 2025 年に同じ内訳（8h 更新可 + 4h 表示のみ）を回答 ✅ [S47]。「iOS 18 で 12 時間に延長」と書く二次情報があるが、現行公式文書と DTS 回答に反する 🔶 [S48]
- **ペイロード**: 静的 + 動的データ合計 4 KB 以内 ✅ [S46]
- **更新手段**: ローカル `Activity.update(_:alertConfiguration:timestamp:)`、ActivityKit push（`apns-priority` 10 は「1 時間あたりの予算」にカウント、5 はカウントされない）、`NSSupportsLiveActivitiesFrequentUpdates` で高頻度 push を許可（ユーザーが設定で無効化可能） ✅ [S49][S50]。push-to-start は端末側の固定予算（短時間に約 10 件で枯渇、DTS: 「予算は固定で増やせない」） ✅ [S51]。予算枯渇時の回復は「最大 24 時間待つしかない」（Apple Frameworks Engineer） ✅ [S52]
- **ローカル更新（`activity.update`）の頻度上限**: 公式文書に数値なし（未確認）。
- **アニメーション**: iOS 16 では `withAnimation` 等は無視。iOS 17+ は組み込みトランジション（opacity/move/slide/push）、`contentTransition`、`numericText(countsDown:)`、最大 2 秒。**常時表示中はアニメーションなし**（`isLuminanceReduced` で検出）。`Text(timerInterval:)` は更新なしでカウント表示 ✅ [S46][S19]
- **StandBy**: 「StandBy 中の iPhone ロック画面上部にミニマル表示が出る。タップすると Lock Screen 表示で全画面に拡大」「StandBy では Lock Screen 表示が画面いっぱいに拡大されるので高解像度アセットを」「`isActivityFullscreen` 環境値で検出」 ✅ [S46]。WWDC26: 「200% に拡大」「カスタム背景色はシステムが画面全体に延長」 ✅ [S8][S53]
- **複数の Live Activity**: `relevanceScore` で Dynamic Island に出すものを制御。同時実行数の上限は「様々な要因に依存」 ✅ [S46]
- **他デバイス**: Live Activity は Mac（macOS 26 のメニューバー、iPhone Mirroring 経由）・CarPlay・Apple Watch（Smart Stack）に自動転送。Watch/CarPlay 用に `.supplementalActivityFamilies([.small])` ✅ [S13][S53][S54]
- **ボタン**: 拡張表示とロック画面で Button/Toggle（AppIntent、iOS 27 は `LiveActivityIntent`）。ロック中は不可、CarPlay では無効 ✅ [S46][S8]
- **HIG の目的規定**: 「開始と終了が定義されたタスクやイベントのために提供する。8 時間を超えない短〜中期間の追跡に最適」「Dynamic Island に注意を引く要素をアプリに追加しない」 ✅ [S53] — 常駐ペット用途は HIG の趣旨から外れるが、Pixel Pals が承認・継続配信されている（後述）。

### 3.2 iPhone 17 Pro の Dynamic Island

- Apple 公式仕様: 6.3 インチ 2622×1206px、ProMotion 最大 120Hz、常時表示、Dynamic Island 搭載 ✅ [S43]。物理サイズは Apple 非公開。
- 発売前に「17 Pro で幅 1.5cm に縮小」の噂があったが MacRumors 自身が信頼度を低く評価 🔶 [S55]。2026-01 の iPhone 18 Pro リーク記事は「現行 iPhone 17 Pro の切り欠きは幅 20.76mm」と記載（= 16 Pro と同等） 🔶 [S56]
- HIG: Dynamic Island の角丸は 44pt、コンパクト表示は leading/trailing の 2 要素。iOS 27 では横向きでも表示されるが幅が伸びない（`isDynamicIslandLimitedInWidth`） ✅ [S53][S8]

### 3.3 Pixel Pals（Christian Selig, 2022〜）の技術解説

- 2022-09-16 に Apollo のイースターエッグとして Dynamic Island に猫を置き、約 1 か月後に Pixel Pals として独立 🔶 [S39]。「Live Activity として動かし、Dynamic Island の周りでアニメーションするグリフを表示」「ホーム画面/ロック画面のウィジェットもアニメーションさせている」 🔶 [S39]。iOS 17 対応版でインタラクティブウィジェット（ミニゲーム）と StandBy 対応 🔶 [S40]。iOS 18 版で Apple Watch の Live Activity 対応 🔶 [S57]
- 2026-09-10 時点で App Store に現存（v2.0.21、2025-11-11、iOS 18.3+）。説明文は Dynamic Island / ロック画面 / ホーム画面ウィジェット / StandBy / Apple Watch 対応を謳う ✅ [S41]
- **アニメーション機構**: Selig 本人の技術解説記事は見つからず（未確認）。Apple DTS が「カスタムフォント + カウントダウンタイマーで毎秒のアニメーションのようなものを作る開発者がいる」と述べた手法 ✅ [S36] と一致するため、Pixel Pals もこの手法（タイマー Text の各秒に対応するグリフ = コマ絵）で動いていると推定 🔷。8 時間で Live Activity が終わる制約はそのまま適用（ユーザーが再開する必要） 🔶 [S58]

### 3.4 CharaTime での使い方案

- 「おでかけモード」として Live Activity を開始: Dynamic Island のコンパクト表示にキャラ（leading）+ 状態アイコン（trailing）、拡張表示で部屋の一部、ロック画面表示で横長の部屋。StandBy ではフルスクリーン（200%）になるので、ロック画面ビューを「待受」として設計する。
- 8 時間で自動終了 → 通知（ローカル通知）や次回起動時に再開を促す。iOS 26 の「スケジュール開始」API で朝の起床時刻に自動開始できる（ただし `AlertConfiguration` 必須で通知を伴う） ✅ [S46]。
- 更新はローカル `update` を 10〜30 分に 1 回（位置・ポーズの差し替え。2 秒トランジションで移動演出）。秒単位の動きはタイマー Text + コマフォント（DTS 非推奨を承知で、ON/OFF 可能に）。
- Push は無料アカウントでは使えないため、初期はローカル更新のみで設計。

---

## 4. Picture in Picture（PiP）でのカスタム描画

### 4.1 制約（公式）

- iOS 15+ の `AVPictureInPictureController.ContentSource` はビデオ通話向けに「PiP を有効にするとアプリは画面の隅に縮小され、**ホーム画面が見え、他アプリを操作できる**」と説明。ソースビューは `AVCaptureVideoPreviewLayer` または `AVSampleBufferDisplayLayer`、iOS 18+ は `MTKView` も可。`AVPictureInPictureVideoCallViewController` 使用時「PiP ウィンドウはタッチイベントを受け取らない（ボタンで UI をカスタマイズできない）」。`canStartPictureInPictureAutomaticallyFromInline` でバックグラウンド移行時に自動開始 ✅ [S59]
- App Store 審査ガイドラインに PiP 固有の条文はない。関連は 2.5.4「マルチタスクアプリはバックグラウンドサービスを本来の目的（VoIP、音声再生、位置情報、タスク完了、ローカル通知など）にのみ使用できる」、2.5.16「ウィジェット・拡張・通知はアプリのコンテンツと機能に関連していること」 ✅ [S60]

### 4.2 実例

- **Mirrativ「配信コメントバー」（2021-11、iOS アプリ 9.38.0 で本番リリース）**: iOS 15.1 で画面共有中の通知が制限されたため、`AVPictureInPictureController.ContentSource` + `AVSampleBufferDisplayLayer` で UIView → `CMSampleBuffer` を生成し PiP に流す方式へ。描画コスト最適化で `drawHierarchy` 49.5ms → `layer.render` 27.8ms → 階層分割 4.9ms/フレーム（60fps のメインスレッド予算 16.7ms） ✅ [S61][S62]。iOSDC 2022 で発表。審査に関する言及は記事・概要にはない 🔶 [S63]
- **uakihir0 の UIPiPDemo / UIPiPView（Zenn, 2021-11）**: UIView → UIImage → CMSampleBuffer を 0.3 秒ごとに enqueue。「実機でしか PiP に対応していない」「内容が変わるたびに enqueue が必要で描画コストは大きい」「PiP 中は他の動画を同時再生できない」「アプリをバックグラウンドにしても再生は続く」 ✅ [S64][S65]
- **App Store に現存する非動画 PiP アプリ**: 「Picture in Picture Notes - PiP」（FugaPiyo Inc., v1.0.6 2025-10-19, iOS 26 以降）、「Floaty - PiP & Floating Viewer」（v1.1.0 2026-08-27, Web/メモ/PDF/時計を PiP 表示）、「PiP Splitware」 ✅ [S66][S67] → 非動画 PiP が一律にリジェクトされる運用ではない 🔶
- 却下事例: 「非動画 PiP を理由に却下」された公開事例は見つからなかった（未確認）。

### 4.3 CharaTime にとっての評価

- **できること**: 30fps 程度でキャラを自由に動かし、ホーム画面や他アプリの上に「浮かせる」。PiP 窓はユーザーがドラッグ・ピンチでサイズ変更・画面端に隠せる。アプリはバックグラウンドでも PiP 中は実行が続く 🔶 [S64]
- **できないこと**: 透明背景（PiP は動画フレームの合成で、四隅が角丸の不透明な窓になる。アルファ付きフレームの検証記事は見つからず） 🔷 → 「ユーザーが選んだ壁紙画像を PiP の背景に敷く」ことで疑似的に壁紙の上に立たせる。他の動画/PiP と排他 ✅ [S64]。位置はユーザー任せ（アプリから画面上の座標は決められない） ✅ [S59]
- **審査リスク**: 中。PiP 自体は公開 API で実例多数。ただし「バックグラウンド継続のために無音オーディオを流す」等は 2.5.4 違反となりうるので避ける 🔷。
- **バッテリー**: フレーム生成コストが支配的。Mirrativ の階層分割（静的レイヤーを事前ラスタライズ、動く部分だけ再描画）と、10〜15fps への抑制が現実的 🔶 [S62]

---

## 5. StandBy（iOS 17+）

- **条件**: 充電中・横向き・ロック中 ✅ [S68]。表示は「時計・写真・ウィジェット（2 つの小ウィジェットを背景除去して拡大表示）・Live Activity（フルスクリーン）」 ✅ [S68][S69]
- **常時表示**: 「Always-On display（対応機種）では StandBy が点灯し続ける。それ以外の機種はタップ/机を揺らす/Siri で起動」「ディスプレイは 20 秒後にオフ。『しない（Never）』を選ぶと StandBy 中ずっと点灯」 ✅ [S68]。iPhone 17 Pro は Always-On 対応 ✅ [S43]
- **夜間モード**: 「周囲が暗くなると赤い色調で表示」。開発者向けには vibrant レンダリング + 赤ティントで描画される ✅ [S68][S27]
- **ウィジェットの更新**: 「StandBy ではシステム定義のレートで更新され、予算にカウントされない」 ✅ [S17]。背景は必ず除去される（`containerBackgroundRemovable(false)` だと StandBy のギャラリーに出ない） ✅ [S29][S30]。`disfavoredLocations(_:for:)` で「不向き」を宣言可能 ✅ [S70]
- **Live Activity**: 上部のミニマル表示をタップで Lock Screen 表示が 2 倍で全画面。デフォルト背景色を使うと「ベゼルと溶け合い、TrueDepth カメラ回避の余白が不要なぶん少し大きく表示」 ✅ [S53]
- **評価**: 「充電スタンドに置いたガラケーの待受」として最も近い面。ウィジェット面は「2 分割で背景なし」なので世界観を作りにくいが、Live Activity 全画面は 1 枚絵の待受として使える。ただし StandBy の Live Activity 全画面はユーザーのタップが必要で、8 時間で終わる。

---

## 6. 壁紙（ロック画面 / ホーム画面）

- **写真シャッフル（Apple サポート, iOS 26）**: 「People / Nature / Cities などのカテゴリ、または既存のアルバムを選択」「手動で写真を選択も可」「頻度は On Tap / On Lock / Hourly / Daily」 ✅ [S15]。アルバム指定は iOS 17.1 から 🔶 [S71]。ロック画面と対になるホーム画面壁紙にも反映（「壁紙ペアを追加」） 🔶 [S72]。シャッフル順序の制御は不可（未確認: 順序はランダム扱い）。
- **ショートカットの壁紙アクション**: 「Set Wallpaper Photo」（写真、対象の壁紙スロット、ロック/ホーム/両方、プレビュー表示、被写体切り抜き、ホームのぼかし）と「Switch Between Wallpapers」（既存壁紙の切替）。写真タイプの壁紙スロットが対象 🔶 [S73]（iOS 16.2 で追加 🔶 [S74]）
- **オートメーション**: 「Time of Day」トリガーは繰り返しが Daily / Weekly / Monthly（時刻・日の出・日の入り）。**1 時間ごとの繰り返しはない** ✅ [S75]。「Ask Before Running」をオフにすると確認なしで実行でき、Apple の一覧では Time of Day / Alarm / Sleep / Arrive / Leave / CarPlay / Email / Message / Transaction / Wi-Fi / Bluetooth / Apple Watch Workout / NFC / App / Airplane Mode … が自動実行可（自動実行できないのは「Before I Commute」） ✅ [S76]。→ 1 日 N 回の切替は「N 個の Time of Day オートメーション」を作れば可能 🔷（作成上限は未確認）。
- **アプリから壁紙を設定する公開 API**: 存在しない（UIKit/SwiftUI/PhotoKit に該当 API なし。Apple が案内する自動化手段はショートカットのみ） 🔶（「存在しないこと」の一次文書はない）
- **Live Photo 壁紙**: 「iOS 17 以降、ロック画面に Live Photo を設定すると、端末をスリープ解除するたびに再生される（再生ボタンをオン）」 ✅ [S77]。iOS 26 固有の変更は見つからず。
- **空間シーン（iOS 26）**: 「iPhone 12 以降、対象写真を 3D 空間壁紙にできる（ライティングが良い・主題と背景の分離が明確・横向き写真が向く）。端末を動かすと視差で動く」 ✅ [S15][S14]
- **iOS 27**: Apple Intelligence による壁紙の「拡張」、Image Playground による壁紙生成、コンパクト時計 🔶 [S10][S11]
- **「キャラが時間とともに壁紙上で位置を変える」の実現可否**: 可能（粒度は 1 時間〜）。方式 A: アプリが「時間帯 × 位置」の静止画セット（例: 24 枚）を専用アルバムに書き出し → 写真シャッフル Hourly（ただし順序はランダムのため時間帯とポーズは一致しない）。方式 B: ショートカットで「CharaTime の App Intent（今の時刻に対応する 1 枚を返す）→ Set Wallpaper Photo」を作り、Time of Day オートメーションを朝/昼/夕/夜など数本登録（決定的・確認なし実行） 🔷。方式 B は Live Photo（短い動き）も壁紙に指定できれば「起こすたびに少し動く」演出が可能（Set Wallpaper Photo が Live Photo を受け付けるかは未確認）。

---

## 7. ロック画面ウィジェット / 常時表示（Always-On）

- ロック画面ウィジェットは accessory 系（circular / rectangular / inline）。iPhone では vibrant レンダリング（脱色 + 壁紙に合わせた発色）、フルカラー画像は「透明ピクセルが背景素材を透過させ、明度がコントラストを決める」 ✅ [S27][S70]。サイズは 430×932pt で 76×76 / 172×76 / 257×26 ✅ [S27]
- 更新はホーム画面と同じタイムライン・予算モデル ✅ [S17]。`Text(timer)` は表示中は動く ✅ [S21]
- **常時表示**: 「対応機種では減光したロック画面が表示され続け、通知・日時・ウィジェットの情報を確認できる。うつ伏せ・ポケット・Apple Watch が近くにない・CarPlay 開始・連係カメラ・低電力モード・就寝時刻で自動オフ。壁紙/通知の表示切替あり」 ✅ [S78]。減光中はアニメーションなし（`isLuminanceReduced`） ✅ [S19]。Live Activity のタイマー秒は `--` 表示 🔶 [S42]
- **評価**: 常時表示ロック画面は「電源を入れずに見える待受」だが、キャラは分単位の静止画差し替えのみ。

---

## 8. その他

- **iPhone ミラーリング / Mac**: macOS 26 では iPhone の Live Activity が Mac のメニューバーに自動表示され、クリックで iPhone Mirroring が開く（iPhone は施錠状態のまま） ✅ [S54][S79]。iPhone ウィジェットは macOS 14 以降 Mac のデスクトップ/通知センターに置ける（操作は iPhone に転送されるため遅延に注意、`invalidatableContent`） ✅ [S23]
- **アプリ内「ホーム画面そっくりの待受」**: アプリはユーザーの現在の壁紙を取得できない（公開 API なし） 🔶。代替: (a) ユーザーにホーム画面のスクリーンショット or 壁紙写真を選ばせる（PhotosPicker）、(b) Apple の標準壁紙風のグラデーションを内蔵、(c) 「透明ウィジェット」用に取得したスクショを共用。画面消灯抑止は `isIdleTimerDisabled = true`（Apple: 「必要なときだけ設定し、不要になったら false に戻す。地図・ゲーム・操作が少なくても表示を続ける必要があるアプリのみ」） ✅ [S80]。長時間の据え置きは Guided Access（単一アプリに固定、「Display Auto-Lock」設定、時間制限機能あり） ✅ [S81]。iOS 12 期に Guided Access が idle timer を上書きする不具合があった 🔶 [S82]
- **バックグラウンド実行**: Apple DTS（Quinn）「実行タイミングはほぼ制御できない。端末状態とユーザーの活動が主因で、使用頻度の低いアプリは app refresh の時間を *まったく* もらえないことがある」 ✅ [S83]。iOS 26 の `BGContinuedProcessingTask` は「ユーザー操作を起点にフォアグラウンドで開始し、バックグラウンドでも継続。進捗を Live Activity に表示し、ユーザーがキャンセル可能。進捗の乏しいタスクから優先的に終了される。GPU 利用は専用エンティトルメント」 ✅ [S84][S85] → 常駐キャラのループには使えない（用途外・強制終了される）。
- **Home 画面グリッド/ページ操作**: 「アプリやウィジェットを任意の位置に置ける（壁紙を額装する等）。複数ページはそれぞれ固有レイアウト。ページの一時非表示、Focus ごとのページ表示が可能」 ✅ [S45]

---

## 9. 開発者アカウント（無料 Personal Team と Apple Developer Program）

Apple 公式「Supported capabilities (iOS)」の 3 列（ADP = 有料 Program / ADEP = Enterprise / Apple Developer = 無料の Apple Account）から抜粋 ✅ [S86]:

| Capability | 有料 ADP | 無料 Apple Developer |
|---|---|---|
| App groups | ✓ | **✓** |
| Background modes | ✓ | ✓ |
| Keychain sharing | ✓ | ✓ |
| Push notifications | ✓ | **×** |
| Fonts / iCloud（CloudKit・書類・KVS）/ Time Sensitive Notifications / In-App Purchase / Sign in with Apple | ✓ | × |

- Widget Extension・ローカル Live Activity（`NSSupportsLiveActivities` Info.plist キーのみ。エンティトルメント不要）は無料枠で動く。ActivityKit push / WidgetKit push（`apns-push-type: widgets`）は Push Notifications capability が必要なので有料 ✅ [S18][S49][S86]
- 無料枠の実機インストール制限: プロビジョニングプロファイルは 7 日で失効、登録デバイス 3 台、App ID 作成 7 日で 10 個（Apple DTS は「Advanced App Capabilities」記事の第 1 列を参照するよう回答。数値自体は開発者コミュニティの報告） 🔶 [S87]
- TestFlight・App Store 配布は Apple Developer Program（99 USD/年）が必要 🔶 [S88]
- **境界**: 「自分の iPhone 17 Pro で 7 日ごとに再インストールしながら開発」までは無料。友人に配る（TestFlight）、Live Activity を push で更新、7 日を超えて放置しても動く、のいずれかを望んだ時点で有料。

---

## 10. 比較表と推奨アーキテクチャ

### 10.1 面ごとの比較

| 面 | 動きの質（fps / 自律移動） | 常駐性 | 審査リスク | 実装工数 | バッテリー | 主な制約 |
|---|---|---|---|---|---|---|
| アプリ内フル待受（L0） | 60fps、自由。SpriteKit/SwiftUI | 低（アプリを開いている間だけ。`isIdleTimerDisabled` で消灯抑止） | 低 | 小 | 中〜大（画面点灯） | ホーム画面ではない。据え置き用途 |
| PiP フローティング（L1） | 10〜30fps、窓内で自由。窓の位置はユーザー | 中（PiP を閉じるまで。他アプリ・ホーム画面上でも表示） | 中（公開 API・実例多数。無音オーディオ等の裏技は不可） | 中〜大（描画パイプライン最適化） | 中〜大 | 不透明な角丸窓、透明不可、動画と排他、実機のみ |
| Live Activity / Dynamic Island（L2） | 2 秒トランジション + タイマー Text ハックで 1 秒コマ送り。位置は固定領域 | 8 時間（ロック画面 +4h）。StandBy 全画面・Mac・Watch・CarPlay に波及 | 低〜中（Pixel Pals 前例。ハックは非推奨） | 中 | 小〜中（ハック使用時は増） | 4 KB、push は有料、AOD で秒停止 |
| ホーム画面ウィジェット（L3） | 15〜60 分ごとの静止画 + 2 秒トランジション + タイマー Text ハック | 高（置きっぱなし） | 低〜中 | 中 | 小（ハック使用時は増） | 30 MB、透明不可（疑似透過はライト/ダークのみ）、予算 40〜70/日 |
| ロック画面ウィジェット / AOD | 同上（脱色表示、AOD はアニメなし） | 高 | 低 | 小 | 小 | 小さい、モノクロ |
| StandBy | ウィジェット: 同上。Live Activity: 全画面 2 倍 | 充電・横置き時のみ | 低 | 小（L2/L3 の派生） | 小（常時表示は端末側） | 背景除去、タップで全画面 |
| 壁紙シャッフル / ショートカット（L4） | 静止画（Live Photo なら起こすたび数秒動く可能性）。1 時間〜数時間粒度で位置変更 | 最高（常に壁紙） | なし（アプリ外） | 小〜中（画像生成 + App Intent） | ほぼゼロ | 順序制御不可（シャッフル）/ 手動セットアップが必要（ショートカット） |

### 10.2 推奨する多層アーキテクチャ

1. **共通コア**: キャラの状態機械（時刻・天気・電池・操作履歴 → 位置/ポーズ/セリフ）と、その「スナップショット画像」を生成するレンダラ（SwiftUI → `ImageRenderer` or SpriteKit オフスクリーン）。App Group コンテナに「今後 12 時間分」を書き出し、全レイヤーが同じ素材を使う。
2. **L0 アプリ内待受（本命）**: フルスクリーン、ユーザー選択の壁紙/スクショを背景に、SpriteKit で 60fps の自律移動（歩く・座る・話しかける）。時計・通知風の要素も自前描画で「ガラケー待受」を再現。`isIdleTimerDisabled` と充電中判定、Guided Access の案内。
3. **L1 PiP（オプション）**: 「他のアプリを使っている間も連れて歩く」モード。`AVSampleBufferDisplayLayer` に 15fps で合成（静的背景は事前ラスタライズ、キャラ層のみ毎フレーム）。背景は L0 と同じ壁紙画像で疑似透過。
4. **L2 Live Activity**: 「おでかけ」開始で 8 時間。コンパクト表示 = 顔アイコン + 状態、拡張/ロック画面 = 部屋の横長ビュー、StandBy = 200% 全画面で待受化。10〜30 分ごとにローカル update（移動は 2 秒トランジション）。iOS 26 のスケジュール API で起床時に自動開始。まばたき等の 1〜2 秒ループはタイマー Text + コマフォント（設定で OFF）。
5. **L3 ウィジェット**: Large + Medium でウィジェット専用ページを構成（4 列 × 6 行を占有）。透明ウィジェット（スクショ切り抜き、キャリブレーション UI 付き）で「壁紙の上を歩く」ように見せる。30 分刻みのタイムライン + Button（AppIntent）でなでる/餌。ロック画面には circular/rectangular の顔ウィジェット。
6. **L4 壁紙**: 「時間帯別ポーズ壁紙セット」を写真アルバムに書き出す機能 + ショートカット用 App Intent（`ReturnsValue<IntentFile>`）を提供し、ユーザーに Time of Day オートメーション（朝/昼/夕/夜）を案内。写真シャッフル Hourly も選択肢として案内。
7. **iOS 27 対応**: Dynamic Island 横向き（幅制約時はアイコンのみ）、`activityBackgroundTint`、`systemExtraLargePortrait` の検証。Xcode 27 は macOS 26.6+ が必要。

### 10.3 優先順位の根拠

- 「自律的に動き回る」要件を満たすのは L0 と L1 のみ。L2/L3 は「様子が変わる」演出であり、秒単位の動きは Apple 非推奨のハックに依存する。
- L4 は常駐性が最高でコストゼロだが、動かない。
- 無料アカウント運用中は push を使わない設計にしておく（L2/L3 ともローカル更新で完結）。

---

## 11. 未確認事項（要・実機検証または追加調査）

1. `containerBackground(for: .widget) { Color.clear }` のホーム画面（ライト/ダーク）での実際の描画（システムがプレートを敷くか）。公式文書なし。
2. iOS 26（Liquid Glass）でのウィジェット配置ピクセル座標（Widget-Blur の表は iOS 18 確認）。iPhone 17 Pro（2622×1206）で「2622」表がずれていないか。
3. iOS 27 で iPhone に `systemExtraLargePortrait` を実際に配置できるか。
4. ローカル `Activity.update` の頻度上限（公式数値なし）。
5. PiP の透明（アルファ付き `CMSampleBuffer`）が黒/不透明になるかの実測。PiP 実行中にアプリがバックグラウンドで何分描画を続けられるか。
6. 非動画 PiP・タイマーフォントハックの審査却下事例の有無（公開情報では発見できず）。
7. 「Set Wallpaper Photo」アクションが Live Photo を受け付けるか、Time of Day オートメーションの作成上限。写真シャッフルの枚数上限（16 枚で頭打ちという観察報告あり 🔶 [S72]）。
8. iPhone 17 Pro の Dynamic Island の正確な pt サイズ（Apple 非公開。二次情報は 20.76mm）。
9. iOS 27 での StandBy の変更有無。
10. Pixel Pals の実装詳細（本人の技術解説が見つからず、推定）。
11. Apple サポート「Customize apps and widgets on the Home Screen」ページ本文（JS 描画で取得不可）。Clear/Tinted/Large の仕様は HIG と WidgetKit 文書で代替確認済み。

---

## 12. 出典一覧（確認日: すべて 2026-09-10）

- [S1] Apple Developer – Releases（Xcode 27 RC 27A266a / iOS 27.0 RC 24A435 / iOS 26.6.2 23G90 / Xcode 26.6 17F113 / Xcode 27 beta 27A5194q 2026-06-08） https://developer.apple.com/news/releases/ ✅
- [S2] Apple Support – About iOS 26 Updates https://support.apple.com/en-us/123075 ✅
- [S3] MacRumors – Apple Releases iOS 26.6.1（2026-08-17） https://www.macrumors.com/2026/08/17/apple-releases-ios-26-6-1-and-more/ 🔶
- [S4] Apple Developer – Xcode 27 beta (27A5194q) 2026-06-08 https://developer.apple.com/news/releases/?id=06082026a ✅
- [S5] 9to5Mac – Apple confirms iOS 27 release date: September 14（2026-09-09） https://9to5mac.com/2026/09/09/apple-confirms-ios-27-release-date-september-14/ 🔶
- [S6] Apple – Xcode 27 RC Release Notes https://developer.apple.com/documentation/xcode-release-notes/xcode-27-release-notes ✅
- [S7] Apple – WWDC26 Session 277 "WidgetKit foundations" https://developer.apple.com/videos/play/wwdc2026/277/ ✅
- [S8] Apple – WWDC26 Session 223 "Live Activities essentials" https://developer.apple.com/videos/play/wwdc2026/223/ ✅
- [S9] wwdc.ai – Session 223 summary https://wwdc.ai/2026/223 🔶
- [S10] MacRumors – iOS 27 Brings These Five New Features to Your iPhone Lock Screen（2026-08-21） https://www.macrumors.com/2026/08/21/ios-27-five-new-features-iphone-lock-screen/ 🔶
- [S11] MacRumors – 30 New Things Your iPhone Can Do in iOS 27（2026-08-14） https://www.macrumors.com/2026/08/14/new-things-your-iphone-can-do-ios-27/ 🔶
- [S12] Apple – WidgetKit updates https://developer.apple.com/documentation/updates/widgetkit ✅
- [S13] Apple – ActivityKit updates https://developer.apple.com/documentation/updates/activitykit ✅
- [S14] Apple Newsroom – Apple elevates the iPhone experience with iOS 26（2025-06） https://www.apple.com/newsroom/2025/06/apple-elevates-the-iphone-experience-with-ios-26/ ✅
- [S15] Apple Support – Change your iPhone wallpaper（写真シャッフル頻度・アルバム・空間シーン） https://support.apple.com/en-us/102638 ✅
- [S16] Apple – WWDC26 Videos https://developer.apple.com/videos/wwdc2026/ ✅
- [S17] Apple – Keeping a widget up to date https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date ✅
- [S18] Apple – Updating widgets with WidgetKit push notifications https://developer.apple.com/documentation/widgetkit/updating-widgets-with-widgetkit-push-notifications ✅
- [S19] Apple – Animating data updates in widgets and Live Activities https://developer.apple.com/documentation/widgetkit/animating-data-updates-in-widgets-and-live-activities ✅
- [S20] Apple – WWDC23 Session 10028 "Bring widgets to life" https://developer.apple.com/videos/play/wwdc2023/10028/ ✅
- [S21] Apple – Displaying dynamic dates in widgets https://developer.apple.com/documentation/widgetkit/displaying-dynamic-dates ✅
- [S22] Apple – Text.init(timerInterval:pauseTime:countsDown:showsHours:)（iOS 16+） https://developer.apple.com/documentation/swiftui/text/init(timerinterval:pausetime:countsdown:showshours:) ✅
- [S23] Apple – Adding interactivity to widgets and Live Activities https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities ✅
- [S24] Apple Developer Forums – Widget is crashing with EXC_RESOURCE (limit=30 MB)（Apple エンジニア回答あり） https://developer.apple.com/forums/thread/713561 ✅
- [S25] Apple Developer Forums – iOS 17 Beta 3: Reaching Memory Limit (30MB) in Widget https://developer.apple.com/forums/thread/733347 🔶
- [S26] Apple Developer Forums – Widget Memory Limit - Per Widget Kind/Size or Per Target? https://developer.apple.com/forums/thread/795793 🔶
- [S27] Apple – Human Interface Guidelines: Widgets（外観・レンダリングモード・寸法・余白） https://developer.apple.com/design/human-interface-guidelines/widgets ✅
- [S28] Max Zeryck – Widget-Blur（透明/ブラー背景の機種別座標表、iOS 18 確認） https://gist.github.com/mzeryck/3a97ccd1e059b3afa3c6666d27a496c9 / https://github.com/mzeryck/Widget-Blur 🔶
- [S29] Apple – Displaying the right widget background https://developer.apple.com/documentation/widgetkit/displaying-the-right-widget-background ✅
- [S30] Apple – WidgetConfiguration.containerBackgroundRemovable(_:) https://developer.apple.com/documentation/swiftui/widgetconfiguration/containerbackgroundremovable(_:) ✅
- [S31] Apple – Optimizing your widget for accented rendering mode and Liquid Glass https://developer.apple.com/documentation/widgetkit/optimizing-your-widget-for-accented-rendering-mode-and-liquid-glass ✅
- [S32] Apple Developer Forums – No containerBackground content on Widget in iOS 18 tinted home screen style https://developer.apple.com/forums/thread/757231 ✅
- [S33] Apple Developer Forums – containerBackgroundRemovable(false) breaks tinting https://developer.apple.com/forums/thread/768862 🔶
- [S34] supermamon – scriptable-no-background https://github.com/supermamon/scriptable-no-background 🔶
- [S35] Apple Developer Forums – How to use AccessoryWidgetBackground with containerBackground API on iOS 17 https://developer.apple.com/forums/thread/733200 🔶
- [S36] Apple Developer Forums – How to use animation for dynamic Island and widgets（Apple DTS 回答: フォント + タイマーは非サポート） https://developer.apple.com/forums/thread/757696 ✅
- [S37] Apple Developer Forums – How can widget be updated every half a second? https://developer.apple.com/forums/thread/733081 🔶
- [S38] App Store – 秒時計 for Widget（Kiichi Ito） https://apps.apple.com/jp/app/id6445807658 ✅
- [S39] Fueled – Pixel Pals is What Dynamic Island Needed https://fueled.com/blog/pixel-pals/ 🔶
- [S40] TechCrunch – Pixel Pals delivers a cute and clever update（2023-09-22） https://techcrunch.com/2023/09/22/pixepixel-pals-delivers-a-cute-and-clever-update-that-takes-advantage-of-new-ios-features 🔶
- [S41] App Store – Pixel Pals Widget Pet Game（v2.0.21, 2025-11-11, iOS 18.3+） https://apps.apple.com/us/app/pixel-pals-widget-pet-game/id6443919232 ✅
- [S42] Apple Developer Forums – Text(timerInterval) displays xx:-- in Live Activity when Always-On Display is active https://developer.apple.com/forums/thread/735124 🔶
- [S43] Apple Support – iPhone 17 Pro Tech Specs https://support.apple.com/en-us/125090 ✅
- [S44] Apple Support – Remove or delete apps from iPhone https://support.apple.com/guide/iphone/remove-or-delete-apps-iph248b543ca/ios ✅
- [S45] Apple Support – Move apps and widgets on the iPhone Home Screen https://support.apple.com/guide/iphone/move-apps-and-widgets-on-the-home-screen-iphd2fc8ce30/ios ✅
- [S46] Apple – Displaying live data with Live Activities https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities ✅
- [S47] Apple Developer Forums – What's the max duration for a live activity?（Apple DTS 回答） https://developer.apple.com/forums/thread/797676 ✅
- [S48] Newly – iOS Live Activities guide（「iOS 18 で 12 時間」と記載する二次情報の例） https://newly.app/guides/ios-live-activities 🔶
- [S49] Apple – Starting and updating Live Activities with ActivityKit push notifications https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications ✅
- [S50] Apple – NSSupportsLiveActivitiesFrequentUpdates https://developer.apple.com/documentation/bundleresources/information-property-list/nssupportsliveactivitiesfrequentupdates ✅
- [S51] Apple Developer Forums – Live Activity budget exceeded（push-to-start 予算、Apple DTS 回答） https://developer.apple.com/forums/thread/799505 ✅
- [S52] Apple Developer Forums – Live Activity Push updates throttling with frequent updates（Apple Frameworks Engineer 回答） https://developer.apple.com/forums/thread/731715 ✅
- [S53] Apple – Human Interface Guidelines: Live Activities https://developer.apple.com/design/human-interface-guidelines/live-activities ✅
- [S54] Apple Support – iPhone Mirroring（Live Activities は macOS 26 以降） https://support.apple.com/en-us/120421 ✅
- [S55] MacRumors – iPhone 17 Pro Has Smaller Dynamic Island, Claims Last-Minute Rumor（2025-09-05） https://www.macrumors.com/2025/09/05/iphone-17-pro-rumor-redesigned-dynamic-island/ 🔶
- [S56] GSMArena – iPhone 18 Pro series' Dynamic Island cutout dimensions leaked（2026-01-23、17 Pro は 20.76mm） https://m.gsmarena.com/iphone_18_pro_series_dynamic_island_cutout_dimensions_leaked-news-71222.php 🔶
- [S57] Christian Selig – Pixel Pals iOS 18 update（Threads） https://www.threads.com/@christianselig/post/DABr2bovcOU 🔶
- [S58] iScreen Blog – Dynamic Island Pets（8 時間制限の説明） https://www.iscreenapp.com/blog/dynamic-island-pets-iphone 🔶
- [S59] Apple – Adopting Picture in Picture for video calls https://developer.apple.com/documentation/avkit/adopting-picture-in-picture-for-video-calls ✅
- [S60] Apple – App Store Review Guidelines（2.5.4 / 2.5.16 / 4.4） https://developer.apple.com/app-store/review/guidelines/ ✅
- [S61] Mirrativ Tech Blog – 配信コメントバー 〜 iOS15 で実現する新しい PiP 体験（2021-11-26） https://tech.mirrativ.stream/entry/2021/11/26/114002 ✅
- [S62] Mirrativ Tech Blog – 配信コメントバー 〜 PiP 描画パフォーマンスとの向き合い方（2021-12-02） https://tech.mirrativ.stream/entry/2021/12/02/113548 ✅
- [S63] fortee – iOSDC Japan 2022「PiPを応用した配信コメントバー機能の開発秘話と技術の詳解」 https://fortee.jp/iosdc-japan-2022/proposal/f9ec6cc3-bc06-4749-a6b4-a472b9234684 🔶
- [S64] uakihir0 – iOS で任意の UIView をピクチャーインピクチャーする（Zenn, 2021-11） https://zenn.dev/uakihir0/articles/211128-uipip ✅
- [S65] uakihir0 – UIPiPDemo（GitHub） https://github.com/uakihir0/UIPiPDemo 🔶
- [S66] App Store – Picture in Picture Notes - PiP（FugaPiyo Inc., v1.0.6 2025-10-19, iOS 26+） https://apps.apple.com/us/app/picture-in-picture-notes-pip/id1618652473 ✅
- [S67] App Store – Floaty - PiP & Floating Viewer（v1.1.0 2026-08-27） https://apps.apple.com/us/app/floaty-pip-floating-viewer/id6767232816 ✅
- [S68] Apple Support – Use StandBy to view information at a distance while iPhone is charging https://support.apple.com/guide/iphone/use-standby-iph878d77632/ios ✅
- [S69] Apple – Adding StandBy and CarPlay support to your widget https://developer.apple.com/documentation/widgetkit/adding-standby-and-carplay-support-to-your-widget ✅
- [S70] Apple – Preparing widgets for additional contexts and appearances https://developer.apple.com/documentation/widgetkit/preparing-widgets-for-additional-contexts-and-appearances ✅
- [S71] MacRumors – How to Shuffle Your iPhone's Lock Screen Wallpaper（iOS 17.1 でアルバム指定） https://www.macrumors.com/how-to/shuffle-between-photos-lock-screen-ios/ 🔶
- [S72] iDownloadBlog – How to change iPhone wallpaper at regular intervals automatically（2024-11-01） https://www.idownloadblog.com/2024/11/01/how-to-use-photo-shuffle-wallpaper-iphone/ 🔶
- [S73] MacMost – 4 Ways To Make Your iPhone Wallpaper Change Automatically（2023-12-27、Set Wallpaper Photo アクション） https://macmost.com/4-ways-to-make-your-iphone-wallpaper-change-automatically.html 🔶
- [S74] Tom's Guide – iOS 16.2 just got these handy shortcuts for wallpapers https://www.tomsguide.com/news/ios-162-just-got-these-handy-shortcuts-for-wallpapers-and-more-how-to-enable-them 🔶
- [S75] Apple Support – Event triggers in Shortcuts on iPhone or iPad（Time of Day: Daily/Weekly/Monthly） https://support.apple.com/guide/shortcuts/event-triggers-apd932ff833f/ios ✅
- [S76] Apple Support – Enable or disable a personal automation in Shortcuts（自動実行できるトリガー一覧） https://support.apple.com/guide/shortcuts/enable-or-disable-a-personal-automation-apd602971e63/ios ✅
- [S77] Apple Support – Set a Live Photo as your Lock Screen wallpaper（iOS 17+） https://support.apple.com/en-us/120734 ✅
- [S78] Apple Support – Keep the iPhone display on longer（Always-On display 節） https://support.apple.com/guide/iphone/keep-the-iphone-display-on-longer-iph7117338a8/ios ✅
- [S79] iDownloadBlog – How to use Live Activities on Mac in macOS Tahoe 26 https://www.idownloadblog.com/2025/06/28/how-to-use-live-activities-mac/ 🔶
- [S80] Apple – UIApplication.isIdleTimerDisabled https://developer.apple.com/documentation/uikit/uiapplication/isidletimerdisabled ✅
- [S81] Apple Support – Use Guided Access with iPhone, iPad, and iPod touch https://support.apple.com/en-us/111795 ✅
- [S82] OpenRadar 44628113 – Guided Access overrides IdleTimerDisabled on iOS 12 https://openradar.appspot.com/44628113 🔶
- [S83] Apple Developer Forums – How accurate is BGTaskScheduler?（Apple DTS 回答） https://developer.apple.com/forums/thread/725675 ✅
- [S84] Apple – BGContinuedProcessingTask（iOS 26） https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtask ✅
- [S85] Apple – Performing long-running tasks on iOS and iPadOS https://developer.apple.com/documentation/backgroundtasks/performing-long-running-tasks-on-ios-and-ipados ✅
- [S86] Apple Developer Help – Supported capabilities (iOS)（ADP / ADEP / Apple Developer の 3 列表） https://developer.apple.com/help/account/reference/supported-capabilities-ios ✅
- [S87] Apple Developer Forums – Free Provisioning Profile Limitations（Apple DTS が Advanced App Capabilities を案内） https://developer.apple.com/forums/thread/669516 🔶 / Apple – Advanced App Capabilities https://developer.apple.com/support/app-capabilities/ ✅
- [S88] Apple – Apple Developer Program: What's included（TestFlight・App Store 配布） https://developer.apple.com/programs/whats-included/ 🔶（検索要約経由）
- [S89] Apple – WWDC23 Session 10027 "Bring widgets to new places"（StandBy・vibrant・containerBackground） https://developer.apple.com/videos/play/wwdc2023/10027/ ✅
- [S90] Apple – WidgetFamily https://developer.apple.com/documentation/widgetkit/widgetfamily ✅
- [S91] Apple Support – Add, edit, and remove widgets on iPhone https://support.apple.com/guide/iphone/add-edit-and-remove-widgets-iphb8f1bf206/ios ✅
- [S92] wwdcnotes – What's new in widgets (WWDC25-278) https://wwdcnotes.com/documentation/wwdc25-278-whats-new-in-widgets/ 🔶
- [S93] 9to5Mac – iOS 26 made Live Activities even better（2025-12-04） https://9to5mac.com/2025/12/04/ios-26-made-live-activities-even-better-on-iphone-heres-whats-new/ 🔶
