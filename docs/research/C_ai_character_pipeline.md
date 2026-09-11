# 担当 C: 生成 AI によるキャラクター制作パイプライン調査

- 作成日: 2026-09-10（すべての出典の確認日も 2026-09-10）
- 対象: CharaTime（iPhone のホーム画面/待受で 2 頭身のオリジナルキャラが自律的に歩き回るアプリ。au「ケータイパートナー」の現代版）
- 前提: 開発者は ChatGPT / Gemini / Claude の有料サブスク契約済み、MacBook Air (Apple Silicon) + iPhone 17 Pro、絵は描けないがコードは書ける
- 凡例: ✅ 一次情報（公式ドキュメント・公式ブログ・規約）で確認 / 🔶 二次情報（解説記事・比較サイト・コミュニティ）/ 🔷 推測・筆者の見解 / **未確認** = 公式ページで確認できなかった
- 注意: 本レポートは法的助言ではない。料金・上限は変動が激しいため、実装前に必ず公式ページを再確認すること。

---

## 0. 要約

1. **画像生成の主力は「ChatGPT Images 2.5（API: `gpt-image-2.5-flare` / `gpt-image-2.5-sunburst`、2026-09-08 公開）」と「Gemini の Nano Banana ファミリー（`gemini-3.1-flash-image` = Nano Banana 2、`gemini-3-pro-image` = Nano Banana Pro）」の 2 本柱。** どちらも参照画像を使った同一キャラの別ポーズ生成に対応し、開発者のサブスク内で手作業運用できる。✅
2. **透明背景をネイティブ出力できるのは OpenAI API だけ（`background: "transparent"` + PNG/WebP）。Gemini は RGB のみ**なので、クロマキー（#00FF00）か白黒 2 枚差分マッティングで後処理する。✅/🔶
3. **Claude は画像生成不可（公式 FAQ で明記）**。役割は「スタイルガイド/プロンプト設計」「生成物の一貫性チェック（Vision, 1 リクエスト最大 100〜600 枚）」「Claude Code でのスプライト化スクリプト」。✅
4. **ドット絵ルートなら PixelLab（API は 1 生成 $0.01〜0.19、歩行アニメ・4/8 方向回転を自動生成）**が最短。Retro Diffusion の Aseprite 拡張はローカル動作だが M1 Pro 64GB 要求で Air には不向き。✅
5. **動画→フレーム抽出ルートは非推奨（補助用途のみ）**。Sora 2 API は 2026-09-24 に停止、Veo 3.1 は透明/ループ出力なし、フレーム毎の背景除去でチラつく。Viggle はグリーンバック出力が可能で唯一の例外候補。✅/🔶
6. **一貫性の鍵は「先にキャラシート（三面図+表情）を作り、以後は毎回それを参照画像として添付」「自然言語の固定スタイルブロック」「1 枚のグリッドに複数ポーズを描かせて分割」**。🔶（複数の実践記事で一致）
7. **推奨パイプライン（今すぐ版）**: Claude でスタイルバイブル → ChatGPT Images 2.5 (Sunburst) で三面図 → 参照添付でポーズ/歩行 4 コマをグリッド生成 → 透明 PNG（OpenAI）or クロマキー除去（Gemini）→ Claude Code の Python/ImageMagick で正規化・アトラス化 → Claude Vision で QA。5 体で API 換算 $5〜20、実働 10〜15 時間。🔷
8. **将来の UGC 自動化は OpenAI `gpt-image-2.5-flare`（透明出力・`moderation` パラメータ・出力トークン $30/1M）を第一候補、コスト最優先なら `gemini-3.1-flash-lite-image`（約 $0.034/枚）+ クロマキー処理**。生成はサーバー側で行い、App Store ガイドライン 1.2（通報・ブロック・フィルタ）を満たす。✅/🔷
9. **法務**: OpenAI/Google/Midjourney/Recraft とも「生成物の権利はユーザー（またはノークレーム）」だが、日本法では AI 生成物は「創作的寄与」がなければ著作物にならず、既存キャラとの「類似性+依拠性」があれば侵害。**サンリオ等の固有キャラの特徴（例: 口のない白猫+赤リボン）を避け、「2 頭身・太線・パステル」という作風レベルの言語化に留める。**✅（文化庁 2024/2025 資料）
10. 未確認事項（§7）: gpt-image-2.5 の 1 枚あたり確定料金、ChatGPT/Gemini アプリの正確な日次上限、PixelLab のサブスク料金と規約、Viggle の商用条件など。

---

## 1. サービス別最新状況（2026-09 時点）

### 1.1 OpenAI（ChatGPT Images / gpt-image API）

**モデルの系譜** ✅🔶
| モデル | 公開 | 備考 |
|---|---|---|
| gpt-image-1 | 2025-03（ChatGPT）/ 2025-04-23（API） | 初代。廃止予定 2026-10-23 という二次情報あり（🔶 **未確認**） |
| gpt-image-1-mini | 2025-10-06 | 廉価版。**2026-12-01 停止** ✅ |
| gpt-image-1.5 | 2025-12-16 | **2026-12-01 停止** ✅ |
| gpt-image-2（ChatGPT Images 2.0） | 2026-04-21 API / 04-22 ChatGPT | 推論（thinking）内蔵、最大 2K、アスペクト 3:1〜1:3、1 プロンプトで最大 8 枚のキャラ一貫セット生成 🔶 |
| **gpt-image-2.5-flare / gpt-image-2.5-sunburst（ChatGPT Images 2.5）** | **2026-09-08** | Flare = 高速デフォルト、Sunburst = 精密編集向け（生成が遅い）。スナップショット `*-2026-09-08` ✅ |
| chatgpt-image-latest | — | **2026-12-01 停止** ✅ |
| dall-e-2 / dall-e-3 | — | **2026-05-12 停止済** ✅ |

出典: OpenAI Deprecations ✅ https://developers.openai.com/api/docs/deprecations ／ モデルページ ✅ https://developers.openai.com/api/docs/models/gpt-image-2.5-flare, https://developers.openai.com/api/docs/models/gpt-image-2.5-sunburst ／ System Card ✅ https://deploymentsafety.openai.com/chatgpt-images-2-5 ／ Wikipedia 🔶 https://en.wikipedia.org/wiki/GPT_Image ／ Images 2.0 解説 🔶 https://www.mindstudio.ai/blog/what-is-gpt-image-2

**Images 2.5 の能力（キャラ制作に関係する点）** ✅（公式ブログ・System Card）
- 参照画像の被写体保持が向上（「Image subjects look more recognizable... distinctive features are more likely to carry through」）、**複数回の編集をまたいで指示追従と品質が劣化しにくい**。
- 「transparent backgrounds を含む複雑なレイアウトを扱える」と明記。
- ChatGPT 側の新機能: Sketch（手描きラフを参照に）、Templates、Image comments（画像の特定箇所にコメントして修正）、Prompt sharing。全 ChatGPT プラン・ChatGPT Work・Codex で利用可。
- 安全: 入力画像と出力の両方を「safety reasoning model」で監視。実在人物の捏造描写はブロック。**C2PA（Conformance Program 参加）に加え Google DeepMind の SynthID 透かしも採用**。
- 出典: https://openai.com/index/introducing-chatgpt-images-2-5/ ✅（プロキシ経由で取得）, https://deploymentsafety.openai.com/chatgpt-images-2-5 ✅, https://community.openai.com/t/introducing-gpt-images-2-5-in-the-api-and-chatgpt/1395897 ✅

**API パラメータ（画像生成ガイド）** ✅ https://developers.openai.com/api/docs/guides/image-generation
- `background: "transparent"` を `output_format: "png"` または `"webp"` と併用 → **アルファ付き PNG を直接出力**。
- `n`: 1 リクエストで複数枚。
- `quality`: `low | medium | high | xhigh | max | auto`（2.5 で `xhigh`/`max` 追加）。
- `size`: 推奨 1024x1024 / 1536x1024 / 1024x1536。カスタムは幅・高さ 16 の倍数、アスペクト 1:3〜3:1、長辺 3840px 以下。
- edits エンドポイント: 複数の参照画像を渡して新規画像を生成（キャラシートを渡して別ポーズを描かせる用途）。インペインティング対応。
- `moderation: "auto" | "low"`。
- 出力形式 PNG/JPEG/WebP、`output_compression` 0-100。

**API 料金** ✅ モデルページ（両モデル同額）
- テキスト入力 $5 / 1M tokens（キャッシュ $1.25）、画像入力 $8 / 1M（キャッシュ $2）、**画像出力 $30 / 1M tokens**。
- 1 枚あたりの確定表は 2.5 では未公開（**未確認**）。コミュニティでは「トークン単価は gpt-image-2 と同じ」🔶。
- 🔷 目安（gpt-image-1 世代の 1024x1024 トークン数 low≈272 / medium≈1,056 / high≈4,160 を仮定）: **low ≈ $0.008、medium ≈ $0.03、high ≈ $0.12**。二次情報では gpt-image-2 が 1K $0.03 / 2K $0.05 / 4K $0.08 🔶 https://unifically.com/blogs/gpt-image-2 。
- レート制限（Tier1→5）: 100K→8M TPM、**5→250 images/min** ✅。

