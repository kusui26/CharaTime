# F. 別リサーチ主張の事実確認（SpritePals / WidgetAnimation / Foundation Models / CMPedometer）

- 作成日: 2026-09-11（すべての出典は同日に WebFetch で確認）
- 凡例: ✅ 一次情報で確認 / 🔶 二次情報（フォーラム投稿・ユーザー報告・検索スニペット等）/ 🔷 推測（出典から導いた推論）/ **未確認**
- 補足: この日の環境では WebSearch が使えず、Apple Developer Documentation の JSON API（`developer.apple.com/tutorials/data/documentation/...json`）、GitHub REST API、iTunes Search/Lookup API、App Store RSS、Apple Developer Forums、Arctic Shift（Reddit アーカイブ API）等を直接取得して確認した。Reddit 本体・Stack Overflow・DuckDuckGo は取得不可（ブロック/CAPTCHA）。
- 参考（OS の現況 ✅）: Apple Developer Releases RSS によると iOS 26.6.2 (23G90) が 2026-09-08、iOS 27.0 RC (24A435) と Xcode 27 RC (27A266a) が 2026-09-09 にリリース済み。Xcode 26.6 (17F113) は 2026-06-25。

---

## 0. 要約

1. **SpritePals** ✅ 実在。「SpritePals: Pixel Pet Widget」（開発者 Ivo van der Zee、App ID 6754703807）。US/JP 両ストアに掲載、2026-01-15 公開、最新 3.2.2（2026-07-18）、iOS 17.0+、無料＋トークン IAP（$0.99〜$3.99）＋Pro 買い切り $5.99、US 評価 3.9/8 件、JP 評価なし。写真→ピクセル化は **サーバー側（Cloudflare Worker 経由で OpenAI へ送信）** とプライバシーポリシーに明記。モデル名は未確認。レビュー不満は「カスタム生成が毎回有料」「Dynamic Island 表示が消える」「感情/動きが単調」。

2. **WidgetAnimation の iOS 26.2 Issue** ✅ 存在する。Issue #3（2025-12-30、open）「This API has stopped working in the latest iOS 26.2 version」。報告者自身のコメントで「Xcode 26.1.1 でビルドすると壊れ、Xcode 26.0.1 では動く」。作者の返答・README・ブログ・SNS の追記は **なし**。同系統の私用 API `_clockHandRotationEffect`（ClockHandRotationKit）でも「Xcode 26.1 以降の SDK でビルド × iOS 26.1 以降で動作しない／Xcode 26.0.1 ビルドなら iOS 26.5 まで動く」という複数報告あり（🔶）。iOS 26.6.x / iOS 27 RC での報告は **未確認**。

3. **Foundation Models** ✅ iOS 26.0+（watchOS は 27.0+）、Apple Intelligence 対応機（iPhone 15 Pro / 16 以降 → iPhone 17 Pro 可）。`availability` は `.available` / `.unavailable(.appleIntelligenceNotEnabled | .deviceNotEligible | .modelNotReady)`。日本語は Apple Intelligence 対応言語に含まれ、`supportsLocale(_:)` で確認、非対応なら `unsupportedLanguageOrLocale`。文脈長 4,096 トークン/セッション（日本語は概ね 1 文字 1 トークン）。レート制限は **バックグラウンド実行時のみ**（前景 UI アプリは無制限、DTS 回答）。ウィジェット拡張からの呼び出しは技術的には可能というユーザー報告があるが、**Apple のエンジニアは 30MB メモリ上限を理由に非推奨、本体アプリで事前生成を推奨**（2026-06）。

4. **CMPedometer** ✅ HealthKit なしで当日の歩数を取得可能（`queryPedometerData(from:to:)`）。`NSMotionUsageDescription` 必須（無いとクラッシュ）、初回の motion データアクセス時にシステムがダイアログを出す。履歴は **過去 7 日分のみ**。ウィジェット拡張から直接呼べるか否かの **Apple 公式回答は未確認**（禁止する記述もなし）。実務上は「本体アプリで取得 → App Group 保存 → ウィジェットが読む」が安全（許可ダイアログは拡張から出せない、拡張の 30MB 制限・更新予算の制約）。HealthKit を使うと Apple Watch 分を含む統合歩数が取れるが、HealthKit capability/entitlement と明示的な認可が必要で、**端末ロック中は読めない**（DTS 回答）。

---

## 1. SpritePals（iOS アプリ）

### 事実

| 項目 | 内容 | 区分 |
|---|---|---|
| 正式名 | SpritePals: Pixel Pet Widget | ✅ |
| 開発者 | Ivo van der Zee（`com.ivovanderzee.spritepals`、Apple ID 6754703807、開発者 ID 1254451944）。この開発者のアプリはこれ 1 本のみ | ✅ |
| 掲載 | US ストア: あり／JP ストア: あり（説明文は英語のまま、価格は円表示） | ✅ |
| 公開日 | 2026-01-15 | ✅ |
| 最新版 | 3.2.2（2026-07-18）「Bugs fixed and performance improvements」 | ✅ |
| 対応 OS | iOS 17.0 以降、Apple Watch アプリは watchOS 10.6 以降。サイズ 94.8 MB。対応言語 英語・オランダ語 | ✅ |
| 価格 | 無料。IAP: 1 token $0.99 / 3 tokens $1.99 / 5 tokens $2.99 / 10 tokens $3.99 / Pro（買い切り）$5.99。JP: ¥150 / ¥300 / ¥500 / ¥600 / ¥1,000。サブスクなし・広告なし | ✅ |
| 評価 | US: 3.875（8 件）→ ストア表示「3.9 / 8 Ratings」。JP: 評価・レビュー件数不足で非表示（0 件） | ✅ |
| 年齢区分 | 4+ | ✅ |
| カテゴリ | Graphics & Design（副: Entertainment） | ✅ |
| プライバシー表示 | 「ユーザーに紐付く」データとして購入、ユーザーコンテンツ（写真/動画）、デバイス ID、ゲームプレイ内容 | ✅ |

