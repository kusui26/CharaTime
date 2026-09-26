# 担当 G: 利用者が自分の生成 AI でキャラを作る（ChatGPT・Gemini・Claude、スマホ中心）

- 作成日: 2026-09-26（出典の確認日も同じ）
- 対象: CharaTime の「キャラ工房」（プラン v1.4 で Phase 5 から Phase 2 に移した）の前提調査。決定（2026-09-26、ユーザー）: 利用者が自分のキャラを使いたいときは、アプリの外で、利用者が自分の ChatGPT / Claude / Gemini（無料か有料かは人による）で作り、その画像をアプリに取り込む。アプリ内で生成 AI の API は呼ばない（従量課金のため）。既定の 5 体は開発者が作って同梱する
- 範囲: `research/C`（2026-09-10）が調べた「開発者が Mac で手作業する流れ」とは重ねず、**一般の利用者が iPhone（と Web）で作る側**に絞る。プロンプトの定石・後処理のコード・日本法の整理は C §2〜§5 を参照
- 凡例: ✅ 一次情報（公式文書・公式ブログ・規約・ヘルプ）/ 🔶 二次情報 / 🔷 推測・筆者の見解 / **未確認** = 確かめられなかった。出典は `[O1]` などの記号で示し、§12 に URL を並べる
- 注意: 法的助言ではない。上限・価格・機能は月単位で変わる。実装の前（プランの 2-0）に公式ページを見直す

## 0. 要約

1. **ChatGPT は無料・Go・Plus のどれでも、アプリから透明背景の画像を頼める。** 公式ヘルプが「背景を透明に」できると書き ✅[O1]、8 月下旬のステッカー機能とともに透明背景が一般向けに入った ✅[O4][O14]。現行は Images 2.5（2026-09-08）✅[O2]。iPhone で範囲を選んで直す編集も使える ✅[O1]。ただし **iPhone の「保存」で写真アプリに透明のまま入るかは未確認**。
2. **画像の上限の公式の数字は、ChatGPT も Gemini も出していない** ✅[O6][G2]。二次情報では無料の ChatGPT は 1 日 2〜3 枚ほど 🔶[S6]、無料の Gemini は 1 日 20 枚ほど 🔶[S12]。Tier 1（生成 6〜12 回）は、無料の ChatGPT だと数日がかり 🔷。
3. **Gemini は今も透明を出せない**（公式の文書に記載なし ✅[G7]、報告 🔶[S13]）。単色の地で作り、アプリで切り抜く。**見える透かしは 2026-08-14 から設定で消せる**（インド・韓国・ベトナムを除く）✅[G3]🔶[S9]。SynthID と C2PA は残る ✅[G3]。ダウンロードは有料 2K・無料 1K ✅[G1]。参照画像を使う編集は 18 歳以上 ✅[G1]。
4. **Claude は今もラスター画像を生成しない** ✅[A1]。代わりに **SVG を書かせる**と、枠・接地線・線の太さを数値で固定でき、まばたきの差分が目だけになる 🔷（可愛さは画像モデルに劣る。C §1.3）。iPhone アプリは成果物を見るだけで、編集・共有設定は Web ✅[A2]。取り出しはメッセージのコピー 🔶[S17] か、コード実行で PNG を作らせる ✅[A4]（iPhone での保存は未確認）。
5. Apple の Image Playground は追加料金なしだが、iOS 27 ではサーバー側のモデルに 1 日の上限があり、将来は有料枠 ✅[P1]。連続したポーズは作れず、Tier 0 の 1 枚どまり 🔷。
6. **規約**: 出力は 3 社とも利用者のもの（OpenAI・Anthropic は権利を譲渡、Google は所有を主張しない）✅[O12][A8][G9]。自分用に別のアプリで使うことを禁じる条項は見当たらない 🔷。3 社とも他人の知的財産の侵害と「AI の生成物を人の作と偽ること」を禁じる ✅（§7）。
7. **頼み方の核**は「キャラカード（固定の文章）＋キャラシートの画像を毎回添付＋変えない点の列挙」✅[O10][G7]。**まばたき・寝息は、格子の別マスより「目だけ閉じる」編集のほうが差分が小さい** 🔷（別マスだと目以外の画素もずれる）。
8. **格子は等間隔にならない**（OpenAI 公式が「配置の精密さは苦手」✅[O9]、Gemini も 🔶[S14]）。アプリは等分割でなく塊ごとに切る 🔷。1K 前後で 3×3 にすると 1 コマの体は約 280〜350 画素で、ウィジェットには足りるが、待受の表示では 1.7〜2.1 倍に引き伸ばす 🔷（§2.2。待受の表示の大きさはレビューで直した）。
9. **スマホだけで完結するか**: ChatGPT ◎、Gemini ○（Gem を作るときだけ Web）、Claude △（アプリが SVG の貼り付けを受け付ければ ○）🔷。
10. C からの主な変化: ChatGPT アプリの透明背景とステッカー（8 月）、Gemini の透かしの切り替え（8/14）と上限の計り方（5 時間ごと・週の上限）、Claude のアーティファクトの刷新（9/16）、iOS 27 の Image Playground（§1）。

## 1. research/C からの変更点（2026-09-10 → 09-26）

| 項目 | C の記述 | 2026-09-26 時点 |
|---|---|---|
| ChatGPT アプリの透明背景 | UI では「transparent background, PNG」と書く（C §3.1）| 公式ヘルプが明記 ✅[O1]。Images 2.0（gpt-image-2）は API の透明が「プレビュー」✅[O10]（8/20 開始 🔶[S2]）で、5 月には市松模様を画素で描く報告 🔶[S1]。2.5 は API の 2 モデルとも透明に対応 ✅[O9] |
| ChatGPT のステッカー | — | 8 月下旬、モバイルの全利用者に（報道 08-24 🔶[S4]、リリースノート 08-31 ✅[O4]）。透明背景 ✅[O14] |
| ChatGPT のカスタム GPT | — | 個人アカウント（Free〜Pro）では新規作成・公開ができない ✅[O6] → 「CharaTime 用の GPT を配る」案は取れない 🔷 |
| ChatGPT の上限 | 公式値なし（🔶 Plus 約 50 枚 / 3 時間）| 変わらず公式値なし。2.5 でも「既存の上限は変えない」✅[O4] |
| Gemini の見える透かし | 無料と AI Pro に付く。9 月時点は未確認 | **設定で入切できる**（インド・韓国・ベトナムは Ultra のときだけ）✅[G3]。08-14 発表 🔶[S9] |
| Gemini の上限 | 日次クォータ（数値非公開）| **計算量で数え、5 時間ごとに回復し、週の上限まで**。Plus は標準の 2 倍、Pro は 4 倍、Ultra は Pro の 5 倍か 20 倍 ✅[G2]。画像のヘルプには「1 日の上限」の言い方も残る ✅[G1] |
| Gemini の透明背景 | RGB のみ | 変わらず（公式の文書に記載なし ✅[G7]）|
| Claude | 生成不可。SVG は補助 | 変わらず生成しない ✅[A1]。09-16 にアーティファクトを刷新し、それより前のものは「レガシー」✅[A2]。コード実行とファイル作成は全プラン・モバイルで使える ✅[A4] |
| Image Playground | 端末内・無料。ImageCreator は iOS 27 で非推奨 | iOS 27 は公開済み。サーバー側のモデルに 1 日の上限、将来は有料枠 ✅[P1]。ImageCreator は 27.0 で非推奨 ✅[P4] |