**ChatGPT サブスク内の生成上限** 🔶（公式は「プランにより異なる」以上を公開していない。ヘルプ記事 ✅ https://help.openai.com/en/articles/6696591-what-are-the-rate-limits-for-image-generation は API 側の説明のみ）
- Plus: 約 50 枚 / 3 時間のローリング枠、Pro: 「unlimited（乱用ガード付き）」、Free: 1 日 2〜3 枚程度、との集計サイト情報 🔶 https://chatgptlimit.com/chatgpt-image-generation-limit/ , https://www.cometapi.com/how-many-images-can-i-generate-with-chatgpt-plus-%E2%80%94-a-2026-status-report/ 。**アプリ内のバナー表示が唯一の正**。

**権利・商用利用** ✅（利用規約 https://openai.com/policies/row-terms-of-use/ をプロキシ経由で確認）
- 「you (a) retain your ownership rights in Input and (b) own the Output」「OpenAI hereby assigns to you all our right, title, and interest, if any, in and to Output」。
- 他ユーザーに類似の出力が出ることは保証外（排他性なし）。**AI 生成物を人間が作ったと偽って表示してはならない**。
- Usage Policies（2025-10-29 更新）✅: 他者の知的財産権侵害、本人同意のない実在人物の肖像利用を禁止。 https://openai.com/policies/usage-policies/
- 二次情報: 規約の現行版は 2026-01-01 発効 🔶 https://terms.law/2024/07/17/who-owns-chatgpt-answers-and-how-can-they-be-used-a-legal-analysis/

### 1.2 Google（Gemini / Nano Banana）

**モデル一覧** ✅ https://ai.google.dev/gemini-api/docs/image-generation
| API ID | 通称 | 解像度 | 参照画像上限 | 公開 |
|---|---|---|---|---|
| `gemini-3.1-flash-lite-image` | Nano Banana 2 Lite | 1K のみ | オブジェクト 14 枚 | **未確認**（2026 年、docs に掲載） |
| `gemini-3.1-flash-image` | **Nano Banana 2** | 0.5K/1K/2K/4K | オブジェクト 10 + **キャラクター 4** + スタイル 3 | 2026-02-26 ✅ |
| `gemini-3-pro-image` | **Nano Banana Pro** | 1K/2K/4K | オブジェクト 6 + **キャラクター 5** | 2025-11-20 ✅ |
| `gemini-2.5-flash-image` | Nano Banana（初代） | 1K | — | 移行推奨 |

- Nano Banana 2 は「Nano Banana Pro の品質と推論を Flash の速度で」、**最大 5 人のキャラと 14 オブジェクトの一貫性**、Gemini アプリ / AI Studio / Vertex / Flow で利用可 ✅ https://blog.google/innovation-and-ai/technology/ai/nano-banana-2/
- Nano Banana Pro（Gemini 3 Pro Image）: 最大 14 枚の入力合成、5 キャラの一貫性、2K/4K、文字描画 ✅ https://deepmind.google/models/gemini-image/pro/ , https://blog.google/technology/ai/nano-banana-pro/
- Imagen シリーズは 2026-06-24 に廃止し Nano Banana へ統合 🔶（TechCrunch 経由）。
- **透明背景**: docs にアルファ出力の記載なし ✅。コミュニティも「RGB のみ、`transparent` と書くとチェッカーボード柄を描くだけ」と報告 🔶 https://transparify.app/blog/gemini-transparent-background , https://www.philschmid.de/generate-stickers （後者は Google の Philipp Schmid 氏による #00FF00 クロマキー手法）。
- **SynthID**: 「All generated images include a SynthID watermark」✅（不可視）。**可視のスパークル透かし**は Free / Google AI Pro に付き、Google AI Ultra と API/AI Studio では付かない（Nano Banana Pro 発表時点）✅ https://blog.google/technology/ai/nano-banana-pro/ 。2026-09 時点で変更の有無は **未確認**。

**API 料金** ✅ https://ai.google.dev/gemini-api/docs/pricing
| モデル | 入力 | 画像出力 | 1 枚あたり | Batch（50% off） | Free tier |
|---|---|---|---|---|---|
| gemini-3-pro-image | $2.00/1M | $120/1M | **$0.134（1K/2K）/ $0.24（4K）** | $0.067 / $0.12 | なし |
| gemini-3.1-flash-image | $0.50/1M | $60/1M | **$0.045（0.5K）/ $0.067（1K）/ $0.101（2K）/ $0.151（4K）** | 半額 | なし |
| gemini-3.1-flash-lite-image | $0.25/1M | $30/1M | **約 $0.034（1K）** | 約 $0.017 | なし |
| gemini-2.5-flash-image | $0.30/1M | — | $0.039（1290 tokens） | $0.0195 | なし |

**Gemini アプリの上限** ✅🔶
- 公式ヘルプ ✅ https://support.google.com/gemini/answer/14286560 : Free/Flash-Lite は Nano Banana 2 Lite、Flash/Pro は Nano Banana 2、Nano Banana Pro は Google AI プラン限定。ダウンロード解像度は有料 2K / 無料 1K。「日次クォータあり」だが数値は非公開。
- 二次情報 🔶: Free 約 20 枚/日、AI Plus 50 枚/日、Pro/Ultra 最大 1,000 枚/日、Pro 上限到達で Nano Banana 2 にフォールバック。 https://ai.zenken.co.jp/en/post/gemini-image-guide/ , https://www.aifreeapi.com/en/posts/gemini-image-free-tier-2026

**権利・商用利用** ✅
- Gemini API 追加規約（2026-03-23 更新）: 「Google won't claim ownership over that content」。ただし他ユーザーに同一・類似の出力を生成する権利を留保。**無料枠（AI Studio 含む）は入力/出力が製品改善に使われ人間レビューあり、有料枠は学習に使わない**。 https://ai.google.dev/gemini-api/terms
- Google 利用規約（2026-07-30 発効）: ユーザーは自分のコンテンツの IP を保持。**「生成 AI コンテンツを人間が作ったと誤認させる」行為と「出力で ML モデルを開発する」行為を禁止**。 https://policies.google.com/terms
- Generative AI Prohibited Use Policy（2024-12-17）: なりすまし、IP 侵害、性的コンテンツ、未成年、誤情報を禁止。 https://policies.google.com/terms/generative-ai/use-policy

### 1.3 Anthropic（Claude）

- **画像生成・編集は不可**。公式 FAQ「Can Claude generate or edit images? — No, Claude is an image understanding model only.」✅ https://platform.claude.com/docs/en/build-with-claude/vision
- Vision の仕様 ✅: claude.ai は 1 ターン 20 枚、API は 1 リクエスト 100 枚（200k コンテキストモデル）/ 600 枚（それ以外）。最大 8000×8000px、20 枚超なら各 2000px 以下。JPEG/PNG/GIF/WebP（アニメは先頭フレームのみ）。トークン = ⌈w/28⌉×⌈h/28⌉（1000×1000 で 1,296 tokens。Haiku 4.5 なら 1,000 枚で約 $1.30）。Files API で参照画像を使い回せる。
- 限界 ✅: 座標・位置関係は近似、個数カウントは近似、**AI 生成画像かどうかは判定不可**。→ 「同一キャラか」の判定は「属性チェックリストの照合」として使えば実用的だが最終判断は人間 🔷。
- 活用法 🔷:
  1. スタイルバイブル・キャラ設定・英語プロンプト生成（§3 のテンプレートは Claude で管理・改訂）。
  2. **一貫性 QA**: `Image 1:` にキャラシート、`Image 2..N:` に生成ポーズを並べ、JSON ルーブリック（輪郭線太さ、頭身、目の形、色 HEX、装飾の有無、余計な背景、切れ）で採点させ、閾値以下を自動リジェクト。
  3. **Claude Code**: クロマキー除去・トリム・ベースライン揃え・アトラス化・パレット量子化のスクリプト、SpriteKit/SwiftUI 側のアニメ再生コードまで一気通貫で書かせる。
  4. SVG/コード生成: 単純形状の 2 頭身キャラなら Claude に SVG を書かせて Path で描画する手も有り（線幅・色を完全固定でき、透明・解像度非依存）。ただし「可愛さ」は画像生成モデルに劣る 🔷。

### 1.4 専門ツール