**説明文の機能（App Store、原文要約）** ✅
- 「Turn your real pet into a retro pixel companion for iPhone and Apple Watch」。猫・犬などの写真から AI でピクセルペット生成、または既製の pal を選択。
- 展開先: Dynamic Island、Lock Screen Live Activities、Home Screen/Lock Screen ウィジェット、Apple Watch コンプリケーション。
- 餌やり・遊び・世話、レベルとムード（毎日チェックインでレベルアップ）。
- Pro: 追加の既製 pal、追加の食べ物、カスタム生成トークン 10 個（1 回限り）、Live Activities に 2 匹目、カスタムアプリアイコン書き出し 等。
- **アニメーションの有無**: App Store の説明文には「アニメーション」の語は無い。公式サイト見出しは「Turn a photo of your pet into an **animated** pixel companion for your Lock Screen, Dynamic Island, widgets and Apple Watch」✅。開発者の Reddit 投稿（r/iosapps、2026-01-27）では「a small pixel companion **with a simple retro-style animation**」と説明 ✅（Reddit 本体は取得不可、Arctic Shift アーカイブ API で本文を取得）。

**写真からスプライトを作る仕組み** ✅（公式プライバシーポリシー v1.6、最終更新 2026-06-14）
- 「Before upload, we run an on-device animal check; those results are not uploaded.」（アップロード前に端末内で動物判定）
- 「Cloudflare, Inc. (United States) runs our Worker proxy and relays requests to OpenAI.」
- 「OpenAI, LLC (United States) receives the photo over TLS to generate your sprite」「OpenAI may retain data for safety/abuse monitoring under their policies.」
- 「We do not store your photos on our own servers; they are forwarded to OpenAI via our proxy」「We cannot delete a photo after it has been sent to OpenAI」
- 「The Watch app itself does not connect to our server, OpenAI, or iCloud.」
- 使用モデル名（gpt-image 系か等）は **未確認**（ポリシー・サイト・ストアに記載なし）。🔷 画像生成 API（OpenAI Images）を Cloudflare Worker で中継している構成と推定。
- 公式サイト spritepals.app は 1 ページ（見出し・機能 3 項目・App Store リンク・プライバシーポリシー）のみで、ブログ・X・プレスキットのリンクは無い ✅。開発者の X 投稿は **未確認**。

**レビュー（App Store RSS、全件）** ✅
- US 5★「Love it!」（2026-09-02、v3.2.2）: 10 トークン $3.99 を評価。「add emotions to your spritepal it can't just have the same mood」（ムードが同じで単調）。
- US 3★「Retro」（2026-01-28、v1.2）: 「purchased pro but wasted money… Pay $1 for every custom animal, every time. No thanks」（カスタム生成が毎回有料であることへの不満）。
- NL 4★「Bugs」（2026-04-07、v2.0.1）: Dynamic Island のペットがランダムに消える／2 匹目の選択が保持されない／ボール投げミニゲームが面倒。
- NL 5★（2026-03-20、v2.0.1）: ノスタルジック、世話する対象ができて良い。
- GB 5★「I LOVE IT!」（2026-08-08、v3.2.2）: 買い切りの価格設定を称賛。
- AU 4★「Still early days」（2026-08-11、v3.2.2）: 広告なしを評価。レベルアップで「アニメーションや機能が解放されるのか」の説明が不足、Pro 購入を保留。
- CA / DE: レビューなし。
- Reddit 開発者スレのコメント（🔶）: 「so cute」「ミニゲーム（餌・水分）を任意にしてほしい」「豪州/ブラジル/マレーシアで配信して」（豪州・ブラジルは 2026-02 に追加）。
- **AI 生成品質**への直接の言及、**審査・年齢区分**に関する言及は、取得できたレビュー・投稿には **無し**。

### 出典
- iTunes Search API（US/JP）、iTunes Lookup API（id=6754703807, id=1254451944）、App Store ページ（US/JP）、App Store RSS（us/jp/nl/gb/ca/au/de）、spritepals.app、spritepals.app/privacy-policy、Arctic Shift API（Reddit r/iosapps 1qotjel の本文とコメント）。URL は §6。

### CharaTime への含意
- 「写真→キャラ化」を売りにする直接競合は実在し、生成はサーバー側 AI（OpenAI）で、トークン課金で原価を回収している。CharaTime がオンデバイス／テンプレート生成で「無料・オフライン・写真をサーバーに送らない」を打ち出せば明確な差別化になる。
- ユーザー不満は「生成ごとの課金」「Dynamic Island の表示不安定」「表情/動きの単調さ」。CharaTime の吹き出し生成やムード表現は、この "同じ顔・同じ気分" 問題への解になりうる。
- 年齢区分 4+ で審査を通過しているため、AI 生成ペット画像 + 写真アップロード自体は審査上の障害にはなっていない（ただし SpritePals はサーバー側で「動物判定」を前置きしている点に注意）。

---

## 2. Bryce Bostwick「WidgetAnimation」PoC と iOS 26.2 問題

### 事実

**リポジトリの状態** ✅（GitHub API、2026-09-11）
- `brycebostwick/WidgetAnimation`「Proof of concept for Animated iOS Widgets using Public APIs」。作成 2025-05-11、**最終 push 2025-05-11**（コード変更なし）、Star 504、Fork 38、open issues/PR 5、アーカイブされていない。
- README は YouTube 動画「Apple's Widget Backdoor」（2025-05-11）へのリンクと「8 FPS の例、同じ手法で最大 30 FPS」のみ。**iOS バージョンに関する追記・警告は無い**。
- デモ本体 `Widget/Widget.swift` は **公開 API のみ**: `Text(date, style: .timer)` × 17 種のカスタムフォント（16 フォントに各フレームのグリフ、1 フォントが 1 秒点滅する矩形）を `.mask` で重ねて 8 FPS を実現。`ClockHandRotationEffect.xcframework`（私用 API `_clockHandRotationEffect` のラッパー）はリポジトリに同梱されているがデモコードでは **未使用**（PR #4 の指摘どおり）。

