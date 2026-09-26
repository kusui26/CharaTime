# 担当 I: 利用者のキャラの取り込み・書き出し — 審査・法務・生成 AI 規約の調査

- 作成日: 2026-09-26（出典の確認日も同じ）
- 対象: CharaTime の「キャラ工房」（プラン v1.4 で Phase 5 から Phase 2 に移した）。利用者が自分の ChatGPT / Gemini / Claude で作った画像を取り込み、端末の中だけで切り抜いて登録する。自分の端末どうしの引っ越しのため、キャラを 1 つのファイルに書き出し・読み込みする
- 前提（決定 2026-09-26）: アプリ内で生成 AI の API を呼ばない。取り込んだ画像は端末内だけで処理・保存し、サーバーに送らない。ほかの利用者に見せる機能（ギャラリー・共有・ランキング）を作らない
- 凡例: ✅ 一次情報（Apple の公式ガイドライン・ドキュメント、e-Gov の法令、裁判所の判決文、文化庁、各社の規約）/ 🔶 二次情報（報道・解説・開発者の投稿）/ 🔷 推測・筆者の見解 / **未確認**
- 注意: 本レポートは法的助言ではない。公開を決めたら条文・規約の最新版を読み直し、必要なら専門家に確かめる
- 既存の調査との関係: 審査の全体（4.2・2.5.x・3.1.1 ほか）は `research/D` §5、サンリオ風の線引きと AI 生成物の著作物性は `research/D` §7・`research/C` §5 にある。ここでは繰り返さず、「利用者の取り込み」に効く点だけを掘る
- 調査手段: Web 検索 約 20 回、公式ページの取得 約 70 回（developer.apple.com の本文と JSON、e-Gov 法令 API、裁判所の判決 PDF、文化庁の PDF、iTunes Lookup API と App Store の製品ページ、各社の規約）

---

## 0. 要約

1. **1.2 の 4 要件（フィルタ・通報・ブロック・連絡先）は「ほかの利用者に見せる」UGC を前提にした条文で、端末の中に閉じた取り込みにはかからないと読むのが自然** 🔷。本文は "filtering objectionable material from being posted to the app" "block abusive users from the service" と書き ✅、年齢区分の UGC の定義は "the broad distribution of content created by users" ✅。ただし Apple は線引きを明文にしていない（**未確認**）。
2. **同じ形のアプリが 4+ で審査を通っている** ✅。写真をドット絵にしてライブアクティビティに常駐させ、AirDrop で友だちに送れる「推しアイランド」（日本の個人開発）、推しの写真をウィジェットに置く「おしデコ」「Oshibana」、ペットを切り抜いて Dynamic Island に出す「いつでもマイペット」など（§2.9）。
3. **OS の共有（AirDrop・ファイル）で 1 対 1 に渡せるだけで、アプリ内に閲覧・発見の場が無ければ、UGC にも SNS（"social feed or similar discovery method"）にも当たらないと読める** 🔷。年齢区分は UGC・SNS・メッセージとも「なし」で答えられ、4+ の見込み 🔷。
4. **ガイドラインは 2026-06-08 に改定されている**（`research/D` の「直近は 2025-11-13」から更新）✅。1.2 に「違反コンテンツを消すのは開発者の責任」の段落が入り、4.3(b) に例が足されて本文に "wallpaper" が並ぶ ✅。2026-07-09 に年齢区分へ SNS の質問が入り、2026-09 から回答が必須 ✅。
5. **生成 AI に固有の条文は 5.1.2(i)（第三者 AI に送る前の同意）と 4.7（チャットボット等）だけ** ✅。API を呼ばず何も送らない CharaTime には当たらない 🔷。AI 生成物に表示を求める条文も、年齢区分の AI 専用の項目も無い ✅。
6. **写真は `PhotosPicker` で受ければ許可が要らない**（別プロセスで動く）✅。端末内だけで処理するデータは App Store の「収集」に当たらない ✅ → 解析 SDK を入れなければ「データの収集なし」と表示できる 🔷。
7. **日本法: 個人が私的使用の目的で生成・鑑賞するのは、既存キャラに似ていても許諾は要らない** ✅（文化庁チェックリスト 4-1-7）。一方 **「複製物の譲渡等」は権利制限の範囲外となる場合が多い** ✅（同 4-1-4）。書き出したファイルを人に渡すと、中身が既存キャラに似ていれば 30 条の外に出うる 🔷。
8. **開発者の責任は低い** 🔷。侵害の主体は原則として AI 利用者（文化庁）✅。ロクラク II は「管理，支配下において…枢要な行為」をした提供者を複製の主体とし ✅、Winny は道具の提供を幇助とするのを「例外的とはいえない範囲の者が…著作権侵害に利用する蓋然性が高い」場合などに限った ✅。サーバーを持たず、汎用の道具で、既存キャラへ誘わない限り、どちらの型にも当たりにくい 🔷。
9. **生成 AI の規約**: 3 社とも出力は利用者のもの ✅、他人の知的財産の侵害は禁止 ✅。「AI 生成」の表示は、人が作ったと偽らない義務（3 社）✅ と、SNS 投稿・出版での明示（OpenAI）✅ だけで、自分用に表示する義務は見当たらない 🔷。**Claude は画像を作れない**（2026-09-26 も同じ）✅。
10. **推奨**: 取り込み・書き出し・読み込みの 3 画面に短い注意書き（§5.4 に文案）。アプリ内の共有・ギャラリー・URL からの読み込み・サーバー中継・実行できる中身を作らない。例文・スクショ・キーワードに他社キャラを使わない。公開時はプライバシーポリシー（必須）・「データの収集なし」・年齢区分 4+ の回答（§5.5）。

---

## 1. 既存の調査から変わった点