| ツール | 得意 | 料金（確認結果） | 透明背景 | 商用 | 所感 |
|---|---|---|---|---|---|
| **PixelLab** ✅ https://www.pixellab.ai/pixellab-api | ドット絵キャラ生成、**テキスト/スケルトンで歩行・走行・攻撃アニメ**、4/8 方向回転、参照スタイル、インペイント、Aseprite 拡張、Pixelorama、API | API 従量: 画像 $0.007〜0.017、キャラ作成 $0.0105〜0.185、アニメ $0.0123〜0.185、リサイズ/背景除去 $0.0055〜0.018。サブスクは freemium（🔶 数値不定）**未確認** | あり（背景除去エンドポイント） | 規約 **未確認** | ドット絵路線なら最有力。最大 512×512、Character Pro 168×168 |
| **Retro Diffusion** ✅ https://astropulse.itch.io/retrodiffusion | Aseprite 内でローカル生成、パレット制御、Neural Pixelate | 拡張 **$65（Lite $20）買い切り**。アニメ生成は Web 版（クラウド・クレジット、約 $0.01/枚 🔶） | 要後処理 | 出力はユーザー所有 ✅ | **Mac 要件 M1 Pro / 64GB** → MacBook Air 不可。学習データは同意済み素材 |
| **Scenario** ✅ https://www.scenario.com/pricing | 自作画像でカスタムモデル学習（10〜30 枚）、大量に同スタイル生成 | Starter $15（1,500 credits）/ Pro $45（学習可、5,000）/ Max $75 | 要後処理 | 全有料プランで商用可 ✅ | スプライトシート/アニメ機能なし 🔶 |
| **Layer.ai** 🔶 | スタジオ向けスタイル固定、8 ポーズ seed 固定 | Studio $49/月（3 席、500 生成） | 不明 | 不明 | 個人開発には過剰 |
| **Leonardo.ai** 🔶 | 汎用、キャラ参照、トークン制 | Free / Essential $12 / Premium $30 / Ultimate $60 | 背景除去ツールあり 🔶 | 有料で商用 🔶 | 中庸 |
| **Midjourney** ✅（docs をプロキシ経由で確認） https://docs.midjourney.com/hc/en-us/articles/36285124473997-Omni-Reference | 作風の質。Omni Reference `--oref` + `--ow`（1〜1000、既定 100、400 未満推奨）で被写体固定 | Basic $10 / Standard $30 / Pro $60 / Mega $120 🔶。**oref は GPU 2 倍消費** ✅ | なし（後処理） | 有料会員は生成物を所有、年商 $1M 超は Pro/Mega 必須 🔶 | **oref は V7 専用、V8.x 非対応（Edit Model を使う）**、参照は 1 枚のみ ✅。現行既定は V8.2（2026-07-24）🔶。ディズニー/ユニバーサル訴訟係争中 🔶 |
| **Ideogram** 🔶 | 文字描画、Character Reference | API 参照付きで +$0.05〜0.11/枚、サブスクは無制限 | 不明 | 有料で商用 🔶 | 4.0 が 2026-07 に登場 🔶 |
| **Krea** 🔶 | 64+ モデルの統合 UI、Realtime Canvas | Free（100/日）/ Basic $9 / Pro $35 / Max $70 | モデル依存 | Basic 以上で商用 🔶 | 比較検証用 |
| **Recraft** ✅ https://www.recraft.ai/docs/api-reference/pricing.md | **ネイティブ SVG 出力**、Remove background（透明化）、Vectorize | API: V4.1 raster $0.035、V4.1 vector $0.08、V4.1 Pro $0.21、Pro Vector $0.30、**背景除去 $0.01、ベクター化 $0.01**（1,000 units = $1） | あり（Remove background）✅ | **Free 枠の画像は Recraft 所有・商用不可、有料は完全所有** ✅ | フラット 2 頭身キャラのベクター化に相性良。SVG→SwiftUI Path も可能 |
| **Draw Things（ローカル）** ✅ https://apps.apple.com/us/app/draw-things-offline-ai-art/id6444050820 | 無料。SDXL / FLUX.1 / **FLUX.2** / Wan 2.2 / Qwen Image / Z Image / LTX-2.3、**ControlNet フル対応、LoRA オンデバイス学習、ポーズ編集**、macOS 12.4+ | 無料（Draw Things+ $8.99/月でクラウド計算） | seed 固定・ControlNet(OpenPose)・自前 LoRA で最も制御可能 | 出力は自分のもの（モデルライセンスに依存）🔷 | FLUX は 16GB+ 推奨、24GB 快適 🔶。FLUX.2 klein 4B なら Apple Silicon で約 40 秒/枚 🔶。**MacBook Air（16GB 以上想定）なら SDXL/FLUX.2 klein + ControlNet は現実的、FLUX.1 dev は遅い** 🔷。IP-Adapter 対応は **未確認**（wiki 取得不可） |

出典（🔶 分）: https://ludo.ai/compare/best-ai-sprite-generators , https://www.eesel.ai/blog/leonardo-ai-pricing , https://blakecrosley.com/guides/midjourney , https://terms.law/2026/01/15/midjourney-commercial-use-rights-complete-2026-guide/ , https://www.eesel.ai/blog/ideogram-pricing , https://costbench.com/software/ai-image-generators/krea/ , https://www.bitdoze.com/ai-images-mac/ , https://rentamac.io/run-flux-locally/ , https://www.heyuan110.com/posts/ai/2026-02-15-draw-things-ultimate-guide/

### 1.5 動画生成 → フレーム抽出ルート

| サービス | 状況 | 料金 | 透明/単色背景 | ループ | 判定 |
|---|---|---|---|---|---|
| **Veo 3.1**（Gemini API）✅ https://ai.google.dev/gemini-api/docs/veo | `veo-3.1-generate-preview` / `-fast-` / `-lite-`。4/6/8 秒、24fps、720p/1080p/4K（4K は 8 秒のみ）、16:9 / 9:16、**参照画像最大 3 枚**、**最初/最後フレーム指定**、延長（720p のみ）、SynthID、生成物はサーバ 2 日保持 | 秒単価 ✅: Standard $0.40（720p/1080p）/ $0.60（4K）、Fast $0.10 / $0.12 / $0.30、Lite $0.05 / $0.08（音声込み） | 透明なし。プロンプトで単色背景を指示するのみ 🔷 | 最初=最後フレームに同じ画像を指定すれば擬似ループ可 🔷 | 補助（モーション参考）向け |
| **Sora 2 / Sora 2 Pro** ✅ https://developers.openai.com/api/docs/deprecations | **2026-09-24 に API・Videos API ごと停止**（2026-03-24 告知、代替なし）。アプリは 2026-04-26 終了 🔶 | — | — | — | **使用不可** |
| **Kling 3.0（Turbo/Omni）** 🔶 | 2026-06-17 に 3.0 Turbo/Omni。キャラ外見ロック、4K60 | 個人 $6.99〜$64.99/月 🔶（公式ページは JS のため未取得） | なし | 難 | 参考動画用 |
| **Runway** ✅ https://runway.com/pricing | Free 125 credits（1 回）/ Standard $12（625/月）/ Pro $28（2,250）/ Max $76（9,500）（年払い）。Gen-4.5 = 12 credits/5 秒、Aleph 2.0 = 140 credits/5 秒。Gen-4 Turbo API $0.05/秒 🔶 | 上記 | なし（緑背景プロンプト） | 難 | 参考動画用 |
| **Viggle** ✅ https://viggle.ai/pricing | キャラ画像 + モーション動画/テンプレ → 動くキャラ。Free / Pro $7.99（80 credits）/ Live $15.99（200）/ Max $63.99（800）（年払い）。有料は透かしなし | 1 credit ≒ 1 秒 🔶 | **グリーンバック出力あり** 🔶（公式ページでは未記載、**商用条件も未確認**） | 難 | 動画ルートで唯一実用候補（2 頭身キャラは人体モーションと相性悪い可能性 🔷） |
| **Pika** 🔶 | Standard 約 $8/月（700 credits）/ Pro $28 / Fancy $76 | — | なし | 難 | — |
| **Hailuo (MiniMax) 2.3** 🔶 | $7.99〜$199.99/月、リセラー API $0.01〜0.08/秒 | — | なし | 難 | — |

**動画ルートの本質的な問題** 🔷: (1) 生成モデルはシームレスループを作らない（歩行の位相が合わない）。(2) 24fps → 4〜8 コマに間引くと足の接地が揃わない。(3) フレーム毎の背景除去でアルファ縁がチラつく。(4) 2 頭身キャラは実写系モーションモデルで崩れやすい。→ **CharaTime の「歩く/立つ/座る/寝る/喜ぶ」程度なら静止画グリッド生成の方が安い・速い・綺麗**。動画は「歩行のキーポーズを観察して静止画プロンプトを書く」参考用に留める。

### 1.6 比較表（キャラスプライト用途）

| | 一貫性（参照画像） | 透明背景 | 料金/枚（目安） | 商用可否 | スプライト適性 | 総合 |
|---|---|---|---|---|---|---|
| ChatGPT Images 2.5 / gpt-image-2.5 | ◎ edits で複数参照、多段編集に強い ✅ | **◎ ネイティブ** ✅ | 🔷 $0.01〜0.12（トークン制）、サブスク内なら追加費用なし | ◎ ユーザー所有 ✅ | ◎ | **本命** |
| Nano Banana 2 / Pro | ◎ キャラ 4〜5 人分の参照 ✅ | ✕（要クロマキー）✅ | $0.034〜0.134 ✅ | ◎ ノークレーム ✅ | ○ | **第二候補・API コスト最安** |
| Claude | 判定のみ | — | Vision $1.3/1000 枚（Haiku 4.5）✅ | — | QA/スクリプト | 補助 |
| PixelLab | ○（参照スタイル） | ◎ | $0.01〜0.19 ✅ | 未確認 | ◎（ドット絵） | ドット絵なら本命 |
| Midjourney | ○ oref（V7 限定、1 枚） | ✕ | サブスク $10〜 | ◎ 有料会員 | △ | 画風探索用 |
| Recraft | ○ | ◎ SVG/背景除去 | $0.035〜0.30 ✅ | 有料のみ ◎ | ○（ベクター） | フラット路線の選択肢 |
| Draw Things（ローカル） | ◎ seed/ControlNet/LoRA | △（後処理） | 電気代のみ | モデル依存 | ◎（手間大） | 上級者向け |
| Veo 3.1 / Viggle 等 | △ | Viggle のみ緑 | $0.05〜0.60/秒 | 要確認 | △ | 補助 |