**Issue / PR 一覧** ✅（すべて open、作者の返答なし）
| # | 種別 | 日付 | 内容 |
|---|---|---|---|
| 1 | PR | 2025-05-11 | スペル修正 |
| 2 | Issue | 2025-09-02 | 「Doesn't work on iOS 17 or older」— `.timer` スタイルの秒丸めが不安定 |
| **3** | **Issue** | **2025-12-30** | **「This API has stopped working in the latest iOS 26.2 version. How can I adapt it?」（本文なし）。同報告者 Rogue24 のコメント（同日）: 「I found that the issue occurs when the project is built with **Xcode 26.1.1**, while it still works fine with **Xcode 26.0.1**.」リアクション 0、他者のコメント無し** |
| 4 | PR | 2026-02-15 | 「[Fix] Widget was not appearing in widget search panel」— `.supportedFamilies([.systemLarge])` 追加と ClockHandRotationEffect.xcframework をウィジェットターゲットから除外。本文に「The framework might not work anymore in latest iOS 26 versions. And the demo code does not use it at all.」。コメント（2026-02-24, giljihun）「perfect solution thx」 |
| 5 | PR | 2026-02-15 | .gitignore 追加 |

**作者側の発信** ✅
- bryce.co の記事一覧に 2025-05-11「[Video] Apple's Widget Backdoor」以降、ウィジェット関連の更新なし（最新記事は 2026-01-31「How Apple Hooks Entire Frameworks」）。
- Bluesky（公開 API で取得）・Mastodon RSS とも iOS 26 / Xcode 26 / 手法が塞がれた旨の投稿は **無し**。
- 作者の他リポジトリにも後継・修正版は無い。

**同系統手法での破損報告（私用 API `_clockHandRotationEffect` 経由）** 🔶
- `octree/ClockHandRotationKit` Issue #11（2025-11-06、open）実測マトリクス:
  - Xcode 26.1 ビルド → iOS 26.1 ❌ ／ iOS 17.5 ✅ ／ iOS 18.6 ✅ ／ iOS 26.0.1 ✅
  - Xcode 26.0.1 ビルド → iOS 26.1 ✅
  - Xcode 26.2 beta 1 ビルド → iOS 26.2 beta 1 ❌
  - 結論（報告者）: 「Xcode 26.1 以上でビルドし iOS 26.1 以上で動かすと回転しない」
  - コメント: 「Apple が 26.1 でこのインターフェースを変更したと確認」「唯一の解は Xcode 26.0.1 でビルド」「Xcode 26.0.1 なら iOS 26.2 で再生できる」（2025-12-17）「Xcode 26.0.1 は iOS 26.5 でも動く」（2026-05-27）。メンテナは対応しないと表明（2025-11-25）。2026-06-09 の「新しい進展は？」に回答なし。
- `Keychy/KeychyApp` PR #244（2026-05-29）: CI を Xcode 26.4.1 → **Xcode 26.0.1 に固定**して回復。「Xcode 26.1+ で私用 API の内部実装が変更され呼び出しが壊れる」。同 PR #130（2026-03-05）は arc マスク + `clockHandRotationEffect` で 30 FPS のウィジェットアニメーションを実装（App Group に PNG フレーム保存）。
- `ClockHandRotationKit` PR #13（2026-03-11）: Xcode 26.0.1 (17A400) + iOS 26.3.1 で動作（TestFlight 配布時の bitcode 問題を修正）。
- 以上から、破損条件は「iOS 26.1 以降の **SDK でリンク**したバイナリが iOS 26.1 以降で動く」場合であり、OS 更新だけで既存ビルドが止まったわけではない（linked-on-or-after 型の挙動変更と推定 🔷）。Bryce のデモ（公開 API のみ）についての報告は Issue #3 の 1 件のみで、根本原因が同一かは **未確認**（🔷 timer Text のフレーム更新経路が共通で、同じ SDK 判定に引っかかった可能性）。

**メディア・コミュニティ** 
- Hackaday「Animated Widgets On Apple Devices Via A Neat Backdoor」（2025-05-17）✅: 手法紹介と「Apple が更新で塞ぐ可能性」への言及。コメント欄は電池消費・審査リスク・将来の破損を懸念。
- Apple Developer Forums: 本手法の破損を扱うスレッドは検索で **見つからず**（関連: 836489「TimeDataSource .dateRange(endingAt:) won't update」2026-06 は Live Activity の別件）。
- Hacker News（Algolia API）: 該当ストーリー無し。Reddit: 取得不可（未確認）。

**iOS 26.6.x / iOS 27 RC での動作報告**: **未確認**（最後の実測報告は「Xcode 26.0.1 ビルドが iOS 26.5 で動作」2026-05-27）。

### 出典
- GitHub API（repo / issues / issues/3 / issues/3/comments / issues/4 / pulls/4/files / forks / git/trees）、raw README・Widget.swift、bryce.co、Bluesky 公開 API、Mastodon RSS、Hackaday、octree/ClockHandRotationKit issues #10/#11/#13、Keychy/KeychyApp #130/#244、Apple Developer Forums 検索。URL は §6。