| 項目 | 既存の記述 | 2026-09-26 の確認 | CharaTime への影響 |
|---|---|---|---|
| ガイドラインの最新版 | D §5「直近の改定は 2025-11-13」 | **2026-02-06**（無作為・匿名のチャットを 1.2 の対象と明記）と **2026-06-08**（序文の子どもの安全、1.2 の削除責任の段落、4.3(a)(b) の例、4.5.3）に改定。本文末尾は "Last Updated: June 8, 2026" ✅ | 1.2 の 4 要件は変わらない。4.3(b) の例に "wallpaper" が並ぶ（新たに加わったことは報道 🔶）ので、壁紙の書き出し（Phase 4）を主役に見せない 🔷 |
| 年齢区分 | D §5.1「UGC は 4+（韓国 13+、ブラジル 9+）」 | UGC は "broad distribution" と定義 ✅。**SNS の質問を追加（2026-07-09）、2026-09 から必須** ✅。いまは韓国が UGC を "All"、ブラジル（自己申告）が "A6" に置く ✅ | UGC・SNS・メッセージとも「なし」で 4+ 🔷 |
| 米国の州法 | 記載なし | Texas SB2420 が 2026-06-04 から新規アカウントに適用。開発者は Declared Age Range API ほかで対応 ✅ | 日本だけに出すなら不要 🔷 |
| Gemini の見える透かし | C §1.2「Free / AI Pro に付く」 | **設定（Media Watermark）で消せる**。インド・韓国・ベトナムは Ultra のみ。SynthID と Content Credentials は残る ✅（2026-08 公表 🔶） | 取り込み前に利用者が消せる。切り抜きでも右下の印は落ちる |
| OpenAI の規約 | C「2026-01-01 発効 🔶」 | "Effective: January 1, 2026"。共有・公開ポリシーに従うよう求める ✅ | §4 |
| OpenAI 画像の来歴 | C「C2PA と SynthID」 | ヘルプで両方を確認 ✅ | 作り直した PNG では C2PA が落ち、SynthID は画素に残りうる 🔷 |
| Claude | C「画像生成は不可」 | 2026-09-26 も "it cannot generate, produce, edit, manipulate, or create images" ✅ | 決定文の「Claude で作る」は、プロンプト作りか SVG の意味に読み替える |
| 著作権法 | C「2026-04 施行の改正は AI 固有でない」 | 2026 年の改正はレコード演奏・伝達権（令和 8 年法律第 48 号）と学校教育法等の改正に伴うもの（同第 37 号）✅。私的使用・生成 AI の扱いを変える改正は見当たらない 🔷 | なし |
| プラン §6.7 | 「1.2 のモデレーション要件が軽い」 | 「端末内に閉じれば 1.2 は当たらないと読むのが自然」🔷 | 言い換える |
| C §5.4 | 「既存 IP に似た場合の削除フローを用意 🔷」 | 配信しないので削除する相手がいない 🔷 | 端末内なら不要（共有を作るなら要る） |
| プラン §6.7 段階 2 | アプリ内生成（API） | 決定で不採用 | 5.1.2(i) の同意、API キーの管理、1.2 の仕組み、「AI 生成」表示がすべて要らなくなる 🔷 |

---

## 2. App Store 審査ガイドライン（2026-06-08 版）

### 2.1 1.2 と 1.2.1 の本文 ✅

> "Apps with user-generated content present particular challenges, ranging from intellectual property infringement to anonymous bullying. To prevent abuse, apps with user-generated content or social networking services must include: A method for filtering objectionable material from being posted to the app / A mechanism to report offensive content and timely responses to concerns / The ability to block abusive users from the service / Published contact information so users can easily reach you"

- 2026-06-08 に足された段落: "It is your responsibility to remove content that violates this guideline, your terms of service, or your community standards." 違反が見つかれば Apple が削除と改善計画を求め、応じなければアプリの削除もありうる ✅。
- 1.2.1 は「クリエイター」の共同体のコンテンツを載せるアプリが対象（"tools and programs to help this community of non-developer creators to author, share, and monetize user-generated experiences"）✅。(a) は年齢を超える内容の見分けと、年齢による制限を求める（2025-11 新設）✅。
- 要点 🔷: 4 要件はどれも「アプリへの投稿」「サービスからの締め出し」を前提にし、複数の利用者が同じ場を共有するアプリを想定している。

### 2.2 端末の中に閉じた取り込みに 1.2 はかかるか

| 根拠 | 内容 | 確信度 |
|---|---|---|
| 1.2 の本文 | 「投稿」「サービスからのブロック」を前提にした 4 要件 | 本文 ✅、読み方 🔷 |
| 年齢区分の UGC | "Includes the broad distribution of content created by users as a component of the app's intended user experience. May include: broadly distributed videos, photos, text, and/or audio created by users of the app." | ✅ |
| 年齢区分の SNS | "Redistribution, amplification, or interaction with user-generated content through a social feed or similar discovery method that visibly spreads content to many users." | ✅ |
| メッセージ | "Users can directly communicate with one another through features within the app." | ✅ |
| 断られた実例 | 利用者どうしでメッセージやイベントを見せ合うアプリ。指摘は EULA・フィルタ・通報・ブロック・24 時間以内の削除（2025-11） | 🔶（開発者の投稿） |
| 通っている前例 | §2.9 の 7 本。どれも 4+ | ✅ |

- **結論** 🔷: 取り込んだ画像を本人の端末でしか表示しない限り、1.2 の義務はかからないと読むのが自然。ただし序文は "We will reject apps for any content or behavior that we believe is over the line." "I’ll know it when I see it" と書き ✅、審査の裁量は残る。

### 2.3 書き出し・読み込み（OS の共有）は UGC か

- アプリが作るのはファイル 1 つ。渡すのは利用者が OS の共有シート（AirDrop・ファイル・メール）で行い、受け手が自分で受け取って開く。アプリ内に一覧・検索・おすすめ・フィードは無い 🔷。
- これは UGC の "broad distribution" でも、SNS の "discovery method that visibly spreads content to many users" でもないと読める 🔷。Apple の明文の線引きは見つからなかった（**未確認**）。
- 前例: 推しアイランドは「AirDrop で友達とシェア」を機能に掲げて 4+ で通っている ✅（1.2 の仕組みの有無は**未確認**）。
- 作り方: 独自のファイル形式は exported type として宣言する。`public.content` に準拠させると AirDrop で送れる（"This conformance allows users to share your type over AirDrop."）✅。
- 5.2.3 "Apps should not facilitate illegal file sharing" ✅ → 引っ越しの道具として作り、交換を促す作り（配布サイトへの案内、URL・QR での受け渡し）にしない 🔷。