---

## 2. 一貫性テクニック（実践者・公式ガイドから）

1. **キャラシートを最初に作る（三面図 + 表情 + 色指定）** 🔶 — 正面・側面・背面を 1 枚に描かせ、以降の全生成の参照にする。三面図があると服装や髪型を変えても同一キャラとして認識されやすい。 https://note.com/3syaku/n/nf3140715927d , https://a-i-manga.com/articles/ai-manga-character-sheet , https://x.com/toto2AI/status/2041395368462815543
2. **毎回、元画像を添付する** ✅（実測記事）— Nano Banana で参照画像を省略すると精度が「劇的に下がる」。会話の履歴に頼らず、都度キャラシートを添付。 https://note.com/m_tani_/n/n6a4e92927388
3. **3 層テンプレート（キャラ層 × シーン層 × 出力層）** 🔶 — 固定情報（髪・目・服・線・色）と可変情報（ポーズ・状況）と出力仕様（背景・比率・スタイル）を分離して書く。「顔が変わる→キャラ層を具体化」「服が変わる→毎回服を書く」「複数キャラ混同→キャラ 1/2 で区分」。 https://shikujiriblogger.com/chatgpt-ai-image-3layer-template/
4. **GPT-Image-2 系は「タグ羅列」より自然言語** 🔶 — `masterpiece, 4k` のようなタグは逆効果。ゴール指向の短い文章が高品質。実名参照は規制で失敗するので物理特徴で言語化。複数シーンで顔がずれる場合は API の `n=4` で独立生成して選ぶ。 https://zenn.dev/totsu_ai_lab/articles/gpt-image-2-character-sheet
5. **1 枚のグリッドに複数ポーズを描かせて分割** 🔶 — 別々に生成するより同一画像内の方が一貫性が高い（記事では 95% vs 85% と主張）。 https://sorceress.games/blog/how-to-make-a-sprite-sheet-in-2-minutes-with-ai-in-2026 , https://www.seeles.ai/resources/blogs/how-to-animate-sprite-sheets-ai-game-development 。ただし各コマのサイズ・位置が微妙にズレるので、後段で「トリム → ベースライン揃え → 固定キャンバスに再配置」が必須 🔷。
6. **モデル固有の参照機能を使う** ✅ — Gemini 3.1 Flash Image はキャラ参照 4 枚 + スタイル参照 3 枚、Pro はキャラ参照 5 枚。Midjourney は `--oref`（V7 のみ、1 枚）。OpenAI は edits に複数画像。
7. **同一 seed**: ローカル（Draw Things/ComfyUI）では seed 固定 + ControlNet(OpenPose) + IP-Adapter/LoRA が最も再現性が高い 🔶。**OpenAI gpt-image API・Gemini 画像モデルに seed 指定があるかは未確認**（docs に記載なし）。
8. **参照画像編集（"same character, now sitting"）** — Images 2.5 は「複数回の編集をまたいだ一貫性」を明記 ✅。Gemini も編集モードで背景だけ差し替える等が得意 🔶（白→黒背景差し替えで被写体がピクセル一致するほど）。
9. **色パレット固定**: HEX を明示（例 `body #FFF4E6, outline #3B2B2B, cheeks #FFB3C6`）し、生成後にパレット量子化で強制的に揃える 🔷。
10. **線画→着色の分離**: 線画（黒線・白背景）を先に確定し、着色は編集で行う。色ブレは減るが 2 回生成するので手間は増える 🔷。ドット絵なら PixelLab/Retro Diffusion のパレット制御が本筋。
11. **失敗パターン**（複数記事で共通）🔶: 「transparent」と書く → チェッカーボードを描く／長い会話でスタイルが漂流／有名キャラ名・作家名で拒否または類似 IP 化／タグ羅列で画質低下／複数キャラ同席で属性混線／グリッド指定でコマ数を守らない（「exactly 4 panels」「2 rows × 3 columns」と数を明示し、Claude で枚数検査）。

---

## 3. プロンプト設計とテンプレート集

### 3.1 スプライト向け設計原則 🔷（§2 の知見 + 公式パラメータから）
- **背景**: OpenAI は `background: "transparent"`（ChatGPT UI なら「transparent background, PNG」と書く）。Gemini/その他は **単色クロマキー**を指定: `solid flat chroma-key green background, EXACTLY #00FF00, no gradients, no shadows, no vignette` 。緑がキャラ色と被る場合はマゼンタ `#FF00FF`。**「transparent」という単語は Gemini では禁句**。
- **向き**: `front-facing` / `3/4 view facing left` / `side view walking left`。iOS 側で左右反転すれば片方向で足りる。
- **等身**: `two heads tall (head:body = 1:1)`、`head about 50% of total height`。
- **輪郭線**: `thick, uniform, dark brown outline (#3B2B2B), consistent line weight, closed shapes`。
- **色数**: `flat colors, no gradients, no texture, max 6 colors + outline`。
- **解像度/余白**: 1024×1024 で生成し、`character centered, occupies ~70% of canvas height, feet on a common baseline, 10% margin, nothing cropped`。表示は 128〜256pt 相当なので縮小前提。
- **影**: `no drop shadow, no ground shadow`（影は iOS 側で別レイヤに描く方が動きに追従する）。
- **ドット絵指定**: `pixel art, 64x64 grid, 1:1 pixel aspect, no anti-aliasing, limited 16-color palette` → 後処理で `nearest-neighbor` 縮小 + パレット量子化。画像モデルは「ドット絵風」を描くだけで整数ピクセルにはならないので後処理必須 🔶（romptn 記事、PixelLab/Retro Diffusion の説明）。
- **IP 回避の作風言語化**（サンリオ/2008 年ガラケー待受風を固有名詞なしで）: `original mascot character, 2000s Japanese feature-phone screensaver mascot style, kawaii, round simplified shapes, minimal face (two dot eyes, tiny mouth, no nose), rosy cheeks, pastel palette, thick clean outline, flat cel shading, sticker-like` 。**禁止語**: Sanrio, Hello Kitty, My Melody, Kuromi, Cinnamoroll, Pompompurin, Gudetama, Pokémon, Sumikko Gurashi, Rilakkuma, 特定作家名。既存キャラの識別要素（口のない白猫 + 赤リボン、垂れ耳の白い犬 + 青い目、など）を組み合わせない。

### 3.2 固定スタイルブロック（全プロンプトの先頭に貼る）

```
[STYLE LOCK — CharaTime]
Original mascot character for a phone home-screen app. NOT based on any existing brand or character.
Proportions: two heads tall (head:body = 1:1), big round head, tiny rounded limbs, no visible fingers.
Face: two small dot eyes, tiny "w"/"ω"-shaped mouth, no nose, soft rosy cheeks.
Line: thick, uniform dark-brown outline (#3B2B2B), closed shapes, consistent line weight.
Color: flat cel shading, pastel palette, no gradients, no textures, max 6 colors plus outline.
Rendering: clean vector-like 2D illustration, sticker-like, no drop shadow, no ground shadow, no text, no watermark.
Camera: orthographic, eye level, character centered, feet on a common baseline, 10% margin, nothing cropped.
```

### 3.3 キャラシート（三面図 + 表情）生成 — ChatGPT Images 2.5 (Sunburst) / Nano Banana Pro

```
[STYLE LOCK — CharaTime]
Create a CHARACTER REFERENCE SHEET for one new character.
Character: "Mochi" — a round cream-colored bun-like creature (#FFF4E6 body), small pink cheeks (#FFB3C6),
a single green leaf sprout on top (#8ED081), and a tiny red scarf (#E85D5D). Friendly, sleepy personality.
Layout: one row of three full-body views on a common baseline, left to right: FRONT, SIDE (facing left), BACK.
Below: a row of four head-only expressions: neutral, happy (closed smiling eyes), sleepy (half-closed eyes), surprised.
Same size and scale for all views. Plain pure white background (#FFFFFF). No labels, no text, no arrows.
```
(OpenAI API なら `background: "transparent"` で白背景指定を外す。Gemini なら最後の行を `Solid flat chroma-key green background, EXACTLY #00FF00...` に置換。)

### 3.4 ポーズ・セット（グリッド）— 参照画像を必ず添付

