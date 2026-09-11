# 担当 D: 先行アプリ・市場・審査ガイドライン・法務・収益化 調査レポート

- 作成日: 2026-09-10（すべての出典は同日に確認）
- 対象プロジェクト: CharaTime（iPhone のホーム画面／待受でキャラクターが自律的に動き回るアプリ。au ガラケー時代「ケータイパートナー（β版）」の現代的再現）
- 確信度の凡例: ✅ 一次情報で確認（公式ページ・App Store・法令原文等） / 🔶 二次情報（記事・推計データ・レビュー要約） / 🔷 推測・一般知識（要追加確認）
- 調査手段: WebSearch 約 60 回、WebFetch 約 55 回、iTunes Search API（apps.apple.com の JP/US ストア実データ）、TMview（EUIPO 商標横断検索 API、JPO データ含む）、Google Play HTML、Wikipedia raw

---

## 0. 要約

1. iOS には「他アプリやホーム画面の上をキャラが歩き回る」API は存在せず（Android の overlay 権限に相当するものがない）、先行アプリはすべて **ウィジェット／Live Activity（Dynamic Island・ロック画面・StandBy）／アプリ内** に閉じている。唯一「ホーム画面の上に浮く」手段は **PiP（AVPictureInPictureController）** で、非動画コンテンツ（時計・メモ・テキスト）の PiP アプリが 2021 年から審査を通過し 2026 年も更新中 ✅。ペット用途の PiP アプリの却下事例は見つからなかった（=承認事例も未確認）🔶。
2. 市場のトップは Widgetable（US 38 万件 ★4.92、Google Play 5000 万 DL）、Pixel Pals（US 3.7 万件 ★4.58、2023 年時点で約 5 万サブスク・四半期売上約 62.5 万ドル推計）、iScreen（US 15 万件）。共通する不満は **「広告が多すぎる」「課金しないと何もできない」「動きが少ない／観るだけ」「アプリの外では動かない」「データ消失」** ✅。
3. 「Shimeji を iPhone で」という需要は明確に存在する（偽アプリ「Shimeji Screen Pets」が ★1.8 でも 225 件評価、Mooshi は 1.6 万件、脱獄ツール Shijima の登場、知恵袋の質問）✅🔶。
4. 直系の先祖は docomo「マチキャラ」（2007〜、待受でキャラが動き回り着信に反応・成長）と au「ケータイパートナー（β版）」（2009-03-19〜2011-04-27、アドレス帳・着信履歴・季節に連動して人格を演出）→「au one キャラタイム」（2011-04-14〜、Flash 待受、1 タイトル 315〜525 円、HELLO KITTY 等）✅。
5. デスクトップマスコット（ペルソナウェア 1998 → 伺か 2000 → Shimeji 2009 → Desktop Goose 2020 → Bongo Cat 2025）から得られる設計知見は「本体／人格／外見の分離」「ユーザー文脈（時間・季節・イベント）への反応」「低頻度のランダムイベント」「いたずら＝主体性」「収集コスメ課金は薄利」✅🔶。
6. 審査: 2.5.4（バックグラウンドは本来目的のみ）、2.5.16（ウィジェットはアプリ機能と関連必須）、4.2（最小機能）、1.2（UGC の 4 要件）、5.1.2(i)（第三者 AI へのデータ共有は明示的同意、2025-11-13 改定）、3.1.1（ガチャは確率開示必須）、新年齢区分 4+/9+/13+/16+/18+（2025-07-24 導入、2026-01-31 回答期限）✅。ウィジェット更新は 1 日 40〜70 回が目安、アニメーションは予算外 ✅。Live Activity は「始まりと終わりがあるもの、8 時間以内」が HIG の建前 ✅（Pixel Pals は常時ペット表示で承認されている実績あり）。
7. 収益: 相場は月 200〜500 円／年 1,500〜3,000 円／買い切り 2,000〜8,000 円。日本のレビューは「サブスク一択」に厳しく、**買い切り＋非消耗型アイテム（家具・小物）＋キャラ追加パック** が筋。有償アプリ内通貨は資金決済法（前払式支払手段、未使用残高 1,000 万円超で届出・供託）の対象になり得るため、初期は導入しない。コンプガチャは景表法で全面禁止 ✅。
8. 法務: 「サンリオ風」は**作風（アイデア）であれば著作権侵害にならない**が、特定キャラの本質的特徴を直接感得させる類似は侵害（ミッフィー vs キャシー事件ではサンリオ自身が差止を受けた）✅。マーケティングで「サンリオ」の語を使うのは不正競争防止法（著名表示冒用）・商標・App Store 4.1(c) の観点で避ける。AI 生成キャラは著作権が生じない可能性があるため、**商標登録で守る**（特許庁 2025-06-19 資料: AI 生成でも通常どおり登録可）✅。
9. 商標「キャラタイム」: JPO に **ネオス株式会社の登録 5269867（第 9・41 類、2009-10-02 登録）が存在したが TMview 上は「Expired（2019-10-02 満了）」** ✅。KDDI 名義の「キャラタイム」は見当たらず、「CHARATIME」は JP/US/EU/WO/GB いずれもヒットなし ✅。App Store にも同名アプリなし ✅。ただし J-PlatPat での最終確認が必要（未確認事項参照）。
10. ポジショニング提案: 「お世話ゲーム」ではなく **「待受に住んでいる相棒」**。部屋・アイテム・自律行動（時間帯・天気・カレンダー連動）でガラケー待受の体験を再現し、広告なし・買い切り中心・30〜40 代の「当時のユーザー」と「かわいいもの好き」を狙う。iOS 26/27 で Live Activity が StandBy 横向き・Apple Watch・Mac メニューバー・CarPlay にも出るため「どこにでもついてくる」が訴求点になる ✅。

---

## 1. 先行アプリ一覧

### 1.1 ペット／キャラ系（iOS、2022〜2026）

評価は iTunes Search API の実データ（2026-09-10 取得、US = 米国ストア、JP = 日本ストア）。価格は App Store ページの IAP 一覧 ✅。