## 2. アプリが受け取りたい絵

### 2.1 規格（いまの実装）

- 枠は 130:180。接地線は上から 93.33%（180 のうち 168）✅[R2]。いまの 5 体は SVG で、viewBox `-5 -5 130 180`、接地線 y=163、頭のてっぺん y≈20、輪郭線 `#3B2B2B`・太さ 5 ✅[R2]。体の高さは枠の約 79% 🔷（計算）。
- 待受モードの絵は @3x で 585×810 画素（枠の 1.5 倍で焼く）✅[R3]。画面では枠の高さを画面の高さの 0.28 倍で描く ✅[R4]。iPhone 17 Pro（874pt）で約 245pt、@3x で約 734 画素（奥では 0.85 倍、体格 1.15 の子は 1.15 倍）。体は枠の約 79% なので、**体の高さが約 580 画素あれば、画面でほぼ等倍** 🔷（計算）。
  - レビューで直した（2026-09-26）: 初めは `pipeline.py` のコメントの「150〜180pt」を枠の高さと読んで約 430 画素としていた。150〜180pt は枠の幅に近い値で、高さは上のとおり。
- ウィジェットの絵（mini）は @3x で 273×378 画素 ✅[R3]。体の高さは約 300 画素 🔷。
- Tier 1 は 12 コマ（idle 2・walk 4・sit 2・sleep 2・happy 2）、Tier 0 は正面の立ち姿 1 枚 ✅[R1]。ウィジェットのまばたきは「目を開けた絵とまばたきの絵の、違う画素」を使う ✅[R1]。

### 2.2 作り方ごとの画素数の見当 🔷

キャラが 1 マスの狭いほうの辺の 85% に収まり、体は枠の 79% として計算した。大きさは OpenAI API の推奨 ✅[O9] と Gemini API の表 ✅[G7] から取った。アプリの中で実際に出てくる画素数は **未確認**。

| 作り方 | 1 マス | 体の高さ | ウィジェット（300）| 待受（580）|
|---|---|---|---|---|
| 1 枚ずつ（どれでも）| — | 700 以上 | ◎ | ◎ |
| ChatGPT 3×3（3:4、1152×1536 を仮定）| 384×512 | 約 350 | ◎ | △ 1.7 倍 |
| ChatGPT 1×4（3:1、1536×512 を仮定）| 384×512 | 約 340 | ◎ | △ 1.7 倍 |
| Gemini 無料 1K 3×3（3:4、896×1200）| 299×400 | 約 280 | △ 1.1 倍 | ✕ 2.1 倍 |
| Gemini 無料 1K 1×4（4:1、2048×512）| 512×512 | 約 340 | ◎ | △ 1.7 倍 |
| Gemini 有料 2K 3×3（3:4、1792×2400）| 597×800 | 約 550 | ◎ | ○ 1.1 倍 |

→ 格子はウィジェットには足りる。待受では 1.7 倍前後に引き伸ばすので、輪郭が少しにじむ 🔷（太い輪郭線のベタ塗りは、写真より目立ちにくい）。気になる人は有料の 2K か、1 枚ずつ作る。

### 2.3 12 コマの作り分け 🔷

| コマ | 作り方 | 理由 |
|---|---|---|
| idle・sit（目開き）| 3×3 の 1・3 番 | 同じ 1 枚に描くと、大きさと画風がそろう（C §2）|
| idle・sit（まばたき）| 3×3 の 2・4 番。差分が目の外に広がったら、目開きの絵を「目だけ閉じる」編集で作り直す | 別マスは目以外の画素もずれる。編集も完全には保たれない ✅[O1] |
| sleep 2 枚 | 3×3 の 5・6 番。6 番が崩れたら省き、アプリの呼吸（拡大縮小）で代える | 数 % の違いは生成で狙いにくい |
| happy 2 枚 | 3×3 の 7・8 番 | — |
| walk 4 枚 | 1×4 の帯（左向き。右はアプリが反転 ✅[R1]）| — |
| 予備 | 3×3 の 9 番（見上げる）| 右下。Gemini の見える透かしが残るとここにかかる |

## 3. ChatGPT（iPhone アプリと Web）

### 3.1 モデルとプラン

- 現行は **ChatGPT Images 2.5**。2026-09-08 に全プランへ、Web・iOS・Android で ✅[O1][O2][O4]。
- 「思考つきの画像生成」は Plus・Pro・Business だけ ✅[O1][O5]。思考つきなら 1 回の依頼でそろった絵を最大 8 枚出せるとの情報 🔶（C §1.1、2.0 時点）→ 12 コマを 1 枚ずつ作る道になる 🔷。

| プラン | 月額（米国の表示）| 画像（公式の言い方）| 思考つき | 二次情報の目安 |
|---|---|---|---|---|
| 無料 | $0 | 限られた・遅い ✅[O5] | ✕ | 1 日 2〜3 枚 🔶[S6] |
| Go | $8 | より多く ✅[O5][O7] | ✕ | 1 日 20〜50 枚、ばらつき大 🔶[S6] |
| Plus | $20 | より複雑で正確 ✅[O5] | ○ | 3 時間で 40〜50 枚 🔶[S6] |
| Pro | $100〜 | 無制限・速い（乱用防止つき）✅[O5] | ○ | — |

- 画像には別枠の上限があり、達するとアプリが知らせる。数字は公開していない ✅[O6]。日本円の価格は **未確認**。Go は ChatGPT が使える全ての国で提供 ✅[O7]。

### 3.2 透明背景