### 2.4 最小機能・スパム・コードの実行（4.2・4.2.3・4.3・2.5.2・4.7）

- 4.2 の本文と先例は D §5。取り込みは本体（部屋・同梱キャラ・自律行動）に足すもので、4.2 の不安を増やさない 🔷。
- 4.2.3(i) "Your app should work on its own without requiring installation of another app to function." ✅ → キャラ工房は ChatGPT などを入れていなくても使えるようにする（手描きの絵を含め、どの画像でも取り込める）🔷。
- 4.3(b)（2026-06-08）"Certain kinds of apps, such as dating, flashlight, sound effects, wallpaper, simple timers, and fortune telling, are well established on the App Store and we will not accept new submissions unless they offer a meaningfully different or improved experience." ✅ → 説明文とスクショで「壁紙アプリ」に見せない 🔷。
- 2.5.2 "...nor may they download, install, or execute code which introduces or changes features or functionality of the app" ✅。4.7 はプラグイン等に 1.2 と同じフィルタ・通報・ブロックを課す ✅ → 書き出しファイルは絵と数値だけにし、動きの台本やスクリプトを入れない 🔷（決定論の原則とも合う）。

### 2.5 写真の扱い（5.1.1・5.1.2・`PhotosPicker`）

- 5.1.1(iii) "Where possible, use the out-of-process picker or a share sheet rather than requesting full access to protected resources like Photos or Contacts." ✅
- `PHPickerViewController` は "Because the system manages its life cycle in a separate process, it’s private by default. The user doesn’t need to explicitly authorize your app to select photos" ✅。SwiftUI の `PhotosPicker`（iOS 16+）も同じ選択画面 🔷。CharaTime は Info.plist に写真の利用目的（`NSPhotoLibraryUsageDescription`）を持たないまま、背景（1-4）と透過背景（3-3）を `PhotosPicker` で取り込めている（手元のコードで確認。利用目的なしに写真ライブラリへ触れると落ちる ✅）→ 許可は要らない。
- ファイルアプリからの取り込み（`fileImporter`）も、利用者が選んだファイルにだけ触れる 🔷。写真アプリへの保存（Phase 4 の壁紙）は追加だけの許可（add-only）で足りる ✅。
- 5.1.2(i) "You must clearly disclose where personal data will be shared with third parties, including with third-party AI, and obtain explicit permission before doing so." ✅ は、アプリが送るときの義務。CharaTime は送らない。プロンプトをコピーや共有シートで ChatGPT などに渡すのは利用者の操作 🔷。
- App プライバシー: "Data that is processed only on device is not “collected” and does not need to be disclosed in your answers." ✅ / "You are not responsible for disclosing data collected by Apple." ✅

### 2.6 知的財産（5.2・4.1(c)・2.3.7）

- 5.2 "Make sure your app only includes content that you created or that you have a license to use." ✅ / 5.2.1 "Don’t use protected third-party material such as trademarks, copyrighted works, or patented ideas in your app without permission" ✅。
- 利用者が他社のキャラを取り込んでも、それはアプリが「含む」ものではない。アプリ側が問われるのは、アプリ自体・メタデータ・例に他社の素材があるとき 🔷。おしデコは「アイドル・俳優・声優・アニメ・K-pop の推し写真を飾りたい」と書いて通っている ✅。
- 5.2.2（第三者サービスの利用）: CharaTime は ChatGPT などにアクセスしない（プロンプトを渡すだけ）ので当たらない 🔷。
- 4.1(c) "You cannot use another developer’s icon, brand, or product name in your app’s icon or name, without approval from the developer." ✅、2.3.7 "don’t try to pack any of your metadata with trademarked terms" ✅ → 「ChatGPT」「Gemini」をアプリ名・サブタイトル・キーワードに入れない。アプリ内で名前を挙げるのは事実の説明にとどめ、各社のロゴは使わない 🔷。

### 2.7 生成 AI に関わる改定（2025〜2026）✅

- 2025-11-13: 5.1.2(i) に "including with third-party AI"、1.2.1(a)、4.1(c)、4.7（HTML5 のミニアプリ）。
- 2026-06-08: 開発者規約（DPLA）に Apple のモデルと Foundation Models の利用条件（3.2(h)・3.3.11(A)）、Sensitive Content Analysis の条件（3.3.3(N)）。ガイドライン本文を "generative" "AI" で探しても、AI 生成物の表示を求める条文は無い。
- 年齢区分に AI 専用の項目は無い（D §5.1 と同じ）。2025-07 の告知どおり、AI の機能は「敏感な内容が出る頻度」として既存の項目に織り込んで答える。

### 2.8 年齢区分（2025 年の新制度と 2026-07 の SNS 質問）✅

- 4+ の欄に "User-generated content" "Messaging and chat" "Advertising"、13+ に "Social media"、16+ に "Unrestricted web access" がある（日本を含む一般の地域）。
- 取り込みは broad distribution ではない → UGC は「なし」🔷。仮に「あり」と答えても 4+ のまま ✅。SNS の質問は 2026-09 から回答が必須 ✅。

### 2.9 審査を通っている似たアプリ（2026-09-26、iTunes Lookup API と製品ページ）✅