| 名前（開発者・国） | 実現方式 | 動きの表現 | 価格 | 評価（件数）・更新 | 学び |
|---|---|---|---|---|---|
| **Pixel Pals Widget Pet Game**（Christian Selig・カナダ） | ホーム／ロック画面ウィジェット、Live Activity（Dynamic Island・ロック画面）、StandBy、インタラクティブウィジェット（iOS 17）、watchOS Live Activity | ドット絵アニメ。DI 内で常時アニメ、ウィジェットも「アニメする」と評される（手法は非公開 🔶） | 無料（犬・猫）＋Premium 月 $1.99／年 $14.99／買い切り $49.99、餌パック $0.99〜4.99。JP: 月 ¥240／年 ¥2,200／買い切り ¥8,000 | US ★4.58（36,687）JP ★4.47（1,004）。v2.0.21 2025-11-11「iOS 26 fixes」 | 個人開発で最大の成功例。不満は「ペイウォール」「プレミアム催促」「観るだけ」「電源断でデータ消失」。詳細は 1.4 |
| **Widgetable: Besties & Couples**（Widgetable Inc./HAPPENY・シンガポール系） | ホーム／ロック画面ウィジェット（友人・カップルと共同育成、距離・睡眠・気分）、Pet Town | ウィジェット内の状態更新（静止画切替中心） | 無料＋Premium 月 $4.99（割引 $1.99）／年 $19.99、餌・卵・ダイヤ $0.99〜4.99。JP: 月 ¥300〜、ダイヤ ¥150〜800。広告多数 | US ★4.92（383,849）JP ★4.91（3,029）。Google Play 5000 万＋ DL ★4.8（558K）。2026-09-04 更新 | 「ソーシャル×ペット」で最大手。不満: 「餌 1 個に 100 秒広告」「Pay-to-win」「ウィジェットが真っ黒」「未成年に不適切な広告」。年齢 12+/13+ |
| **iScreen - Widgets & Wallpaper**（Xiamen ShenZhuo・中国） | ウィジェット・壁紙・Dynamic Island「Pet Island / Plant Island / Animation Island」、音付きインタラクティブウィジェット | DI 内アニメ、GIF ウィジェット | 週 $1.99／月 $7.99／年 $19.99／永久 $23.99 | US ★4.74（149,343）JP ★4.62（56,908）。2026-08-31 更新 | 「起動のたびに広告」「GIF ウィジェットが空白」が不満。無料でも使えることを評価する声 |
| **LockWidget - LockScreen Themes**（SoCloud・香港） | ロック画面のピクセルペット（餌やり・遊び） | 静止画切替 | 週 $1.99／月 $6.99／年 $19.99／買い切り $29.99 | US ★4.50（27,701）JP ★4.41（1,204）。2026-08-04 更新 | 「操作のたびに広告」。レビューに「Hello Kitty がある唯一のアプリ」（ライセンスの有無は不明 🔷）→ キャラ IP 需要の証拠 |
| **Mooshi - Ah Shimeji**（Tekeltoglu Doruk） | アプリ内で最大 6 体が歩く・座る・登る・寝る・飛ぶ・転がる、ホーム画面ウィジェット、Live Activity（DI） | アプリ内はフル 2D アニメ、ウィジェット／DI はコマ表示 | 週 $1.99／月 $3.99／年 $6.99 | US ★4.22（16,095）JP ★3.70（23）。2026-01-08 更新、年齢 17+/18+。Android 版 50 万＋ DL ★3.8 | 不満:「アプリ内かウィジェットにしか出ない（ホーム画面を歩くと思った）」「ボタンごとに広告」「Vox/Alastor 等の他社キャラを広告に使う虚偽」。**Shimeji 需要と iOS の限界を同時に示す** |
| **Shimeji Screen Pets**（Shamus Ul Hayatam） | 実態は静止画を壁紙として書き出すだけ | 動かない | 無料 | US ★1.84（225）。2026-01-23 公開 | 「歩き回る」と謳って 225 件も評価が付く＝**期待の大きさ**。同開発者の「Kawaii & Anime Shimeji Screen」★3.93（138） |
| **Pixel Shimeji: My Digital Pets**（Sihoooo・中国） | ホームウィジェット（時計・天気・カレンダー兼用）、Dynamic Island（触覚付き）、アプリ内 | ドット絵アニメ、振ると寝る等のジェスチャ | 週 $1.99／年 $12.99／買い切り $17.99 | US ★4.76（3,739）JP ★4.66（93）。2026-07-16 更新 | 「楽しい要素は有料」「DI が起動しないことがある」「★5 評価でデザート解放（審査グレー）」 |
| **Pixel Pets - Homescreen Widget**（PassiFlora） | ホーム／ロック画面ウィジェット（走る・歩く・寝る） | 静止画切替 | 月 $1.99／年 $9.99／買い切り $48.99 | US ★4.38（151）。最終更新 2024-05-07（放置） | レビュー「**他のアプリを使っている間も画面下にペットを見たい**」→ 需要の一次証拠 |
| **Pixel Pets - Cute, Widget, App**（Twinstar Creatives） | ロック画面・Dynamic Island・Live Activity | コマアニメ | 無料＋IAP | US ★4.69（5,043）。2025-02-06 更新 | 8 種のペット。DI 系の中堅 |
| **Pixel Pet Widget: Island Pet**（雪萍 雷） | ロック画面・DI・Live Activity | コマ表示 | 無料＋IAP | US ★4.49（3,066）JP ★4.33（161）。最終更新 2023-12-02（放置） | DI ブームに乗った短命アプリの典型 |
| **Cute pet: Self care pet widget**（静 刘） | DI・ホーム／ロック画面ウィジェット、起床・就寝の挨拶、水分・座りすぎリマインド | 状態切替 | 無料＋IAP | US ★4.59（4,475）JP ★4.29（49）。2026-06-18 更新 | 「生活リズム連動」は自律行動の参考 |
| **Care Pet Game - Screen Widget**（LeoStudio Global） | ホーム／ロック画面ウィジェット、壁紙、卵孵化 | 静止画切替 | 週 $1.99〜2.99／月 $4.99／ダイヤ $0.99〜9.99 | US ★4.73（1,209）。2026-07-29 更新 | 「孵化に 24 時間」「広告が出ず宝石が稼げない」 |
| **Mochi Pets - Cute Pet Widget**（Dillon Mok・個人） | ホームウィジェットで暮らすペット、StandBy 対応、ティントアイコン対応 | ドット絵アニメ | 無料＋IAP | US ★4.07（216）。2025-07-10 更新 | 個人開発の中規模例。11 種の動物に個性と好物 |
| **Boko: Tamagotchi Virtual Pet**（個人、2026-03 公開） | ホームウィジェット・DI・ロック画面、カスタムペット | 状態表示 | 無料＋IAP | US ★4.79（19）。2026-06-13 更新 | 2026 年になっても新規参入が続く＝ジャンルは生きている |
| **NotiSprite**（BXQ.AI、2025-10 公開、日本語対応） | アニメ付きホームウィジェット＋DI／Live Activity、通知メッセージ | 「なめらかで可愛いアニメーション」 | 無料＋IAP | JP ★5.0（1）。2026-08-09 更新 | 「ログイン不要・データ収集なし・広告なし」を前面に出す訴求は CharaTime にも有効 |
| **veyebes — 育成ウィジェットペット**（Timofei Surkov、日本語対応） | ウィジェットの「目」が 5 秒ごとに別方向を見る | 低頻度アニメで「生きている感」 | 無料 | JP 評価なし。2026-08-28 更新 | **ウィジェット予算内で「常に動いている」錯覚を作る**好例 |
| **WidPet - Pet on widget**（Viet Hoang） | ウィジェット上で育成、部屋のカスタマイズ | 静止画切替 | 月 $1.99 | US ★4.51（78）。2025-09-18 更新 | 「部屋」要素を持つ数少ない例 |
| **OuO cute pet**（2026-01 公開） | アプリ内で触ると反応する顔＋ホームウィジェット、音声コマンド | リアクション中心 | 無料＋IAP | US ★4.28（400）。2026-09-02 更新 | 「触る→反応」の気持ちよさに特化 |
| **Steve \| Widget Dinosaur Game**（Calm Sea・スペイン、2016〜） | 通知センター／ウィジェットで遊ぶランナー | ゲーム | 無料＋IAP | US ★4.58（128,772）。2026-07-14 更新 | **ウィジェット中心アプリでも 10 年続き審査も通る**証拠 |
| **WidgetKit: Widgets & Wallpaper（iStandBy pet）**（CEM Software） | StandBy 向けペットウィジェット・テーマ | 静止画 | 週 $4.99／月 $9.99／年 $29.99／StandBy 買い切り $39.99 | US ★4.16（222）。2026-03-18 更新 | 「広告だらけ」「分かりにくい」。StandBy 単体では弱い |
| **Peridot**（Niantic → Niantic Spatial・米国） | AR ペット（AI 駆動の行動）、アプリ内のみ。ウィジェットは確認できず 🔷 | フル 3D | F2P＋IAP | 2023-05-09 世界配信 → 2026-04-23 終了告知、2026-05-14 ストア削除、2026-08-31 サーバ停止 | 「常時 AR を維持するコストが巨大」が終了理由。**高コスト技術×F2P は個人・小規模では持たない**教訓 |
| **My Tamagotchi Forever／マイたまごっち**（Bandai Namco Europe） | アプリ内育成。ウィジェットなし 🔷 | フル 2D | F2P | US ★4.59（28,303）JP ★4.34（23,489）。2025-11-19 更新 | 老舗 IP でも「ホーム画面に出る」体験は提供していない＝空白地帯 |

### 1.2 日本のホーム画面カスタマイズ／透過ウィジェット層（追加調査項目 1）