```
[STYLE LOCK — CharaTime]
Reference: the attached image is the official reference sheet of "Mochi". Keep EVERY design detail identical
(body color #FFF4E6, leaf sprout, red scarf, dot eyes, outline #3B2B2B, two-heads-tall proportions).
Draw exactly 6 full-body poses of the SAME character in a 3-column x 2-row grid, each cell the same size,
character centered in each cell, feet on the cell's baseline, all at the same scale:
1) standing idle, front view   2) standing idle, 3/4 view facing left   3) sitting on the floor, 3/4 view
4) lying down asleep on its side, "zzz" NOT drawn   5) happy jump with arms up, front view   6) waving, front view
Solid flat chroma-key green background, EXACTLY #00FF00, no gradients, no shadows. No text, no labels, no borders between cells.
```

### 3.5 歩行サイクル 4 コマ（横向き）

```
[STYLE LOCK — CharaTime]
Reference: attached reference sheet of "Mochi". Keep the design identical.
Create a 4-frame WALK CYCLE sprite strip, side view facing LEFT, in a single row of 4 equal cells, same scale:
frame 1 CONTACT (front foot forward, back foot back), frame 2 DOWN/PASSING (legs together, body slightly lower),
frame 3 CONTACT (opposite legs), frame 4 UP/PASSING (legs together, body slightly higher).
Subtle arm swing opposite to legs. Head and body shape must not change between frames.
Feet on a common baseline. Solid flat chroma-key green background, EXACTLY #00FF00. No text.
```
歩行 4〜8 コマ・contact/down/passing/up の 4 キーポーズ・8 コマなら 10fps という定石 🔶 https://www.spritesheets.ai/blog/how-to-create-a-walk-cycle-spritesheet 。2 頭身では 4 コマ（12fps・約 0.33 秒/周）で十分 🔷。

### 3.6 単体ポーズの追加・修正（編集モード）

```
Using the attached reference sheet of "Mochi": same character, now SITTING on the floor hugging its knees, 3/4 view facing left.
Change nothing about the design. Solid #00FF00 background (or transparent PNG). Single character, centered, feet/bottom on baseline.
```
修正指示例:
- `Keep everything, but make the outline thicker and perfectly uniform; remove the gradient on the cheeks.`
- `The scarf is missing in frame 3. Redraw frame 3 only with the red scarf, keep other frames untouched.`
- `The head became smaller than in the reference. Match the head:body ratio of the reference exactly (1:1).`
- `Background has a soft shadow under the feet — remove it, background must be flat #00FF00 everywhere.`

### 3.7 ドット絵バリアント（PixelLab を使わない場合）

```
[STYLE LOCK — CharaTime] rendered as PIXEL ART:
64x64 pixel canvas look, crisp 1:1 square pixels, no anti-aliasing, no blur, 12-color palette,
1-pixel dark outline, flat colors, chibi mascot "Mochi" (see attached reference), front view idle pose,
centered, solid #00FF00 background.
```
→ 生成後に `nearest-neighbor` で 64px へ縮小し、指定パレットへ量子化（§4）。

### 3.8 Claude 用 QA プロンプト（一貫性チェック）

```
You are a strict art director. Image 1 is the official reference sheet of the character "Mochi".
Images 2..N are candidate sprites. For EACH candidate return JSON:
{"image": n, "same_character": true|false, "score_0_100": int,
 "checks": {"head_body_ratio_1to1": pass|fail, "outline_uniform_dark_brown": pass|fail, "body_color_FFF4E6": pass|fail,
            "leaf_sprout_present": pass|fail, "red_scarf_present": pass|fail, "dot_eyes_no_nose": pass|fail,
            "flat_shading_no_gradient": pass|fail, "background_flat_green_or_transparent": pass|fail,
            "nothing_cropped": pass|fail, "no_text_or_watermark": pass|fail},
 "problems": ["..."], "fix_prompt": "one-sentence edit instruction"}
Be literal; do not give credit for 'close enough'. Threshold for acceptance is score >= 85 with all checks pass.
```

### 3.9 NG 例
- `Sanrio style cute cat like Hello Kitty with red bow` → IP 直撃。
- `masterpiece, best quality, 8k, ultra detailed, trending on artstation` → GPT-Image 系では逆効果 🔶、かつスプライト用途と矛盾（詳細不要）。
- `transparent background` を Gemini に指示 → チェッカーボード模様の不透明画像 🔶。
- `cute character walking`（数・向き・コマ数・背景の指定なし）→ 毎回違う結果。
- 参照画像なしで「さっきのキャラで」→ 会話が長いほど漂流。

---

## 4. 後処理

### 4.1 透明化
| 手段 | 適する場面 | 手順・コマンド | 出典 |
|---|---|---|---|
| **OpenAI ネイティブ透明** | 第一選択 | `background:"transparent", output_format:"png"` | ✅ image-generation guide |
| **macOS プレビュー「背景を削除」** | 少数枚を手早く | プレビューで画像を開く → 「背景を削除」→ PNG に変換して保存。Finder のクイックアクション「背景を削除」でも複数ファイル一括可（被写体が明確な画像向け） | ✅ https://support.apple.com/guide/preview/remove-a-background-or-extract-an-image-prvw15636/mac , 🔶 https://osxdaily.com/2023/01/19/how-to-remove-the-background-from-images-on-mac-with-a-quick-action/ |
| **クロマキー（HSV 判定）** | Gemini 等の #00FF00 背景 | 下記 Python。緑を HSV で判定（H≈120°, S>75%, V>70%）しアルファ 0 に。縁の緑かぶりは color decontamination で処理 | ✅ 手法 https://www.philschmid.de/generate-stickers |
| **白黒 2 枚差分マッティング** | 半透明の縁を綺麗に | 白背景で生成 → 編集で「背景だけ純黒に、被写体は完全に同じ」→ `alpha = 1 - (I_white - I_black)`、`color = I_black / alpha` | 🔶 https://transparify.app/blog/gemini-transparent-background （Julien De Luca 氏の手法） |
| **rembg** | 一括・自動化 | `pip install "rembg[cpu,cli]"`（Python 3.11〜3.13）。`rembg i -m isnet-anime in.png out.png`、フォルダ一括 `rembg p -m isnet-anime in/ out/`、縁補正 `-a`（alpha matting）/ `-dc`（色かぶり除去）。既定モデル **bria-rmbg は商用ライセンス要確認**、MIT なのは rembg 本体のみ | ✅ https://github.com/danielgatis/rembg/blob/main/README.md |
| **Recraft Remove background** | Recraft 生成物 | Studio のコンテキストパネル → Remove background（1024px 以上は自動縮小で劣化注意）。API $0.01 | ✅ Recraft docs |
| **PixelLab 背景除去 API** | ドット絵 | $0.0055〜0.018 | ✅ |

**クロマキー除去（Python / Pillow + NumPy）** 🔷（philschmid 手法を元に筆者実装）
```python
from PIL import Image
import numpy as np, colorsys, sys

def key_green(src, dst, h_center=120, h_tol=25, s_min=0.6, v_min=0.5):
    im = Image.open(src).convert("RGBA"); a = np.asarray(im).astype(np.float32) / 255.0
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx, mn = a[..., :3].max(-1), a[..., :3].min(-1); v = mx; s = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    h = np.zeros_like(mx); d = np.maximum(mx - mn, 1e-6)
    h = np.where(mx == g, 60 * (((b - r) / d) + 2), np.where(mx == r, 60 * (((g - b) / d) % 6), 60 * (((r - g) / d) + 4)))
    green = (np.abs(h - h_center) < h_tol) & (s > s_min) & (v > v_min)
    a[..., 3] = np.where(green, 0.0, a[..., 3])
    # 縁の緑かぶりを弱める（G が R,B より突出している画素の G を抑える）
    spill = (~green) & (g > np.maximum(r, b) * 1.15)
    a[..., 1] = np.where(spill, np.maximum(r, b), g)
    Image.fromarray((a * 255).astype(np.uint8), "RGBA").save(dst)

key_green(sys.argv[1], sys.argv[2])
```

**白黒差分マッティング（概念コード）** 🔷
```python
W = np.asarray(Image.open("on_white.png").convert("RGB")).astype(np.float32)/255
B = np.asarray(Image.open("on_black.png").convert("RGB")).astype(np.float32)/255
alpha = np.clip(1 - (W - B).mean(-1), 0, 1)               # 完全不透明なら W==B → alpha 1
color = np.where(alpha[...,None] > 1e-3, B / np.maximum(alpha[...,None], 1e-3), 0)
rgba = np.dstack([np.clip(color,0,1), alpha]); Image.fromarray((rgba*255).astype(np.uint8), "RGBA").save("out.png")
```
（生成が 2 回必要 + 被写体がピクセル一致している前提。Gemini の編集モードは背景差し替え時に被写体を保ちやすい 🔶）