- 公式: 「ChatGPT Images can follow instructions to ... make the background transparent.」✅[O1]。ステッカーの発表で「ほかの画像にも透明背景を作れる」✅[O14]。プランによる制限は書かれていない → 無料・Go・Plus とも頼める 🔷。
- 経緯: 2.0（gpt-image-2）は API の透明がプレビュー ✅[O10]。2.5 は API の 2 モデルとも正式に対応 ✅[O9]。「2.0 は試すと本物のアルファを返さず、2.5 で正式な機能になった」との記事 🔶[S3]。
- 頼み方（OpenAI の公式ガイド。API 向けだがアプリでも同じ言い方が使える 🔷）: 「isolated subject on a fully transparent background」と書き、背景・単色の地・市松模様・影を入れないと明記する ✅[O10]。背景を説明する言葉があると、そちらが優先される ✅[O11]。編集のたびに「透明の背景を保つ」と書き直す ✅[O10]。
- 確かめ方: iPhone では透明が白や黒に見え、目で区別しにくい 🔶。アプリの取り込み画面で市松模様の上に出し、アルファの有無を知らせる 🔷。

### 3.3 iPhone での取り出し

- 画像を開いて「コピー」「保存」（端末にダウンロード）「共有」（ほかのアプリへ直接送る）✅[O1]。
- **形式は未確認**: 写真アプリに PNG のまま（アルファつきで）入るか、「"ファイル"に保存」で PNG か、公式の記載も確かな検証も見つからない。2024 年（DALL·E のころ）は名前が .png で中身が WebP だった報告 🔶[S8]。Web のダウンロードは PNG との記事 🔶[S21]。
- iCloud 写真: 透明の PNG を写真に入れると、ほかの端末では軽い JPEG 版が出て透明が消え、元の端末でも時間がたつと置き換わりうるとの報告 🔶[S7]（原本は iCloud にある）。取り込みは写真ピッカーで変換を避ける（`.current` ✅[P5]。CLAUDE.md の落とし穴どおり）。原本まで取りに行くかは実機で確かめる 🔷。
- 推奨 🔷: 「共有」から CharaTime へ直接送れる入口（共有拡張）を作る。次点は「"ファイル"に保存」→ ファイルから取り込み。透明が無くても、アプリが切り抜く（プラン §6.7 ✅[R1]）。

### 3.4 参照画像・格子・縦横比・解像度・部分編集

- 参照: 手持ちの画像を上げて変更を頼める ✅[O1]。2.5 は参照写真の被写体を保ちやすく、何度も編集しても崩れにくい ✅[O2]。
- 縦横比: 自由。縦横比の選択か、プロンプトで指定 ✅[O1]。API は 1:3〜3:1、辺は 16 の倍数・3840 以下 ✅[O9]。**アプリの出力画素数は未確認**。
- 格子: 公式は「構造的な配置を正確に置くのは苦手なことがある」「繰り返し出るキャラの一貫性を保ちにくいことがある」と書く ✅[O9]。2.5 は図表の配置の正確さを上げた ✅[O3]。数は守っても間隔はずれる前提で、アプリで吸収する 🔷。
- 部分編集（スマホ）: 画像を全画面で開き「選択」→ 指でなぞる（太さはスライダー、取り消し・やり直しあり）→「次へ」→ 変えたいことを書く ✅[O1]。「選んだ範囲からはみ出すことがある」✅[O1]。画像にコメントを置いて直す機能もある ✅[O4]。「@」→ Sketch で落書きから作れる ✅[O1]。
- 会話をまたぐ: キャラを保存して呼び出す機能は公式の案内に無い 🔷。プロジェクトにシートと指示を置ける（ファイルは無料 5・Go と Plus 25・Pro 40）✅[O8]。画像生成がプロジェクトの画像を自動で参照するかは **未確認** → 毎回添付する 🔷。
- プロンプトの共有: 共有 →「プロンプトテンプレート」→ リンクをコピー ✅[O1]。開発者が作った型を配れる可能性 🔷（何が引き継がれるかは未確認）。

### 3.5 ステッカー（2026-08）

- 「画像」→「ステッカー」で、写真やアイデアからステッカーのパックを作る。モバイルの全利用者向け ✅[O4]。透明背景 ✅[O14]。1 パック最大 9 枚、画風は 18 種（kawaii を含む）🔶[S5]。書き出しは iMessage・WhatsApp・写真に保存 🔶[S4]。
- 使い道 🔷: 9 枚が 1 枚ずつ透明で出るなら、格子の切り分けが要らない。ただし、ステッカー風の白いふち・画風の変化・大きさの不ぞろいが入りうる（**未確認**）。「白いふち無し、同じ画風、同じ大きさ」を頼み、足元はアプリでそろえる。

## 4. Gemini アプリ（iPhone と Web）

### 4.1 モデルとプラン

| Gemini のモデル設定 | 画像のモデル | 向き不向き |
|---|---|---|
| Flash-Lite | Nano Banana 2 Lite | 速い。**複数の参照・連続した編集には向かない** ✅[G1] |
| Flash / Pro | Nano Banana 2 | 複数の参照画像を受ける。キャラの一貫性 ✅[G1] |
| Pro ＋「Pro でやり直す」| Nano Banana Pro | Google AI プランのみ。細部を足して作り直す ✅[G1] |

- AI プランが無くても 3 つのモデルを選べる ✅[G2]。AI Plus $4.99・Pro $19.99・Ultra $99.99〜（米国の表示）✅[G5]、日本円は **未確認**。
- 年齢: 画像の生成は 13 歳以上、**生成と編集は 18 歳以上** ✅[G1]。上げた画像をもとに新しい画像を作るのも編集に入る ✅[G1]。

### 4.2 見える透かし

- 設定 →「Media Watermark」で入切できる。SynthID（見えない透かし）と C2PA（出どころの情報）は切れない ✅[G3]。インド・韓国・ベトナムでは Ultra のときだけ設定が出る ✅[G3]。
- 発表は 2026-08-14 🔶[S9]。位置は右下のきらめきの印 🔶[S10]。既定が入か切かは **未確認**。
- 格子への影響 🔷: 右下のマス（3×3 の 9 番、1×4 の 4 番）にかかる。設定で切る。切れない地域なら 9 番を予備にする（§2.3）。

### 4.3 ダウンロードと大きさ

- iPhone: 画像を長押し →「保存」で端末へ。「共有」は**画像の公開リンクを作る** ✅[G1] → 取り込みには「保存」を使う 🔷。
- 解像度: AI プランありは 2K、なしは 1K ✅[G1]。形式は、Android アプリと Web のフルサイズが PNG だった報告 🔶[S11]。iPhone は **未確認**。
- API の大きさ（参考）: 1K で 1:1 は 1024×1024、3:4 は 896×1200、4:1 は 2048×512。2K は縦横 2 倍 ✅[G7]。API は縦横比を指定しないと、入力画像の大きさに合わせる ✅[G7] → アプリでも添付した画像の縦横比に引っぱられる可能性 🔷。アプリでの指定はプロンプトで（**未確認**）。

### 4.4 上限

- 公式: 計算量で数え、5 時間ごとに回復、週の上限まで ✅[G2]。倍率は §1 の表のとおり ✅[G2]。
- 二次情報: 1 日に無料 20 枚・Plus 50 枚・Pro 100 枚・Ultra 1,000 枚 🔶[S12]（計り方が変わる前の数字かもしれない 🔷）。