### CharaTime への含意
- 「iOS 26.2 で動かなくなった」という主張は **Issue として実在するが、正確には "Xcode 26.1 以降の SDK でビルドすると iOS 26.1 以降で動かない"** という報告群。Xcode 26.0.1 に固定すれば 2026-05 時点まで延命できていたが、iOS 27 SDK（Xcode 27 RC、2026-09-09）の新機能と両立せず、App Store の最低 SDK 要件が上がれば詰む。
- したがってこの手法は **製品の中核に据えない**。採用するなら「動かなくなっても成立する体験」（静止画フォールバック）を前提に、ビルド環境固定というコストを支払う覚悟が必要。私用 API 版（`_clockHandRotationEffect`）は審査リスクも加わる。
- 公式に許される動きは、タイムラインエントリ（≥5 分間隔目安、1 日 40〜70 回の更新予算）、`Text(timerInterval:)` 等のシステム描画タイマー、Live Activity/Dynamic Island の更新、インタラクティブウィジェットのボタン押下時アニメーション、に限られる（WidgetKit 公式ドキュメント ✅）。

---

## 3. Apple Foundation Models フレームワーク

### 事実

**(a) 対応 OS・デバイス** ✅
- フレームワーク: iOS 26.0+ / iPadOS 26.0+ / macOS 26.0+ / Mac Catalyst 26.0+ / visionOS 26.0+ / **watchOS 27.0+**（watchOS は iOS 27 世代で追加）。
- 「To use Apple Foundation Models, users need a device that supports Apple Intelligence」。Apple サポート 121115: iPhone は「iPhone 15 Pro models, and iPhone 16 models or later」→ **iPhone 17 Pro（A19 Pro、2025-09-19 発売、iOS 26 搭載）は対象** ✅（Apple Newsroom 2025-09 の発表文でも Apple Intelligence を iOS 26 全体に統合と明記）。
- 中国本土で購入した端末では Apple Intelligence が動作しない ✅。
- オンデバイスモデル: 約 3B パラメータ（Apple ML Research 2025-06-09）✅。iOS 27 では `SystemLanguageModel.Variant` が追加され `core3`（"AFM 3 Core"）と `coreAdvanced3`（"AFM 3 Core Advanced"）が存在 ✅。どちらが使われるかは **端末種別と OS バージョンで自動決定され、指定 API は無い**（DTS 回答 2026-06、「4K の contextSize なら 3B Core」）✅。iPhone 17 Pro で Core Advanced が使えるかは **未確認**。

**(b) 可用性判定** ✅
- `SystemLanguageModel.default.availability` → `.available` ／ `.unavailable(UnavailableReason)`。`isAvailable: Bool` もある。
- `UnavailableReason`（iOS 26.0+）: `appleIntelligenceNotEnabled`（Apple Intelligence が未有効）、`deviceNotEligible`（非対応機）、`modelNotReady`（モデルが端末に無い＝ダウンロード中など）。
- 公式ガイド: 「It can take some time for the model to download and become available when a person turns on Apple Intelligence.」必ず先に可用性を確認しフォールバック UI を用意すること。
- DTS（2025-11）: モデルは OS が管理し、**ユーザーが対応機で Apple Intelligence をオンにして初めて端末に存在する**。Apple Intelligence の言語は **システム言語ではなく Siri の言語設定** に基づく（設定 > Apple Intelligence と Siri > 言語）🔶（Apple スタッフ回答）。
- 「言語未対応」は `availability` の理由には含まれず、後述の `supportsLocale` / `unsupportedLanguageOrLocale` で扱う。

**(c) 日本語対応** ✅
- Apple Intelligence 対応言語（サポート 121115）: English, Danish, Dutch, French, German, Italian, Norwegian, Portuguese, Spanish, Swedish, Turkish, Chinese (Simplified/Traditional), **Japanese**, Korean, Vietnamese。iPhone 17 Pro 発表文でも日本語は初期対応言語 ✅。
- Apple ML Research（2025-06）: 15 言語対応、PFIGSCJK（日本語含む）で評価 ✅。
- 公式記事「Supporting languages and locales with Foundation Models」: オンデバイスモデルは **多言語で、Apple Intelligence 対応言語すべて**を理解・生成。`supportsLocale(_:)`（既定 `Locale.current`、アプリ別言語設定を考慮、近縁ロケールも true）で事前確認。非対応言語の入力/出力要求は `LanguageModelError.unsupportedLanguageOrLocale(_:)` を投げる。Instructions に **英語で** 「The person's locale is ja_JP.」を入れ、必要なら「You MUST respond in Japanese.」と出力言語を明示。`@Generable` の型名・プロパティ名・`@Guide` 説明も対応言語で書く。ガードレールは対応言語のみ有効 ✅。
- トークン: 「日本語・中国語・韓国語・ベトナム語は概ね 1 文字 = 1 トークン」✅（英語は 3〜4 文字/トークン）。

