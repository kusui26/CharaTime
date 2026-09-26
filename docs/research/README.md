# CharaTime 調査報告（2026-09-10）

`docs/260910_dev_plan.md` の根拠。5 本とも並行リサーチで作成し、各事実に出典 URL・確認日・確信度（✅ 一次情報 / 🔶 二次情報 / 🔷 推測）を付けている。

| ファイル | 担当 | 内容 |
|---|---|---|
| `A_keitai_partner_history.md` | A | ケータイパートナー（β版）／キャラタイム／au one アバター／マチキャラの史実、当時のユーザー評、体験の核 P1〜P8、ユーザーの記憶との照合 |
| `B_ios_surface_feasibility.md` | B | iOS 26/27 でキャラを出せる面（WidgetKit・Live Activity・PiP・StandBy・壁紙・透過ウィジェット）の技術制約と開発者アカウント、推奨構成 |
| `C_ai_character_pipeline.md` | C | 画像生成サービス（OpenAI・Google・Anthropic・専門ツール・動画）の最新状況、一貫性テクニック、プロンプト集、後処理、法務、推奨パイプライン |
| `D_market_precedents_policy.md` | D | 先行アプリの実データ、PiP 事例、Shimeji 需要、デスクトップマスコットの知見、審査ガイドライン、収益化、法務、商標、命名 |
| `E_animation_runtime_and_assets.md` | E | 2D 実装選択肢、ウィジェット描画とフォントハック、アセットパイプラインのコマンド、最小アニメセット、自律行動設計、プロジェクト構成 |

各報告の末尾に「未確認事項」がある。実装前に料金・API 仕様・iOS の挙動は再確認すること。

追加（2026-09-11、プラン v1.1）:

| ファイル | 担当 | 内容 |
|---|---|---|
| `F_verification_gpt_claims.md` | F | 別リサーチ `../260820_gpt.md` の主張 4 点の事実確認（SpritePals、Bryce Bostwick の WidgetAnimation PoC と iOS 26.x、Apple Foundation Models、`CMPedometer`） |

追加（2026-09-26、プラン v1.4。キャラ工房を Phase 2 に移し、アプリ内での生成をやめた決定（D-32・D-33）の前提）:

| ファイル | 担当 | 内容 |
|---|---|---|
| `G_user_made_characters_tools.md` | G | 利用者が自分の生成 AI でキャラを作る道（ChatGPT・Gemini・Claude の iPhone アプリ、無料での可否・上限・透明・透かし・保存）、規約、プロンプトのひな形、スマホだけの手順 |
| `H_on_device_character_import.md` | H | 端末の中での取り込み（Vision の実測、単色の地の自前の抜き方、塊での切り分け、形式、SVG、縮小、ウィジェットでの読み方、持ち出しの形）。Mac での実測つき（iOS 実機の値ではない） |
| `I_user_character_policy.md` | I | 取り込み・書き出しの審査・年齢区分・前例、日本法（私的使用と受け渡し、開発者の責任）、生成 AI 3 社の規約、注意書きの文案 |