### 4.2 トリム・正規化・アトラス化（ImageMagick）🔶（コマンドは筆者の経験に基づく。公式: https://imagemagick.org/ ）
```bash
brew install imagemagick
# 緑を透明化（fuzz は 6〜12% で調整）→ 余白トリム → 512x512 の透明キャンバス中央下（足元）に配置
magick in.png -fuzz 8% -transparent '#00FF00' -trim +repage \
  -background none -gravity south -extent 512x512 out.png
# グリッド画像（3x2）を 6 コマに分割
magick grid.png -crop 3x2@ +repage +adjoin cell_%02d.png
# 4 コマ横一列のスプライトシートに結合
magick montage walk_0*.png -tile 4x1 -geometry 256x256+0+0 -background none walk_strip.png
# ドット絵化: 64px へ最近傍縮小 → 16 色に量子化（ディザなし）→ 4 倍拡大
magick in.png -filter point -resize 64x64 -dither None -colors 16 -filter point -resize 400% pixel.png
# 指定パレット PNG に合わせて減色
magick in.png -dither None -remap palette.png out.png
```
- **足元ベースライン揃え**: 各コマの不透明ピクセルの最下端を検出し、同じ y に揃えてから固定キャンバスに配置（Pillow で `getbbox()`）。グリッド生成物は必ずこれを通す 🔷。
- **ffmpeg でフレーム抽出**（動画ルート）: `ffmpeg -i clip.mp4 -vf "fps=8" f_%03d.png`。

### 4.3 ツール
- **Aseprite** $19.99（Steam/itch）🔶、スプライトシートの入出力・GIF・CLI 自動化 ✅ https://store.steampowered.com/app/431730/Aseprite/ 。ソースから自前ビルドも可（ライセンス条件は要確認）🔶。
- **TexturePacker Pro** $49.99 買い切り（1 年アップデート付き、年商 $10 万未満のインディー割引あり）✅ https://www.codeandweb.com/store/texturepacker-single 。SpriteKit/Unity 等 40+ 形式。ただし iOS なら **Xcode の Sprite Atlas（.spriteatlas フォルダ）で無料に自動アトラス化**できる 🔷。
- **Pixelmator Pro**: Apple 傘下。2026-01-28 発表の Apple Creator Studio（$12.99/月）に同梱、iPad 版も登場 🔶 https://www.macrumors.com/2026/01/13/pixelmator-no-longer-being-updated/ 。単体価格は **未確認**（$49.99 との情報と「無料」との情報が混在 🔶）。
- **Photoshop**: 「被写体を選択」「コンテンツに応じた塗り」は強力だが月額課金。Air の RAM 事情も含め Pixelmator/プレビューで足りる 🔷。
- **rembg / ImageMagick / Pillow**: 自動化の中核（Claude Code で書く）。

---

## 5. 法務

### 5.1 各サービスの生成物の権利・商用条件（要点）
| サービス | 権利 | 商用 | 注意 |
|---|---|---|---|
| OpenAI ✅ | Output はユーザー所有（OpenAI が権利を譲渡） | 可 | 類似出力の非排他性、人間作と偽らない、IP 侵害・実在人物の無断肖像禁止 |
| Google Gemini ✅ | Google はノークレーム、ユーザーが IP 保持 | 可（EEA/UK/CH 向け提供は有料 API のみ） | 無料枠は学習・人間レビュー対象、人間作と偽らない、出力で ML 開発禁止、SynthID 必ず付与 |
| Midjourney 🔶 | 有料会員は生成物を所有（年商 $1M 超は Pro/Mega） | 可 | 無料トライアルは不可、係争中の訴訟 |
| Recraft ✅ | 有料プランは完全所有、**Free は Recraft 所有・商用不可** | 有料のみ | — |
| Scenario ✅ | 全有料プランで商用ライセンス | 可 | — |
| Retro Diffusion ✅ | ユーザー所有 | 可 | モデル/コードは Astropulse 所有 |
| PixelLab | **未確認**（ToS 要確認） | 未確認 | — |
| Viggle | **未確認** | 未確認 | — |
| Apple Image Playground | **未確認**（Apple Developer 規約） | 未確認 | ImageCreator は iOS 27 で deprecated ✅ |

### 5.2 日本法（文化庁の考え方）✅
- **「AI と著作権に関する考え方について」（2024-03-15、法制度小委員会）** https://www.bunka.go.jp/seisaku/bunkashingikai/chosakuken/pdf/94037901_01.pdf 、概要 https://www.bunka.go.jp/seisaku/bunkashingikai/chosakuken/pdf/94057901_01.pdf
  - 「開発・学習段階」（30 条の 4）と「生成・利用段階」を分けて考える。
  - **生成・利用段階の侵害判断は通常の著作物と同じ「類似性（創作的表現の共通）+ 依拠性」**。依拠性は、既存著作物が学習データに含まれていれば利用者が知らなくても通常推認される。「〜風」という作風・アイデアの共通は類似性にならないが、特定キャラの創作的表現が直接感得できれば侵害。
  - **AI 生成物の著作物性**: ボタンを押すだけ・簡単な指示のみなら著作物でない。人が「創作意図」を持ち「創作的寄与」（創作的表現を具体的に示す詳細な指示、生成物を確認して指示を修正する試行、加筆修正）を積み重ねれば著作物となり得る。試行回数の多さや単なる選択は寄与にならない。→ **CharaTime のキャラは「詳細なキャラ設計 → 生成 → 修正指示の反復 → 手動の後処理・修正」の記録（プロンプト履歴・修正ログ）を保存しておくと、著作物性の主張材料になる** 🔷。
- **2025-09-11 文化審議会 WT 資料「生成 AI をめぐる最新の状況」** https://www.bunka.go.jp/seisaku/bunkashingikai/chosakuken/workingteam/r07_01/pdf/94269701_04.pdf ✅: 各国動向（EU AI Act 生成 AI 規定 2025-08 施行、米国 AI Action Plan、英 Data Act）、法律相談窓口の「AI と著作権」相談は令和 6 年度 89 件（i2i で類似画像を作られた、LoRA を作られた等）、「AI と著作権に関する関係者ネットワーク」（2025-05-30 時点でアドビ・Google・Sakana AI・漫画家協会など参加）。対価還元（学習データの有償提供）のモデル事業に令和 8 年度 3 億円要求 🔶 https://corp.aicu.ai/ja/report-20250912
- **2026-04-01 改正著作権法（令和 5 年法 33 号）全面施行**: 未管理公表著作物の新裁定制度、損害賠償算定の見直し。**生成 AI 固有の条文改正は含まれない**（学習 = 30 条の 4、生成 = 類似性・依拠性の枠組みは不変）🔶 https://www.manegy.com/news/detail/15990/ 。パテント誌 2026 の論点整理でも「考え方」の課題が議論継続中 🔶 https://jpaa-patent.info/patent/viewPdf/4773
- **既存 IP に似せるリスク**（弁護士解説 ✅ https://takase-law.tokyo/column/character_ai/ ）: 人気キャラに酷似すれば翻案権侵害、不正競争防止法（周知表示の混同）、パブリシティ権も問題化。社内利用でも流出リスク。対策 = 特定キャラに誘導する表現をプロンプトから排除、商用可のモデルを使う、法務確認。
- **日本の 30 条の 4 は「利用者側の生成」を免責しない**点に注意（学習は広く可、生成・公表は通常の侵害判断）。

### 5.3 米国動向 🔶（App Store 配信・海外ユーザー向け）
- 米著作権局 AI 報告 Part 2（2025-01-29）: プロンプトだけでは著作者性に足りない。Part 3（学習、2025-05-09 事前公開）。 https://www.copyright.gov/ai/
- **Thaler v. Perlmutter**: 2026-03-02 最高裁が上告不受理 → 「人間の著作者」要件が確定。 https://www.mayerbrown.com/en/insights/publications/2026/03/supreme-court-denies-review-in-ai-authorship-case
- Disney / Universal（+ Warner Bros.）v. Midjourney（2025-06 提訴）: 係争中、ディスカバリ段階。 https://www.law.georgetown.edu/tech-institute/research-insights/insights/disney-nbc-universal-and-dreamworks-file-major-ip-lawsuit-against-ai-image-generator-midjourney/

### 5.4 App Store / UGC 🔶
- ガイドライン 1.2（User-Generated Content）: 不適切コンテンツのフィルタ、**通報**、**ブロック**、連絡先の掲示が必須。1.2.1 で年齢制限機構。違反時はアプリ削除もあり得る。 https://developer.apple.com/app-store/review/guidelines/ , https://acceptmy.app/guidelines/1-2-user-generated-content
- 5.2（知的財産）: 他者 IP を使わない。ユーザー生成キャラが既存 IP に似ていた場合の削除フロー を用意 🔷。

---

## 6. 推奨パイプライン

### 6.1 今すぐ開発者が手作業でやる版（サブスク内、追加費用ほぼゼロ）