### 4.5 一貫性の道具

- Nano Banana 2 の特長に「キャラの一貫性」✅[G1]。API ではキャラの参照を最大 4 枚（Pro は 5 枚）✅[G7]。「前に作った画像を次のプロンプトに入れる」のが公式の勧め ✅[G7]。
- Gems: 指示と知識ファイル（画像も）を持たせ、モバイルでも使える。**作る・直すのは Web だけ** ✅[G4]。画像生成が Gem の知識の画像を参照に使うかは **未確認**。

### 4.6 単色背景と透明

- 透明（アルファ）の出力は、公式の画像生成の文書に記載が無い ✅[G7]。2026-09-10 までのリリースノートにも無い ✅[G6]。「transparent」と書くと灰と白の市松模様を画素で描く 🔶[S13]。
- #00FF00 の守られ方 🔶[S14]: 「EXACT hex #00FF00、グラデーション・ノイズ・影なし」と強く書けば使える。ただし、緑がキャラに混ざる、縁に 1 画素の緑が残る、格子は等間隔にならない、会話をまたぐと比率がずれる。純緑でなく #05F904 のような近い緑になる 🔶[S15] → 抜く色は四隅から測る 🔷。
- 「真っ白」「真っ黒」と純度を強調すると地がきれいになる 🔶[S13]。
- CharaTime では 🔷: アプリが Vision で切り抜く前提なので、**白地を第一に勧める**（緑のにじみが無い。太い輪郭線が切り抜きを助ける）。白いキャラだけ緑（緑を使うキャラはマゼンタ）。実装の前（プランの 2-0）に緑地と比べて確かめる。

## 5. Claude（iPhone アプリと Web）

### 5.1 いまも画像を生成しない

- 「Claude doesn't generate photos or illustrations the way image-generation tools do.」（2026-03-16）✅[A1]。会話の中の図（HTML と SVG）はベータで、Web とデスクトップだけ ✅[A1][A5]。
- 2026-09-25 までのリリースノートに画像生成の追加は無い ✅[A7]。Claude Design（2026-04-17）もコードで組むデザインで、書き出しは zip・PDF・PPTX・HTML など（PNG・SVG は挙がっていない）✅[A6][A7]。

### 5.2 SVG を iPhone から取り出す

- アーティファクト: Free を含む全プラン ✅[A2]。09-16 に刷新 ✅[A7]。iPhone アプリでは、頼んだ成果物をアーティファクトのタブで見られる。テンプレートから始める・編集・共有設定は Web かデスクトップ ✅[A2][A3]。それより前の「レガシー」は、パネルの上でコードを見る・コピー・ダウンロードができる ✅[A2]。
- メッセージのコピー: モバイルではコピーがメッセージ全体の単位で、一部だけは選びにくいとの報告 🔶[S17] → 「SVG のコードだけを返して」と頼む 🔷。
- コード実行とファイル作成: Free を含む全プラン、Web・デスクトップ・モバイル ✅[A4]。PNG の画像ファイルも作れる、1 ファイル 30MB まで ✅[A4]。Free・Pro・Max はネットワークが既定で有効で、PyPI などからパッケージを入れられる ✅[A4] → SVG を PNG に焼かせられるはず 🔷（**未確認**）。iPhone アプリでその PNG を「ファイル」に保存できるかは **未確認**（3 月には「PDF 以外は保存できない」という利用者の声 🔶[S16]）。Safari で claude.ai を開けば保存できる見込み 🔷。
- 年齢: 18 歳以上 ✅[A8]。

### 5.3 SVG の長所と短所 🔷

- 長所: 枠・接地線・線の太さ・色を数字で固定できる。アプリと同じ座標（§2.1）で描かせれば正規化が要らない。部品を `<defs>` で共有すれば、まばたきの差分が目だけになる。SVG は文字なので、会話が変わっても貼り直せば同じキャラ。透明で、解像度に縛られない。いまの 5 体も同じ SVG 方式 ✅[R2]。
- 短所: 可愛さ・表現力は画像モデルに劣る（C §1.3）。複雑な形は崩れる。iPhone で取り出す手間。アプリ側に SVG を焼く仕組みが要る（iOS には実行時に任意の SVG を読む公開 API が無いと筆者は理解している。JavaScript を切った WKWebView で焼くなど）。

## 6. そのほかの無料の手段（短く）

- **Image Playground（iOS 27）**: 文章・写真・人から絵を作る。Apple Intelligence の画風か ChatGPT の画風を選ぶ（ChatGPT を選ぶと依頼内容が ChatGPT に送られる）✅[P1]。iPhone 15 Pro 以降 ✅[P1]。「変更を説明」と、指でなぞって直す編集がある ✅[P1]。サーバー側のモデルに 1 日の上限、将来は有料枠 ✅[P1][P3]。Genmoji はステッカーとして保存 ✅[P1]、iOS 27 で既定の画風が 3D 風に 🔶[S18]。透明で書き出せるか **未確認**。連続したポーズは作れない → Tier 0 の 1 枚どまり 🔷。アプリから呼ぶ `ImageCreator` は iOS 27.0 で非推奨（代わりは `ImagePlaygroundViewController` / `imagePlaygroundSheet`）✅[P4]。
- **写真アプリの「被写体を持ち上げる」**: 長押し → コピー／ステッカーを追加／共有 ✅[P2]。利用者が自分で切り抜ける（CharaTime が切り抜くので必須ではない）🔷。
- **Microsoft Copilot**: 無料で画像を作れ、1 日の優先枠があるとの情報 🔶[S20]。使っているモデルと透明の可否は **未確認**。

## 7. 規約（自分用・他社 IP・透かし）

| 論点 | OpenAI | Google（Gemini）| Anthropic（Claude）| Apple |
|---|---|---|---|---|
| 出力の権利 | 利用者が所有。OpenAI の権利を譲渡 ✅[O12] | 生成したものの所有を主張しない ✅[G9] | 権利を譲渡（あれば）✅[A8] | **未確認**（利用規約 2026-09-09 は上限だけ ✅[P3]）|
| 自分用に別アプリで使う | 禁じる条項なし 🔷 | 同 🔷 | 同 🔷 | 未確認 |
| 他社 IP | 権利侵害を禁止 ✅[O12]、知的財産の侵害の試みを禁止 ✅[O13] | 知的財産権の侵害を禁止 ✅[G10] | 同 ✅[A9] | — |
| 人の作と偽る | 禁止 ✅[O12] | 禁止 ✅[G9][G10] | 禁止 ✅[A9] | — |
| 透かし・出どころ | C2PA と SynthID ✅[O3]。保護の仕組みを回避しない ✅[O12] | 見える透かしは任意。SynthID と C2PA は常に ✅[G3]。出どころを偽らない ✅[G10] | 生成しない | — |
| 年齢 | 13 歳以上、18 歳未満は保護者の許可 ✅[O12] | 生成 13 歳以上、編集 18 歳以上 ✅[G1] | 18 歳以上 ✅[A8] | 写実的な絵は 18 歳以上を推奨 ✅[P1] |