**(d) 主要 API** ✅
- モデル: `SystemLanguageModel.default`、`init(useCase:guardrails:)`（`UseCase.contentTagging`）、`Guardrails`、`supportedLanguages`、`supportsLocale(_:)`、`contextSize`／`tokenCount(for:)`（26.4 で追加・26.0 に backDeployed）。
- セッション: `LanguageModelSession(instructions:)`、`init(model:tools:instructions:)`、`init(model:tools:transcript:)`（履歴復元）。`respond(to:options:)`、`respond(to:generating:includeSchemaInPrompt:options:)`、`respond(to:schema:...)`、`streamResponse(...)`（`ResponseStream` が部分生成スナップショットを流す）、`prewarm(promptPrefix:)`、`transcript`、`isResponding`（**同時に 1 リクエストのみ**、重ねると `concurrentRequests` エラー）。
- `GenerationOptions(samplingMode:temperature:maximumResponseTokens:toolCallingMode:)`。`maximumResponseTokens` は暴走防止用で、短く切ると文が壊れる。
- Guided generation: `@Generable(description:)` を struct / enum / actor に、`@Guide(description:, .range(0...20), .minimumCount/.maximumCount, .anyOf([...]), 正規表現)` を stored property に。**プロパティは宣言順に生成**。ネスト・associated value 付き enum 可。`DynamicGenerationSchema` → `GenerationSchema` → `GeneratedContent` で実行時スキーマ。
- Tool calling: `Tool` プロトコル（`name`、`description`、`@Generable struct Arguments`、`call(arguments:) async throws -> String | Generable | GeneratedContent`）。並列呼び出しあり。3〜5 個以内推奨。`toolCallingMode`: `.allowed`（既定）/`.required`/`.disallowed`。
- エラー: iOS 26 は `LanguageModelSession.GenerationError`（`exceededContextWindowSize`, `rateLimited`, `guardrailViolation`, `unsupportedLanguageOrLocale`, `assetsUnavailable`, `decodingFailure`, `concurrentRequests`, `unsupportedGuide`, `refusal`）。**iOS 27 で deprecated** となり `LanguageModelError`（`contextSizeExceeded`, `rateLimited`, `refusal`, `timeout`, `guardrailViolation`, `unsupportedCapability`, `unsupportedTranscriptContent`, `unsupportedGenerationGuide`, `unsupportedLanguageOrLocale`）と `SystemLanguageModel.Error.assetsUnavailable` に整理。
- iOS 27 追加: `PrivateCloudComputeLanguageModel`（entitlement `com.apple.developer.private-cloud-compute` の申請が必要、32K 文脈、日次クォータ）、`LanguageModel` プロトコル（他社/OSS モデルの接続）、Dynamic Profiles、`Attachment` による画像入力、`usage`（トークン使用量）。

**(e) 文脈長・レート制限** ✅
- オンデバイス: **4,096 トークン / セッション**（Instructions・全プロンプト・ツール定義と入出力・Generable スキーマ・全応答の合計）。超えると `contextSizeExceeded`。対処は転写のトリミングか新セッション。Instruments の Foundation Models テンプレートで計測可能。PCC（iOS 27）は 32K、オンデバイスは「Usage limits: Unlimited」と公式比較表に記載。
- レート制限: 公式ドキュメント「`rateLimited` は **アプリがバックグラウンドで実行され、システム定義のレート制限を超えた場合にのみ**発生」。DTS/Frameworks Engineer 回答（2025-06〜08、🔶 Apple スタッフ）: 「UI を持つ前景アプリにはレート制限なし」「電源接続中は制限されない想定（既知の問題あり）」「**バッテリー駆動 × バックグラウンド**で制限」「推論は OS 全体で直列に 1 つずつ実行される共有資源」「バックグラウンドでは streaming より `respond` を推奨」。具体的な閾値は **非公開**（ユーザー報告: Safari 拡張で 30 秒間隔 4 リクエストで到達、2025-06 beta）。

**(f) ウィジェット拡張からの利用** 
- 🔶 ユーザー報告（Apple Developer Forums 840737、2026-08）: 「The API works as expected when invoked from the widget extension.」（Apple の返答なし）。
- ✅ Apple Frameworks Engineer 回答（Forums 834384、2026-06、Accepted）: 「widget extensions have relatively small memory caps (~30mb), using local AI models may not work well… Exceeding memory limits often can cause your widget reloads to fail, and cause future reloads to occur at times later than normal」「pre-computing or generating what you need from your application where memory constraints are more generous seems a more plausible model」。
- 🔶 他の拡張: DeviceActivityReport では sandbox エラー、MessageFilter では利用不可（いずれもユーザー報告）。Safari 拡張はバックグラウンド扱いでレート制限。
- 🔷 ウィジェット拡張は WidgetKit 上「continually active ではない」別プロセス（公式）で、前景 UI を持たないため (e) のバックグラウンド・レート制限の対象になると考えられる。

**(g) WWDC セッション** ✅
- WWDC25: 286「Meet the Foundation Models framework」、259「Code-along: Bring on-device AI to your app using the Foundation Models framework」、301「Deep dive into the Foundation Models framework」、248「Explore prompt design & safety for on-device foundation models」、360「Discover machine learning & AI frameworks on Apple platforms」。
- WWDC26: 241「What's new in the Foundation Models framework」（新オンデバイスモデル、画像理解、PCC、モデル抽象化、Dynamic Profiles、評価フレームワーク、`fm` CLI、Python SDK）、242「Build agentic app experiences with the Foundation Models framework」、319「Build with the new Apple Foundation Model on Private Cloud Compute」、339「Bring an LLM provider to the Foundation Models framework」、334「Build AI-powered scripts with the fm CLI and Python SDK」、277「WidgetKit foundations」（参考）。

### 出典
- developer.apple.com の FoundationModels ドキュメント JSON（framework, SystemLanguageModel, Availability, UnavailableReason, supportedLanguages, supportsLocale, contextSize, Variant, LanguageModelSession, GenerationError, rateLimited, LanguageModelError, SystemLanguageModel.Error, GenerationOptions, PrivateCloudComputeLanguageModel、記事 5 本）、Apple サポート 121115、Apple Newsroom（iPhone 17 Pro）、Apple ML Research、WWDC セッションページ、Apple Developer Forums 805378 / 834384 / 840737 / 787737 / 789788 / 798113 / 832555。URL は §6。