| アプリ（ID） | 開発者 | 取り込みと表示 | 共有 | 年齢 | プライバシー表示 |
|---|---|---|---|---|---|
| 推しアイランド（6751716346、2026-01 公開） | Ryo Tsudukihashi（日本の個人） | 写真→ドット絵、アニメ、ライブアクティビティで常駐 | **AirDrop で友達とシェア** | 4+ | 写真・ユーザコンテンツの項目なし（使用状況・ID） |
| いつでもマイペット（6762539983、2026-05） | Masanori Uesugi | ペットの写真・動画を切り抜き、Dynamic Island に | なし | 4+ | 写真の項目なし |
| おしデコ（6752970703、2026-01） | Tomohiro Kawase | 推しの写真をホーム画面ウィジェットに | なし | 4+ | 写真の項目なし（広告・解析） |
| 推し活アプリ Oshibana（1581399897、2021〜） | booklista | 推し画像を登録、動くアルバムのウィジェット | なし | 4+（12,747 件 ★4.8） | 写真の項目なし |
| Peta（6790650954、2026-07） | MOCHA, LIMITED LIABILITY CO. | 被写体の切り抜きを端末内で（「背景除去のために写真を外部サーバーへ送信しません」） | 共有シートで書き出し | 4+ | 写真の項目なし |
| Photo Widget — The Best One（1532588789、US） | Sindre Sorhus | 写真・ファイルから取り込み、ウィジェットと StandBy | なし | 4+ | 診断（クラッシュ）のみ |
| SpritePals（F §1） | Ivo van der Zee | 写真をサーバー経由で OpenAI に送って生成（対照: サーバー型） | — | 4+ | — |

- 読み取れること: 写真を取り込んでウィジェット・ライブアクティビティに出すアプリは 4+ で通り、プライバシー表示に写真を載せていない（端末内処理は収集に当たらないという Apple の定義どおり）✅/🔷。これらが通報・ブロックを持つか、審査で何を言われたかは**未確認**。

---

## 3. 日本法

### 3.1 30 条（私的使用）と生成 AI ✅

- 30 条 1 項: 「個人的に又は家庭内その他これに準ずる限られた範囲内において使用すること（以下「私的使用」という。）を目的とするときは、次に掲げる場合を除き、その使用する者が複製することができる。」除外は、公衆用の自動複製機器・技術的保護手段の回避・違法配信からの録音録画・違法配信からの複製（知りながら）。
- 47 条の 6 第 1 項 1 号: 30 条 1 項で使えるときは「翻訳、編曲、変形又は翻案」もできる。
- 趣旨: 「閉鎖的な私的領域における零細な複製を許容する観点」（文化審議会の参考資料、平成 30 年度）。
- 文化庁「AI と著作権に関する考え方について」（2024-03-15、36〜38 頁）: 生成・利用段階でも「私的使用目的の複製（法第 30 条第１項）」などが適用されうる。ただし「生成段階と、利用段階の利用行為それぞれについて、権利制限規定の適用を検討する必要があり」、一方で適用されても他方では許諾が要る場合がある。
- 同「チェックリスト＆ガイダンス」（2024-07-31、27〜28 頁）:
  - 4-1-7「AI生成物を『…私的使用』を目的とする場合であれば、仮に生成物に既存の著作物との類似性及び依拠性があったとしても、権利者の許諾は必要なく、生成物の生成や私的な鑑賞などが可能です。」
  - 4-1-4「AI生成物の利用（インターネットでの配信、複製物の譲渡等）については、権利制限規定の範囲外となる場合が多いと考えられます。」
  - 4-1-6 プロンプトに「キャラクター名などの特定の固有名詞を入力した場合は、…依拠性が認められやすくなると考えられます。」
- 当てはめ 🔷: 利用者が自分用に作った画像を自分の iPhone に取り込み、切り抜いて動かすのは、30 条（と 47 条の 6）の範囲に収まる。
- 残る論点: クラウドの生成で「その使用する者が複製」と言えるか。「考え方」の注 49 は事業者が物理的な行為主体と評価される場合もあるとする ✅。これは生成の段の話で、取り込みの段（本人の端末での複製）には効かない 🔷。

### 3.2 取り込みの機能を提供する開発者の責任

| 型 | 判例・資料 | 物差し | CharaTime |
|---|---|---|---|
| カラオケ法理 | クラブキャッツアイ（最判昭和 63 年 3 月 15 日）🔶 | 管理・支配と営業上の利益で、店を歌唱の主体とみた | 利用者の端末で動き、開発者は管理も支配もしない 🔷 |
| 複製の主体 | ロクラク II（最判平成 23 年 1 月 20 日）✅ | 「複製の対象，方法，複製への関与の内容，程度等の諸要素を考慮」。提供者が「その管理，支配下において…枢要な行為」をすれば主体 | 取り込み・切り抜き・保存は、利用者の端末で利用者の操作で起きる。低い 🔷 |
| 送信の主体 | まねき TV（最判平成 23 年 1 月 18 日）✅ | 機器を管理して情報を入力する者が送信の主体。提供者からみて「本件サービスの利用者は不特定の者として公衆に当たる」 | サーバーで受け渡しを中継すると、開発者が送信の主体になりうる → 作らない 🔷 |
| 利用の主体（最新） | 音楽教室（最判令和 4 年 10 月 24 日）✅ | 「演奏の目的及び態様、演奏への関与の内容及び程度等の諸般の事情を考慮」。生徒は「任意かつ自主的に演奏する」 | 利用者は自分の目的で、自分で取り込む 🔷 |
| 道具と幇助（刑事） | Winny（最決平成 23 年 12 月 19 日）✅ | 具体的な侵害の認識・認容、または「例外的とはいえない範囲の者が同ソフトを著作権侵害に利用する蓋然性が高い」ことの認識・認容が要る | 汎用の取り込み。自作キャラ向けと明示すれば蓋然性は低い 🔷 |
| 道具と不法行為 | ときめきメモリアル（最判平成 13 年 2 月 13 日）🔶 | 「専らゲームソフトの改変のみを目的とする」道具を流通させた者は責任を負う | 特定の作品の改変を目的にしない 🔷 |
| 代行 | 自炊代行（知財高判平成 26 年 10 月 22 日）🔶 | 代行業者が複製の主体で、30 条は使えない | サーバーでの切り抜き代行は同じ構図 → 作らない 🔷 |
| AI の事業者 | 文化庁「考え方」✅ | 主体は原則「AI 利用者」。事業者は、侵害物が高頻度で出る、防ぐ措置を取らない場合に主体と評価されやすい。幇助はビデオメイツ（最判平成 13 年 3 月 2 日）の注意義務の型 | CharaTime は AI ではないがプロンプトを組み立てる。STYLE LOCK と固有名詞の注意は「防ぐ措置」に当たる 🔷 |