| # | ステップ | ツール | 成果物 | 目安時間 |
|---|---|---|---|---|
| 0 | **スタイルバイブル**: §3.2 の STYLE LOCK と 3〜5 体のキャラ設定（名前/色 HEX/特徴/性格）を Claude と作る。禁止語リストも。 | Claude | `docs/art/style_bible.md` | 1h |
| 1 | **キャラシート**: §3.3 で三面図 + 表情。Sunburst で 3〜4 回生成 → 最良を採用。白背景（OpenAI なら透明） | ChatGPT Images 2.5（Sunburst）/ 予備: Nano Banana Pro | `ref/<name>_sheet.png` | 30〜45 分/体 |
| 2 | **ポーズ 6 種グリッド**: §3.4。参照シートを毎回添付。NG コマだけ §3.6 で個別再生成 | 同上 | `raw/<name>_poses.png` | 30 分/体 |
| 3 | **歩行 4 コマ**: §3.5。横向き左。右向きは iOS 側で反転 | 同上 | `raw/<name>_walk.png` | 30 分/体 |
| 4 | **QA**: §3.8 のルーブリックで Claude に採点、85 点未満は再生成 | Claude（claude.ai に 20 枚まで添付） | 採点 JSON | 10 分/体 |
| 5 | **透明化・正規化**: OpenAI 透明 PNG はそのまま、Gemini はクロマキー除去 → トリム → 足元揃え → 512×512 → @2x/@3x 用に 256/128 生成。必要ならドット絵化 | Claude Code で Python/ImageMagick スクリプト（初回 2h、以後自動） | `sprites/<name>/<pose>.png` | 初回 2h |
| 6 | **アトラス化**: Xcode Sprite Atlas または TexturePacker。命名 `mochi_walk_00..03`, `mochi_idle`, `mochi_sit`, `mochi_sleep`, `mochi_happy` | Xcode / TexturePacker | `.spriteatlas` | 30 分 |
| 7 | **実機確認**: iPhone 17 Pro で 12fps 歩行、縮小時の線の潰れ・縁のフリンジを確認 → 線を太くする等で再生成 | Xcode | — | 30 分 |

- **合計**: 1 体目 4〜5 時間、2 体目以降 1.5〜2 時間/体。5 体で **10〜15 時間**。
- **コスト**: ChatGPT Plus 内なら追加 0 円（Plus の枠 🔶 約 50 枚/3h に収まる）。API 換算なら 5 体 × 約 25 枚 ≒ 125 枚 → gpt-image-2.5 medium 目安 $4〜6、Nano Banana 2 なら $8〜13、Pro なら $17 🔷。
- **ドット絵路線に振る場合**: ステップ 1〜3 を PixelLab（キャラ作成 → Animate with text「walk」→ 8 方向回転）に置換。API なら 1 体 $1 未満 ✅。iOS 側は nearest-neighbor 拡大（`filteringMode = .nearest`）。
- **ローカル路線**: Draw Things + SDXL/FLUX.2 klein + ControlNet(OpenPose) で seed 固定。Air の RAM が 16GB なら SDXL 中心 🔶。自前 LoRA をキャラシートから学習すると一貫性は最強だが工数大 🔷。

### 6.2 将来の UGC（ユーザー生成キャラ）API 自動化版 🔷

**モデル選定**
| 候補 | 理由 | 概算コスト/体（キャラシート 1 + ポーズ 6 + 歩行 4 + リトライ 30% ≒ 15 枚） |
|---|---|---|
| **A. OpenAI `gpt-image-2.5-flare`（第一候補）** | 透明 PNG をネイティブ出力、edits で参照画像、`moderation` パラメータ、多段編集の一貫性 ✅ | 🔷 medium 想定 $0.03 × 15 ≒ **$0.45**（high なら ≒ $1.8） |
| **B. Gemini `gemini-3.1-flash-image`（コスト/速度重視）** | $0.067/1K ✅、キャラ参照 4 枚 + スタイル参照 3 枚、Batch で半額 | $1.0（Batch $0.5）+ クロマキー処理（自前、無料） |
| **C. Gemini `gemini-3.1-flash-lite-image`（最安）** | 約 $0.034/枚 ✅、1K のみ | ≒ $0.5 |
| **D. Apple Image Playground（オンデバイス・無料）** | `ImagePlaygroundViewController` / `imagePlaygroundSheet`（**`ImageCreator` は iOS 27.0 で deprecated** ✅ https://developer.apple.com/documentation/imageplayground/imagecreator ）。スタイルは animation / illustration / sketch / emoji / any / externalProvider（ChatGPT）✅ | $0。ただし参照画像からのポーズ一貫生成や透明出力の保証がなく、スプライト用途には不向き。「アバター 1 枚」用途の無料枠として検討 |

**設計**
1. iOS → 自社バックエンド（Cloud Run/Lambda 等）。**API キーはアプリに埋め込まない**。
2. 入力サニタイズ: ユーザーの自由文は「色・生き物の種類・持ち物・性格」程度の構造化フォームに限定し、STYLE LOCK と結合。禁止語（既存キャラ名・作家名・実在人物）をブロック。
3. 生成ジョブ: (a) キャラシート 1 枚 → (b) Claude Vision で IP 類似・NSFW・破綻チェック → (c) 参照付きでポーズグリッド + 歩行ストリップ → (d) 後処理（クロマキー/トリム/ベースライン/リサイズ/アトラス JSON）→ (e) CDN 配信 → アプリがダウンロード。
4. モデレーション: プロバイダ側（OpenAI `moderation: auto`、Google safety）+ 事後の Claude Vision 判定 + **ユーザー通報・ブロック・運営削除（App Store 1.2）** + 生成物の C2PA/SynthID メタデータ保持と「AI 生成」表示（Google/OpenAI 規約の「人間作と偽らない」遵守）。
5. コスト制御: 1 ユーザーあたり日次上限、キャッシュ、Batch API（Gemini 50% off）で夜間一括生成、失敗時のリトライ上限。
6. 権利: 利用規約で「ユーザー入力に基づく AI 生成物、既存 IP に類似する場合は削除、当社は利用ライセンスを得る」を明記。日本法上ユーザーの著作物にならない可能性が高い（プロンプト数語のため）ことを前提に、排他性を約束しない 🔷。

---

## 7. 未確認事項

1. `gpt-image-2.5-*` の 1 枚あたり確定料金（トークン数表が未公開）。§1.1 の数値は gpt-image-1 世代の推定。
2. ChatGPT 各プラン（Plus/Pro/Go）の画像生成上限の公式値（ヘルプに数値なし）。
3. Gemini アプリの日次上限の公式値、および 2026-09 時点で可視透かしが Pro プランに付くか。
4. `gemini-3.1-flash-lite-image`（Nano Banana 2 Lite）の公開日。
5. OpenAI gpt-image API / Gemini 画像モデルの `seed` 対応の有無。
6. gpt-image-1 の停止日（二次情報 2026-10-23、Deprecations ページで未確認）。
7. PixelLab のサブスク料金・利用規約（商用/権利）。Viggle の商用条件とグリーンバック出力の公式仕様。Kling の公式価格（JS ページで未取得）。
8. Draw Things の IP-Adapter 対応範囲（FLUX 系）と MacBook Air の実 RAM での FLUX.2 速度（開発者の Air の RAM 容量に依存）。
9. Pixelmator Pro の単体価格（Creator Studio 外）と Aseprite の Apple Silicon ネイティブ対応。
10. Midjourney の現行 ToS 原文（docs.midjourney.com が 403。terms.law 経由の要約のみ）。
11. Apple Image Playground 生成物の商用利用条件。
12. 文化庁の「考え方」以後、2026 年中に生成 AI 固有の法改正・ガイドライン改訂が出たか（検索では未検出。改正法 2026-04 施行分は AI 固有ではない）。

---

## 8. 出典一覧（確認日: すべて 2026-09-10）

### OpenAI ✅
- Deprecations: https://developers.openai.com/api/docs/deprecations
- Image generation guide（background/transparent, n, quality, size, moderation）: https://developers.openai.com/api/docs/guides/image-generation
- Pricing: https://developers.openai.com/api/docs/pricing
- Model: gpt-image-2.5-flare: https://developers.openai.com/api/docs/models/gpt-image-2.5-flare
- Model: gpt-image-2.5-sunburst: https://developers.openai.com/api/docs/models/gpt-image-2.5-sunburst
- Introducing ChatGPT Images 2.5（プロキシ経由）: https://openai.com/index/introducing-chatgpt-images-2-5/
- ChatGPT Images 2.5 System Card: https://deploymentsafety.openai.com/chatgpt-images-2-5
- Developer Community announcement: https://community.openai.com/t/introducing-gpt-images-2-5-in-the-api-and-chatgpt/1395897
- Terms of Use（プロキシ経由）: https://openai.com/policies/row-terms-of-use/
- Usage Policies（プロキシ経由、2025-10-29）: https://openai.com/policies/usage-policies/
- Help: image generation rate limits: https://help.openai.com/en/articles/6696591-what-are-the-rate-limits-for-image-generation
- 🔶 Wikipedia GPT Image: https://en.wikipedia.org/wiki/GPT_Image ／ 🔶 Images 2.0 解説: https://www.mindstudio.ai/blog/what-is-gpt-image-2 ／ 🔶 gpt-image-2 料金: https://unifically.com/blogs/gpt-image-2 ／ 🔶 プラン上限: https://chatgptlimit.com/chatgpt-image-generation-limit/ , https://www.cometapi.com/how-many-images-can-i-generate-with-chatgpt-plus-%E2%80%94-a-2026-status-report/ ／ 🔶 規約解説: https://terms.law/2024/07/17/who-owns-chatgpt-answers-and-how-can-they-be-used-a-legal-analysis/