### CharaTime への含意
- 「テンプレート → オンデバイス LLM で吹き出し生成」は **本体アプリの前景で行い、結果を App Group にキャッシュしてウィジェットが表示する**設計にする。ウィジェット拡張内で直接生成するのは Apple 非推奨（30MB）かつバックグラウンド・レート制限の対象。
- 可用性の分岐は `.available` / `.appleIntelligenceNotEnabled` / `.deviceNotEligible` / `.modelNotReady` の 4 通り＋ `supportsLocale()` false＋ `unsupportedLanguageOrLocale` の実行時エラーを想定し、**常にテンプレート生成へフォールバック**できるようにする。
- 日本語は対応言語だが、Instructions は英語で書き「The person's locale is ja_JP.」「You MUST respond in Japanese.」を入れる。短い吹き出し用途は 4,096 トークンで十分だが、`@Generable` のスキーマや `@Guide` 説明もトークンを消費するため型は最小限に。`GenerationOptions.temperature` で口調の揺らぎを調整。
- iOS 26 と 27 でエラー型が変わる（`GenerationError` → `LanguageModelError`）ため、`#available` で両対応するか、iOS 27 以降に限定する判断が必要。将来はプロフィール写真を `Attachment` で渡す（iOS 27）拡張も視野。

---

## 4. Core Motion `CMPedometer` による歩数取得

### 事実

**(a) HealthKit なしで当日の歩数** ✅
- `CMPedometer` は「system-generated live walking data」を取得するオブジェクトで、履歴キャッシュを `queryPedometerData(from:to:withHandler:)` で問い合わせ、`startUpdates(from:withHandler:)` でライブ更新を受ける（iOS 8.0+）。当日 0 時〜現在を指定すれば当日歩数が得られる。HealthKit の capability は不要。
- Core Motion 概要: 「Access step-counting data from the built-in motion processor」→ **iPhone 本体のセンサーで数えた歩数**であり、Apple Watch の歩数は含まれない（🔷 公式に明文化は無いが、ドキュメントの定義から導かれる。Forums の 2017 年ユーザー報告でも「iPhone の CMPedometer は Watch より大幅に少ない」🔶）。

**(b) Info.plist と権限フロー** ✅
- `NSMotionUsageDescription` は `CMSensorRecorder`, `CMPedometer`, `CMMotionActivityManager`, `CMMovementDisorderManager` を使うアプリに必須。「If you don't include this key, your app will crash when it attempts to access motion data.」（DTS も 2024-09 に同文を引用して確認。`CMMotionManager` だけなら不要）。
- ダイアログ: CMPedometer リファレンスの Important 注記「The usage description appears in the prompt that the user must accept **the first time the system asks for access to motion data**」→ 明示的な request API は無く、**最初のクエリ/更新開始時にシステムが自動でダイアログを出す**。
- `CMPedometer.authorizationStatus()`（iOS 11+）→ `CMAuthorizationStatus`: `.notDetermined` / `.restricted`（システム制限）/ `.denied` / `.authorized`。未認可時のエラーは `CMErrorMotionActivityNotAuthorized`（コード 105）🔶（Forums 回答）。
- App Store Connect は `NSMotionUsageDescription` が無いと ITMS-90683 でアップロードを拒否する 🔶（Forums 複数報告）。

**(c) 取得できる期間** ✅
- `queryPedometerData` の Discussion: 「**Only the past seven days worth of data is stored and available for you to retrieve.** Specifying a start date that is more than seven days in the past returns only the available data.」

**(d) ウィジェット拡張から直接呼べるか** 
- Apple 公式文書に CMPedometer を app extension で禁止する記述は **無い**（Core Motion / CMPedometer / WidgetKit の各ドキュメント、旧 App Extension Programming Guide の「Some APIs Are Unavailable to App Extensions」にも Core Motion は挙がっていない）✅。ただし「ウィジェット拡張から呼べる／呼べない」を明言した **Apple の回答は未確認**（Forums を 6 通りのクエリで検索したが該当スレッド無し）。
- 制約（公式 ✅）: ウィジェット拡張は WidgetKit が別プロセスで描画し「not continually active」、メモリ上限は約 30MB（Frameworks Engineer 回答、複数の EXC_RESOURCE 報告）、更新予算は 1 日 40〜70 回、エントリ間隔は約 5 分以上。
- 🔷 権限ダイアログは UI を持たない拡張からは出せないため、**必ず本体アプリで初回アクセスして認可を得てから**でないと拡張のクエリは 105 で失敗する。認可後の拡張からの直接クエリが可能かは未検証。
- 参考実装（🔶 コミュニティ）: `kana-shin/PedometerApp-WidgetKit`（2023、日本語）は本体アプリで `CMPedometer.queryPedometerData` を呼び、ウィジェットの `TimelineProvider` は App Group の `UserDefaults(suiteName:)` から歩数を読む構成。Medium の iOS 16 ロック画面歩数ウィジェット記事も同様の題材（本文取得不可）。

**(e) `isStepCountingAvailable` と iPhone 17 Pro** 
- `class func isStepCountingAvailable() -> Bool`（iOS 8.0+）: 「Returns true if step counting is available」✅。機種別の一覧は公式に無い。iPhone 17 Pro での実測は **未確認**（🔷 モーションコプロセッサ搭載機では true が期待され、否定する報告も見当たらない）。

**(f) HealthKit（`HKHealthStore`）を使う場合との違い** ✅
- 要件: Xcode で HealthKit capability を有効化（entitlement `com.apple.developer.healthkit`、申請不要の標準 capability）。有効化すると `healthkit` が Required device capabilities に追加される（任意機能なら削除）。`NSHealthShareUsageDescription`（読み取り）を Info.plist に記載し、`requestAuthorization` で明示的に許可を取る。`isHealthDataAvailable()` で事前確認。
- データ: HealthKit は **複数ソース（iPhone・Apple Watch・他アプリ）を統合**。`HKStatisticsQuery`（`.cumulativeSum`）で集計すると **重複を除いた歩数**が得られる（DTS 2025-05、生サンプルを自分で足すと二重計上）。Health アプリの既定優先順位は「手入力 > iPhone/iPad/Apple Watch > アプリ/Bluetooth 機器」（Apple サポート）。履歴は 7 日制限なし。
- 制限: **端末ロック中は HealthKit を読めない**（`HKError.Code.errorDatabaseInaccessible`、DTS 2026-05 「your app is not allowed to read health data while a device is locked」）。ロック画面ウィジェットのタイムライン更新時に失敗し得る。回避策（🔶 コミュニティ）: ウィジェットターゲットに `com.apple.developer.default-data-protection = NSFileProtectionComplete` を付けてロック中の更新を保留させる、失敗時は前回値を保持し「0」を出さない。
- 拡張での利用: iOS 8.0 時点の公式ガイドでは HealthKit は app extension で利用不可 ✅（当時）。現在はウィジェットから読んでいる開発者が複数（🔶）だが、Apple による「ウィジェット可」の明文は未確認。
- 比較まとめ: CMPedometer = iPhone 単体の歩数・過去 7 日・entitlement 不要・自動ダイアログ・ロック中も可（🔷 明文なし）。HealthKit = Watch 込みの統合歩数・全履歴・capability + 明示認可・ロック中不可・審査時にプライバシーポリシー等の追加要件。