- 結論 🔷: 端末内だけで動き、サーバーを持たず、既存キャラへの誘導が無い限り、開発者が主体・幇助者とされる可能性は低い。上げる要素は (a) 既存キャラ名を例・テンプレートに入れる、(b)「推しのキャラを動かそう」と誘う、(c) サーバーで変換・保管・中継する、(d) 配布・交換の場を作る、の 4 つ。

### 3.3 書き出したファイルを他人に渡す場合

- 30 条の範囲は「個人的に又は家庭内その他これに準ずる限られた範囲」✅。友人に渡すのはふつうこの外 🔷（文化庁のいう「閉鎖的な私的領域」✅ の外）。チェックリスト 4-1-4 も「複製物の譲渡等」は範囲外となる場合が多いとする ✅。
- 49 条 1 項 1 号: 30 条 1 項などの目的以外のために、その適用を受けて作った複製物を「頒布し、又は当該複製物によつて当該著作物の公衆への提示…を行つた者」は複製を行ったものとみなす ✅。「頒布」は「複製物を公衆に譲渡し、又は貸与すること」（2 条 1 項 19 号）、「公衆」には「特定かつ多数の者を含む」（2 条 5 項）✅。
- 当てはめ 🔷:
  - 中身が自作のオリジナル（既存作品と似ていない）なら、著作権の問題は生じない（類似性がなければ許諾は不要、4-1-5 ✅）。
  - 既存キャラに似た画像や他人の絵が入っていると、1 人に渡すだけでも、渡すための写し（相手の端末にできるファイル）は私的使用の範囲外の複製になりうる。多数に配れば頒布・公衆送信の問題になる。
  - 実在の人の写真は肖像の問題がある（本調査の範囲外、**未確認**）。
- 開発者の対策 🔷: 書き出しは「引っ越し用」と名付け、注意書きを出す。アプリ内に送り先の選択や配布の場を作らない。
- 「自分の端末でしか開けない」ようにする案 🔷: iCloud キーチェーンで同期する鍵（iOS 14 以降は暗号鍵も同期する ✅）でファイルを暗号化すれば、同じ Apple アカウントの端末でしか開けない。ただし iCloud キーチェーンが切なら開けない、鍵を失うと戻せない、暗号の輸出規制の回答が要る（OS の暗号でも年末の自己分類報告が要る場合がある ✅）。**既定では入れず、必要になったら検討する。**
- 機種変更そのものは、iCloud バックアップと iPhone どうしの転送でアプリのデータが移る（"it periodically creates a backup of the user’s device, including your app’s data" ✅。App Group も含まれるというのが Apple の技術サポートの見解 🔶）。書き出しは、バックアップを使わない移行や iPad への移し替えの補助になる 🔷。

### 3.4 そのほかの法令

- 商標法 2 条 1 項は「業として」使うものを商標とする ✅ → 利用者の私的な取り込みは商標の問題になりにくい 🔷。開発者の宣伝は「業として」なので、他社の名前を入れない。
- 情報流通プラットフォーム対処法の「特定電気通信」は「不特定の者によって受信されることを目的とする電気通信…の送信」✅ → サーバーも共有の場も無い CharaTime は対象外 🔷。共有を作ればこの法の枠（削除の申出への対応）に入る。
- AI 推進法（令和 7 年法律第 53 号）は国・活用事業者・国民の責務と協力を定めるだけで、AI 生成物の表示義務は無い ✅。

---

## 4. 生成 AI の規約（利用者が自分の契約で作る場合）

| 項目 | OpenAI（ChatGPT。利用規約 2026-01-01 発効） | Google（Gemini。利用規約 2026-07-30 発効、生成 AI 禁止ポリシー 2024-12-17） | Anthropic（Claude。消費者規約 2025-10-08、利用ポリシー 2025-09-15） |
|---|---|---|---|
| 出力の権利 | "you ... own the Output. We hereby assign to you all our right, title, and interest, if any, in and to Output." ✅ | "Google won’t claim ownership over that content." ✅ | "we assign to you all of our right, title, and interest—if any—in Outputs." ✅ |
| 別のアプリで自分用に使う | 禁じる条項は見当たらない 🔷 | 同 🔷 | 同 🔷 |
| 既存 IP | "Use our Services in a way that infringes, misappropriates or violates anyone’s rights." を禁止 ✅。利用ポリシー（2025-10-29）も知的財産の侵害の試みを禁止 ✅ | "Violates the rights of others, including privacy and intellectual property rights" を禁止 ✅ | "Infringe, misappropriate, or violate the intellectual property rights of a third party" を禁止 ✅ |
| 人が作ったと偽る | "Represent that Output was human-generated when it was not." を禁止 ✅ | "misleading others into thinking that generative AI content was created by a human" を禁止 ✅ | "Impersonate a human by presenting results as human-generated" を禁止 ✅ |
| 表示の義務 | SNS 投稿・出版は "Indicate that the content is AI-generated in a way no user could reasonably miss or misunderstand." ✅（共有・公開ポリシー）。自分用は定めなし 🔷 | 偽らない義務のみ。自分用は定めなし 🔷 | 表示義務は高リスクの用途と消費者向けチャットボットだけ ✅。自分用は定めなし 🔷 |
| 来歴の印 | 画像に C2PA と SynthID ✅ | SynthID と Content Credentials は常に付く。見える透かしは設定で消せる ✅ | 画像を作れない ✅ |
| 同じような出力 | "other users may receive similar output" ✅ | C §1.2 | — |