- 既存キャラ: 画像モデルは既存キャラの依頼を多く断る（8 月の試験で 24 回中 22 回）🔶[S19]。日本法の私的使用の範囲なら権利制限の対象になりうるが、個別の判断（C §5.2）🔷。**アプリは既存キャラの再現を勧めず、例にも使わない** 🔷。
- 透かしと取り込み 🔷: アプリの正規化で画像を作り直すと、C2PA のメタデータは落ちる。SynthID がどこまで残るかは **未確認**。利用者の端末の中で使う限り「人の作と偽る」には当たらない。共有の機能を足すなら「AI で生成」を表示する（プラン §6.6 と同じ考え）。

## 8. 実用: 頼み方と、よくある失敗

### 8.1 共通の骨組み（別の会話でも変えない）

- OpenAI の公式ガイド: まず「キャラの錨」になる絵を作り、次からはそれを入力して「デザインを変えない」と書く。変えない点を毎回書き直す。「X だけ変え、ほかは同じ」✅[O10]。複数の画像は「Image 1: …」と番号で呼ぶ ✅[O10]。
- Google: 参照画像＋関係の指示＋新しい場面、の順に書く ✅[G8]。前の画像を次のプロンプトに入れる ✅[G7]。
- CharaTime では 🔷: ①**キャラカード**（名前・体の色と HEX・特徴 3 つ・画風）を固定の文章にし、毎回そのまま貼る ②キャラシートを写真に保存し、毎回添付する ③1 段ごとに新しい会話 ④プロンプトは英語（アプリが組み立ててコピー）、キャラの説明は日本語でもよい。

### 8.2 ひな形（アプリがコピーする文）🔷

```text
[Character card — 毎回そのまま貼る]
Original character "<名前>". Not based on any existing character or brand.
Body: <色と HEX（例: soft yellow #FFE066）>, <形（例: round chick-like body）>
Keep exactly: <特徴 1>, <特徴 2>, <特徴 3>
Style: chibi, about 2 heads tall, big round head, short rounded limbs, thick uniform dark outline,
flat pastel colors, no gradients, no texture.
Never add: text, labels, numbers, grid lines, frames, drop shadow, ground shadow, watermark.

[Background — ChatGPT] Fully transparent background (real alpha, PNG). No scenery, no solid backdrop, no checkerboard, no shadow.
[Background — Gemini]  Solid flat pure white #FFFFFF background everywhere. No gradient, no shadow, no texture.
                       （白いキャラ: solid flat green, exactly #00FF00, and no green on the character）
```

**(a) キャラシート**（Tier 0 なら、正面の 1 枚を取り込めば終わり）

```text
<Character card>
Create a character reference sheet of this one character. Portrait 3:4.
Top row: three full-body views at the same scale, feet on one shared baseline: FRONT, SIDE facing LEFT, BACK.
Bottom row: three head-only expressions: neutral (eyes open), happy (eyes closed in a smile), asleep.
<Background>
```

**(b) 3×3 のポーズ格子**（シートを添付）

```text
<Character card>
Image 1 is the reference sheet of this character. Do not redesign it: same shapes, colors, face and proportions.
Make ONE image with exactly 9 cells, 3 columns x 3 rows, portrait 3:4, no grid lines.
Same scale in every cell. One full-body pose per cell, centered, feet on the bottom of the cell,
clear empty space between cells, nothing touching or crossing a cell edge.
1 standing, front, eyes open          2 exactly the same as 1, eyes closed
3 sitting, front, eyes open           4 exactly the same as 3, eyes closed
5 asleep, curled up, eyes closed      6 exactly the same as 5, body slightly bigger (breathing in)
7 happy, both arms up                 8 happy, arms open, big smile
9 standing, front, looking up
<Background>
```

**(c) 1×4 の歩く帯**（シートを添付）

```text
<Character card>
Image 1 is the reference sheet of this character. Do not redesign it.
Make ONE image: a single row of exactly 4 equal cells (ChatGPT 3:1, Gemini 4:1), no grid lines.
Walk cycle, side view facing LEFT, same scale in every cell, feet on one shared baseline:
1 contact, front foot forward     2 passing, legs together, body a little lower
3 contact, other foot forward     4 passing, legs together, body a little higher
Only the legs, arms and the small up-down move change. Head, body shape and colors stay identical.
<Background>
```

**まばたきの作り直し**（目開きの絵を開いて。ChatGPT は「選択」で目だけ塗ってから ✅[O1]）

```text
Edit this image. Change ONLY the eyes: close them (a gentle curved line).
Keep everything else exactly the same: outline, colors, pose, size, position and background.
```

### 8.3 Claude に SVG のスプライトシートを書かせる 🔷

1 マスはアプリと同じ枠（viewBox `-5 -5 130 180`・接地線 y=163 を 5 ずらして 0〜130 × 0〜180・接地線 168 にしたもの ✅[R2]）。

```text
Write ONE SVG sprite sheet for an iPhone app. Reply with the SVG code only, no explanation.
<Character card>
Root: <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 520 540" width="520" height="540">. No background.
Grid: 4 columns x 3 rows, each cell 130 wide x 180 tall. Cell n (0-11) starts at x = 130*(n mod 4), y = 180*floor(n/4);
wrap it in <g id="<name>" transform="translate(x,y)"> with the numbers written out, and draw in cell coordinates 0..130 x 0..180.
Every cell: feet touch y = 168, top of the head near y = 25, centered on x = 65, nothing crosses the cell edges.
0 idle_01 front, eyes open   1 idle_02 same, eyes closed   2 sit_01 eyes open   3 sit_02 eyes closed
4-7 walk_01..walk_04 side view facing LEFT (contact, passing, contact, passing)
8 sleep_01 eyes closed   9 sleep_02 same, body 3% taller   10 happy_01 arms up   11 happy_02 arms open
Style: stroke #3B2B2B, stroke-width 5, round joins and caps; flat fills, at most 4 colors plus the outline.
Draw the head, body and ears once in <defs> and reuse them with <use>. Cells 1 and 3 differ from cells 0 and 2 ONLY in the eyes.
Use only svg, g, defs, use, path, circle, ellipse, rect. No text, style, CSS, filter, gradient, image, script or link.
```