| 名前（開発者） | 内容 | 価格 | 評価（件数） | レビュー傾向 |
|---|---|---|---|---|
| **WidgetClub**（Liume, Inc.・日本） | 壁紙・アイコン・ウィジェットを一括着せ替え。4,500 テンプレ超。たまごっち公式コラボ（2024-01-13 発売、680 円、GIF ウィジェットで「ピコピコ動く」）✅ | 月 ¥980／年 ¥2,700／買い切り ¥9,800〜15,000、テンプレ単品 ¥480〜2,000 | JP ★4.65（71,457）US ★4.69（2,399）。2026-09-09 更新 | 「使えるテンプレはほぼ有料」（開発者は「4,000 件中半分以上は無料」と返答）、「アイコンがショートカット経由で起動が遅い」「見た目だけ」。400 万 DL・プレミアム会員 10 万人超 🔶 |
| **フォトウィジェット**（Photo Widget Inc.・日本） | おしゃれ壁紙・アイコン着せ替え | 無料＋IAP | JP ★4.66（72,133）US ★4.65（167,691） | 日本発で US でも大きい |
| **Widgetsmith**（Cross Forward・米国） | 定番。写真・カウントダウン・天気・時間帯切替 | Premium ¥200〜¥5,000 の段階 | US ★4.61（769,854）JP ★4.62（141,237） | 日本語非対応への不満 |
| **Widgy**（Woodsign） | 高自由度のウィジェットエディタ | 無料＋IAP | US ★4.65（26,080）JP ★4.39（25,725） | 上級者向け |
| **・(Yidget) 透明Widget**（MoriRanMaru・個人） | 透過ウィジェット | 無料 | JP ★4.57（3,687） | 個人開発でも 3.7 千件 |
| **写真ウィジェット 時計カレンダー - Widgets SD**／**ショートカット アイコン着せ替え**（Daisuke Suzuki・個人） | 写真・時計・透過、アイコン着せ替え | 無料＋IAP | JP ★4.31（33,319）／★4.60（19,033） | **日本の個人開発者がこの層で数万件の評価を得ている**実例 |
| **Lodgety**（Yournet）／**MD Widget 動く壁紙**／**Mico**／**Color Widgets** | 透明ウィジェット・動く壁紙・テンプレ | 無料＋IAP | JP ★4.46（1,682）／★4.43（641）／★4.61（38,351）／★4.54（10,757） | 「動く壁紙（Live Photo）」も需要あり |
| **メモ帳 サンリオキャラクターズ（+ウィジェット）**（ArtsPlanet・日本、サンリオ公式承認 No.620037）| キティ・シナモン・プリン・キキララのメモウィジェット | 無料 | JP ★4.31（3,904）。2024-12-19 更新 | **サンリオが小規模開発者にもライセンスを出す**実例 |
| **ホームキャラ**（A PLUS ENTERTAINMENT、2025-04） | 声優ボイス付きバーチャルアシスタント、部屋背景・衣装着せ替え | 無料＋IAP | JP ★4.31（13） | 「部屋＋着せ替え＋キャラ」の直近例。商標「ホームキャラ」は A PLUS JAPAN が 2025-12-03 登録（第 9 類）✅ |
| **ウィジェット野球**（Narushi Nakai・個人、2026-07） | アプリを開かなくても 6:00〜21:00 に試合が進む「リアルタイム進行ウィジェット」 | 無料＋IAP | JP ★4.70（83） | **ウィジェット・ネイティブな時間進行設計**の国産例 |
| **PixelPot - 歩数で育てる植物**（Akihito Shimizu・個人、2026-02） | 歩数で育つ植物ウィジェット。銀・金のタネは **AI が一株ごとにユニークな絵を生成** | 無料＋IAP | JP ★4.78（9,812）。2026-09-09 更新 | **国産個人開発×ウィジェット×AI 生成ビジュアル**が既に審査を通り評価も高い。CharaTime の AI キャラ生成の前例 |

この層のユーザーは「ホーム画面をおしゃれに・自分らしく」（app-liv の 2026-08-27 更新記事は「色合い・フォント・絵柄を揃えた統一感」を推奨）✅。CharaTime のターゲットとして有望だが、**このジャンルの価格帯（月 ¥980 級のサブスク）には「有料だらけ」の不満が強い**ため、CharaTime は「無料で 1 キャラ＋部屋が完全に動く」「追加は買い切り」で差別化できる。

### 1.3 PiP・デスクトップ・Mac 系

| 名前 | 方式 | 価格 | 評価 | 備考 |
|---|---|---|---|---|
| **Floating Notepad -Overlay-／流れるメモ帳**（Ryo Tsudukihashi・日本、2021-12 公開） | PiP でメモを他アプリの上に浮かせる | 無料＋サポータープラン $2.49〜24.99 | JP ★4.25（471）US ★3.17（18）。2026-02-07 更新 | 「唯一、常に上に出せる」称賛 / 「PiP が勝手に消える」「ウィジェットが出ない」不満 |
| **PiP - Picture in Picture**（Supagarn Pattananuchart、2022-07） | 動画・写真・カメラ・PDF・**テキスト**の PiP | 月 $1.99／年 $9.99／買い切り $19.99 | US ★4.52（324）。2026-08-21 更新。年齢 16+/17+ | 非動画 PiP が継続承認されている証拠 |
| **Floatory: Floating Clock PiP**（亦彬 潘、2026-03） | 時計・日付・通信速度を PiP で常時表示 | 買い切り $29.99／月 $4.99／年 $14.99 | US ★5.0（3）。2026-08-06 更新 | 2026 年に新規で審査通過 |
| **Pets Therapy - Desktop Pets**（Csquared・Mac） | デスクトップ／ウィンドウ／メニューバーを歩く 75+ 匹 | 買い切り $12.99／年 $5.99 | 3.7（51、iOS 側の値） | Mac ではオーバーレイが可能。「フルスクリーンで消える」「重い」 |
| MenuBar Pets／xpet／Mac Pet（Mac） | メニューバー／ノッチに住む | — | — | 🔶 記事ベース。Mac の「ノッチペット」は iPhone の Dynamic Island ペットの兄弟 |

### 1.4 Pixel Pals 詳細（追加調査項目 3）

- 出自: Apollo（Reddit クライアント）の Dynamic Island 機能を切り出して 2022-10-24 に無料公開。Selig の告知ツイート「they're freeeeee」✅。Apollo は 2023 年に Reddit API 有料化で終了、Pixel Pals が本業化 🔶（TechCrunch）。
- 価格の経緯: 公開時は無料。2022-11-27 のレビューに「プレミアム催促が UI を覆う」とあり、公開 1 か月以内に Premium（月 $1.99／年 $14.99）が導入されていた 🔶。2023-09-21 v2.0 で大改修（インタラクティブウィジェット、StandBy、Morphs、農場、友達・バトル）。2023-10 Black Friday で月 $1.59／年 $11.99／買い切り $48.49 のセール ✅（バージョン履歴）。現在は買い切り $49.99（JP ¥8,000）。餌パック（消耗型 $0.99〜4.99）も併売 ✅。
- 収益: TechCrunch（2023-10-18、Appfigures 推計）: 累計 333 万インストール、約 5 万サブスクライバー、2023 年 7〜9 月の売上約 62.5 万ドル 🔶。mwm.ai の 2024-10 推計: 月 7 万 DL・月 3 万ドル 🔶（ピークからは減少）。
- 露出面の拡大: DI（2022-10）→ ホーム／ロック画面ウィジェット、Live Activity でロック画面を「走り回る」→ iOS 17 で StandBy・インタラクティブウィジェット（ゲーム・fidget spinner・言語学習 Pal・Trivia）→ iOS 18 でティントアイコン対応・watchOS Live Activity（2024-09）→ iOS 26 対応（2025-11-11）✅。
- レビューの不満（US、日付付き）: 「ほとんどのペットが有料」（2024-09）、「Morph はウィジェット経由でしか見られない」、「観る以外のインタラクションが薄い」（2023-07）、「電源が落ちると進捗が全消去、2023 年から直っていない」（2024-12）、「ペットが死んだ（端末リセット）」（2024-07）、「プレミアム催促と評価依頼が頻繁」（2022-11）、JP「ペットが勝手にリセット」✅。称賛: 「小さなたまごっち」「広告も強制課金もない」「ドット絵が可愛い」。
- 学び: (1) 無料で 2 匹＋広告なしという誠実な設計で 4.6 を維持、(2) 面の拡大（DI→ウィジェット→StandBy→Watch）を OS 更新ごとに続けたのが寿命の源、(3) **iCloud 同期の欠如によるデータ消失**が最大の長期不満、(4) 「観るだけ」への不満はあるが、それでも成功している＝**動きの量より「常にそこにいる」こと**が価値。

---

## 2. PiP を非動画に使った事例と審査

- App Store には非動画 PiP アプリが複数存在し、いずれも 2026 年に更新されている（Floating Notepad 2021-12 公開→2026-02 更新、PiP app 2022-07→2026-08、Floatory 2026-03 公開→2026-08）✅。つまり **「AVPictureInPictureController + AVSampleBufferDisplayLayer で任意の描画を PiP に流す」手法は審査上ブロックされていない**。
- Apple Developer Forums にはメモアプリ開発者が「Float Note（ユーザーが明示的に開始する PiP）は審査に通るか」と質問しているスレッドがあるが、Apple からの公式回答は取得できなかった 🔶。「Tips from App Review」（2025-12）にも PiP の言及なし ✅。
- ガイドライン本文に PiP の直接規定はない。関係するのは 2.5.4「Multitasking apps may only use background services for their intended purposes: VoIP, audio playback, location, task completion, local notifications, etc.」✅ と 2.4.2（無関係なバックグラウンド処理の禁止）✅。PiP はシステムが正規に提供する「動画再生の継続」機能なので、**「ユーザーが自分で開始・停止する視覚コンテンツ」である限り既存アプリと同じ扱い**と考えられる 🔷。
- ペット／キャラ用途で PiP を使うアプリの却下例・承認例はどちらも確認できなかった（Mooshi・Pixel Shimeji 等はいずれも PiP を使っていない）🔶。
- 実務上の注意（レビューから）: PiP ウィンドウが「勝手に消える」（Floating Notepad）、他の動画再生・通話で奪われる、Home 画面上にも浮くがホーム画面編集中は隠れる、バッテリー消費 🔷。**CharaTime では「お散歩モード（PiP）」をオプション機能に留め、審査ノートで「ユーザーが開始する、キャラ観賞のための表示」と説明**するのが安全。