- 読み取れること 🔷: 自分で作った画像を CharaTime に取り込んで自分で眺めるのは、3 社の規約のどれにも反しない。表示の義務も無い。人に渡すなら「AI で作った」と言えるようにしておくのが安全（OpenAI の共有・公開ポリシーの趣旨、Google・Anthropic の偽らない義務）。
- Claude で「作る」なら、SVG などのコードを書かせてから PNG にする道になる 🔷。CharaTime は SVG を直接読まず、PNG・JPEG・HEIC だけを受ける（SVG は外部参照を含みうるため）🔷。

---

## 5. CharaTime への推奨

### 5.1 やること

1. 取り込みは `PhotosPicker` と `fileImporter` だけ。写真全体の許可を求めない（5.1.1(iii)）✅。
2. 処理はすべて端末内（Vision の前景マスク、§6.4 と同じ正規化）🔷。元画像は保存せず、切り抜いて作り直した PNG だけを App Group の `images/` に置く（Exif・位置情報・C2PA が残らない）🔷。
   - プランでの扱い（v1.4、§9 Phase 2 の 2-C ③）: 置き場はキャラごとのフォルダ `characters/<id>/` にした。元の画像はこの項のとおり残さない（整え直すときは写真やファイルから選び直す）。
3. 取り込み・書き出し・読み込みの 3 画面に §5.4 の注意書き。初回だけ全文、2 回目からは 1 行 🔷。
4. プロンプトを組み立てるときは STYLE LOCK（"Original mascot character ... NOT based on any existing brand or character."、プラン §6.3）を必ず先頭に置く。説明欄に作品名・キャラ名らしい語があれば「似やすくなります」と 1 行出す（止めはしない）🔷。例文は自作キャラ（Piyo など）だけ。
5. 書き出しファイルは「引っ越し用」と名付け、中身は `Codable` の型ひとつから作る JSON と PNG だけ。独自の UTType を exported type で宣言し、`public.content` に準拠 ✅。
6. 読み込みは信頼しない入力として扱う: 形式・版・枚数・画素数・ファイルの大きさに上限を置き、`Codable` で形を検査し、失敗は理由付きで断る。ウィジェットが読むのは小さい mini だけにして、拡張のメモリ（約 30 MB）を守る 🔷（CLAUDE.md「拡張を落とさない」）。
7. 取り込んだ画像は iCloud バックアップに入る場所に置く（Caches に置かない。Apple も、利用者が取り込んだファイルは作り直せないのでバックアップから外すなと書く ✅）。
8. 確かめ方: 機内モードで取り込み→書き出し→読み込みが通る。「App プライバシーレポート」（設定 → プライバシーとセキュリティ）の「App のネットワークアクティビティ」に CharaTime の通信先が出ない ✅。

### 5.2 やらないこと（避ける機能）

| 機能 | 理由 |
|---|---|
| アプリ内のギャラリー・共有・ランキング・いいね・コメント | 1.2 の 4 要件・EULA・24 時間の対応、年齢区分の UGC・SNS（13+）✅ |
| 「友だちに送る」ボタン、URL・QR コードからの読み込み、配布サイトへの案内 | 引っ越し以外の用途を促し、5.2.3・49 条の論点に近づく 🔷 |
| 開発者のサーバーでの変換・保管・中継、独自のクラウド同期 | ロクラク II・まねき TV・自炊代行の構図。プライバシー表示と 5.1.2 の義務が増える ✅/🔷 |
| アプリから生成 AI の API を呼ぶ | 決定どおり。5.1.2(i) の同意と API キーの管理が要る ✅ |
| 書き出しファイルにスクリプト・動きの台本を入れる | 2.5.2、4.7 ✅ |
| 他社キャラを使った例・スクショ・キーワード・宣伝文句（「推しを動かせる」など） | 5.2.1・2.3.7・4.1(c) ✅。誘導は開発者の責任を上げる 🔷 |
| 写真ライブラリ全体の許可 | 5.1.1(iii) ✅ |
| 取り込んだ画像への自動の「不適切判定」 | 本人しか見ないので要らない。誤判定の不満のほうが大きい 🔷 |

### 5.3 Local First を保つ設計（プラン §3.6 の原則に沿う）🔷

- 置き場: UGC の画像は App Group の `images/`、キャラは `characters.json` に `origin: .user` で足す（プラン §7 のとおり）。キャラを消せば画像も片づけで消える。→ プラン v1.4 では、キャラごとのフォルダ `characters/<id>/`（`character.json` と絵）に改めた。キャラを消すとフォルダごと消える。
- 通信: キャラ工房のコードに `URLSession` を入れない。解析・広告・クラッシュ収集の SDK も入れない（→「データの収集なし」）。
- 共有: OS に任せる（`ShareLink` と共有シート）。アプリは送り先を持たない。
- 引っ越し: まず iCloud バックアップと iPhone どうしの転送に任せ、書き出しは補助にする。

### 5.4 注意書きの文案（日本語）

**取り込み画面（初回は全文）**

> **画像はこの iPhone の中だけで使います**
> 取り込んだ画像は、この iPhone の中で切り抜いて保存します。CharaTime がどこかに送ることはありません。
> 自分で作ったキャラや、自分で描いた絵を使ってください。アニメやゲーム、会社のキャラクターに似た画像は、自分で楽しむだけにして、人に渡したり公開したりしないでください。
> 画像生成 AI で作るときは、その AI の利用規約に従ってください。プロンプトに作品名やキャラクター名を入れないと、似すぎを避けやすくなります。

2 回目から: 「画像はこの iPhone の中だけで使います。自分で楽しむ範囲でどうぞ。」

**プロンプトをコピーする画面**

> オリジナルのキャラを作るためのプロンプトです。作品名やキャラクター名は入れないでください。

**書き出し画面**

> **別の iPhone や iPad に引っ越すためのファイルです**
> このキャラの画像と設定が、そのまま 1 つのファイルに入ります。
> 機種変更なら、iCloud バックアップや iPhone どうしの転送で、ふつうはそのまま引き継がれます。
> 人に渡すと、あなたの手を離れて広がることがあります。既存のキャラクターに似た画像、ほかの人が描いた絵、実在の人の写真が入っているキャラは、人に渡さないでください。