続けて PNG が欲しいとき: `Now use code execution: render each cell to a transparent PNG of 585 x 810 pixels (scale 4.5), name them idle_01.png … happy_02.png, and give me one ZIP file.`（585×810 は待受モードの絵と同じ ✅[R3]。動くかは **未確認**）

### 8.4 よくある失敗と直し方

| 症状 | 見当 | 直し方 |
|---|---|---|
| コマ数が違う | 数の指示が埋もれる 🔶（C §2）| 「exactly 9 cells, 3 columns x 3 rows」を前のほうに。直らなければ作り直す（足す編集より早い 🔷）。アプリが塊の数で検める 🔷 |
| 格子がずれる・マスをまたぐ | 等間隔は苦手 ✅[O9]🔶[S14] | 「clear empty space between cells, nothing crossing a cell edge」。アプリは塊ごとに切る 🔷 |
| キャラが変わる | 参照なし・長い会話 🔶（C §2）| シートを毎回添付、キャラカードを貼り直す、新しい会話で ✅[O10] |
| 影・文字・番号・枠が入る | 既定の画作り 🔶 | 「Never add: …」を毎回書く ✅[O10] |
| 市松模様（偽の透明）| Gemini は透明を出せない ✅[G7]、ChatGPT でもまれに 🔶[S1] | Gemini は単色の地に。ChatGPT は「real alpha, no checkerboard」✅[O10] |
| 縁が緑・キャラに緑 | 緑の指示が漏れる 🔶[S14] | 白地にする。緑地ならキャラに緑を使わない。抜く色は四隅から測る 🔷 |
| 右下にきらめきの印 | Gemini の見える透かし ✅[G3] | 設定で切る ✅[G3]。切れなければ 9 番を予備に 🔷 |
| まばたきで全体がちらつく | 別マスで描くと目以外もずれる 🔷 | 「目だけ閉じる」編集で作り直す ✅[O1] |
| マスごとに大きさが違う | 🔶[S14] | 「same scale in every cell」。アプリが身長をそろえる（C §4.2）|
| ステッカーに白いふち | ステッカーの画風 🔷 | 「no white sticker border」|
| 断られる | 既存キャラ・実在の人・作家名 🔶[S19] | 固有名詞を外し、自分の言葉で形と色を書く ✅[O13] |

### 8.5 スマホだけで完結できるか 🔷

| | 生成 | 一貫性の道具 | 透明 | 取り出し | 総合 |
|---|---|---|---|---|---|
| ChatGPT | 全プラン ✅[O1] | 参照・範囲を選ぶ編集 ✅[O1]、プロジェクト ✅[O8] | ◎ ✅[O1] | 保存・共有・コピー ✅[O1]（形式は未確認）| ◎ |
| Gemini | 全プラン ✅[G2] | 参照 ✅[G1]、Gem（作るのは Web）✅[G4] | ✕ → アプリで切り抜く | 長押しで保存 ✅[G1]（形式 🔶 PNG）| ○ |
| Claude | SVG のみ | SVG を貼り直せば同じ | ◎（SVG）| コピー 🔶、PNG は未確認 | △（SVG の貼り付けに対応すれば ○）|
| Image Playground | 1 枚 ✅[P1] | 「変更を説明」✅[P1] | 未確認 | 写真に保存 ✅[P1] | Tier 0 のみ |

## 9. アプリ（キャラ工房）への示唆 🔷

1. 取り込み口を 4 つ: 写真（`.current` で変換を避ける ✅[P5]）、ファイル（PNG・JPEG・HEIC・WebP）、共有拡張（ChatGPT の「共有」から直接）、貼り付け（画像か SVG の文字。コードの囲み記号は外す）。
2. 透明かどうかを判定し、無ければ Vision で切り抜く（プラン §6.7）。市松模様の上で見せ、「透明あり／なし」を知らせる。
3. 格子は等分割でなく塊ごとに切る。塊の数が 9 や 4 と違えば、やり直しを勧める。Vision が 1 枚から分けられる被写体の数の上限は、公式の文書に記載が無い（✅[P6] で確認）→ 先に背景の色で塊に分け、1 つずつ Vision にかけるのが堅い。
4. まばたきの差分の面積を測る。目のまわりに収まらなければ「目だけ閉じる」編集を案内するか、まばたき無しに落とす。寝息の 2 枚目が崩れていれば、アプリの呼吸で代える。
5. 解像度: 体の高さが 300 画素未満なら知らせる（ウィジェットでも引き伸ばす）。§2.2 の表を目安に。
6. SVG を受けるなら、使える要素を絞り（§8.3 の一覧）、スクリプト・外部参照・CSS を拒んで、端末の中で焼く。
7. プロンプトは段ごとに分けてコピーさせる（シート → 格子 → 帯 → 編集）。ChatGPT と Gemini の違いは背景の行だけにする。
8. 無料の上限で数日かかる前提にする: Tier 0 で先に動かし、あとからコマを足せる登録にする。

## 10. 利用者向けの推奨手順（スマホだけで）

### 10.1 ChatGPT（iPhone アプリ）

1. アプリを最新にする。無料でもよい（1 日に作れる枚数は少ない 🔶[S6]）。
2. CharaTime でキャラの説明を入れ、「シート」のプロンプトをコピー → ChatGPT の新しいチャットに貼って送る。絵から始めたいなら「@」→ Sketch で落書きを添える ✅[O1]。
3. 気に入った絵を開いて「共有」→ CharaTime（または「"ファイル"に保存」）🔷。**Tier 0 ならここで取り込んで終わり。**
4. Tier 1: 新しいチャットで「＋」からシートを添付し、「3×3」のプロンプトを送る → 同じように保存。
5. 新しいチャットでシートを添付し、「歩く帯」→ 保存。
6. CharaTime に取り込む。アプリが「まばたきを作り直して」と言ったら、ChatGPT で目開きの絵を開き「選択」で目だけ塗る →「次へ」→「目だけ閉じる」の文を送る ✅[O1] → 保存して取り込む。
7. 透明にならなかったら「Fully transparent background (real alpha). Keep everything else the same.」と頼み直す（地が残っていてもアプリが切り抜く）。
8. 上限に達したら、日を改めて続きから。

### 10.2 Gemini（iPhone アプリ）

1. 設定 →「Media Watermark」を切る ✅[G3]。モデルは Flash か Pro にする（Flash-Lite は参照・連続編集に向かない ✅[G1]）。編集には 18 歳以上が要る ✅[G1]。
2. 「シート（Gemini）」のプロンプトを送る → 画像を長押し →「保存」✅[G1]（「共有」は公開リンクになるので使わない）。**Tier 0 ならここで取り込んで終わり。**
3. 新しいチャットでシートを添付し、「3×3（Gemini）」→ 保存。続けて「歩く帯（Gemini）」→ 保存。
4. CharaTime に取り込む（白や緑の地はアプリが切り抜く）。
5. まばたきは、目開きの絵を添付して「目だけ閉じる」の文を送る（範囲を選ぶ道具があるかは **未確認**）。
6. 任意: Safari で gemini.google.com を開き、Gem の指示に「キャラカード」を入れ、シートを知識に足しておくと、次から貼る手間が減る（Gem は Web でしか作れない ✅[G4]。画像の参照に効くかは未確認）。