### 出典
- developer.apple.com Core Motion / CMPedometer / queryPedometerData / isStepCountingAvailable / authorizationStatus / CMAuthorizationStatus / CMError / NSMotionUsageDescription、HealthKit / HKHealthStore / Setting up HealthKit / entitlement / HKStatisticsQuery / errorDatabaseInaccessible、WidgetKit「Keeping a widget up to date」「Creating a widget extension」、旧 App Extension Programming Guide、Apple サポート「Manage Health data」、Apple Developer Forums 762886 / 784375 / 824819 / 756794 / 834384、GitHub kana-shin/PedometerApp-WidgetKit。URL は §6。

### CharaTime への含意
- 歩数を「キャラの機嫌・台詞」に使うだけなら **CMPedometer で十分**（HealthKit の capability・審査負担を避けられる）。ただし Apple Watch 中心のユーザーには iPhone 単体の歩数が実感より少なく出るので、UI 文言は「iPhone が数えた歩数」と明示する。
- 実装は「本体アプリ起動時/バックグラウンド更新時に `queryPedometerData(今日 0 時〜現在)` → App Group に保存 → `WidgetCenter.reloadTimelines`」を基本線とし、ウィジェット内からの直接クエリは（認可後の）任意の最適化として実機検証してから採用する。
- 初回は本体アプリの明確な導線（「歩数と連動する」トグル等）で `NSMotionUsageDescription` のダイアログを出す。`.denied/.restricted` 時は歩数機能を静かに無効化。
- 将来 Watch 込みの歩数や 7 日超の履歴が必要になった時点で HealthKit を追加検討（ロック中に読めない点はウィジェット設計に影響）。

---

## 5. 未確認事項

1. SpritePals が使用する OpenAI の **モデル名**（gpt-image 系か DALL·E 系か）と生成コスト。開発者の X 投稿の有無。App Review で指摘を受けたかどうか。
2. SpritePals のスプライトが「何フレームのアニメーション」で、Live Activity 内でどう動かしているか（公式・レビューとも詳細なし）。
3. WidgetAnimation（公開 API 版）の破損が ClockHandRotationKit と同じ根本原因か（Issue #3 の 1 件のみ、作者未回答）。iOS 26.3〜26.6.2、iOS 27 RC、Xcode 27 RC での動作。App Store の最低 SDK 要件が Xcode 26.1 以上になる時期。
4. Foundation Models: iPhone 17 Pro で `Variant.coreAdvanced3` が使えるか／iOS 27 の新モデルの文脈長。レート制限の具体的閾値。ウィジェット拡張から呼んだ場合の実測メモリ。Reddit / Stack Overflow 上の追加報告（取得不可）。
5. CMPedometer: ウィジェット拡張から `queryPedometerData` を（認可済みの状態で）直接呼べるかの Apple 公式見解と実測。`isStepCountingAvailable()` の iPhone 17 Pro での値。CMPedometer がロック中にも応答するかの明文。
6. HealthKit がウィジェット拡張で利用可能であることの Apple 公式明文（コミュニティ報告のみ）。

---

## 6. 出典一覧（確認日: 2026-09-11）

### SpritePals
- https://itunes.apple.com/search?term=SpritePals&country=us&entity=software
- https://itunes.apple.com/search?term=SpritePals&country=jp&entity=software
- https://itunes.apple.com/lookup?id=6754703807&country=us
- https://itunes.apple.com/lookup?id=1254451944&entity=software&country=us
- https://apps.apple.com/us/app/spritepals-pixel-pet-widget/id6754703807
- https://apps.apple.com/jp/app/spritepals-pixel-pet-widget/id6754703807
- https://itunes.apple.com/us/rss/customerreviews/id=6754703807/sortby=mostrecent/json （同 jp / nl / gb / ca / au / de）
- https://spritepals.app
- https://spritepals.app/privacy-policy
- https://arctic-shift.photon-reddit.com/api/posts/ids?ids=1qotjel （Reddit r/iosapps 投稿 https://www.reddit.com/r/iosapps/comments/1qotjel/ のアーカイブ）
- https://arctic-shift.photon-reddit.com/api/comments/search?link_id=1qotjel