**読み込み画面**

> 自分で書き出したキャラのファイルを読み込みます。人から受け取ったファイルは、作った人が渡してよいとしたものだけにしてください。

**設定・ヘルプ（常設）**

> キャラ工房の画像は、この端末の中にだけあります。アプリを削除すると消えます。

### 5.5 公開するときに追加で要るもの

1. **プライバシーポリシー**: URL は iOS アプリで必須 ✅、アプリ内からも開けること（5.1.1(i)）✅。書くこと 🔷: 集める情報は無い／取り込んだ画像は端末内で処理・保存し、送らない／書き出しは利用者の操作で OS の共有に渡す／消し方（キャラの削除、アプリの削除）／解析・広告なし／連絡先。
2. **サポート URL**: 実際の連絡先につながること ✅。
3. **App プライバシー**: 「データの収集なし」。解析・クラッシュ収集の SDK を入れない前提。Apple が集めるクラッシュは開示しなくてよい ✅。
4. **プライバシーマニフェスト**（`PrivacyInfo.xcprivacy`）: App Group の `UserDefaults` は理由 `1C8F.1`、App Group 内のファイルの日付・大きさに触れるなら `C617.1`、利用者が選んだファイルなら `3B52.1` ✅。トラッキングなし。
5. **年齢区分の回答案** 🔷（→ 4+ の見込み）:

| 質問 | 回答 | 理由 |
|---|---|---|
| Parental Controls / Age Assurance | なし | 機能が無い |
| Unrestricted Web Access | なし | ブラウザを持たない |
| User-Generated Content | なし | 取り込みは本人の端末だけで、broad distribution ではない（定義 ✅） |
| Social Media（2026-09 から必須） | なし | フィードも発見の仕組みも無い |
| Messaging and Chat | なし | 利用者どうしの連絡が無い |
| Advertising | なし | 広告なしの方針 |
| Mature Themes / Sexuality / Violence | なし | 同梱の絵に無い。取り込んだ絵はアプリの内容ではない 🔷 |
| Medical or Wellness | なし | 歩数に合わせて「歩こう」などと勧めるなら "Health or Wellness Topics"（9+）に当たりうる 🔷 |
| Chance-Based（ガチャ・コンテスト） | なし | D §6.5 の方針 |

6. **審査メモ**（App Review Information の Notes）の文案 🔷:
   > The Character Workshop lets users import images they made themselves (for example with their own image-generation tools, or drawings). All processing happens on-device; nothing is uploaded, and there is no gallery, feed, or sharing between users inside the app. The export button only creates a file for moving the user's own characters to their other devices through the system share sheet.
7. **配信地域**: まず日本だけにすれば、Texas SB2420 などの州法の対応が要らない 🔷。

### 5.6 将来、人に見せる機能を作るなら（参考）

- 1.2 の 4 要件、EULA（不適切なコンテンツと利用者を許さないと明記）、24 時間以内の削除（審査の文面 🔶）、年齢区分の UGC・SNS（13+）✅、クリエイター型なら 1.2.1(a) の年齢制限 ✅、情報流通プラットフォーム対処法の対象 ✅、著作権侵害の申出の窓口、画像の事前判定（Sensitive Content Analysis は DPLA 3.3.3(N) の条件 ✅）。個人の規模では重い 🔷。

---

## 6. 未確認事項

1. 端末内だけの取り込み・OS の共有での書き出しを 1.2 の外とする Apple の明文（見つからなかった）。
2. §2.9 のアプリが通報・ブロックを持つか、審査で何を指摘されたか。
3. App Group の中身が iCloud バックアップ・iPhone どうしの転送で確実に移るか（Apple の技術サポートの 2021 年の見解のみ。取り除いた（オフロードした）アプリで戻らない不具合の報告もある 🔶）→ 実機で確かめる。
4. Vision の前景マスクがネットワークを使わないことの公式の明記（→ 機内モードで確かめる）。
5. クラウドの生成 AI での生成を「その使用する者が複製」と言えるか（事業者が物理的な主体とされる場合の 30 条の扱い。判例なし）。
6. 友人 1 人に渡す行為の 30 条・49 条上の扱いを直接示した判例。
7. 取り込んだ他人の絵を切り抜いて動かすことと同一性保持権（20 条）の関係（私的な改変の扱いは学説が分かれる 🔷）。
8. OpenAI の共有・公開ポリシーの改定日（ページに日付が無い）と、ファイルを 1 人に渡す行為に及ぶか。
9. Gemini の見える透かしの設定が日本の無料プランで表示されるか（ヘルプの文面では出る）。
10. 暗号化案の輸出規制の区分（OS の暗号だけで免除か、自己分類報告が要るか）。
11. 肖像権・パブリシティ権（実在の人の写真の取り込みと受け渡し）。
12. 令和 8 年法律第 37 号（学校教育法等の改正）が著作権法のどの条を変えたか（題名から学校関係と見て、本文は読んでいない）。

---

## 7. 出典一覧（確認日: すべて 2026-09-26）

### Apple（ガイドライン・ニュース・App Store Connect）✅
- App Review Guidelines（Last Updated: June 8, 2026）https://developer.apple.com/app-store/review/guidelines/
- Updated Apple Developer Program License Agreement and App Review Guidelines now available（2026-06-08）https://developer.apple.com/news/?id=a233fmpw
- Updated App Review Guidelines now available（2026-02-06）https://developer.apple.com/news/?id=d75yllv4 ／（2025-11-13）https://developer.apple.com/news/?id=ey6d8onl
- Latest News（Age rating questionnaire now includes social media questions 2026-07-09、Update for Apps Distributed in Texas 2026-06-03）https://developer.apple.com/news/
- Age ratings values and definitions https://developer.apple.com/help/app-store-connect/reference/age-ratings-values-and-definitions/
- App privacy details https://developer.apple.com/app-store/app-privacy-details/
- App information（Privacy Policy URL）https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/ ／ Platform version information（Support URL）https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/