### 10.3 Claude（iPhone アプリ）

1. 18 歳以上 ✅[A8]。PNG まで作らせるなら、設定 →「機能」→「コード実行とファイル作成」を入にする ✅[A4]。
2. 「SVG」のプロンプト（§8.3）を送る → 返ってきた絵をアーティファクトのタブで見る（iPhone では見るだけ ✅[A2]）。
3. 直したい点を「耳を大きく。ほかは変えない」のように頼む。
4. 取り出し A（CharaTime が SVG の貼り付けに対応したら）: 「SVG のコードだけを、もう一度そのまま返して」→ メッセージを長押しでコピー 🔶[S17] → CharaTime に貼る。
5. 取り出し B: §8.3 の続きの文で PNG の ZIP を作らせる → 保存（iPhone アプリでできるかは **未確認**。できなければ Safari で claude.ai の同じ会話から保存する 🔷）→ CharaTime へ「ファイル」から。
6. 別の会話で続けるときは、前の SVG を貼って「このキャラのまま、happy のコマだけ描き直して」と頼む（文字なので形がそのまま引き継がれる 🔷）。

## 11. 未確認事項

1. ChatGPT iPhone アプリの「保存」で写真アプリに入る形式（PNG のままか、アルファが残るか）。「"ファイル"に保存」と「コピー」の形式。
2. ChatGPT アプリの出力画素数（縦横比ごと、プランの差）。
3. ChatGPT・Gemini の画像の上限の公式値（どちらも非公開）と、日本円の価格。
4. ChatGPT のステッカー: 白いふちの有無、1 パックの枚数（🔶 9）、「写真に保存」の形式、画風の指定の効き。
5. ChatGPT: プロジェクトの画像を画像生成が参照に使うか。プロンプトテンプレートの共有で何が引き継がれるか。
6. Gemini: 見える透かしの既定の入切と位置（🔶 右下）、日本での設定の出方。
7. Gemini iPhone アプリの保存形式と実寸、アプリでの縦横比の指定のしかた、範囲を選ぶ編集の有無。
8. Gemini の Gem の知識ファイル（画像）が、画像生成の参照に使われるか。
9. Gemini の透明背景（2026-09-26 時点で公式の記載なし）。
10. Claude: iPhone アプリで、コード実行が作った PNG や ZIP を「ファイル」に保存できるか。サンドボックスで SVG を PNG に焼けるか。09-16 以後の、テンプレートでないアーティファクトの書き出し手段。テンプレート（Design など）が Free で使えるか（ヘルプは有料のみ ✅[A2]、リリースノートは Free も ✅[A7] と食い違う）。
11. Image Playground: 出力の形式と透明、生成物の利用条件（Apple の規約に記載を見つけられなかった）。
12. Vision `VNGenerateForegroundInstanceMaskRequest` が 1 枚から分けられる被写体の数（3×3 の 9 体を一度に分けられるか）。
13. SynthID が、アプリの縮小・作り直しのあとにどこまで残るか。
14. iCloud 写真の「ストレージを最適化」が入のとき、写真ピッカー（`.current`）が透明の PNG の原本を渡すか。
15. Copilot の現行モデルと透明の可否、日本での無料枠。

## 12. 出典一覧（確認日: すべて 2026-09-26）

### OpenAI ✅
- [O1] Images in ChatGPT（ヘルプ）: https://help.openai.com/en/articles/11084440-chatgpt-images-faq
- [O2] Introducing ChatGPT Images 2.5: https://openai.com/index/introducing-chatgpt-images-2-5/
- [O3] ChatGPT Images 2.5 System Card（2026-09-08）: https://deploymentsafety.openai.com/chatgpt-images-2-5
- [O4] ChatGPT Release Notes（08-31 ステッカー、09-08 Images 2.5）: https://help.openai.com/en/articles/6825453-chatgpt-release-notes
- [O5] ChatGPT Pricing: https://chatgpt.com/pricing
- [O6] ChatGPT Free Tier FAQ: https://help.openai.com/en/articles/9275245-chatgpt-free-tier-faq
- [O7] What is ChatGPT Go?: https://help.openai.com/en/articles/11989085-what-is-chatgpt-go
- [O8] Projects in ChatGPT: https://help.openai.com/en/articles/10169521-projects-in-chatgpt
- [O9] Image generation（API ガイド）: https://developers.openai.com/api/docs/guides/image-generation
- [O10] GPT Image Generation Models Prompting Guide（Cookbook）: https://developers.openai.com/cookbook/examples/multimodal/image-gen-models-prompting-guide
- [O11] Generate Transparent Image Assets（Cookbook）: https://developers.openai.com/cookbook/examples/multimodal/transparent-image-assets-for-campaigns-and-presentations
- [O12] Terms of Use（2026-01-01 発効）: https://openai.com/policies/row-terms-of-use/
- [O13] Usage Policies（2025-10-29 更新）: https://openai.com/policies/usage-policies/
- [O14] ChatGPT 公式アカウントの投稿（ステッカーと透明背景。検索結果の抜粋で確認）: https://x.com/ChatGPT/status/2091996384954069032

### Google ✅
- [G1] Generate & edit images with Gemini Apps（英・パソコン／日・iPhone）: https://support.google.com/gemini/answer/14286560?hl=en , https://support.google.com/gemini/answer/14286560?hl=ja&co=GENIE.Platform%3DiOS
- [G2] Gemini Apps limits & upgrades: https://support.google.com/gemini/answer/16275805?hl=en
- [G3] Manage watermark settings in Gemini Apps（iPhone）: https://support.google.com/gemini/answer/17405358?hl=en&co=GENIE.Platform%3DiOS
- [G4] Use Gems in Gemini Apps（iPhone）: https://support.google.com/gemini/answer/15146780?hl=en&co=GENIE.Platform%3DiOS
- [G5] Google AI subscriptions: https://gemini.google/subscriptions/
- [G6] Gemini Apps release notes（最新 2026-09-10）: https://gemini.google/release-notes/
- [G7] Gemini API: Image generation: https://ai.google.dev/gemini-api/docs/image-generation
- [G8] Ultimate prompting guide for Nano Banana（Google Cloud、2026-03-06）: https://cloud.google.com/blog/products/ai-machine-learning/ultimate-prompting-guide-for-nano-banana
- [G9] Google Terms of Service（2026-07-30 発効）: https://policies.google.com/terms
- [G10] Generative AI Prohibited Use Policy（2024-12-17）: https://policies.google.com/terms/generative-ai/use-policy