---

## 3. Android との差と需要の証拠

### 3.1 技術差
- Android は `SYSTEM_ALERT_WINDOW`（「他のアプリの上に重ねて表示」権限）で他アプリの上にキャラを描ける。Google Play の Shimeji 系: 「Shimeji - desktop pet」50 万＋ DL ★3.1（2025-07 更新）、「Mooshi: Shimeji Screen Pets」50 万＋ DL ★3.8（2026-09-04 更新）、「Cute Shimeji」1 万＋ DL ★4.2 ✅。
- iOS には overlay API がなく、脱獄ツール **Shijima-iOS**（pixelomer、2024-08、iOS 14.0〜17.7.9、脱獄必須。サンドボックス版 ipa は機能限定）が「初のモバイル版」✅。ScreenRant（2023-08-01）は「Apple は third-party がホーム画面に物を置くことを許さない」と明記し、代替に My Tamagotchi Forever・Dogotchi を挙げるしかなかった ✅。

### 3.2 需要の証拠（iOS ユーザーが欲しがっている）
- Yahoo! 知恵袋（2021-04-05）「Shimeji という、設定したら画面上をキャラクターが動くみたいなアプリがあるらしいのですが探しても見つかりません」→ 回答は「Simeji はキーボードアプリ」✅（名前の混同が起きるほど認知されている）。
- App Store レビュー: Mooshi「アプリ内かウィジェットでしか出ない」（US 1.6 万件の評価を集めつつ）、Pixel Pets「他のアプリを使っている間も画面下にペットを見たい」、Shimeji Screen Pets（偽アプリ）が ★1.84 でも 225 件 ✅。
- TikTok に「Shimeji on iPhone Apple Screen Pets」のディスカバーページが存在 ✅（中身は取得不可）。
- Reddit／X の個別投稿は本環境からアクセス不可のため未確認（→ 9 章）。
- 補足: 日本語圏では「Shimeji」より「Simeji（キーボード）」が圧倒的に強く、App Store 検索「しめじ」はキーボードしか出ない ✅。**CharaTime の ASO は「しめじ」ではなく「待ち受け／ホーム画面／キャラ／動く」で取るべき。**

---

## 4. デスクトップマスコットの系譜と設計知見

### 4.1 年表（✅ は一次／Wikipedia raw 等で確認）
| 年 | 作品 | 要点 |
|---|---|---|
| 1998-10 | ペルソナウェア（現 Chararina） | 「仮想人格エージェントを用いたヒューマン・マシン・インターフェース」。伺か作者・黒衣鯖人は「数日で全容が見えて飽きた」と述懐 ✅ |
| 2000-05-25 | 伺か（偽ペルソナウェア／MATERIA→SSP） | ベースウェア／ゴースト（人格・語彙）／シェル（外見）の分離。2 体の掛け合い、ランダムトーク、メール着信確認、NTP、ToDo、ヘッドラインセンサ、マウスいたずら。ユーザー制作ゴーストで 20 年以上継続（窓の杜 2022-04-20）✅ |
| 2007 | docomo **マチキャラ**（D903i〜、2008 年秋から iコンシェルの一部） | 待受画面・メニュー画面を **動き回り、着信・メール受信に反応し、成長** する。待受画像と別レイヤー。2D（アニメ GIF）と 3D、加速度センサー・音声反応対応。自作ツールも無料配布 ✅（Wikipedia） |
| 2008-10-27 発表 → 2009-03-19 公開 | au **ケータイパートナー（β版）**（カタリスト・モバイル＋プライムワークス＋KDDI） | 「アドレス帳や着信履歴や時節の情報などに基づき、人気のキャラクターが携帯電話と一体化し、まるで人格を持ったかのような演出」。季節イベントでキャラデータをサーバ配信。加速度センサー機種（W64SH/W65T/CA001）。無料。オリジナルキャラのほか「バカボンのパパ」「鬼太郎」を予定 ✅。2011-04-27 終了 ✅ |
| 2009 | Shimeji（Group Finity・山田佑樹） | `actions.xml`／`behaviors.xml` で「条件＋頻度」からランダムに行動選択（歩く・登る・座る・増殖、ウィンドウ上端を這う）。ドラッグ・投げに反応 ✅（GitHub shimeji-ee） |
| 2011-04-14 | au one **キャラタイム**（Flash EZ アプリ） | 1 タイトル 315〜525 円。「生活型（キャラの日常）」「トレカ型（時間でランダム画像）」「マンガ型（名場面の吹き出しに着信情報）」「動画」の 4 形式。ウサビッチ・HELLO KITTY・北斗の拳・ぷち・ねこ。コンセプトは「au 携帯電話に愛着を持ち長くご利用いただく」✅ |
| 2020-01 | Desktop Goose（Sam Chiet） | カーソルを奪う・メモを引きずる・鳴く。「仕事の邪魔をする」「90〜00 年代アシスタントの記憶」を意図。「timid な人のパワーファンタジー」🔶 |
| 2024-08 | Shijima（Shimeji 互換、Mac/Win/Linux/Android/脱獄 iOS） | iOS 非脱獄では実現できないことを逆証明 ✅ |
| 2025-03-05 | Bongo Cat（Steam、無料） | キー入力で叩く。30 分ごとにランダムドロップ（帽子）＋Paw Pass。同時接続 Steam 上位 5 位に入ったが **開発者の純収入は月 2,000〜4,050 ドル** 🔶 |

### 4.2 「自律行動」設計への示唆
1. **分離アーキテクチャ**: 伺か（ゴースト／シェル）、Shimeji（XML 定義）、マチキャラ（自作ツール）はいずれも「本体と別に人格・外見・行動をデータ化」したことで長寿化した。CharaTime も「キャラ＝スプライト＋行動定義（JSON）」にしておくと、将来の AI 生成キャラや配布に直結する。
2. **文脈反応が「生きている感」を作る**: マチキャラ（着信・メール）、ケータイパートナー（アドレス帳・履歴・季節）、Cute pet（起床・就寝・水分）、Bongo Cat（キー入力）。iOS で使えるのは時刻・曜日・季節・天気・カレンダー予定・歩数（HealthKit）・充電（StandBy）・アプリ起動（Live Activity 更新）など。
3. **低頻度ランダム＋レア**: Shimeji の「頻度付き行動表」、Bongo Cat の 30 分ドロップ、veyebes の「5 秒ごとに別方向を見る」。ウィジェット予算（40〜70 回/日）内で「次に見たとき違う」を保証する設計（タイムラインで 15〜30 分ごとに別シーンを事前生成）。
4. **主体性・いたずら**: Desktop Goose の「邪魔をする」は共有・拡散の源。iOS ではできることが限られるが「勝手に模様替えする」「ミラーボールを勝手に回す」「夜中に寝ている」等の**ユーザーが操作していない間の変化**で代替できる。
5. **飽きへの対策**: 伺か作者が「全容が見えると飽きる」と述べた通り、行動の総数より「未見の組み合わせ」と「季節・記念日イベントの配信」が重要（ケータイパートナーはサーバ配信で季節イベントを実施していた）。
6. **収益の現実**: コスメ収集型は熱狂しても薄利（Bongo Cat）。個人開発では **サブスク or 買い切り＋少数の高付加価値アイテム** に絞る。

---

## 5. App Store 審査ガイドライン（2026-09-10 時点の本文を developer.apple.com で確認）

直近の改定は 2025-11-13（Apple Developer News「Updated App Review Guidelines now available」）✅。関連条文の引用:

| 条項 | 引用（原文） | CharaTime への含意 |
|---|---|---|
| **1.2 User-Generated Content** | "apps with user-generated content or social networking services must include: A method for filtering objectionable material from being posted to the app / A mechanism to report offensive content and timely responses to concerns / The ability to block abusive users from the service / Published contact information so users can easily reach you" ✅ | ユーザー生成キャラを**他人に共有・配布**する機能を付けた時点で 4 要件が必須。端末内・本人のみなら UGC 規制の主眼から外れる 🔷 |
| **1.2.1(a)**（2025-11 新設）| クリエイター系アプリはアプリの年齢区分を超えるコンテンツを識別でき、確認済み／申告された年齢に基づくアクセス制限機構を持つこと ✅（News の要約） | AI キャラ共有を開放する場合の年齢ゲート |
| **2.3.6** | "Answer the age rating questions in App Store Connect honestly..." ✅ | 新質問票に正直に回答 |
| **2.4.2** | "Apps... may not run unrelated background processes, such as cryptocurrency mining." ✅ | PiP をバックグラウンド実行の口実にしない |
| **2.5.4** | "Multitasking apps may only use background services for their intended purposes: VoIP, audio playback, location, task completion, local notifications, etc." ✅ | 常駐のためにオーディオ／位置情報を使う設計は却下リスク大。Live Activity・ウィジェット・PiP の正規手段に限定 |
| **2.5.16** | "Widgets, extensions, and notifications should be related to the content and functionality of your app." ✅ | 本体アプリに「部屋・キャラ・アイテム」の実体があればウィジェットは正当 |
| **3.1.1** | "If you want to unlock features or functionality within your app... you must use in-app purchase." / "Apps offering 'loot boxes' or other mechanisms that provide randomized virtual items for purchase must disclose the odds of receiving each type of item to customers prior to purchase." ✅ | ガチャ導入時は確率開示必須 |
| **4.1(c)**（2025-11 新設）| 他の開発者のアイコン・ブランド・製品名をアイコン名・アプリ名に使えない ✅ | 「サンリオ」「たまごっち」等を名前・アイコンに使わない |
| **4.2 Minimum Functionality** | "Your app should include features, content, and UI that elevate it beyond a repackaged website. If your app is not particularly useful, unique, or 'app-like,' it doesn't belong on the App Store. If your App doesn't provide some sort of lasting entertainment value or adequate utility, it may not be accepted." ✅ | 却下事例は「リンク集」「薄い機能」（2026-03 の TVNext 却下例: "The usefulness of the app is limited by the minimal functionality it currently provides."）。Widgetsmith・Steve・Pixel Pals などウィジェット中心アプリは承認されている ✅ → **本体に「部屋の模様替え・アイテム・キャラ選択・図鑑」があれば個人開発でも 4.2 リスクは低い** 🔷 |
| **4.2.1** | "Apps using ARKit should provide rich and integrated augmented reality experiences; merely dropping a model into an AR view or replaying animation is not enough." ✅ | AR 機能を付けるならおまけにしない |
| **4.5.3** | "Do not use Apple Services to spam, phish, or send unsolicited messages to customers, including Game Center, Push Notifications, Live Activities, etc." ✅ | Live Activity での販促は禁止 |
| **5.1.2(i)**（2025-11-13 改定）| "You must clearly disclose where personal data will be shared with third parties, including with third-party AI, and obtain explicit permission before doing so." ✅ | AI キャラ生成で外部 API（OpenAI 等）に写真・文章を送るなら、**送信前に提供先と送信データを示す同意モーダル**が必須 |

### 5.1 年齢区分（2025-07-24 発表、2026-01-31 回答期限）✅
- 4+/9+/13+/16+/18+ の 5 段階。質問票に「In-app controls」「Capabilities」「Medical or wellness」「Violent themes」が追加。
- 定義: 「User-generated content」は 4+ の Capability（韓国は 13+、ブラジルは 9+）。「Loot boxes」（有償ランダムアイテム）は **9+**。「Social media」（フィードで UGC を拡散）は 13+。「Unrestricted web access」は 16+ ✅。
- Apple の注記: "you must consider how all app features, including AI assistants and chatbot functionality, impact the frequency of sensitive content appearing within your app" ✅。**AI 生成コンテンツ専用の申告項目は 2026-09-10 時点の定義ページには存在しない** ✅。
- 含意: 「キャラ表示＋部屋」だけなら 4+。ガチャを入れると 9+。ユーザー間共有フィードを入れると 13+。

### 5.2 技術的制約（Apple 公式ドキュメント）
- WidgetKit 更新予算: "For a widget the user frequently views, a daily budget typically includes from 40 to 70 refreshes. This rate roughly translates to widget reloads every 15 to 60 minutes" / 予算に数えないケース: "The widget's containing app is in the foreground / ... has an active audio or navigation session / The widget performs an app intent / **The widget performs an animation** / The system locale changes" ✅。
- Live Activities HIG: "Offer Live Activities for tasks and events that have a defined beginning and end. Live Activities work best for tracking short to medium duration activities that don't exceed eight hours." / "Don't use a Live Activity to display ads or promotions." / "Update a Live Activity only when new content is available." ✅。ActivityKit の上限は 8 時間（＋ロック画面で 4 時間の stale 表示）🔶。**Pixel Pals は 2022 年から「常時ペット」用途で承認され続けている**ため実務上は許容されているが、HIG の建前とはずれる（方針変更リスク 🔷）。
- iOS 26（WWDC25「What's new in widgets」）: CarPlay 全車種でウィジェット・Live Activity、visionOS ウィジェット、macOS Tahoe で iPhone の Live Activity がメニューバーに表示、Home 画面の accented（Liquid Glass／ティント）レンダリング、**APNs によるウィジェット push 更新** ✅。
- iOS 27（WWDC26「Live Activities essentials」）: "in iOS 27, Live Activities are visible in the Dynamic Island, when in portrait and landscape" / "They also appear in other places too, like in StandBy, when iPhone is in landscape and charging" / "automatically appears on other Apple devices. Including right on Apple Watch, in the Smart Stack... In the macOS menu bar or right on the CarPlay Dashboard" ✅。`isDynamicIslandLimitedInWidth` 環境値、`activityFamily.small` 対応が必要。

---

## 6. 収益化

### 6.1 価格ベンチマーク（App Store 実売価格、2026-09-10）✅
| モデル | 海外ペット／ウィジェット系 | 日本 |
|---|---|---|
| 月額 | $1.99（Pixel Pals, Pixel Pets, WidPet, PiP）〜$4.99（Widgetable）〜$7.99（iScreen） | ¥240（Pixel Pals）、¥300〜（Widgetable）、¥980（WidgetClub） |
| 年額 | $6.99（Mooshi）〜$14.99（Pixel Pals）〜$19.99（Widgetable, iScreen, LockWidget） | ¥2,200（Pixel Pals）、¥2,700（WidgetClub） |
| 買い切り | $17.99（Pixel Shimeji）〜$23.99（iScreen）〜$29.99（LockWidget, Floatory）〜$49.99（Pixel Pals） | ¥8,000（Pixel Pals）、¥9,800〜15,000（WidgetClub） |
| 消耗型 | 餌・ダイヤ $0.99〜4.99（Pixel Pals, Widgetable, Care Pet） | ¥150〜800（Widgetable） |
| 単品コンテンツ | — | テンプレ ¥480〜2,000、たまごっちセット ¥680（WidgetClub） |
| 週額（海外系に多い） | $1.99〜4.99 | 日本のレビューでは不評 🔶 |

### 6.2 売上事例
- Pixel Pals: 累計 333 万 DL・約 5 万サブスク・2023 年 7〜9 月約 62.5 万ドル（Appfigures 推計）、2024-10 月次推計 3 万ドル 🔶。
- Widgetable: 2024-10 月次推計 100 万 DL・20 万ドル 🔶、Google Play 5000 万 DL ✅。
- Bongo Cat: Steam 同接上位でも純収入月 2,000〜4,050 ドル 🔶。
- 日本の個人開発一般: 電卓アプリ累計 1,180 万円（広告 1,100 万円＋課金 80 万円）、ゲームアプリ 4 年で 800 万円等 🔶（ITプロマガジン等）。Apple Developer Program 年 $99 ✅。

### 6.3 「払ってもらえる」ポイント（レビュー分析）
- 払う: 「可愛い」「自分の推し・好きなキャラがいる」（LockWidget の Hello Kitty）、「透過・見た目のカスタム」、「広告なしの安心」（Pixel Pals, NotiSprite）、「買い切りの選択肢」（PiP app "Just pay the dollar"）。
- 払わない／怒る: 週額サブスク、餌 1 個に広告 100 秒、「有料だらけ」、評価強要でアイテム解放、機能が「見た目だけ」。
- 日本固有: WidgetClub の「使えるテンプレはほぼ有料」批判は根強い一方、たまごっち公式セット 680 円のような **IP 付き買い切り**は受け入れられている 🔶。