### Apple（ドキュメント・サポート）✅
- Delivering an enhanced privacy experience in your photos app https://developer.apple.com/documentation/photokit/delivering-an-enhanced-privacy-experience-in-your-photos-app
- PhotosPicker https://developer.apple.com/documentation/photosui/photospicker ／ PHPickerViewController https://developer.apple.com/documentation/photosui/phpickerviewcontroller
- Defining file and data types for your app https://developer.apple.com/documentation/uniformtypeidentifiers/defining-file-and-data-types-for-your-app
- Optimizing your app’s data for iCloud Backup https://developer.apple.com/documentation/foundation/optimizing-your-app-s-data-for-icloud-backup
- NSPrivacyAccessedAPITypeReasons https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons
- kSecAttrSynchronizable https://developer.apple.com/documentation/security/ksecattrsynchronizable ／ Complying with encryption export regulations https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations
- VNGenerateForegroundInstanceMaskRequest https://developer.apple.com/documentation/vision/vngenerateforegroundinstancemaskrequest
- About App Privacy Report https://support.apple.com/en-us/102188
- 🔶 フォーラム: 1.2 の却下（2025-11）https://developer.apple.com/forums/thread/807358 ／ https://developer.apple.com/forums/thread/688227 ／ App Group のバックアップ（2021）https://developer.apple.com/forums/thread/693766 ／ オフロード時の不具合 https://developer.apple.com/forums/thread/95343

### App Store（iTunes Lookup API と製品ページ）✅
- 推しアイランド https://apps.apple.com/jp/app/id6751716346 （規約 https://tsuzukit.com/legal/terms-of-service.html 、プライバシー https://tsuzukit.com/legal/privacy-policy.html ）
- いつでもマイペット https://apps.apple.com/jp/app/id6762539983 ／ おしデコ https://apps.apple.com/jp/app/id6752970703 ／ 推し活アプリ Oshibana https://apps.apple.com/jp/app/id1581399897 ／ Peta https://apps.apple.com/jp/app/id6790650954 ／ Photo Widget — The Best One https://apps.apple.com/us/app/id1532588789
- Lookup API https://itunes.apple.com/lookup?id=6751716346,6762539983,6752970703,1581399897,6790650954&country=jp

### 法令・文化庁・判例 ✅
- 著作権法 https://laws.e-gov.go.jp/law/345AC0000000048 （本文は e-Gov 法令 API https://laws.e-gov.go.jp/api/1/lawdata/345AC0000000048 、改正履歴 https://laws.e-gov.go.jp/api/2/law_revisions/345AC0000000048 ）
- 商標法 https://laws.e-gov.go.jp/law/334AC0000000127 ／ 情報流通プラットフォーム対処法 https://laws.e-gov.go.jp/law/413AC0000000137 ／ AI 推進法 https://laws.e-gov.go.jp/law/507AC0000000053
- 文化庁「AI と著作権に関する考え方について」（2024-03-15）https://www.bunka.go.jp/seisaku/bunkashingikai/chosakuken/pdf/94037901_01.pdf
- 文化庁「AI と著作権に関するチェックリスト＆ガイダンス」（2024-07-31）https://www.bunka.go.jp/seisaku/chosakuken/pdf/94097701_01.pdf
- 文化審議会 参考資料「私的使用目的の複製に係る権利制限について」https://www.bunka.go.jp/seisaku/bunkashingikai/chosakuken/hoki/h30_06/pdf/r1411529_06.pdf
- 文化庁「令和 8 年特別国会 著作権法改正について」https://www.bunka.go.jp/seisaku/chosakuken/hokaisei/r08_hokaisei/index.html
- ロクラク II https://www.courts.go.jp/assets/hanrei/hanrei-pdf-81015.pdf ／ まねき TV https://www.courts.go.jp/assets/hanrei/hanrei-pdf-81012.pdf ／ Winny https://www.courts.go.jp/assets/hanrei/hanrei-pdf-81846.pdf ／ 音楽教室 https://www.courts.go.jp/assets/hanrei/hanrei-pdf-91473.pdf
- 🔶 ときめきメモリアル https://ipforce.jp/Hanketsu/jiken/no/10724 ／ 自炊代行 https://www.thomsonreuters.co.jp/ja/westlaw-japan/column-law/2015/150105/ ／ クラブキャッツアイ https://chosakukenhou.jp/club-cats-eye-karaoke-doctrine-case

### 生成 AI の規約 ✅
- OpenAI Terms of Use（2026-01-01。直接の取得は 403 のため r.jina.ai 経由）https://openai.com/policies/row-terms-of-use/
- OpenAI Sharing & publication policy https://openai.com/policies/sharing-publication-policy/ ／ Usage policies（2025-10-29）https://openai.com/policies/usage-policies/
- OpenAI Help: Provenance signals https://help.openai.com/en/articles/8912793-c2pa-in-chatgpt-images
- Google Terms of Service（2026-07-30）https://policies.google.com/terms ／ Generative AI Prohibited Use Policy（2024-12-17）https://policies.google.com/terms/generative-ai/use-policy ／ Generative AI Additional Terms（2024-05-22 以降は企業の個別契約を除き非適用）https://policies.google.com/terms/generative-ai
- Gemini Apps Help: Manage watermark settings https://support.google.com/gemini/answer/17405358 ／ 🔶 TechCrunch（2026-08-14）https://techcrunch.com/2026/08/14/google-will-now-allow-users-to-remove-visible-watermark-from-its-ai-generations/
- Anthropic Consumer Terms（2025-10-08）https://www.anthropic.com/legal/consumer-terms ／ Usage Policy（2025-09-15）https://www.anthropic.com/legal/aup
- Claude Vision docs（生成不可の FAQ）https://platform.claude.com/docs/en/build-with-claude/vision

### 報道 🔶
- MacRumors（2026-06-09）https://www.macrumors.com/2026/06/09/app-store-guidelines-low-quality-apps/
- 9to5Mac（2026-06-09）https://9to5mac.com/2026/06/09/apple-tightens-app-review-guidelines-against-apps-that-do-not-add-value-to-the-app-store/