### Google ✅
- Image generation docs（モデル ID・参照枚数・SynthID）: https://ai.google.dev/gemini-api/docs/image-generation
- Pricing（画像・Veo）: https://ai.google.dev/gemini-api/docs/pricing
- Veo 3.1 docs: https://ai.google.dev/gemini-api/docs/veo
- Nano Banana 2 announcement: https://blog.google/innovation-and-ai/technology/ai/nano-banana-2/
- Nano Banana Pro announcement（可視透かしポリシー）: https://blog.google/technology/ai/nano-banana-pro/
- DeepMind Gemini 3 Pro Image: https://deepmind.google/models/gemini-image/pro/
- Gemini app image help: https://support.google.com/gemini/answer/14286560
- Gemini API Terms（2026-03-23）: https://ai.google.dev/gemini-api/terms
- Google Terms of Service（2026-07-30）: https://policies.google.com/terms
- Generative AI Prohibited Use Policy: https://policies.google.com/terms/generative-ai/use-policy
- 🔶 アプリ上限: https://ai.zenken.co.jp/en/post/gemini-image-guide/ , https://www.aifreeapi.com/en/posts/gemini-image-free-tier-2026 ／ 🔶 Imagen 廃止・Nano Banana 2: https://techcrunch.com/2026/02/26/google-launches-nano-banana-2-model-with-faster-image-generation/
- 透明化手法: ✅ https://www.philschmid.de/generate-stickers ／ 🔶 https://transparify.app/blog/gemini-transparent-background ／ 🔶 https://jidefr.medium.com/nano-banana-2-with-transparency-4673640bb9e6

### Anthropic ✅
- Vision docs（生成不可の FAQ、枚数・解像度・トークン）: https://platform.claude.com/docs/en/build-with-claude/vision

### 専門ツール
- PixelLab ✅: https://www.pixellab.ai/ , https://www.pixellab.ai/docs , https://www.pixellab.ai/pixellab-api ／ 🔶 https://knowara.com/ai-tools/image/pixellab-review/
- Retro Diffusion ✅: https://astropulse.itch.io/retrodiffusion , https://astropulse.gitbook.io/retro-diffusion/aseprite-extension/retro-diffusion-for-aseprite
- Scenario ✅: https://www.scenario.com/pricing ／ 🔶 https://ludo.ai/compare/ludo-vs-scenario
- Layer.ai 🔶: https://ludo.ai/compare/best-ai-sprite-generators , https://www.futurepedia.io/tool/layer-ai
- Leonardo 🔶: https://www.eesel.ai/blog/leonardo-ai-pricing
- Midjourney ✅（プロキシ経由）: https://docs.midjourney.com/hc/en-us/articles/36285124473997-Omni-Reference ／ 🔶 https://blakecrosley.com/guides/midjourney , https://terms.law/2026/01/15/midjourney-commercial-use-rights-complete-2026-guide/ , https://www.eesel.ai/blog/midjourney-pricing
- Ideogram 🔶: https://www.eesel.ai/blog/ideogram-pricing , https://developer.puter.com/tutorials/ideogram-api-pricing/
- Krea 🔶: https://costbench.com/software/ai-image-generators/krea/
- Recraft ✅: https://www.recraft.ai/pricing , https://www.recraft.ai/docs/api-reference/pricing.md , https://www.recraft.ai/docs/recraft-studio/image-editing/background-tools.md ／ 🔶 https://www.recraft.ai/docs/recraft-models/recraft-V4
- Draw Things ✅: https://apps.apple.com/us/app/draw-things-offline-ai-art/id6444050820 , https://drawthings.ai/ ／ 🔶 https://www.heyuan110.com/posts/ai/2026-02-15-draw-things-ultimate-guide/ , https://www.bitdoze.com/ai-images-mac/ , https://rentamac.io/run-flux-locally/ , https://wiki.drawthings.ai/wiki/Flux_Kontext
- Apple Image Playground ✅: https://developer.apple.com/documentation/imageplayground/imagecreator , https://developer.apple.com/documentation/imageplayground/imageplaygroundstyle ／ 🔶 https://www.macrumors.com/2025/06/10/ios-26-image-playground-chatgpt/

### 動画
- Veo ✅（上記）／ Sora 停止 ✅（Deprecations）／ 🔶 https://unifically.com/blogs/sora-api , https://magichour.ai/blog/sora-2-pricing
- Runway ✅: https://runway.com/pricing ／ 🔶 https://unifically.com/blogs/runway-gen-4
- Viggle ✅: https://viggle.ai/pricing , https://viggle.ai/ ／ 🔶 https://flowith.io/blog/viggle-ai-pricing-2026-free-vs-premium-credits/ , https://www.techjockey.com/us/detail/viggle-ai
- Kling 🔶: https://www.atlascloud.ai/blog/tips/kling-ai , https://aivideobootcamp.com/blog/kling-ai-complete-guide-pricing-features-prompts-tips/
- Pika / Hailuo 🔶: https://www.atlascloud.ai/blog/guides/hailuo-ai-pricing-cost , https://magichour.ai/blog/hailuo-23-pricing , https://www.vo3ai.com/ai-video-generator-pricing-comparison

### 一貫性・プロンプト（実践記事）🔶
- https://note.com/m_tani_/n/n6a4e92927388 （Nano Banana、毎回画像添付の重要性）
- https://zenn.dev/totsu_ai_lab/articles/gpt-image-2-character-sheet （GPT-Image-2 設定資料一括生成）
- https://shikujiriblogger.com/chatgpt-ai-image-3layer-template/ （3 層テンプレート）
- https://note.com/3syaku/n/nf3140715927d , https://a-i-manga.com/articles/ai-manga-character-sheet , https://x.com/toto2AI/status/2041395368462815543 （三面図）
- https://romptn.com/article/80792 （Nano Banana でドット絵）
- https://weel.co.jp/media/innovator/nano-banana-prompts/ , https://blog.copainter.ai/nano-banana-for-illustration/
- https://www.spritesheets.ai/blog/how-to-create-a-walk-cycle-spritesheet , https://sorceress.games/blog/how-to-make-a-sprite-sheet-in-2-minutes-with-ai-in-2026 , https://www.seeles.ai/resources/blogs/how-to-animate-sprite-sheets-ai-game-development
- https://note.com/kawakijourney_ai/n/n3836d664e499 , https://blognokoto.site/ai-manga-greenback-remove-background/ （グリーンバック生成）

### 後処理
- Apple プレビュー ✅: https://support.apple.com/guide/preview/remove-a-background-or-extract-an-image-prvw15636/mac ／ 🔶 https://osxdaily.com/2023/01/19/how-to-remove-the-background-from-images-on-mac-with-a-quick-action/
- rembg ✅: https://github.com/danielgatis/rembg/blob/main/README.md
- Aseprite ✅/🔶: https://store.steampowered.com/app/431730/Aseprite/ , https://www.aseprite.org/buy/
- TexturePacker ✅: https://www.codeandweb.com/store/texturepacker-single
- Pixelmator Pro 🔶: https://www.macrumors.com/2026/01/13/pixelmator-no-longer-being-updated/ , https://costbench.com/software/design/pixelmator-pro/
- ImageMagick 🔶: https://imagemagick.org/

### 法務
- 文化庁「AI と著作権に関する考え方について」✅: https://www.bunka.go.jp/seisaku/bunkashingikai/chosakuken/pdf/94037901_01.pdf ／ 概要 ✅: https://www.bunka.go.jp/seisaku/bunkashingikai/chosakuken/pdf/94057901_01.pdf
- 文化庁 2025-09-11 WT 資料 4 ✅: https://www.bunka.go.jp/seisaku/bunkashingikai/chosakuken/workingteam/r07_01/pdf/94269701_04.pdf ／ WT ページ: https://www.bunka.go.jp/seisaku/bunkashingikai/chosakuken/workingteam/r07_01/
- 🔶 AICU 議事レポート: https://corp.aicu.ai/ja/report-20250912 ／ 🔶 2026 改正法解説: https://www.manegy.com/news/detail/15990/ ／ 🔶 パテント 2026 論点整理: https://jpaa-patent.info/patent/viewPdf/4773 ／ 🔶 note 解説: https://note.com/itlawyer/n/n34dbbc5746d7
- 弁護士コラム ✅: https://takase-law.tokyo/column/character_ai/ ／ 🔶 https://miralab.co.jp/media/ai_anime_characters_method/
- 米国 ✅/🔶: https://www.copyright.gov/ai/ , https://www.mayerbrown.com/en/insights/publications/2026/03/supreme-court-denies-review-in-ai-authorship-case , https://www.law.georgetown.edu/tech-institute/research-insights/insights/disney-nbc-universal-and-dreamworks-file-major-ip-lawsuit-against-ai-image-generator-midjourney/
- App Store 🔶: https://developer.apple.com/app-store/review/guidelines/ , https://acceptmy.app/guidelines/1-2-user-generated-content

### 参考（ケータイパートナー）✅
- KDDI 2011-04-13 別紙（ケータイパートナー β 版は au one ラボで提供、2011-04-27 終了、後継「au one キャラタイム」はライフタイプ/トレカタイプ等、Flash 待受、315〜525 円）: https://www.kddi.com/corporate/news_release/2011/0413/besshi.html ／ 🔶 https://k-tai.watch.impress.co.jp/docs/news/439342.html