### 6.4 日本の法規制
- **景品表示法**: 有料ガチャで得るアイテムは「取引そのもの」なので景品類規制の対象外だが、**コンプガチャは「カード合わせ」として全面禁止**（消費者庁「オンラインゲームの『コンプガチャ』と景品表示法の景品規制について」2012-05-18、2016-04-01 改定）✅（PDF 原文確認）。出現率の虚偽表示は優良誤認 ✅。2024-10 から優良誤認に直罰（100 万円以下の罰金）🔶（ベリーベスト 2025-08-19 更新）。
- **業界自主ガイドライン**: JOGA/CESA のランダム型アイテム提供方式ガイドライン（レアアイテム取得推定金額の上限 5 万円または 1 回課金額の 100 倍以内、確率表示）🔶（JOGA サイト本文は取得不可、ベリーベスト経由）。
- **資金決済法（前払式支払手段）**: 「ポイントと称して発行されるものであっても、当該ポイントに対して、利用者から現金等の対価を得て発行している場合等…原則、前払式支払手段に該当」。自家型は個人でも発行可。基準日（3 月末・9 月末）の未使用残高が **1,000 万円を超えたら 2 か月以内に届出・供託（残高の半額）**。無償ポイントは対象外だが有償分と区分管理が必要。有効期限 6 か月以内の記載があれば適用除外（実質延長不可）✅（日本資金決済業協会 Q&A）。→ **初期は「コイン」を作らず、アイテムを直接 IAP で売る**のが最も管理が軽い。
- **Apple 3.1.1**: 有償ランダムアイテムは確率の事前開示 ✅。年齢区分も 9+ に上がる ✅。

### 6.5 CharaTime への推奨
1. 無料: 開発者製キャラ 1〜2 体＋基本の部屋＋自律行動を**完全に**無料（Pixel Pals 方式）。広告なし（この層の最大の不満を最初から排除）。
2. 非消耗型アイテム: 家具・小物（ミラーボール等）を ¥160〜¥480 で単品／セット販売。「持っている物を部屋に置く」体験が課金の中心。
3. キャラ追加パック: ¥480〜¥980（買い切り）。季節限定は「期間限定販売」で希少性を出す（ガチャにしない）。
4. 任意の月額パス（¥300〜¥480）は「毎月の季節イベント・追加アイテム」の配信原資として後から追加（サブスクだけにしない）。
5. AI キャラ生成は従量コストがあるため「生成チケット（消耗型、確率要素なし）」または月額パス特典に。
6. ガチャ・アプリ内通貨・週額は導入しない（法規制・レビュー・年齢区分すべてで不利）。

---

## 7. 法務

### 7.1 「サンリオ風」の線引き（著作権・商標・不正競争防止法）
- 著作権侵害は「依拠」＋「既存著作物の**表現上の本質的特徴を直接感得**できる類似」が必要。「目玉をロゴにする」のようなアイデアや「丸い顔・大きな瞳」のようなありふれた表現は保護されない（東京地裁 1999-07-23 判決の解説: 顔の上部が丸く瞳が大きい等の共通点があっても細部の相違で非侵害）✅🔶（関真也法律事務所 2024-11-16、STORIA）。
- ただし **ミッフィー vs キャシー**: サンリオ自身がアムステルダム地裁で 2010-11-02 に差止仮処分を受け、2011 年に訴訟取り下げ・共同で 15 万ユーロを震災義援金として寄付して決着（類似性の司法判断は出ず）✅🔶。村上隆 vs ナルミヤ（DOB くん）は和解。**「〜風」でも特定キャラの輪郭・目鼻の配置・配色を写すと危険**。
- 不正競争防止法: 周知・著名な商品等表示（ハローキティ等）と混同を生じさせる、または著名表示を冒用する行為は差止・損害賠償の対象 🔷（METI ページは 403 で本文未取得）。「サンリオ風」という**語自体をアプリ名・説明文・ASO キーワードに使わない**（App Store 4.1(c) とも整合）。
- 実務ルール案: (a) 既存キャラのシルエット検索で目視比較、(b) 「シンプル・丸顔・点目」は作風として採用するが、口の有無・耳の形・リボン等の識別要素は独自化、(c) キャラ名は先行商標検索（TMview／J-PlatPat）を通す。

### 7.2 AI 生成キャラの権利
- 文化庁「AI と著作権に関する考え方について」（2024-03）: AI が自律的に生成したものは著作物に当たらず、人間の「創作意図」と「創作的寄与」（プロンプトの試行錯誤・加筆修正等）がある場合に限り著作権が生じ得る 🔶（複数の法律事務所解説）。→ プロンプト一発のキャラは他人に複製されても著作権では止められない可能性。
- 商標: 特許庁 産業構造審議会 商標制度小委員会（2025-06-19、資料 2）「商標が AI により生成されたものかに関わらず、商標法第 3 条及び第 4 条等に規定された拒絶理由に該当しない限り商標登録を受けることができる」✅🔶（Authense 記事経由の引用）。→ **主要キャラの図形・名称は商標出願で保護**（第 9 類: アプリ・画像データ、第 41 類: オンラインゲーム・コンテンツ提供、グッズ展開時に第 16・18・21・25・28 類等 🔷）。
- 生成 AI ツール側の利用規約（商用利用可否、出力の権利帰属）を確認 🔷。既存 IP に似た出力は依拠性が認められ得るため、生成結果の目視チェックを運用に組み込む。

### 7.3 ユーザー生成キャラを扱う利用規約の要点 🔷（1.2・5.1.2(i)・国内法を踏まえた整理）
1. 権利帰属とライセンス: ユーザー作成データの権利はユーザーに留保しつつ、アプリ内での表示・改変（アニメ化・縮小）・バックアップ・（共有機能を出すなら）他ユーザーへの配信に必要な非独占・無償のライセンスを取得。
2. 保証と禁止: 第三者の著作権・商標・肖像権を侵害しない旨の保証、実在人物・既存キャラの模倣、性的・暴力的コンテンツの禁止。
3. モデレーション: 事前フィルタ（画像モデレーション API）、通報、ブロック、公開連絡先（1.2 の 4 要件）。侵害通知への対応手順（情報流通プラットフォーム対処法の著作権ガイドラインは大規模事業者向けだが、プロバイダ責任制限の枠組みは小規模でも参考になる）✅🔶。
4. AI 処理の透明性: 第三者 AI に送るデータの種類・提供先を明示し、送信前に同意（5.1.2(i)）。未成年向け配慮（13+ 判定の可能性）。
5. 免責・削除権・サービス終了時の扱い（Peridot の「返金なし・残高は期限内に消費」告知が参考）✅。

### 7.4 グッズ展開時の注意 🔷
- 商標出願は「アプリ名」「キャラ名」「主要図形」を、第 9・41 類に加えてグッズの類（第 16・18・21・25・28 類等）で早めに。出願前に TMview／J-PlatPat で先行調査（本レポート 8.3 参照）。
- AI 生成素材を含む場合は著作権で守れない可能性があるため、商標＋（必要なら）意匠、キャラ設定・ストーリーの著作物性で補強。
- サンリオ等の公式ライセンス品が並ぶ市場で「〜風」と誤認される表示は不正競争防止法・景表法（優良誤認）の両面でリスク。

---

## 8. ポジショニング提案

### 8.1 差別化の軸
| 軸 | 先行アプリ | CharaTime |
|---|---|---|
| 体験の中心 | お世話（餌・排泄・成長）＝義務感 | **「待受に住んでいる」**＝観察・愛着。義務なし（Pixel Pals の「観るだけ」批判を「それでいい」設計に転換） |
| 動き | 状態切替、DI 内の小さなアニメ | 部屋という舞台での**自律行動**（時間帯・天気・予定・季節・充電で変わる）。ウィジェット 3 サイズ＋ロック画面 Live Activity＋StandBy（横向き）で「部屋の全景／窓／ドア」の見え方を変える |
| 空間 | ペット単体 | **部屋・家具・小物**（ミラーボール等）＝ガラケー待受アイテムの再現。非消耗型課金と直結 |
| キャラ | 動物・ドット絵 | 開発者製オリジナル数体 → **AI 生成キャラを同じ行動定義で動かす**（PixelPot が国産で先例） |
| 収益 | 広告＋週額サブスク | 広告なし・買い切り中心（NotiSprite・Pixel Pals の「誠実さ」を訴求） |
| 面 | DI 中心 | iOS 26/27 の全面（DI 縦横・ロック画面・StandBy・Watch・Mac メニューバー・CarPlay）＝**「どこにでもついてくる相棒」** |