### WidgetAnimation
- https://api.github.com/repos/brycebostwick/WidgetAnimation
- https://api.github.com/repos/brycebostwick/WidgetAnimation/issues?state=all
- https://api.github.com/repos/brycebostwick/WidgetAnimation/issues/3 ／ /issues/3/comments ／ /issues/4 ／ /issues/4/comments ／ /pulls/4/files ／ /forks ／ /git/trees/main
- https://raw.githubusercontent.com/brycebostwick/WidgetAnimation/main/README.md
- https://raw.githubusercontent.com/brycebostwick/WidgetAnimation/main/Widget/Widget.swift
- https://bryce.co/ ／ https://bryce.co/widget-animations/
- https://public.api.bsky.app/xrpc/app.bsky.feed.getAuthorFeed?actor=brycebostwick.bsky.social
- https://mastodon.bryce.co/@bryce.rss
- https://www.youtube.com/watch?v=NdJ_y1c_j_I （oEmbed でタイトルのみ確認）
- https://hackaday.com/2025/05/17/animated-widgets-on-apple-devices-via-a-neat-backdoor/
- https://api.github.com/repos/octree/ClockHandRotationKit/issues?state=all ／ /issues/11 ／ /issues/11/comments ／ /issues/10 ／ /issues/13
- https://api.github.com/repos/Keychy/KeychyApp/issues/244 ／ /issues/130
- https://developer.apple.com/forums/search/?q=animated%20widget%20timer%20iOS%2026
- https://hn.algolia.com/api/v1/search?query=animated%20widgets%20apple%20backdoor&tags=story
- https://developer.apple.com/news/releases/rss/releases.rss （iOS 26.6.2 / iOS 27.0 RC / Xcode 27 RC の日付）

### Foundation Models
- https://developer.apple.com/documentation/foundationmodels （JSON: /tutorials/data/documentation/foundationmodels.json）
- https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel
- https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum
- https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/availability-swift.enum/unavailablereason
- https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/supportedlanguages
- https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/supportslocale(_:)
- https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/contextsize
- https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/variant-swift.struct
- https://developer.apple.com/documentation/foundationmodels/languagemodelsession
- https://developer.apple.com/documentation/foundationmodels/languagemodelsession/generationerror
- https://developer.apple.com/documentation/foundationmodels/languagemodelsession/generationerror/ratelimited(_:)
- https://developer.apple.com/documentation/foundationmodels/languagemodelerror
- https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/error
- https://developer.apple.com/documentation/foundationmodels/generationoptions
- https://developer.apple.com/documentation/foundationmodels/privatecloudcomputelanguagemodel
- https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models
- https://developer.apple.com/documentation/foundationmodels/managing-the-context-window
- https://developer.apple.com/documentation/foundationmodels/supporting-languages-and-locales-with-foundation-models
- https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation
- https://developer.apple.com/documentation/foundationmodels/expanding-generation-with-tool-calling
- https://developer.apple.com/documentation/foundationmodels/improving-the-safety-of-generative-model-output
- https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute
- https://developer.apple.com/documentation/foundationmodels/analyzing-images-with-multimodal-prompting
- https://support.apple.com/en-us/121115 （Apple Intelligence 対応機種・対応言語）
- https://www.apple.com/newsroom/2025/09/apple-unveils-iphone-17-pro-and-iphone-17-pro-max/
- https://en.wikipedia.org/wiki/IPhone_17_Pro （A19 Pro・発売日の補助確認）
- https://machinelearning.apple.com/research/apple-foundation-models-2025-updates
- https://developer.apple.com/videos/play/wwdc2025/286/ ／ /wwdc2025/301/ ／ /wwdc2026/241/ ／ /wwdc2026/242/ ／ /wwdc2026/319/ ／ /wwdc2026/339/ ／ /wwdc2026/277/ ／ https://developer.apple.com/videos/wwdc2026/
- https://developer.apple.com/forums/thread/805378 （DTS: Apple Intelligence 有効化とモデル存在、Siri 言語）
- https://developer.apple.com/forums/thread/834384 （Frameworks Engineer: ウィジェット拡張 30MB、事前生成推奨）
- https://developer.apple.com/forums/thread/840737 （ユーザー: ウィジェット拡張から動作）
- https://developer.apple.com/forums/thread/787737 ／ /thread/789788 ／ /thread/798113 （レート制限に関する Apple スタッフ回答）
- https://developer.apple.com/forums/thread/832555 （DTS: モデル variant は自動決定）
- https://developer.apple.com/forums/thread/810398 （MessageFilter 拡張で利用不可・要望）

### CMPedometer / HealthKit
- https://developer.apple.com/documentation/coremotion
- https://developer.apple.com/documentation/coremotion/cmpedometer
- https://developer.apple.com/documentation/coremotion/cmpedometer/querypedometerdata(from:to:withhandler:)
- https://developer.apple.com/documentation/coremotion/cmpedometer/isstepcountingavailable()
- https://developer.apple.com/documentation/coremotion/cmpedometer/authorizationstatus()
- https://developer.apple.com/documentation/coremotion/cmauthorizationstatus
- https://developer.apple.com/documentation/coremotion/cmerror
- https://developer.apple.com/documentation/bundleresources/information-property-list/nsmotionusagedescription
- https://developer.apple.com/forums/thread/762886 （DTS: NSMotionUsageDescription が必要な API）
- https://developer.apple.com/documentation/healthkit ／ /healthkit/hkhealthstore ／ /healthkit/setting-up-healthkit ／ /healthkit/hkstatisticsquery ／ /healthkit/hkerror/code/errordatabaseinaccessible
- https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.healthkit
- https://developer.apple.com/forums/thread/784375 （DTS: HKStatisticsQuery が重複除去）
- https://developer.apple.com/forums/thread/824819 （DTS: ロック中は HealthKit 読み取り不可）
- https://developer.apple.com/forums/thread/756794 （ロック画面ウィジェットと HealthKit、Data Protection 回避策）
- https://support.apple.com/en-us/HT204351 （Health のデータソース優先順位）
- https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date ／ /widgetkit/creating-a-widget-extension
- https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionOverview.html
- https://developer.apple.com/forums/search/?q=CMPedometer%20widget （他に pedometer extension / Core Motion widget extension / queryPedometerData / NSMotionUsageDescription widget / Motion Fitness widget extension で検索、該当なし）
- https://github.com/kana-shin/PedometerApp-WidgetKit （PedometerTimelineProvider.swift / PedometermManager.swift / entitlements）