### Anthropic ✅
- [A1] Can Claude produce images?（2026-03-16）: https://support.claude.com/en/articles/9002504-can-claude-produce-images
- [A2] What are artifacts and how do I use them?: https://support.claude.com/en/articles/17153992-what-are-artifacts-and-how-do-i-use-them
- [A3] Share artifacts: https://support.claude.com/en/articles/9547008-share-artifacts
- [A4] Create and edit files with Claude（2026-08-06）: https://support.claude.com/en/articles/12111783-create-and-edit-files-with-claude
- [A5] Visual and interactive content（2026-03-16）: https://support.claude.com/en/articles/13641943-visual-and-interactive-content
- [A6] Get started with Claude Design: https://support.claude.com/en/articles/14604416-get-started-with-claude-design
- [A7] Release notes（04-17 Claude Design、09-16 アーティファクト、〜09-25）: https://support.claude.com/en/articles/12138966-release-notes
- [A8] Consumer Terms of Service: https://www.anthropic.com/legal/consumer-terms
- [A9] Usage Policy: https://www.anthropic.com/legal/aup

### Apple ✅
- [P1] Create original images with Image Playground on iPhone（iOS 27）: https://support.apple.com/guide/iphone/create-original-images-with-image-playground-iph0063238b5/ios
- [P2] Lift a subject from the photo background on iPhone: https://support.apple.com/guide/iphone/lift-a-subject-from-the-photo-background-iphfe4809658/ios
- [P3] Apple Intelligence Usage Terms（2026-09-09）: https://support.apple.com/en-us/148587
- [P4] ImageCreator（iOS 18.4〜、27.0 で非推奨）: https://developer.apple.com/documentation/imageplayground/imagecreator
- [P5] PhotosPickerItem.EncodingDisambiguationPolicy.current: https://developer.apple.com/documentation/photosui/photospickeritem/encodingdisambiguationpolicy/current
- [P6] VNGenerateForegroundInstanceMaskRequest: https://developer.apple.com/documentation/vision/vngenerateforegroundinstancemaskrequest

### 二次情報 🔶
- [S1] OpenAI Developer Community「Having trouble getting transparent backgrounds」（2026-05）: https://community.openai.com/t/having-trouble-getting-transparent-backgrounds-in-chatgpt-images/1380143
- [S2] OpenAI Developer Community「Transparent backgrounds ... preview for GPT-Image-2」（2026-08-20。検索結果の要約）: https://community.openai.com/t/transparent-backgrounds-are-now-available-in-preview-for-gpt-image-2-in-the-api/1391541
- [S3] Renoise「ChatGPT Images 2.5 Explained」（2026-09）: https://renoise.ai/blog/chatgpt-images-2-5-explained
- [S4] 9to5Mac（2026-08-24）: https://9to5mac.com/2026/08/24/chatgpt-now-lets-users-create-custom-imessage-and-whatsapp-stickers/
- [S5] t2ONLINE（2026-08-25）: https://t2online.in/tech/tech-news/chatgpt-images-can-now-turn-your-favourite-characters-and-inside-jokes-into-custom-stickers/2007498
- [S6] 上限の集計: https://www.cometapi.com/how-many-images-can-you-create-with-chatgpt-free-in-2026/ , https://chatgptlimit.com/chatgpt-image-generation-limit/ , https://chatgptimage2.org/blog/chatgpt-go-image-generation-limit
- [S7] note「透過 PNG が JPG に」（2025-10-12）: https://note.com/unitopiyo/n/na229888c7750
- [S8] OpenAI Developer Community「saved as WEBP despite PNG extension」（2024）: https://community.openai.com/t/dall-e-images-in-chatgpt-environment-saved-as-webp-despite-png-extension/537826
- [S9] TechCrunch（2026-08-14）: https://techcrunch.com/2026/08/14/google-will-now-allow-users-to-remove-visible-watermark-from-its-ai-generations/ ／ Search Engine Journal（2026-08-17）: https://www.searchenginejournal.com/google-lets-you-turn-off-visible-watermarks-in-gemini/586145/
- [S10] allblogthings（2026-08-18、透かしの位置）: https://www.allblogthings.com/2026/08/how-to-turn-off-watermark-in-gemini.html
- [S11] はてなブログ（2026-05-13、Gemini のフルサイズは PNG）: https://clone-01.hatenablog.com/entry/2026/05/13/211506
- [S12] WEEL「Nano Banana 2 とは」（1 日の枚数。検索結果の要約）: https://weel.co.jp/media/tech/nano-banana-2/
- [S13] Transparify「Gemini Transparent Background」（2026-06-07）: https://transparify.app/blog/gemini-transparent-background
- [S14] Robotic Ape「Generating Game Sprites with Gemini Image Generation」（2026-03-07）: https://roboticape.com/2026/03/07/generating-game-sprites-with-gemini-image-generation-nano-banana-pro-lessons-learned/
- [S15] nano-banana-2-skill の README（近い緑。検索結果の要約）: https://github.com/kingbootoshi/nano-banana-2-skill
- [S16] Threads の投稿（2026-03-27、Claude iOS の保存）: https://www.threads.com/@mcdonaldryn/post/DWZWH61FLA4/
- [S17] GitHub Issue（モバイルの長押しでのコピー）: https://github.com/anthropics/claude-code/issues/93938
- [S18] MacRumors「Apple Overhauls Genmoji in iOS 27」（2026-06-08）: https://www.macrumors.com/2026/06/08/apple-overhauls-genmoji-in-ios-27/
- [S19] DreamPixelForge（2026-08、既存キャラの拒否率）: https://www.dreampixelforge.com/blog/ai-image-generators-copyrighted-characters
- [S20] Copilot（検索結果の要約のみ）: https://support.microsoft.com/en-us/microsoft-copilot/using-image-generation-in-microsoft-copilot , https://office-watch.com/2026/chatgpt-images-2-0-copilot-image-generator/
- [S21] Tenorshare「ChatGPT Images 2.0 Transparent Background Guide」（2026-09-18）: https://www.tenorshare.ai/chatgpt-tips/gpt-image-2-transparent-background.html

### リポジトリ
- [R1] `docs/260910_dev_plan.md`（§6.2〜§6.7、Phase 5）
- [R2] `design/chara.py`（viewBox・接地線・輪郭線）
- [R3] `tools/pipeline/pipeline.py`（待受の絵と mini の大きさ、150〜180pt）
- [R4] `ios/Packages/CTRender/Sources/CTRender/SceneLayout.swift`（`characterHeightRatio = 0.28`。待受で描く枠の高さ）
- C = `docs/research/C_ai_character_pipeline.md`