### 8.2 ターゲットとトーン
- 主: 30〜40 代、ガラケー（マチキャラ／ケータイパートナー／キャラタイム）世代。訴求語は「待受」「相棒」「あの頃のケータイ」。KDDI の当時のコンセプト「携帯電話に愛着を持ち長く使う」をそのまま現代語訳する。
- 副: 10〜20 代のホーム画面カスタマイズ層（WidgetClub・フォトウィジェットの 7 万件レビュー層）。透過ウィジェット文化と親和性が高いので「壁紙に溶け込む透過部屋」「ティント／Liquid Glass 対応」を初期から用意。
- トーン: ほのぼの・ゆるい・少しおせっかい（着信・予定を教えてくれる）。「育成」「ミッション」「連続ログイン」を使わない。

### 8.3 命名と商標（追加調査項目 2）
**現行名「CharaTime／キャラタイム」**
- JPO（TMview 経由）: 「キャラタイム」= ネオス株式会社、出願 2009-044698、登録 5269867、第 9・41 類、2009-10-02 登録、**tradeMarkStatus: Expired、expirationDate 2019-10-02** ✅。KDDI 名義の「キャラタイム」「au one キャラタイム」はヒットなし ✅（KDDI はネオスからの許諾または未登録での使用だった可能性 🔷）。
- 「CHARATIME」: JP・US・EUIPO・WIPO・UK でヒット 0 ✅。「CHARA TIME」で出るのは "CHARACTER TIME" 等の無関係マークのみ ✅。
- App Store: 「キャラタイム」「CharaTime」「chara time」いずれも同名アプリなし（JP ストア検索は無関係アプリのみ）✅。
- 評価: **登録上の障害は現時点で見当たらない**。ただし (1) TMview の反映遅延・更新（更新登録なら 2029 年まで存続）を J-PlatPat で最終確認する、(2) 「キャラ＋タイム」は記述的で識別力が弱い可能性（3 条 1 項）があるため、ロゴ化した図形商標や「CharaTime」欧文併記で出願する、(3) KDDI の旧サービス名と同一のため、ガラケー世代に「au のあれ？」と想起される利点と、KDDI から周知性を主張されるリスク（サービス終了から 10 年以上経過しており低い 🔷）の両面がある。

**代替名候補 5 つ（TMview JP 検索＋App Store JP 検索、2026-09-10）**
| 候補 | 由来 | 商標（JP） | App Store（JP） | 所感 |
|---|---|---|---|---|
| **まちうけっと** | 待受＋ウィジェット | ヒット 0 ✅ | 同名なし ✅ | ガラケー語「待受」を残しつつ現代的。識別力あり |
| **キャラすまい** | キャラ＋住まい／すまう | ヒット 0 ✅ | 同名なし ✅ | 「部屋に住む」コンセプト直結 |
| **おへやキャラ** | お部屋＋キャラ | ヒット 0 ✅ | 同名なし ✅ | 平易。やや記述的 |
| **まちうけメイト** | 待受＋mate（相棒） | ヒット 0 ✅ | 同名なし ✅ | 「パートナー」の言い換え。「ホームメイト」は不動産商標があるので避けた |
| **キャラぐらし** | キャラ＋暮らし | ヒット 0 ✅ | 同名なし ✅ | 響きは良いが San-X「すみっコぐらし」を想起させる懸念 🔷 |

**避けるべき名**: 「まちキャラ／マチキャラ」（NTT ドコモ、第 9・38・41・42 類、2007 年登録。存続状況は要確認だがサービス名として周知）✅、「ホームキャラ」（A PLUS JAPAN 2025-12-03 登録・同名アプリあり）✅、「キャラタウン」（ハピネット多数）✅、「キャラばこ／キャラバコ」（Minto 2024 登録 第 35・41 類）✅、「おさんぽキャラ」（個人 2020 登録 第 41 類）✅、「ケータイパートナー」（KDDI／カタリスト・モバイルの旧サービス名。商標ヒットはなかったが周知性リスク 🔷）。

---

## 9. 未確認事項

1. **J-PlatPat での最終確認**（本レポートは EUIPO TMview の JPO データに依拠。「キャラタイム」の更新登録の有無、「マチキャラ」の存続状況、称呼類似の範囲）。
2. Reddit・X の「iPhone で Shimeji が欲しい」投稿の個別 URL（本環境からアクセス不可）。TikTok ディスカバーページの中身。
3. PiP をペット用途に使ったアプリの審査結果（承認・却下どちらの一次情報も未発見）。Apple Developer Forums のメモアプリ PiP 質問への Apple 回答。
4. Pixel Pals がウィジェット／DI で「アニメ」を実現している技術（Fueled 記事は「animate させることに成功した」とのみ）。
5. Pixel Pals の Premium 導入日（レビューから 2022-11 以前と推定）と売上（Appfigures 推計のみ、公式公表値ではない）。
6. JOGA ガイドラインの原文（サイト本文取得不可、二次情報のみ）。METI 不正競争防止法ページ（403）。JPO 区分ページ（取得不可）。
7. Peridot のウィジェット／ロック画面機能の有無（見つからず＝なしと推定）。
8. WidgetClub の「400 万 DL」「プレミアム会員 10 万人」（二次情報）。
9. iOS 27 の一般公開状況（WWDC26 発表内容は確認、2026-09-10 時点のリリース有無は未確認）。
10. LockWidget の Hello Kitty がサンリオ公式ライセンスかどうか。
11. Google Play の Shimeji 系アプリの正確な DL 数（「500K+」等の丸め値のみ）。

---

## 10. 出典一覧（すべて 2026-09-10 確認）

### App Store（apps.apple.com、iTunes Search API 含む）
- Pixel Pals Widget Pet Game（US）https://apps.apple.com/us/app/pixel-pals-widget-pet-game/id6443919232 ／（JP）https://apps.apple.com/jp/app/id6443919232 ／レビュー・バージョン履歴 https://apps.apple.com/us/app/pixel-pals-widget-pet-game/id6443919232?see-all=version-history
- Widgetable（US）https://apps.apple.com/us/app/widgetable-besties-couples/id1641107226 ／（JP）https://apps.apple.com/jp/app/id1641107226
- iScreen https://apps.apple.com/us/app/iscreen-widgets-wallpaper/id1534704608
- LockWidget https://apps.apple.com/us/app/lockwidget-lockscreen-themes/id1643112111
- Mooshi - Ah Shimeji https://apps.apple.com/us/app/mooshi-ah-shimeji/id6746576406
- Shimeji Screen Pets https://apps.apple.com/us/app/-/id6757619322
- Pixel Shimeji: My Digital Pets https://apps.apple.com/us/app/pixel-shimeji-my-digital-pets/id6463613786
- Pixel Pets- Homescreen Widget https://apps.apple.com/us/app/pixel-pets-homescreen-widget/id1660283848
- Care Pet Game https://apps.apple.com/us/app/care-pet-game-screen-widget/id6504230695
- WidgetKit: Widgets & Wallpaper (iStandBy) https://apps.apple.com/us/app/istandby-pet-widgets-themes/id6467385403
- Floatory https://apps.apple.com/us/app/floatory-floating-clock-pip/id6760526872
- Floating Notepad -Overlay- https://apps.apple.com/us/app/floating-notepad-overlay/id1598380826
- PiP - Picture in Picture https://apps.apple.com/us/app/pip-picture-in-picture/id1635796246
- Pets Therapy (Mac) https://apps.apple.com/us/app/pets-therapy-desktop-pets/id1575542220?mt=12
- WidgetClub（JP）https://apps.apple.com/jp/app/id1580284904
- Widgetsmith（JP）https://apps.apple.com/jp/app/id1523682319
- その他（Pixel Pets Twinstar id6444085825、Island Pet id6445975134、Cute pet id6443751681、Steve id1090617661、Mochi Pets id6463988125、Boko id6759446145、OuO id6757497926、Chimomo id6747741618、WidPet id6466376612、NotiSprite id6752292657、veyebes id1661246440、WoWidget id6444002239、ウィジェット野球 id6789549319、PixelPot id6758675804、メモ帳サンリオ id1554047695、ホームキャラ id6670744395、Yidget id1532848312、Widgets SD id1533190034、Lodgety id1640030946、Mico id1640653011、Color Widgets id1531594277、フォトウィジェット id1530149106、Widgy id1524540481、Widgify id6449579793、マイたまごっち id1267861706）: iTunes Search/Lookup API https://itunes.apple.com/lookup?id=...&country=jp|us

### Google Play（HTML 直接取得）
- Shimeji - desktop pet https://play.google.com/store/apps/details?id=com.anbu.shimeji.desktoppet
- Cute Shimeji https://play.google.com/store/apps/details?id=com.cutepet.shimeji.petonscreen.virtualpet
- Mooshi (Android) https://play.google.com/store/apps/details?id=com.androidapp.mooshi.ah_shimeji.my_screen_pet
- Widgetable (Android) https://play.google.com/store/apps/details?id=com.widgetable.theme.android

### Apple 公式（ガイドライン・ドキュメント・ニュース）
- App Review Guidelines https://developer.apple.com/app-store/review/guidelines/
- Updated App Review Guidelines now available（2025-11-13）https://developer.apple.com/news/?id=ey6d8onl
- Updated age ratings in App Store Connect（2025-07-24）https://developer.apple.com/news/?id=ks775ehf
- Age Rating Updates（Upcoming Requirements）https://developer.apple.com/news/upcoming-requirements/?id=07242025a
- Age Ratings Values and Definitions https://developer.apple.com/help/app-store-connect/reference/age-ratings-values-and-definitions/
- Keeping a widget up to date https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date
- HIG: Live Activities https://developer.apple.com/design/human-interface-guidelines/live-activities
- WWDC25 What's new in widgets https://developer.apple.com/videos/play/wwdc2025/278/
- WWDC26 Live Activities essentials https://developer.apple.com/videos/play/wwdc2026/223/
- Tips from App Review（Forums, 2025-12）https://developer.apple.com/forums/thread/810791
- 4.2 却下例（2026-03）https://developer.apple.com/forums/thread/817622 ／ その他 4.2 スレッド https://developer.apple.com/forums/thread/93116 https://developer.apple.com/forums/thread/115230
- Max duration for a live activity（Forums）https://developer.apple.com/forums/thread/797676

### 記事・二次情報
- TechCrunch（2023-10-18）Pixel Pals 50K subscribers https://techcrunch.com/2023/10/18/reddit-may-have-killed-apollo-but-the-developers-new-pixel-pals-app-has-hit-50k-subscribers/
- TechCrunch（2023-09-22）Pixel Pals 2.0 https://techcrunch.com/2023/09/22/pixepixel-pals-delivers-a-cute-and-clever-update-that-takes-advantage-of-new-ios-features/
- Fueled（2023-08-30）Pixel Pals 分析 https://fueled.com/blog/pixel-pals/
- Christian Selig 告知ツイート（2022-10）https://x.com/ChristianSelig/status/1584636939885740032
- mwm.ai Pixel Pals 推計 https://mwm.ai/apps/pixel-pals-widget-pet-game/6443919232 ／ Widgetable 推計 https://mwm.ai/apps/widgetable-besties-couples/1641107226 ／ Appfigures https://appfigures.com/resources/insights/20230721/amp?f=2
- Peridot 終了告知（2026-04-23）https://playperidot.com/en/news/peridot-mobile-sunset ／ Wikipedia https://en.wikipedia.org/wiki/Peridot_(franchise)
- ScreenRant（2023-08-01）Shimeji alternatives for iPhone https://screenrant.com/shimeji-alternatives-iphone-best-which/
- Shijima https://getshijima.app/ ／ iDownloadBlog（2024-08-21）https://www.idownloadblog.com/2024/08/21/shijima-shimeji-desktop-pet-for-ios/
- Yahoo! 知恵袋（2021-04-05）https://detail.chiebukuro.yahoo.co.jp/qa/question_detail/q11241311201
- TikTok ディスカバー https://www.tiktok.com/discover/shimeji-on-iphone-apple-screen-pets
- Desktop Goose: GameSpot https://www.gamespot.com/articles/annoy-yourself-with-this-untitled-goose-game-virtu/1100-6473237/ ／ Laptop Mag https://www.laptopmag.com/news/i-let-the-goose-from-untitled-goose-game-rampage-all-over-my-desktop
- Bongo Cat: GameSpot https://www.gamespot.com/articles/viral-steam-hit-bongo-cat-doesnt-actually-make-any-money/1100-6532777/ ／ XDA https://www.xda-developers.com/bongo-cat-taking-over-steam/ ／ Dexerto https://www.dexerto.com/gaming/one-of-steams-most-popular-games-is-actually-losing-the-devs-money-3220149/
- 伺か: 窓の杜（2022-04-20）https://forest.watch.impress.co.jp/docs/serial/yajiuma/1404090.html ／ Wikipedia https://ja.wikipedia.org/wiki/伺か
- Shimeji-ee XML https://github.com/TigerHix/shimeji-ee/blob/master/conf/behaviors.xml
- マチキャラ Wikipedia https://ja.wikipedia.org/wiki/マチキャラ
- ケータイパートナー: プライムワークス／カタリスト・モバイル プレスリリース PDF（2009-03-23）https://prtimes.jp/a/?c=933&f=f1c7edcd368fede66de9483923d79ff6.pdf&r=15 ／ PR TIMES https://prtimes.jp/main/html/rd/p/000000015.000000933.html ／ ケータイ Watch（2008-10-27）https://k-tai.watch.impress.co.jp/cda/article/news_toppage/42458.html
- au one キャラタイム: KDDI リリース（2011-04-13）https://www.kddi.com/corporate/news_release/2011/0413/index.html ／ 別紙 https://www.kddi.com/corporate/news_release/2011/0413/besshi.html ／ ITmedia https://www.itmedia.co.jp/mobile/articles/1104/13/news089.html ／ ケータイ Watch https://k-tai.watch.impress.co.jp/docs/news/439342.html
- WidgetClub×たまごっち: BANDAI TOYS（2024-01）https://toy.bandai.co.jp/ja/topics/01_18498/ ／ たまごっち公式 https://tamagotchi-official.com/jp/item/01_848/
- app-liv ホーム画面カスタマイズ（2026-08-27 更新）https://app-liv.jp/customizations/screen/3691/
- Mac desktop pets: Mac Pet Blog https://mac-pet.com/en/blog/best-desktop-pets-mac/ ／ MenuBar Pets https://apps.apple.com/us/app/menubar-pets/id6766222004?mt=12
- Live Activity 解説: Newly https://newly.app/guides/ios-live-activities ／ OneSignal https://documentation.onesignal.com/docs/en/live-activities
- iOS 27 まとめ: Tom's Guide https://www.tomsguide.com/phones/iphones/ios-27-is-official-all-the-new-upgrades-and-features-announced-at-wwdc-2026

### 法務（日本）
- 消費者庁「オンラインゲームの『コンプガチャ』と景品表示法の景品規制について」（2012-05-18、2016-04-01 改定）https://www.caa.go.jp/policies/policy/representation/fair_labeling/guideline/pdf/120518premiums_1.pdf
- ベリーベスト「ガチャと景品表示法」（2025-08-19 更新）https://corporate.vbest.jp/columns/9165/
- 日本資金決済業協会 前払式支払手段 Q&A https://www.s-kessai.jp/businesses/prepaid/q_and_a/
- 関真也法律事務所「キャラクターってどれくらい似てると権利侵害なの？」（2024-11-16）https://www.mseki-law.com/archives/1930 ／ #2 https://www.mseki-law.com/archives/1932
- STORIA 法律事務所「パクリデザイナーと言われないために押さえておくべき３つの裁判例」https://storialaw.jp/blog/855
- 弁護士 JP「封印されたサンリオのキャラ『キャシー』」https://www.ben54.jp/news/1318 ／ 日経（2010-10）https://www.nikkei.com/article/DGXNASDG20056_R21C10A0000000/ ／ 日経（2011-06）https://www.nikkei.com/article/DGXNASFL070CB_X00C11A6000000/
- Authense「AI 生成のロゴや名称、商標登録できる？〜特許庁の最新資料」（特許庁 2025-06-19 資料の引用）https://authense-ip.com/article/956/
- 文化庁「AI と著作権に関する考え方について」解説: LegalOn https://www.legalontech.com/jp/media/copyright-of-generative-ai ／ リードプラス https://www.leadplus.co.jp/blog/comprehensive-summary-of-generative-ai
- 情報流通プラットフォーム対処法 著作権関係ガイドライン https://www.isplaw.jp/guidel/guidel_c_aim.html ／ 総務省 https://www.soumu.go.jp/main_sosiki/joho_tsusin/d_syohi/ihoyugai.html
- 個人開発の収益事例: ITプロマガジン https://itpropartners.com/blog/1657/ ／ Qiita https://qiita.com/nakapon9517/items/14bf412fe169824cc824

### 商標検索
- TMview（EUIPO、JPO データ含む）検索 API https://www.tmdn.org/tmview/ （「キャラタイム」= JP 2009-044698／登録 5269867、ネオス株式会社、第 9・41 類、Expired 2019-10-02。詳細 https://www.tmdn.org/tmdsview-cdc/trademark/data/JP502009000044698）
- J-PlatPat（要最終確認）https://www.j-platpat.inpit.go.jp/
