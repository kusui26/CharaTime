# CharaTime キャラを作るプロンプトのテンプレート（v2、2026-09-26）

- 位置づけ: プラン（`docs/260910_dev_plan.md` v1.6）§9 Phase 2 の 2-C ④「作り方の手引き」の本文。決めごとは D-34・D-37・D-38・D-39
- 使い方: **自分の番のフェーズだけ読めばよい**（§0 の早見表）。プロンプトは枠ごとそのままコピーして貼る。iPhone の Safari で GitHub のこの文書を開くと、枠の右上にコピーのボタンが出る
- 版: **v2**（2-0 の試しの結果で改めた。変えたことは §6）。アプリで取り込んだキャラの記録に、どの版の手引きで作ったかを残す
- 凡例: ✅ 一次情報・実測 / 🔶 二次情報 / 🔷 推測・設計判断（プランと同じ）

---

## 0. 早見表

| フェーズ | いつ | 誰が | どこで | 作るもの | 読む節 |
|---|---|---|---|---|---|
| **A 試し** | 2-0（済み。v2 の確かめ A-7 も済み） | ユーザー | ChatGPT | ピヨ 1 体（試し） | §2 |
| **B 既定の 5 体** | 2-4（10/05〜） | ユーザー（生成）＋ Claude（採点・整える） | Mac の ChatGPT（Web かアプリ） | 5 体の本番の絵（ポーズ 4 コマを 2 枚） | §3 |
| **C 本番運用** | 2-6〜（アプリに載せる） | 利用者 | iPhone（キャラ工房がプロンプトを組み立てる） | 自分の子（ポーズ 6 コマを 1 枚） | §4 |

どのフェーズも、**同じ本文（§1.3）** を使う（D-34）。違うのは、空欄をだれがどう埋めるか・参照画像の有無・ポーズを何枚に分けるか（D-38）だけ。

---

## 1. 共通のしくみ

### 1.1 アプリが要る絵（プロンプトが守らせること）

アプリは、取り込んだ絵を整えて（背景を外す・コマを見つける・枠にそろえる）から描く（プラン 2-C ⑤）。整える処理が確実に通るように、プロンプトで次を守らせる。

| アプリの都合 | プロンプトに書くこと | 守られないと |
|---|---|---|
| 背景を外す（透明ならそのまま、1 色の地なら縁から抜く。D-36） | ChatGPT は透明、Gemini は真っ白（白いキャラは緑）。床・影・模様を描かない | 模様や写真の地は Vision に回り、縁がにじむ・部品を落とす |
| コマを「つながった塊」で見つける | 絵どうし・画像の縁のあいだを広く空ける。枠線・格子の線を描かない | 触れ合った 2 体が 1 つになる |
| 接地線をそろえる（輪郭線のいちばん下を枠の 94.7% に置く） | 影を描かない（足元の影も）。全身を描く | 影が足元とみなされ、キャラが浮く |
| **枠は縦長（130:180）。立ち姿は高さ 93%・幅 80% の中、どのコマも幅 95% の中で、上端が枠からはみ出さない**（いまの 5 体の最大に合わせた） | **姿勢を縦にまとめる**。腕・羽は体に添えるか上へ。寝姿は丸まる。どの姿勢も立ち姿より横に広くしない | 横に広い姿勢に合わせて全体を縮めるので、キャラが小さくなる（2-0 で約 4 分の 1 小さくなった） |
| 背を 1 つの倍率でそろえる（画像ごと。立ち姿が基準） | どのコマも同じ大きさ | 大きさが揃わず、コマを送るたびに伸び縮みする |
| まばたきと寝息の 2 コマ目は**アプリが作る**（D-38） | 目は小さな点（白い光を 1 つ） | 目が見つからず、まばたきが作れない |
| 歩きは左向きの 4 コマ（右は反転）。上下の揺れはアプリが足す | 横向き・左向き。頭と体の高さは 4 コマで同じ | 揺れが二重になる、体が伸び縮みする |
| 解像度（§1.4） | 1 枚に詰めすぎない | 待受で引き伸ばされ、輪郭がにじむ |

### 1.2 プロンプトの 5 つの部品

1 回に貼るプロンプトは、次の 5 つを上から順につないだもの（D-37）。

| 部品 | 中身 | 変えてよいか |
|---|---|---|
| ① 段の指示 | 何を作るか（シート・ポーズ・歩く）、縦横比、コマの数と並び。参照画像を添えるときの 1 行 | 変えない |
| ② キャラカード | 名前・何の生き物か・色（HEX）・守る特徴。**毎回そのまま貼る** | キャラごとに埋める |
| ③ 画風 | まるっとフラット（2 頭身・太い一定の輪郭線・平塗り） | 変えてよい（既定はこのまま） |
| ④ 取り込みの条件 | 全身・同じ大きさ・同じ接地線・**姿勢を縦にまとめる**・広い余白・影なし・文字や枠線なし | **変えない**（アプリが頼る約束） |
| ⑤ 背景の 1 行 | サービスごとに違う | サービスで選ぶ |

### 1.3 本文（正本）

`{…}` を埋めて、参照の 1 行（あれば）→ ① → ② → ③ → ④ → ⑤ の順につなぐ。フェーズ A はピヨで埋めたもの（§2）、B は 5 体ぶん（§3）、C はアプリが利用者の入力で埋める（§4）。

**② キャラカード**

```text
Character: "{NAME}", {WHAT}. An original character, not based on any existing character or brand.
Colors: {COLORS}. Outline: dark brown #3B2B2B.
Keep these features exactly: {FEATURES}.
```

**③ 画風**

```text
Style: cute, simple mascot art. About two heads tall, big round head, short rounded limbs, no fingers.
Thick, even dark-brown outline around every shape. Flat colors with at most one soft shade. No gradients, no texture, no glow.
```

**④ 取り込みの条件**（v2 で 2 行目を足した）

```text
Rules: every drawing is full body and the same size; in each row, all drawings rest on the same ground line.
Keep every pose compact: arms stay close to the body or point up, never spread out to the sides, and no pose is wider than the standing pose.
Leave wide empty space around every drawing; nothing touches another drawing or the edge of the image.
No shadows at all (not even under the feet). No text, letters, numbers or labels. No grid lines, dividers, frames or borders. No watermark or signature.
```

**⑤ 背景の 1 行**

| サービス | 行 |
|---|---|
| ChatGPT | `Background: fully transparent (real alpha, PNG). No background color, no checkerboard, no floor.` |
| Gemini | `Background: solid pure white #FFFFFF everywhere. No gradient, no texture, no floor.` |
| Gemini（白・ごく淡い色のキャラ） | `Background: solid pure green #00FF00 everywhere. No gradient, no texture, no floor. Do not use any green on the character.` |

Gemini は透明を出せず、「transparent」と書くと市松模様を描く 🔶（`research/G` §4.6）。白い地のほうが縁に色がにじまない（G §4.6）。白いキャラ（モチ）だけ緑にする。

**参照の 1 行**（ポーズ・歩く・直しの段で、先頭に付ける）

```text
Image 1 is the reference sheet of this character. Keep the design exactly the same: shapes, colors, face and proportions. Do not redesign it.
```

**① 段の指示**

S1 キャラシート（正方形 1:1。**これだけで 1 枚の絵のキャラ（Tier 0）になる**。いちばん左の正面を使う）:

```text
Make a character reference sheet of this character. Square image (1:1).
Three full-body views side by side, left to right: FRONT, SIDE (facing left), BACK.
```

P6 ポーズ 6 コマ（3×2、正方形 1:1。**利用者の既定**）:

```text
Make ONE square image (1:1) with exactly 6 poses of this character in 2 rows x 3 columns:
Row 1: (1) standing, front view, arms at the sides, eyes open. (2) sitting on the floor, front view, feet forward, eyes open. (3) asleep, curled up in a round ball on its belly, side view facing left, eyes closed.
Row 2: (4) happy, eyes closed in a big smile, both arms raised straight up beside the head, feet on the ground. (5) happy, eyes closed in a big smile, arms bent up next to the cheeks, feet on the ground. (6) standing, front view, looking up.
```

P4 ポーズ 4 コマを 2 枚（2×2、縦 3:4。**既定の 5 体と、利用者の「くっきり」**。どちらにも同じ立ち姿を入れて、2 枚の背をそろえる基準にする。4 コマ目の「驚く」は予備で、Phase 4 の Tier 2 で使う）:

```text
Make ONE portrait image (3:4) with exactly 4 poses of this character in 2 rows x 2 columns:
(1) standing, front view, arms at the sides, eyes open. (2) sitting on the floor, front view, feet forward, eyes open.
(3) asleep, curled up in a round ball on its belly, side view facing left, eyes closed. (4) happy, eyes closed in a big smile, both arms raised straight up beside the head, feet on the ground.
```

```text
Make ONE portrait image (3:4) with exactly 4 poses of this character in 2 rows x 2 columns:
(1) standing, front view, arms at the sides, eyes open (the same as the FRONT view in Image 1). (2) happy, eyes closed in a big smile, arms bent up next to the cheeks, feet on the ground.
(3) standing, front view, looking up. (4) surprised, front view, eyes wide open, arms slightly raised.
```

W4 歩く 4 コマ（2×2、縦 3:4）:

```text
Make ONE portrait image (3:4) with exactly 4 walking frames of this character in 2 rows x 2 columns. Side view facing LEFT in every frame.
(1) front foot forward, back foot back. (2) feet together under the body. (3) the other foot forward. (4) feet together under the body.
Only the feet and arms move. The head and body keep the same size and the same height in all 4 frames.
```

- **歩きを 2×2 にする理由**: 横 1 列（1×4、横長 3:1）よりコマが縦に長く、同じ画像で体が約 1.5 倍大きく描ける（§1.4）。上下の揺れはアプリが足すので、絵では頭と体の高さを変えない（`design/chara.py` の歩きと同じ）。2-0 では 4 コマとも左向きで、背の差は 1% 以内だった ✅
- **ポーズからまばたき・寝息の 2 コマ目を外した理由**（D-38）: 2-0 で ChatGPT に描かせた「目だけ閉じた絵」は、輪郭ごと 1〜2 画素描き直されていて、閉じた目の形も立ち姿とすわる姿で違った。「息を吸った寝姿」は全体の 28% が違う別の絵だった ✅。目を開けた絵から作るほうが、目のまわりだけが変わり、形もそろう（§2.1）

### 1.4 割り方と解像度（2-0 の実測）

ChatGPT は、縦横比に関わらず**約 157 万画素**で出した ✅（1:1 は 1254×1254、3:4 は 1086×1448。Web から保存、2026-09-26）。立ち姿の外接矩形（とさか・耳を含む）の高さは次のとおり。

| 段 | 縦横比 | 1 枚のコマ | 立ち姿の高さ | 生成の回数（シートを含む） | 待受での引き伸ばし 🔷 |
|---|---|---|---|---|---|
| S1 シート（正面） | 1:1 | 3 体 | **496 画素** ✅ | 1 回 | 約 1.2 倍 |
| P6 | 1:1 | 3×2 | **449 画素** ✅（A-7） | 3 回（S1・P6・W4） | 約 1.25 倍 |
| P4（2 枚） | 3:4 | 2×2 | 約 500 画素（W4 の実測から） | 4 回（S1・P4 2 枚・W4） | 約 1.2 倍 |
| W4 | 3:4 | 2×2 | **約 500 画素** ✅ | — | 約 1.2 倍 |
| 参考: P9（v1） | 3:4 | 3×3 | **330 画素** ✅ | 3 回 | 約 1.8 倍（輪郭がにじむ） |

- 引き伸ばしは、2-0 のピヨの体つき（立ち姿の幅が高さの 0.72 倍。いまのピヨは 0.64 倍）で計算した。立ち姿が幅 80% で決まり、画面では高さ約 587 画素（@3x）で描かれる。細いキャラほど大きく描くので、引き伸ばしは少し増える
- **目安（取り込みの知らせ）**: 立ち姿の高さが **400 画素未満なら「待受で少しぼやけます」**、**300 画素未満なら「ウィジェットでもぼやけます」**（プラン 2-C ⑤-7）
- **決めたこと（D-38、2026-09-26）**: 利用者は **P6 ＋ W4**（生成 3 回。作る手間を少なく）。既定の 5 体は **P4 の 2 枚 ＋ W4**（生成 4 回。見た目を優先）。利用者も、画面の「くっきりさせたいとき」から P4 を選べる

### 1.5 変えてよい所・変えてはいけない所

- **変えない**: ④ 取り込みの条件、⑤ 背景の 1 行、① のコマの数と並び。アプリの取り込み（コマの割り当て・知らせ）がこれに頼る
- **埋める**: ② キャラカード
- **変えてよい**: ③ 画風（ただし太い輪郭線と平塗りは、背景を外す処理を助けるので残すのが望ましい）
- **書かない**: 既存の作品名・キャラクター名・作家名・ブランド名（似すぎを避ける。`research/I` §3.1・§5.1）。例は既定の 5 体だけにする

---

## 2. フェーズ A: 試し（2-0。ピヨ 1 体）

### 2.1 結果（2026-09-26。v1 の A-1〜A-3、作り直しなし）

| 確かめたこと | 結果 |
|---|---|
| 手引きのとおりに作れるか | 3 枚とも 1 回で指示どおり（迷った所なし） ✅ |
| 形式 | PNG、本当の透明（縁は 100% 透明）。ただし**体の中の不透明さは 253〜254 で 255 にならず、縁の外に 1〜31 の薄いにじみ**がある ✅。来歴の情報（C2PA）があり、位置情報は無い ✅ |
| 大きさ | 約 157 万画素（1:1 は 1254×1254、3:4 は 1086×1448） ✅ |
| 切り分け | 3・9・4 体とも、手直しなしで分けられた（100%）。触れ合いも、ごみも無い。足元のずれは 1 段の中で 9 画素以内 ✅ |
| 大きさのそろい | 目の間隔がどのポーズでも ±2% で、頭の大きさがそろっていた（段によって外接矩形の高さが違うのは、姿勢の違い） ✅ |
| 枠に収まるか | **収まらなかった**。いまのピヨと同じ背にすると、寝姿（寝そべり）と、羽を広げた「よろこぶ」が縦長の枠からはみ出す。全部が収まる倍率では、立ち姿が枠の 69%（いまのピヨは 90%）になった ✅ → v2 で姿勢を縦にまとめる |
| まばたき | ChatGPT の「目だけ閉じた絵」は、目のまわりの差はきれいだが、輪郭が全体で 1〜2 画素ずれ、閉じた目の形も立ち姿（笑った目）とすわる姿（ふつうの閉じ目）で違う。目を開けた絵から作る試作は、目のまわりだけが変わり、寝姿の目と同じ形にそろった ✅ → アプリが作る（D-38） |
| 寝息の 2 コマ目 | 「息を吸った寝姿」は全体の 28% が違う別の絵 ✅ → 1 コマ目を縦に少し伸ばして作る |
| 保存の道 | 3 枚は Mac の Chrome で chatgpt.com から保存されていた（ファイルの記録）。**A-7 で、iPhone の ChatGPT から写真に保存し AirDrop で送った絵は、Mac で保存した絵と 1 バイトも違わなかった**（透明の PNG のまま）✅。アプリの `PhotosPicker`（`.current`）で同じに受け取れるかは、2-6 のあと実機で確かめる（S1） |

確かめた画像は `iPhone/2-0/`（git に入れない）。

### 2.2 A-7 v2 の確かめ（ポーズ 6 コマ）

**結果（2026-09-26）: 合格。** 1 回目で指示どおりの 6 コマになった。

| 確かめたこと | 結果 |
|---|---|
| 切り分け | 6 体とも手直しなしで分けられた。ごみも触れ合いも無い ✅ |
| 姿勢のまとまり | 立ち姿の幅に対して、すわる 0.96・寝姿 1.05（v1 は 1.37）・よろこぶ（腕を上げる）1.12・よろこぶ（ほお）0.91・見上げる 0.94 倍。どれも枠の幅 95% に収まり、**全コマを収めるための縮めは不要**（v1 は 87% まで縮めた）✅ |
| 大きさ | 立ち姿は 449 画素（見込みは約 430）。枠の中で高さ 77%・幅 80%。待受での引き伸ばしは約 1.25 倍 ✅ |
| まばたき | 目を開けた絵から作る処理が、立ち姿・すわる姿とも 2 つの目を正しく見つけ、変わる画素は目のまわりに収まった ✅ |
| 寝息の 2 コマ目 | 1 コマ目を縦に 3% 伸ばすと、細いとさかで 1 コマ目を覆いきれない（543 画素がはみ出す）。覆えないときの描き方（2 枚を出し分ける）になる。いまの 5 体も同じ描き方（`sleepFrameCoversBase` はどれも false）✅ |
| 形式 | 1254×1254 の透明 PNG。体の中の不透明さは 252〜254 が 93%（2-0 と同じ）✅ |
| 保存の道 | iPhone の写真から送った絵と、Mac で保存した絵は 1 バイトも違わなかった ✅ |

アプリの枠に当てた姿と、アプリが作ったまばたきの見本は `iPhone/2-0/`（git に入れない）。

**ねらい**: v2 の言い回しで、(1) 姿勢が縦にまとまり、立ち姿を本来の大きさ（幅 80% いっぱい）にしたまま、全コマが枠に収まるか、(2) 6 コマでの立ち姿の画素数（見込み約 430）を確かめる。

1. ChatGPT で**新しいチャット**を開き、「＋」から **A-1 の絵**（2-0 のキャラシート）を添えて、下の **A-7** を送る（作り直さずに、1 回目の絵でよい）
2. 保存して Mac に置く（前回と同じく `iPhone/` でよい）。できれば iPhone でも同じ絵を「保存」（写真）して AirDrop で送る（写真を通したときの透明の確かめ。任意）

**A-7 ポーズ 6 コマ（v2）**

```text
Image 1 is the reference sheet of this character. Keep the design exactly the same: shapes, colors, face and proportions. Do not redesign it.

Make ONE square image (1:1) with exactly 6 poses of this character in 2 rows x 3 columns:
Row 1: (1) standing, front view, wings at the sides, eyes open. (2) sitting on the floor, front view, feet forward, eyes open. (3) asleep, curled up in a round ball on its belly, side view facing left, eyes closed.
Row 2: (4) happy, eyes closed in a big smile, both wings raised straight up beside the head, feet on the ground. (5) happy, eyes closed in a big smile, wings bent up next to the cheeks, feet on the ground. (6) standing, front view, looking up.

Character: "Piyo", a round chick-like creature. An original character, not based on any existing character or brand.
Colors: body soft yellow #FFE066, wings a slightly deeper yellow #FFCF4D, beak and feet orange #FF9F43, cheeks pink #FFB3C6. Outline: dark brown #3B2B2B.
Keep these features exactly: one small curved crest feather on top of the head; two small black dot eyes with a tiny white highlight; a small triangle beak; small rounded wings; short orange feet.

Style: cute, simple mascot art. About two heads tall, big round head, short rounded limbs, no fingers.
Thick, even dark-brown outline around every shape. Flat colors with at most one soft shade. No gradients, no texture, no glow.

Rules: every drawing is full body and the same size; in each row, all drawings rest on the same ground line.
Keep every pose compact: arms stay close to the body or point up, never spread out to the sides, and no pose is wider than the standing pose.
Leave wide empty space around every drawing; nothing touches another drawing or the edge of the image.
No shadows at all (not even under the feet). No text, letters, numbers or labels. No grid lines, dividers, frames or borders. No watermark or signature.

Background: fully transparent (real alpha, PNG). No background color, no checkerboard, no floor.
```

**Claude が確かめること**: 6 体に分けられるか、どの姿勢も立ち姿より横に広くないか（寝姿・よろこぶ）、全コマを収めるために本来の大きさから何 % 縮めるか（1 割未満なら合格）、立ち姿の画素数。うまくいかなければ言い回しを直して v2 を改める。

### 2.3 v1 で使ったプロンプト（記録）

<details>
<summary>v1 のプロンプト（2-0 で使った A-1〜A-3 と、任意の A-4〜A-6）</summary>

**A-1 キャラシート**（v1。段の指示は v2 でも同じ。v2 では取り込みの条件に 1 行足した）

```text
Make a character reference sheet of this character. Square image (1:1).
Three full-body views side by side, left to right: FRONT, SIDE (facing left), BACK.

Character: "Piyo", a round chick-like creature. An original character, not based on any existing character or brand.
Colors: body soft yellow #FFE066, wings a slightly deeper yellow #FFCF4D, beak and feet orange #FF9F43, cheeks pink #FFB3C6. Outline: dark brown #3B2B2B.
Keep these features exactly: one small curved crest feather on top of the head; two small black dot eyes with a tiny white highlight; a small triangle beak; small rounded wings; short orange feet.

Style: cute, simple mascot art. About two heads tall, big round head, short rounded limbs, no fingers.
Thick, even dark-brown outline around every shape. Flat colors with at most one soft shade. No gradients, no texture, no glow.

Rules: every drawing is full body and the same size; in each row, all drawings rest on the same ground line.
Leave wide empty space around every drawing; nothing touches another drawing or the edge of the image.
No shadows at all (not even under the feet). No text, letters, numbers or labels. No grid lines, dividers, frames or borders. No watermark or signature.

Background: fully transparent (real alpha, PNG). No background color, no checkerboard, no floor.
```

**A-2 ポーズ 9 コマ**（v1。v2 では使わない）

```text
Image 1 is the reference sheet of this character. Keep the design exactly the same: shapes, colors, face and proportions. Do not redesign it.

Make ONE portrait image (3:4) with exactly 9 poses of this character in 3 rows x 3 columns:
Row 1: (1) standing, front view, wings at the sides, eyes open. (2) exactly the same as (1), only the eyes closed. (3) sitting on the floor, front view, feet forward, eyes open.
Row 2: (4) exactly the same as (3), only the eyes closed. (5) lying on its belly asleep, side view facing left, eyes closed. (6) exactly the same as (5), body slightly rounder (breathing in).
Row 3: (7) happy, eyes closed in a big smile, both wings raised, feet on the ground. (8) happy, eyes closed in a big smile, wings spread out, feet on the ground. (9) standing, front view, looking up.

Character: "Piyo", a round chick-like creature. An original character, not based on any existing character or brand.
Colors: body soft yellow #FFE066, wings a slightly deeper yellow #FFCF4D, beak and feet orange #FF9F43, cheeks pink #FFB3C6. Outline: dark brown #3B2B2B.
Keep these features exactly: one small curved crest feather on top of the head; two small black dot eyes with a tiny white highlight; a small triangle beak; small rounded wings; short orange feet.

Style: cute, simple mascot art. About two heads tall, big round head, short rounded limbs, no fingers.
Thick, even dark-brown outline around every shape. Flat colors with at most one soft shade. No gradients, no texture, no glow.

Rules: every drawing is full body and the same size; in each row, all drawings rest on the same ground line.
Leave wide empty space around every drawing; nothing touches another drawing or the edge of the image.
No shadows at all (not even under the feet). No text, letters, numbers or labels. No grid lines, dividers, frames or borders. No watermark or signature.

Background: fully transparent (real alpha, PNG). No background color, no checkerboard, no floor.
```

**A-3 歩く 4 コマ**（v1。取り込みの条件の 1 行のほかは v2 と同じ）

```text
Image 1 is the reference sheet of this character. Keep the design exactly the same: shapes, colors, face and proportions. Do not redesign it.

Make ONE portrait image (3:4) with exactly 4 walking frames of this character in 2 rows x 2 columns. Side view facing LEFT in every frame.
(1) front foot forward, back foot back. (2) feet together under the body. (3) the other foot forward. (4) feet together under the body.
Only the feet and wings move. The head and body keep the same size and the same height in all 4 frames.

Character: "Piyo", a round chick-like creature. An original character, not based on any existing character or brand.
Colors: body soft yellow #FFE066, wings a slightly deeper yellow #FFCF4D, beak and feet orange #FF9F43, cheeks pink #FFB3C6. Outline: dark brown #3B2B2B.
Keep these features exactly: one small curved crest feather on top of the head; two small black dot eyes with a tiny white highlight; a small triangle beak; small rounded wings; short orange feet.

Style: cute, simple mascot art. About two heads tall, big round head, short rounded limbs, no fingers.
Thick, even dark-brown outline around every shape. Flat colors with at most one soft shade. No gradients, no texture, no glow.

Rules: every drawing is full body and the same size; in each row, all drawings rest on the same ground line.
Leave wide empty space around every drawing; nothing touches another drawing or the edge of the image.
No shadows at all (not even under the feet). No text, letters, numbers or labels. No grid lines, dividers, frames or borders. No watermark or signature.

Background: fully transparent (real alpha, PNG). No background color, no checkerboard, no floor.
```

**A-4・A-5（Gemini）**: A-1・A-2 の背景の行を `Background: solid pure white #FFFFFF everywhere. No gradient, no texture, no floor.` にしたもの（試していない）

**A-6（Claude の SVG）**

```text
Write ONE SVG sprite sheet for an iPhone app. Reply with the SVG code only, no explanation.

Character: "Piyo", a round chick-like creature. An original character, not based on any existing character or brand.
Colors: body #FFE066, wings #FFCF4D, beak and feet #FF9F43, cheeks #FFB3C6, outline #3B2B2B.
Keep these features exactly: one small curved crest feather on top of the head; two small black dot eyes with a tiny white highlight; a small triangle beak; small rounded wings; short orange feet.

Root: <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 520 540" width="520" height="540">. No background.
Grid: 4 columns x 3 rows of cells, each 130 wide x 180 tall. Cell n (0-11) is at x = 130 * (n mod 4), y = 180 * floor(n / 4).
Wrap each cell in <g id="NAME" transform="translate(X,Y)"> with the numbers written out, and draw inside it in cell coordinates (0-130 x 0-180).
In every cell: the feet touch y = 168, the top of the head is near y = 25, the body is centered on x = 65, and nothing crosses the cell edges.
Cells: 0 idle_01 standing, front, eyes open. 1 idle_02 the same, eyes closed. 2 sit_01 sitting, front, feet forward, eyes open. 3 sit_02 the same, eyes closed.
4-7 walk_01..walk_04 side view facing LEFT: front foot forward, feet together, the other foot forward, feet together.
8 sleep_01 lying on its belly asleep, facing left, eyes closed. 9 sleep_02 the same, body 3% taller. 10 happy_01 eyes closed in a smile, wings raised. 11 happy_02 eyes closed in a smile, wings spread.
Style: stroke #3B2B2B, stroke-width 5, round joins and caps; flat fills; no gradients.
Draw the head and body once in <defs> and reuse them with <use>, so cells 1 and 3 differ from cells 0 and 2 only in the eyes.
Use only these elements: svg, g, defs, use, path, circle, ellipse, rect. No text, style, CSS, filter, gradient, image, script or link.
```

</details>

---

## 3. フェーズ B: 既定の 5 体（2-4）

**ねらい**: 既定の 5 体を本番の絵にする。**利用者と同じ本文（§1.3）** を使い、いまの絵を参照に添える点と、ポーズを 2 枚に分けて大きく描く点（D-38）が違う。作り方は Q-18 で決めた（5 体とも生成 AI で作り直す。40pt で見分けがつかない・その子らしさが消えた子は、いまの SVG のまま残す）。
**場所**: Mac の ChatGPT（Web かアプリ）。参照画像を添えやすく、大きな絵をそのまま保存できる。

### 3.1 手順（1 体ぶん。生成は 4 回）

1. Claude が、いまの絵（Asset Catalog の `<id>_idle_01@3x.png` と `<id>_walk_01@3x.png`）を `assets-src/characters/<id>/ref/` に置く
2. **B-1 シート**: 新しいチャットで ref の 2 枚を添えて送る。気に入るまで作り直す（ここで見た目が決まる）
3. **B-2a・B-2b ポーズ**: それぞれ新しいチャットで、B-1 の絵を添えて送る
4. **B-3 歩く**: 新しいチャットで、B-1 の絵を添えて送る
5. 生成そのままの絵を `assets-src/characters/<id>/raw/` に置く（git に入れない）
6. Claude が採点し（§3.3）、似たキャラを確かめ（§3.4）、Mac の道具で整えてコンタクトシートを見る。直しは §5 のプロンプトで
7. 記録を `assets-src/characters/<id>/prompts.md` に残す（§3.5）

### 3.2 5 体ぶんの組み上げたプロンプト（開いて、そのまま貼る）

色は `design/chara.py` のパレット ✅。フワは足が無いので、足の言い回しを裾に置き換えてある（すわる姿は裾を広げ、歩きは裾が揺れる「すべる」4 コマ）。

<details>
<summary>ピヨ（piyo）</summary>

**キャラカード**

```text
Character: "Piyo", a round chick-like creature. An original character, not based on any existing character or brand.
Colors: body soft yellow #FFE066, wings a slightly deeper yellow #FFCF4D, beak and feet orange #FF9F43, cheeks pink #FFB3C6. Outline: dark brown #3B2B2B.
Keep these features exactly: one small curved crest feather on top of the head; two small black dot eyes with a tiny white highlight; a small triangle beak; small rounded wings; short orange feet.
```

**B-1 キャラシート**（新しいチャットで、`ref/` の 2 枚を添えて送る）

```text
Image 1 and Image 2 are the current simple drawings of this character (front and side). Keep the same character — shapes, colors and features — and redraw it as a clean, higher-quality character reference sheet.

Make a character reference sheet of this character. Square image (1:1).
Three full-body views side by side, left to right: FRONT, SIDE (facing left), BACK.

Character: "Piyo", a round chick-like creature. An original character, not based on any existing character or brand.
Colors: body soft yellow #FFE066, wings a slightly deeper yellow #FFCF4D, beak and feet orange #FF9F43, cheeks pink #FFB3C6. Outline: dark brown #3B2B2B.
Keep these features exactly: one small curved crest feather on top of the head; two small black dot eyes with a tiny white highlight; a small triangle beak; small rounded wings; short orange feet.

Style: cute, simple mascot art. About two heads tall, big round head, short rounded limbs, no fingers.
Thick, even dark-brown outline around every shape. Flat colors with at most one soft shade. No gradients, no texture, no glow.

Rules: every drawing is full body and the same size; in each row, all drawings rest on the same ground line.
Keep every pose compact: arms stay close to the body or point up, never spread out to the sides, and no pose is wider than the standing pose.
Leave wide empty space around every drawing; nothing touches another drawing or the edge of the image.
No shadows at all (not even under the feet). No text, letters, numbers or labels. No grid lines, dividers, frames or borders. No watermark or signature.

Background: fully transparent (real alpha, PNG). No background color, no checkerboard, no floor.
```

**B-2a ポーズ 4 コマ（1 枚目）**（新しいチャットで、B-1 の絵を添えて送る）

```text
Image 1 is the reference sheet of this character. Keep the design exactly the same: shapes, colors, face and proportions. Do not redesign it.

Make ONE portrait image (3:4) with exactly 4 poses of this character in 2 rows x 2 columns:
(1) standing, front view, wings at the sides, eyes open. (2) sitting on the floor, front view, feet forward, eyes open.
(3) asleep, curled up in a round ball on its belly, side view facing left, eyes closed. (4) happy, eyes closed in a big smile, both wings raised straight up beside the head, feet on the ground.

Character: "Piyo", a round chick-like creature. An original character, not based on any existing character or brand.
Colors: body soft yellow #FFE066, wings a slightly deeper yellow #FFCF4D, beak and feet orange #FF9F43, cheeks pink #FFB3C6. Outline: dark brown #3B2B2B.
Keep these features exactly: one small curved crest feather on top of the head; two small black dot eyes with a tiny white highlight; a small triangle beak; small rounded wings; short orange feet.

Style: cute, simple mascot art. About two heads tall, big round head, short rounded limbs, no fingers.
Thick, even dark-brown outline around every shape. Flat colors with at most one soft shade. No gradients, no texture, no glow.

Rules: every drawing is full body and the same size; in each row, all drawings rest on the same ground line.
Keep every pose compact: arms stay close to the body or point up, never spread out to the sides, and no pose is wider than the standing pose.
Leave wide empty space around every drawing; nothing touches another drawing or the edge of the image.
No shadows at all (not even under the feet). No text, letters, numbers or labels. No grid lines, dividers, frames or borders. No watermark or signature.

Background: fully transparent (real alpha, PNG). No background color, no checkerboard, no floor.
```

**B-2b ポーズ 4 コマ（2 枚目）**（新しいチャットで、B-1 の絵を添えて送る）

```text
Image 1 is the reference sheet of this character. Keep the design exactly the same: shapes, colors, face and proportions. Do not redesign it.

Make ONE portrait image (3:4) with exactly 4 poses of this character in 2 rows x 2 columns:
(1) standing, front view, wings at the sides, eyes open (the same as the FRONT view in Image 1). (2) happy, eyes closed in a big smile, wings bent up next to the cheeks, feet on the ground.
(3) standing, front view, looking up. (4) surprised, front view, eyes wide open, wings slightly raised.

Character: "Piyo", a round chick-like creature. An original character, not based on any existing character or brand.
Colors: body soft yellow #FFE066, wings a slightly deeper yellow #FFCF4D, beak and feet orange #FF9F43, cheeks pink #FFB3C6. Outline: dark brown #3B2B2B.
Keep these features exactly: one small curved crest feather on top of the head; two small black dot eyes with a tiny white highlight; a small triangle beak; small rounded wings; short orange feet.

Style: cute, simple mascot art. About two heads tall, big round head, short rounded limbs, no fingers.
Thick, even dark-brown outline around every shape. Flat colors with at most one soft shade. No gradients, no texture, no glow.

Rules: every drawing is full body and the same size; in each row, all drawings rest on the same ground line.
Keep every pose compact: arms stay close to the body or point up, never spread out to the sides, and no pose is wider than the standing pose.
Leave wide empty space around every drawing; nothing touches another drawing or the edge of the image.
No shadows at all (not even under the feet). No text, letters, numbers or labels. No grid lines, dividers, frames or borders. No watermark or signature.

Background: fully transparent (real alpha, PNG). No background color, no checkerboard, no floor.
```

**B-3 歩く 4 コマ**（新しいチャットで、B-1 の絵を添えて送る）

```text
Image 1 is the reference sheet of this character. Keep the design exactly the same: shapes, colors, face and proportions. Do not redesign it.

Make ONE portrait image (3:4) with exactly 4 walking frames of this character in 2 rows x 2 columns. Side view facing LEFT in every frame.
(1) front foot forward, back foot back. (2) feet together under the body. (3) the other foot forward. (4) feet together under the body.
Only the feet and wings move. The head and body keep the same size and the same height in all 4 frames.

Character: "Piyo", a round chick-like creature. An original character, not based on any existing character or brand.
Colors: body soft yellow #FFE066, wings a slightly deeper yellow #FFCF4D, beak and feet orange #FF9F43, cheeks pink #FFB3C6. Outline: dark brown #3B2B2B.
Keep these features exactly: one small curved crest feather on top of the head; two small black dot eyes with a tiny white highlight; a small triangle beak; small rounded wings; short orange feet.

Style: cute, simple mascot art. About two heads tall, big round head, short rounded limbs, no fingers.
Thick, even dark-brown outline around every shape. Flat colors with at most one soft shade. No gradients, no texture, no glow.

Rules: every drawing is full body and the same size; in each row, all drawings rest on the same ground line.
Keep every pose compact: arms stay close to the body or point up, never spread out to the sides, and no pose is wider than the standing pose.
Leave wide empty space around every drawing; nothing touches another drawing or the edge of the image.
No shadows at all (not even under the feet). No text, letters, numbers or labels. No grid lines, dividers, frames or borders. No watermark or signature.

Background: fully transparent (real alpha, PNG). No background color, no checkerboard, no floor.
```

</details>

<details>
<summary>モチ（mochi）</summary>

**キャラカード**

```text
Character: "Mochi", a round, soft, cat-like creature. An original character, not based on any existing character or brand.
Colors: body off-white #FFF6EE, arms and feet cream #FFEADD, inside of the ears pink #FFC9D9, cheeks pink #FFB3C6. Outline: dark brown #3B2B2B.
Keep these features exactly: two small triangle ears with pink insides; two small black dot eyes with a tiny white highlight; a small smiling mouth that is always visible; tiny rounded arms and feet. No ribbon, bow or other accessory.
```

**B-1 キャラシート**（新しいチャットで、`ref/` の 2 枚を添えて送る）

```text
Image 1 and Image 2 are the current simple drawings of this character (front and side). Keep the same character — shapes, colors and features — and redraw it as a clean, higher-quality character reference sheet.

Make a character reference sheet of this character. Square image (1:1).
Three full-body views side by side, left to right: FRONT, SIDE (facing left), BACK.

Character: "Mochi", a round, soft, cat-like creature. An original character, not based on any existing character or brand.
Colors: body off-white #FFF6EE, arms and feet cream #FFEADD, inside of the ears pink #FFC9D9, cheeks pink #FFB3C6. Outline: dark brown #3B2B2B.
Keep these features exactly: two small triangle ears with pink insides; two small black dot eyes with a tiny white highlight; a small smiling mouth that is always visible; tiny rounded arms and feet. No ribbon, bow or other accessory.

Style: cute, simple mascot art. About two heads tall, big round head, short rounded limbs, no fingers.
Thick, even dark-brown outline around every shape. Flat colors with at most one soft shade. No gradients, no texture, no glow.

Rules: every drawing is full body and the same size; in each row, all drawings rest on the same ground line.
Keep every pose compact: arms stay close to the body or point up, never spread out to the sides, and no pose is wider than the standing pose.
Leave wide empty space around every drawing; nothing touches another drawing or the edge of the image.
No shadows at all (not even under the feet). No text, letters, numbers or labels. No grid lines, dividers, frames or borders. No watermark or signature.

Background: fully transparent (real alpha, PNG). No background color, no checkerboard, no floor.
```

**B-2a ポーズ 4 コマ（1 枚目）**（新しいチャットで、B-1 の絵を添えて送る）

```text
Image 1 is the reference sheet of this character. Keep the design exactly the same: shapes, colors, face and proportions. Do not redesign it.

Make ONE portrait image (3:4) with exactly 4 poses of this character in 2 rows x 2 columns:
(1) standing, front view, arms at the sides, eyes open. (2) sitting on the floor, front view, feet forward, eyes open.
(3) asleep, curled up in a round ball on its belly, side view facing left, eyes closed. (4) happy, eyes closed in a big smile, both arms raised straight up beside the head, feet on the ground.

Character: "Mochi", a round, soft, cat-like creature. An original character, not based on any existing character or brand.
Colors: body off-white #FFF6EE, arms and feet cream #FFEADD, inside of the ears pink #FFC9D9, cheeks pink #FFB3C6. Outline: dark brown #3B2B2B.
Keep these features exactly: two small triangle ears with pink insides; two small black dot eyes with a tiny white highlight; a small smiling mouth that is always visible; tiny rounded arms and feet. No ribbon, bow or other accessory.

Style: cute, simple mascot art. About two heads tall, big round head, short rounded limbs, no fingers.
Thick, even dark-brown outline around every shape. Flat colors with at most one soft shade. No gradients, no texture, no glow.

Rules: every drawing is full body and the same size; in each row, all drawings rest on the same ground line.
Keep every pose compact: arms stay close to the body or point up, never spread out to the sides, and no pose is wider than the standing pose.
Leave wide empty space around every drawing; nothing touches another drawing or the edge of the image.
No shadows at all (not even under the feet). No text, letters, numbers or labels. No grid lines, dividers, frames or borders. No watermark or signature.

Background: fully transparent (real alpha, PNG). No background color, no checkerboard, no floor.
```

**B-2b ポーズ 4 コマ（2 枚目）**（新しいチャットで、B-1 の絵を添えて送る）

```text
Image 1 is the reference sheet of this character. Keep the design exactly the same: shapes, colors, face and proportions. Do not redesign it.

Make ONE portrait image (3:4) with exactly 4 poses of this character in 2 rows x 2 columns:
(1) standing, front view, arms at the sides, eyes open (the same as the FRONT view in Image 1). (2) happy, eyes closed in a big smile, arms bent up next to the cheeks, feet on the ground.
(3) standing, front view, looking up. (4) surprised, front view, eyes wide open, arms slightly raised.

Character: "Mochi", a round, soft, cat-like creature. An original character, not based on any existing character or brand.
Colors: body off-white #FFF6EE, arms and feet cream #FFEADD, inside of the ears pink #FFC9D9, cheeks pink #FFB3C6. Outline: dark brown #3B2B2B.
Keep these features exactly: two small triangle ears with pink insides; two small black dot eyes with a tiny white highlight; a small smiling mouth that is always visible; tiny rounded arms and feet. No ribbon, bow or other accessory.

Style: cute, simple mascot art. About two heads tall, big round head, short rounded limbs, no fingers.
Thick, even dark-brown outline around every shape. Flat colors with at most one soft shade. No gradients, no texture, no glow.

Rules: every drawing is full body and the same size; in each row, all drawings rest on the same ground line.
Keep every pose compact: arms stay close to the body or point up, never spread out to the sides, and no pose is wider than the standing pose.
Leave wide empty space around every drawing; nothing touches another drawing or the edge of the image.
No shadows at all (not even under the feet). No text, letters, numbers or labels. No grid lines, dividers, frames or borders. No watermark or signature.

Background: fully transparent (real alpha, PNG). No background color, no checkerboard, no floor.
```

**B-3 歩く 4 コマ**（新しいチャットで、B-1 の絵を添えて送る）

```text
Image 1 is the reference sheet of this character. Keep the design exactly the same: shapes, colors, face and proportions. Do not redesign it.

Make ONE portrait image (3:4) with exactly 4 walking frames of this character in 2 rows x 2 columns. Side view facing LEFT in every frame.
(1) front foot forward, back foot back. (2) feet together under the body. (3) the other foot forward. (4) feet together under the body.
Only the feet and arms move. The head and body keep the same size and the same height in all 4 frames.

Character: "Mochi", a round, soft, cat-like creature. An original character, not based on any existing character or brand.
Colors: body off-white #FFF6EE, arms and feet cream #FFEADD, inside of the ears pink #FFC9D9, cheeks pink #FFB3C6. Outline: dark brown #3B2B2B.
Keep these features exactly: two small triangle ears with pink insides; two small black dot eyes with a tiny white highlight; a small smiling mouth that is always visible; tiny rounded arms and feet. No ribbon, bow or other accessory.

Style: cute, simple mascot art. About two heads tall, big round head, short rounded limbs, no fingers.
Thick, even dark-brown outline around every shape. Flat colors with at most one soft shade. No gradients, no texture, no glow.

Rules: every drawing is full body and the same size; in each row, all drawings rest on the same ground line.
Keep every pose compact: arms stay close to the body or point up, never spread out to the sides, and no pose is wider than the standing pose.
Leave wide empty space around every drawing; nothing touches another drawing or the edge of the image.
No shadows at all (not even under the feet). No text, letters, numbers or labels. No grid lines, dividers, frames or borders. No watermark or signature.

Background: fully transparent (real alpha, PNG). No background color, no checkerboard, no floor.
```

</details>

<details>
<summary>クマオ（kumao）</summary>

**キャラカード**

```text
Character: "Kumao", a round bear-like creature. An original character, not based on any existing character or brand.
Colors: body warm brown #C89464, arms and feet a slightly darker brown #B8814F, muzzle and inside of the ears cream #F2DCC2, cheeks #E79A86. Outline: dark brown #3B2B2B.
Keep these features exactly: two round ears with cream insides; a cream oval muzzle with a small dark nose; two small black dot eyes with a tiny white highlight; short rounded arms and feet.
```

**B-1 キャラシート**（新しいチャットで、`ref/` の 2 枚を添えて送る）

```text
Image 1 and Image 2 are the current simple drawings of this character (front and side). Keep the same character — shapes, colors and features — and redraw it as a clean, higher-quality character reference sheet.

Make a character reference sheet of this character. Square image (1:1).
Three full-body views side by side, left to right: FRONT, SIDE (facing left), BACK.

Character: "Kumao", a round bear-like creature. An original character, not based on any existing character or brand.
Colors: body warm brown #C89464, arms and feet a slightly darker brown #B8814F, muzzle and inside of the ears cream #F2DCC2, cheeks #E79A86. Outline: dark brown #3B2B2B.
Keep these features exactly: two round ears with cream insides; a cream oval muzzle with a small dark nose; two small black dot eyes with a tiny white highlight; short rounded arms and feet.

Style: cute, simple mascot art. About two heads tall, big round head, short rounded limbs, no fingers.
Thick, even dark-brown outline around every shape. Flat colors with at most one soft shade. No gradients, no texture, no glow.

Rules: every drawing is full body and the same size; in each row, all drawings rest on the same ground line.
Keep every pose compact: arms stay close to the body or point up, never spread out to the sides, and no pose is wider than the standing pose.
Leave wide empty space around every drawing; nothing touches another drawing or the edge of the image.
No shadows at all (not even under the feet). No text, letters, numbers or labels. No grid lines, dividers, frames or borders. No watermark or signature.

Background: fully transparent (real alpha, PNG). No background color, no checkerboard, no floor.
```

**B-2a ポーズ 4 コマ（1 枚目）**（新しいチャットで、B-1 の絵を添えて送る）

```text
Image 1 is the reference sheet of this character. Keep the design exactly the same: shapes, colors, face and proportions. Do not redesign it.

Make ONE portrait image (3:4) with exactly 4 poses of this character in 2 rows x 2 columns:
(1) standing, front view, arms at the sides, eyes open. (2) sitting on the floor, front view, feet forward, eyes open.
(3) asleep, curled up in a round ball on its belly, side view facing left, eyes closed. (4) happy, eyes closed in a big smile, both arms raised straight up beside the head, feet on the ground.

Character: "Kumao", a round bear-like creature. An original character, not based on any existing character or brand.
Colors: body warm brown #C89464, arms and feet a slightly darker brown #B8814F, muzzle and inside of the ears cream #F2DCC2, cheeks #E79A86. Outline: dark brown #3B2B2B.
Keep these features exactly: two round ears with cream insides; a cream oval muzzle with a small dark nose; two small black dot eyes with a tiny white highlight; short rounded arms and feet.

Style: cute, simple mascot art. About two heads tall, big round head, short rounded limbs, no fingers.
Thick, even dark-brown outline around every shape. Flat colors with at most one soft shade. No gradients, no texture, no glow.

Rules: every drawing is full body and the same size; in each row, all drawings rest on the same ground line.
Keep every pose compact: arms stay close to the body or point up, never spread out to the sides, and no pose is wider than the standing pose.
Leave wide empty space around every drawing; nothing touches another drawing or the edge of the image.
No shadows at all (not even under the feet). No text, letters, numbers or labels. No grid lines, dividers, frames or borders. No watermark or signature.

Background: fully transparent (real alpha, PNG). No background color, no checkerboard, no floor.
```

**B-2b ポーズ 4 コマ（2 枚目）**（新しいチャットで、B-1 の絵を添えて送る）

```text
Image 1 is the reference sheet of this character. Keep the design exactly the same: shapes, colors, face and proportions. Do not redesign it.

Make ONE portrait image (3:4) with exactly 4 poses of this character in 2 rows x 2 columns:
(1) standing, front view, arms at the sides, eyes open (the same as the FRONT view in Image 1). (2) happy, eyes closed in a big smile, arms bent up next to the cheeks, feet on the ground.
(3) standing, front view, looking up. (4) surprised, front view, eyes wide open, arms slightly raised.

Character: "Kumao", a round bear-like creature. An original character, not based on any existing character or brand.
Colors: body warm brown #C89464, arms and feet a slightly darker brown #B8814F, muzzle and inside of the ears cream #F2DCC2, cheeks #E79A86. Outline: dark brown #3B2B2B.
Keep these features exactly: two round ears with cream insides; a cream oval muzzle with a small dark nose; two small black dot eyes with a tiny white highlight; short rounded arms and feet.

Style: cute, simple mascot art. About two heads tall, big round head, short rounded limbs, no fingers.
Thick, even dark-brown outline around every shape. Flat colors with at most one soft shade. No gradients, no texture, no glow.

Rules: every drawing is full body and the same size; in each row, all drawings rest on the same ground line.
Keep every pose compact: arms stay close to the body or point up, never spread out to the sides, and no pose is wider than the standing pose.
Leave wide empty space around every drawing; nothing touches another drawing or the edge of the image.
No shadows at all (not even under the feet). No text, letters, numbers or labels. No grid lines, dividers, frames or borders. No watermark or signature.

Background: fully transparent (real alpha, PNG). No background color, no checkerboard, no floor.
```

**B-3 歩く 4 コマ**（新しいチャットで、B-1 の絵を添えて送る）

```text
Image 1 is the reference sheet of this character. Keep the design exactly the same: shapes, colors, face and proportions. Do not redesign it.

Make ONE portrait image (3:4) with exactly 4 walking frames of this character in 2 rows x 2 columns. Side view facing LEFT in every frame.
(1) front foot forward, back foot back. (2) feet together under the body. (3) the other foot forward. (4) feet together under the body.
Only the feet and arms move. The head and body keep the same size and the same height in all 4 frames.

Character: "Kumao", a round bear-like creature. An original character, not based on any existing character or brand.
Colors: body warm brown #C89464, arms and feet a slightly darker brown #B8814F, muzzle and inside of the ears cream #F2DCC2, cheeks #E79A86. Outline: dark brown #3B2B2B.
Keep these features exactly: two round ears with cream insides; a cream oval muzzle with a small dark nose; two small black dot eyes with a tiny white highlight; short rounded arms and feet.

Style: cute, simple mascot art. About two heads tall, big round head, short rounded limbs, no fingers.
Thick, even dark-brown outline around every shape. Flat colors with at most one soft shade. No gradients, no texture, no glow.

Rules: every drawing is full body and the same size; in each row, all drawings rest on the same ground line.
Keep every pose compact: arms stay close to the body or point up, never spread out to the sides, and no pose is wider than the standing pose.
Leave wide empty space around every drawing; nothing touches another drawing or the edge of the image.
No shadows at all (not even under the feet). No text, letters, numbers or labels. No grid lines, dividers, frames or borders. No watermark or signature.

Background: fully transparent (real alpha, PNG). No background color, no checkerboard, no floor.
```

</details>

<details>
<summary>フワ（fuwa）</summary>

**キャラカード**

```text
Character: "Fuwa", a soft ghost-like creature. An original character, not based on any existing character or brand.
Colors: body lavender #C9BCEA, shade #B7A6E0, light accent #F3EEFB, cheeks #E3B6D8. Outline: dark brown #3B2B2B.
Keep these features exactly: one small teardrop-shaped tuft on top of the head; a wavy hem at the bottom instead of feet (the hem touches the ground line); small rounded arms; two small black dot eyes with a tiny white highlight.
```

**B-1 キャラシート**（新しいチャットで、`ref/` の 2 枚を添えて送る）

```text
Image 1 and Image 2 are the current simple drawings of this character (front and side). Keep the same character — shapes, colors and features — and redraw it as a clean, higher-quality character reference sheet.

Make a character reference sheet of this character. Square image (1:1).
Three full-body views side by side, left to right: FRONT, SIDE (facing left), BACK.

Character: "Fuwa", a soft ghost-like creature. An original character, not based on any existing character or brand.
Colors: body lavender #C9BCEA, shade #B7A6E0, light accent #F3EEFB, cheeks #E3B6D8. Outline: dark brown #3B2B2B.
Keep these features exactly: one small teardrop-shaped tuft on top of the head; a wavy hem at the bottom instead of feet (the hem touches the ground line); small rounded arms; two small black dot eyes with a tiny white highlight.

Style: cute, simple mascot art. About two heads tall, big round head, short rounded limbs, no fingers.
Thick, even dark-brown outline around every shape. Flat colors with at most one soft shade. No gradients, no texture, no glow.

Rules: every drawing is full body and the same size; in each row, all drawings rest on the same ground line.
Keep every pose compact: arms stay close to the body or point up, never spread out to the sides, and no pose is wider than the standing pose.
Leave wide empty space around every drawing; nothing touches another drawing or the edge of the image.
No shadows at all (not even under the feet). No text, letters, numbers or labels. No grid lines, dividers, frames or borders. No watermark or signature.

Background: fully transparent (real alpha, PNG). No background color, no checkerboard, no floor.
```

**B-2a ポーズ 4 コマ（1 枚目）**（新しいチャットで、B-1 の絵を添えて送る）

```text
Image 1 is the reference sheet of this character. Keep the design exactly the same: shapes, colors, face and proportions. Do not redesign it.

Make ONE portrait image (3:4) with exactly 4 poses of this character in 2 rows x 2 columns:
(1) standing, front view, arms at the sides, eyes open. (2) sitting on the floor, front view, the wavy hem spread out on the floor, eyes open.
(3) asleep, curled up in a round ball on its belly, side view facing left, eyes closed. (4) happy, eyes closed in a big smile, both arms raised straight up beside the head, the wavy hem touching the ground.

Character: "Fuwa", a soft ghost-like creature. An original character, not based on any existing character or brand.
Colors: body lavender #C9BCEA, shade #B7A6E0, light accent #F3EEFB, cheeks #E3B6D8. Outline: dark brown #3B2B2B.
Keep these features exactly: one small teardrop-shaped tuft on top of the head; a wavy hem at the bottom instead of feet (the hem touches the ground line); small rounded arms; two small black dot eyes with a tiny white highlight.

Style: cute, simple mascot art. About two heads tall, big round head, short rounded limbs, no fingers.
Thick, even dark-brown outline around every shape. Flat colors with at most one soft shade. No gradients, no texture, no glow.

Rules: every drawing is full body and the same size; in each row, all drawings rest on the same ground line.
Keep every pose compact: arms stay close to the body or point up, never spread out to the sides, and no pose is wider than the standing pose.
Leave wide empty space around every drawing; nothing touches another drawing or the edge of the image.
No shadows at all (not even under the feet). No text, letters, numbers or labels. No grid lines, dividers, frames or borders. No watermark or signature.

Background: fully transparent (real alpha, PNG). No background color, no checkerboard, no floor.
```

**B-2b ポーズ 4 コマ（2 枚目）**（新しいチャットで、B-1 の絵を添えて送る）

```text
Image 1 is the reference sheet of this character. Keep the design exactly the same: shapes, colors, face and proportions. Do not redesign it.

Make ONE portrait image (3:4) with exactly 4 poses of this character in 2 rows x 2 columns:
(1) standing, front view, arms at the sides, eyes open (the same as the FRONT view in Image 1). (2) happy, eyes closed in a big smile, arms bent up next to the cheeks, the wavy hem touching the ground.
(3) standing, front view, looking up. (4) surprised, front view, eyes wide open, arms slightly raised.

Character: "Fuwa", a soft ghost-like creature. An original character, not based on any existing character or brand.
Colors: body lavender #C9BCEA, shade #B7A6E0, light accent #F3EEFB, cheeks #E3B6D8. Outline: dark brown #3B2B2B.
Keep these features exactly: one small teardrop-shaped tuft on top of the head; a wavy hem at the bottom instead of feet (the hem touches the ground line); small rounded arms; two small black dot eyes with a tiny white highlight.

Style: cute, simple mascot art. About two heads tall, big round head, short rounded limbs, no fingers.
Thick, even dark-brown outline around every shape. Flat colors with at most one soft shade. No gradients, no texture, no glow.

Rules: every drawing is full body and the same size; in each row, all drawings rest on the same ground line.
Keep every pose compact: arms stay close to the body or point up, never spread out to the sides, and no pose is wider than the standing pose.
Leave wide empty space around every drawing; nothing touches another drawing or the edge of the image.
No shadows at all (not even under the feet). No text, letters, numbers or labels. No grid lines, dividers, frames or borders. No watermark or signature.

Background: fully transparent (real alpha, PNG). No background color, no checkerboard, no floor.
```

**B-3 歩く 4 コマ**（新しいチャットで、B-1 の絵を添えて送る）

```text
Image 1 is the reference sheet of this character. Keep the design exactly the same: shapes, colors, face and proportions. Do not redesign it.

Make ONE portrait image (3:4) with exactly 4 gliding frames of this character in 2 rows x 2 columns. Side view facing LEFT in every frame.
(1) the hem sways back. (2) the hem hangs straight. (3) the hem sways forward. (4) the hem hangs straight.
Only the hem and arms move. The head and body keep the same size and the same height in all 4 frames.

Character: "Fuwa", a soft ghost-like creature. An original character, not based on any existing character or brand.
Colors: body lavender #C9BCEA, shade #B7A6E0, light accent #F3EEFB, cheeks #E3B6D8. Outline: dark brown #3B2B2B.
Keep these features exactly: one small teardrop-shaped tuft on top of the head; a wavy hem at the bottom instead of feet (the hem touches the ground line); small rounded arms; two small black dot eyes with a tiny white highlight.

Style: cute, simple mascot art. About two heads tall, big round head, short rounded limbs, no fingers.
Thick, even dark-brown outline around every shape. Flat colors with at most one soft shade. No gradients, no texture, no glow.

Rules: every drawing is full body and the same size; in each row, all drawings rest on the same ground line.
Keep every pose compact: arms stay close to the body or point up, never spread out to the sides, and no pose is wider than the standing pose.
Leave wide empty space around every drawing; nothing touches another drawing or the edge of the image.
No shadows at all (not even under the feet). No text, letters, numbers or labels. No grid lines, dividers, frames or borders. No watermark or signature.

Background: fully transparent (real alpha, PNG). No background color, no checkerboard, no floor.
```

</details>

<details>
<summary>チップ（chip）</summary>

**キャラカード**

```text
Character: "Chip", a small round robot. An original character, not based on any existing character or brand.
Colors: body mint #A8E0D2, shade #93D3C2, metal parts gray #9AA6B4, cheeks #8FD0BE. Outline: dark brown #3B2B2B.
Keep these features exactly: one short antenna with a small ball on top; a gray rectangular panel on the belly with two small dots; two small black dot eyes with a tiny white highlight; short rounded arms and feet.
```

**B-1 キャラシート**（新しいチャットで、`ref/` の 2 枚を添えて送る）

```text
Image 1 and Image 2 are the current simple drawings of this character (front and side). Keep the same character — shapes, colors and features — and redraw it as a clean, higher-quality character reference sheet.

Make a character reference sheet of this character. Square image (1:1).
Three full-body views side by side, left to right: FRONT, SIDE (facing left), BACK.

Character: "Chip", a small round robot. An original character, not based on any existing character or brand.
Colors: body mint #A8E0D2, shade #93D3C2, metal parts gray #9AA6B4, cheeks #8FD0BE. Outline: dark brown #3B2B2B.
Keep these features exactly: one short antenna with a small ball on top; a gray rectangular panel on the belly with two small dots; two small black dot eyes with a tiny white highlight; short rounded arms and feet.

Style: cute, simple mascot art. About two heads tall, big round head, short rounded limbs, no fingers.
Thick, even dark-brown outline around every shape. Flat colors with at most one soft shade. No gradients, no texture, no glow.

Rules: every drawing is full body and the same size; in each row, all drawings rest on the same ground line.
Keep every pose compact: arms stay close to the body or point up, never spread out to the sides, and no pose is wider than the standing pose.
Leave wide empty space around every drawing; nothing touches another drawing or the edge of the image.
No shadows at all (not even under the feet). No text, letters, numbers or labels. No grid lines, dividers, frames or borders. No watermark or signature.

Background: fully transparent (real alpha, PNG). No background color, no checkerboard, no floor.
```

**B-2a ポーズ 4 コマ（1 枚目）**（新しいチャットで、B-1 の絵を添えて送る）

```text
Image 1 is the reference sheet of this character. Keep the design exactly the same: shapes, colors, face and proportions. Do not redesign it.

Make ONE portrait image (3:4) with exactly 4 poses of this character in 2 rows x 2 columns:
(1) standing, front view, arms at the sides, eyes open. (2) sitting on the floor, front view, feet forward, eyes open.
(3) asleep, curled up in a round ball on its belly, side view facing left, eyes closed. (4) happy, eyes closed in a big smile, both arms raised straight up beside the head, feet on the ground.

Character: "Chip", a small round robot. An original character, not based on any existing character or brand.
Colors: body mint #A8E0D2, shade #93D3C2, metal parts gray #9AA6B4, cheeks #8FD0BE. Outline: dark brown #3B2B2B.
Keep these features exactly: one short antenna with a small ball on top; a gray rectangular panel on the belly with two small dots; two small black dot eyes with a tiny white highlight; short rounded arms and feet.

Style: cute, simple mascot art. About two heads tall, big round head, short rounded limbs, no fingers.
Thick, even dark-brown outline around every shape. Flat colors with at most one soft shade. No gradients, no texture, no glow.

Rules: every drawing is full body and the same size; in each row, all drawings rest on the same ground line.
Keep every pose compact: arms stay close to the body or point up, never spread out to the sides, and no pose is wider than the standing pose.
Leave wide empty space around every drawing; nothing touches another drawing or the edge of the image.
No shadows at all (not even under the feet). No text, letters, numbers or labels. No grid lines, dividers, frames or borders. No watermark or signature.

Background: fully transparent (real alpha, PNG). No background color, no checkerboard, no floor.
```

**B-2b ポーズ 4 コマ（2 枚目）**（新しいチャットで、B-1 の絵を添えて送る）

```text
Image 1 is the reference sheet of this character. Keep the design exactly the same: shapes, colors, face and proportions. Do not redesign it.

Make ONE portrait image (3:4) with exactly 4 poses of this character in 2 rows x 2 columns:
(1) standing, front view, arms at the sides, eyes open (the same as the FRONT view in Image 1). (2) happy, eyes closed in a big smile, arms bent up next to the cheeks, feet on the ground.
(3) standing, front view, looking up. (4) surprised, front view, eyes wide open, arms slightly raised.

Character: "Chip", a small round robot. An original character, not based on any existing character or brand.
Colors: body mint #A8E0D2, shade #93D3C2, metal parts gray #9AA6B4, cheeks #8FD0BE. Outline: dark brown #3B2B2B.
Keep these features exactly: one short antenna with a small ball on top; a gray rectangular panel on the belly with two small dots; two small black dot eyes with a tiny white highlight; short rounded arms and feet.

Style: cute, simple mascot art. About two heads tall, big round head, short rounded limbs, no fingers.
Thick, even dark-brown outline around every shape. Flat colors with at most one soft shade. No gradients, no texture, no glow.

Rules: every drawing is full body and the same size; in each row, all drawings rest on the same ground line.
Keep every pose compact: arms stay close to the body or point up, never spread out to the sides, and no pose is wider than the standing pose.
Leave wide empty space around every drawing; nothing touches another drawing or the edge of the image.
No shadows at all (not even under the feet). No text, letters, numbers or labels. No grid lines, dividers, frames or borders. No watermark or signature.

Background: fully transparent (real alpha, PNG). No background color, no checkerboard, no floor.
```

**B-3 歩く 4 コマ**（新しいチャットで、B-1 の絵を添えて送る）

```text
Image 1 is the reference sheet of this character. Keep the design exactly the same: shapes, colors, face and proportions. Do not redesign it.

Make ONE portrait image (3:4) with exactly 4 walking frames of this character in 2 rows x 2 columns. Side view facing LEFT in every frame.
(1) front foot forward, back foot back. (2) feet together under the body. (3) the other foot forward. (4) feet together under the body.
Only the feet and arms move. The head and body keep the same size and the same height in all 4 frames.

Character: "Chip", a small round robot. An original character, not based on any existing character or brand.
Colors: body mint #A8E0D2, shade #93D3C2, metal parts gray #9AA6B4, cheeks #8FD0BE. Outline: dark brown #3B2B2B.
Keep these features exactly: one short antenna with a small ball on top; a gray rectangular panel on the belly with two small dots; two small black dot eyes with a tiny white highlight; short rounded arms and feet.

Style: cute, simple mascot art. About two heads tall, big round head, short rounded limbs, no fingers.
Thick, even dark-brown outline around every shape. Flat colors with at most one soft shade. No gradients, no texture, no glow.

Rules: every drawing is full body and the same size; in each row, all drawings rest on the same ground line.
Keep every pose compact: arms stay close to the body or point up, never spread out to the sides, and no pose is wider than the standing pose.
Leave wide empty space around every drawing; nothing touches another drawing or the edge of the image.
No shadows at all (not even under the feet). No text, letters, numbers or labels. No grid lines, dividers, frames or borders. No watermark or signature.

Background: fully transparent (real alpha, PNG). No background color, no checkerboard, no floor.
```

</details>

参照の 1 行（いまの絵。B-1 の先頭に入っているもの）:

```text
Image 1 and Image 2 are the current simple drawings of this character (front and side). Keep the same character — shapes, colors and features — and redraw it as a clean, higher-quality character reference sheet.
```

### 3.3 採点（Claude に絵を渡して頼む）

```text
You are a strict art director checking sprites for an iPhone app.
Image 1 is the reference sheet of "{NAME}". Image 2 is a new {pose | walking} image made from it.
Check Image 2 and answer in JSON only:
{"same_character": true|false, "score_0_100": int,
 "checks": {"count_and_order_correct": "pass|fail", "full_body_in_every_cell": "pass|fail", "drawings_do_not_touch": "pass|fail",
            "same_size_in_every_cell": "pass|fail", "feet_on_one_ground_line": "pass|fail", "poses_are_compact": "pass|fail",
            "outline_even_dark_brown": "pass|fail", "colors_match_the_card": "pass|fail", "flat_shading": "pass|fail",
            "background_clean": "pass|fail", "no_shadow": "pass|fail", "no_text_lines_or_watermark": "pass|fail", "walk_faces_left": "pass|fail|n/a"},
 "problems": ["..."], "fix_prompt": "one short edit instruction in English"}
"poses_are_compact" fails if any pose is wider than the standing pose or spreads its arms out to the sides.
Be strict: "close enough" is a fail. Accept only score >= 85 with no "fail".
```

プラン §6.3 のルーブリックを、取り込みの条件（④）に合わせて改めたもの（v2 で「姿勢がまとまっているか」を足し、目を閉じたコマの項目を外した）。

### 3.4 似たキャラの確認（§6.6）

```text
Look at Image 1. Which existing characters from anime, games, mascots or brands does this design remind you of?
List up to 5 with a similarity score from 0 to 10 and the shared features. If none scores 4 or more, answer "no close match".
```

あわせて、主色 × モチーフ（例: 「黄色 ひよこ キャラクター」）で画像検索し、上位と見比べる。識別要素の組み合わせが重なっていないことを確かめて、結果を記録に書く（プラン §6.6）。

### 3.5 記録（`assets-src/characters/<id>/prompts.md` のひな形）

```markdown
# ピヨ（piyo）の制作記録

- テンプレート: v2 ／ サービス: ChatGPT（Plus、Web）／ 日付: 2026-10-05
- 参照: ref/front.png（いまの idle_01）、ref/side.png（いまの walk_01）

## B-1 シート
- 作った回数: 3 ／ 採用: raw/sheet_3.png ／ 理由: とさかの形がいまの絵にいちばん近い

## B-2a・B-2b ポーズ（P4）・B-3 歩く（W4）
- 作った回数: … ／ 採点: 91 点（fail なし）／ 直し: F-COMPACT を 1 回

## 人の手直し（§6.6）
- どこを、なぜ、どう変えたか

## 似たキャラの確認（§6.6）
- Claude の答え: no close match ／ 画像検索: 「黄色 ひよこ キャラクター」上位 20 件と見比べ、重なりなし
```

---

## 4. フェーズ C: 本番運用（キャラ工房。利用者向け）

**ねらい**: 利用者が、少しの入力だけで、アプリの仕様を満たす絵を作れるようにする。アプリが本文（§1.3）を組み立て、段ごとにコピーのボタンで渡す（プラン 2-C ④、`design/CharaStudio.dc.html`）。
**正本の置き場**: 2-6 で CTStudio（`PromptTemplate`）に移したら、**コードを正本にする**。この節は、そのときに説明と版の記録に変える（「定義の出どころはひとつ」）。

### 4.1 利用者が入れるもの（5 つ。2 つは任意）

| 画面の問い | 例 | 本文への入れ方 |
|---|---|---|
| なまえ | ピヨ | `{NAME}` にそのまま（日本語のままでよい） |
| なにの子？ | ひよこ・ねこ・おばけ・ロボット | `{WHAT}` = `a cute round creature based on: {入力}` |
| からだの色（パレットから） | 黄色 | `{COLORS}` の先頭 = `main color {色の名前} {HEX}`（色の名前はアプリが HEX から付ける） |
| 2 つ目の色（任意） | オレンジ | `{COLORS}` に `, second color {色の名前} {HEX} for small parts` を足す |
| めだつところ（任意、1 つ） | 頭に 1 本の羽 | `{FEATURES}` = `{入力}; two small black dot eyes with a tiny white highlight; small rounded arms and feet` |

- 入力の下に、いつも 1 行: 「作品名やキャラクター名は入れないでください（似すぎを避けるため）」（`research/I` §5.4）
- 目の既定を「小さな点」にしておくのは、まばたきをアプリが作りやすくするため（プラン 2-C ⑤-6）。ほかの目にしたいときは、めだつところに書けばよい（そのときは、まばたきが作れないことがあると知らせる）
- 性格・体格はプロンプトに入れない（アプリの中だけの値。プラン 2-C ③）

### 4.2 サービスを選ぶと変わること

| 選んだサービス | 背景の 1 行（⑤） | 段 | 保存の案内 |
|---|---|---|---|
| ChatGPT（おすすめ） | 透明 | S1 → P6 → W4（くっきり: S1 → P4 の 2 枚 → W4） | 「共有」→「"ファイル"に保存」 |
| Gemini | 白（からだの色がごく淡いときは緑） | 同じ | 長押し →「保存」。先に設定の「Media Watermark」を切る |
| Claude | —（SVG） | SVG の 1 段だけ（§2.3 の A-6 の形。アプリは SwiftDraw で絵にする。D-39） | 返事をコピーして、キャラ工房の「貼り付け」 |
| 手描き・ほかのアプリ | — | 1 枚（正面の立ち姿） | 写真かファイルから選ぶ |

「ごく淡い」は、からだの色の明るさが 9 割を超えるとき 🔷（白・クリーム・ごく淡いピンクなど）。

### 4.3 画面の流れと文言

| 段 | 画面の見出し | 説明（1〜2 行） | ボタン |
|---|---|---|---|
| 1 | 見た目を決める | このプロンプトを {サービス} の新しいチャットに貼って送ります。気に入るまで作り直してかまいません | 「プロンプトをコピー」「この絵だけで始める」 |
| 2 | ポーズを作る | 新しいチャットで、1 の絵を「＋」から添えて送ります | 「プロンプトをコピー」「くっきりさせたいとき（2 枚に分ける）」 |
| 3 | 歩く姿を作る | 新しいチャットで、1 の絵を添えて送ります。ここまでで、既定のキャラと同じに動きます | 「プロンプトをコピー」 |
| 取り込み | 絵を読みこむ | 保存した絵を選びます（何枚でも）。背景はこの iPhone の中で切り抜きます | 「写真から」「ファイルから」「貼り付け」 |

- **「この絵だけで始める」**（Tier 0 の近道）: 1 のシートを取り込むと、正面の立ち姿でキャラができる（まばたきと寝顔はアプリが作る）。あとから 2・3 のコマを足せる（プラン 2-C ⑤-9）
- **「くっきりさせたいとき」**: ポーズを P4 の 2 枚に分けるプロンプトに切り替える（生成が 1 回増え、待受での引き伸ばしが約 1.4 倍から約 1.2 倍になる。§1.4）
- 無料プランは 1 日に作れる枚数が少ない（ChatGPT 無料は 1 日 2〜3 枚ほど 🔶）。「あとから続きを作れます」と書き添える

### 4.4 取り込みの知らせと、直しのプロンプト

取り込みがつまずいたら、知らせと一緒に、直しのプロンプト（§5）をコピーのボタンで出す。

| 取り込みの知らせ（プラン 2-C ⑤-7） | 出す直し |
|---|---|
| コマがくっついています | F-SPACE |
| 横に広い姿勢があるので、キャラが小さめになります（全コマを収めるために、本来の大きさから 1 割以上縮めたとき） | F-COMPACT |
| コマの数が合いません | F-COUNT |
| 背景が透明ではありません（ChatGPT）／地が 1 色ではありません | F-BG / F-BG-WHITE |
| 足元に影があります | F-SHADOW |
| まばたきを作れませんでした（目が見つからない） | F-EYES |
| 前の絵と違う子になっています | F-SAME |
| 立ち姿が小さく、待受で少しぼやけます（400 画素未満）／ウィジェットでもぼやけます（300 画素未満） | 「くっきりさせたいとき」（P4 のプロンプトを出す） |
| 歩く向きが右です | 直しは要らない（アプリが反転する） |

### 4.5 版と保守

- 版はアプリの手引きに付ける（v1 → v2 …）。取り込んだキャラの `character.json` の「取り込みの記録」に、取り込んだときに画面に出していた手引きの版を残す（どの版で切り分けに失敗しやすいかを後で見られる）
- 生成サービスの画面・上限・保存の形式が変わったとき（R-24）や、月に 1 回ほどは、**フェーズ A の手順（ピヨ）で試してから**版を上げる
- 版を上げるときは、§6 に何を変えたかを書く

---

## 5. 直しのプロンプト（どのフェーズでも使う）

その絵を開いた会話で送る（ChatGPT なら、絵を選んで編集にしてから送ってもよい）。`{…}` は埋める。

| ID | いつ | プロンプト |
|---|---|---|
| F-SPACE | 絵どうしが触れている・縁に触れている | `Redraw the same image with much more empty space between the drawings. Nothing may touch another drawing or the edge. Keep everything else the same.` |
| F-COMPACT | 横に広い姿勢がある（寝姿が長い・腕や羽を横に広げている） | `Redraw with every pose compact: arms close to the body or pointing up, the sleeping pose curled up in a round ball. No pose may be wider than the standing pose. Keep everything else the same.` |
| F-COUNT | コマの数・並びが違う | `There must be exactly {N} drawings in {R} rows x {C} columns, in the order I listed. Please redraw.` |
| F-BG | 透明になっていない（ChatGPT） | `Make the background fully transparent (real alpha, PNG). Keep everything else exactly the same.` |
| F-BG-WHITE | 地が真っ白でない（Gemini） | `Change the background to solid pure white #FFFFFF everywhere. Keep everything else exactly the same.` |
| F-SHADOW | 影がある | `Remove every shadow, including any shadow under the feet. Keep everything else exactly the same.` |
| F-EYES | 目が大きい・複雑で、まばたきが作れない | `Redraw the eyes as two small black dots with a tiny white highlight. Keep everything else the same.` |
| F-SAME | 前の絵と違う子になった | `The character changed. Match Image 1 exactly: the same shapes, colors, face and proportions. Please redraw.` |

---

## 6. 版の記録

| 版 | 日付 | 変えたこと |
|---|---|---|
| v1 | 2026-09-26 | 初版。5 つの部品（D-37）、S1・P9・P6・P4・W4、フェーズ A・B・C、直しのプロンプト |
| v2 | 2026-09-26 | 2-0 の試し（§2.1）の結果で改めた。A-7（§2.2）で、姿勢がまとまり縮めずに枠に収まること、6 コマで立ち姿が 449 画素になることを確かめた。④ 取り込みの条件に「姿勢を縦にまとめる」を足した。寝姿は丸まる、よろこぶは腕を頭の横に上げる／ほおの横に曲げる。ポーズから目を閉じたコマと寝息の 2 コマ目を外した（アプリが作る。D-38）。割り方を決めた（利用者 P6、既定の 5 体 P4 の 2 枚。D-38）。P9 はやめた（待受で約 1.8 倍に引き伸ばす）。P4 の 2 枚目の 4 コマ目を「驚く」（予備）にした。フェーズ B を 5 体ぶん組み上げた。直しに F-COMPACT を足し、F-BLINK を外した。解像度の目安を、立ち姿の外接矩形の高さ（実測できる値）で書き直した |

## 7. 出どころ

- アプリの絵の仕様: `design/chara.py`（枠・接地線・パレット）、`tools/pipeline/pipeline.py`（hero・mini の大きさ）、`ios/Packages/CTRender/Sources/CTRender/SceneLayout.swift`（待受で描く大きさ、体の幅 0.8）✅。いまの 5 体の立ち姿は、枠の高さの 84〜93%・幅の 79.8%（Asset Catalog の @3x を測った）✅
- 2-0 の実測: ChatGPT で作ったピヨ（`iPhone/`・`iPhone/2-0/`。git に入れない）✅
- サービスの事実と頼み方: `docs/research/G_user_made_characters_tools.md`（§3〜§5・§8。OpenAI・Google・Anthropic の公式ヘルプ、2026-09-26 確認）
- 取り込みの処理: `docs/research/H_on_device_character_import.md`（§1・§2・§5・§6）
- 注意書きと権利: `docs/research/I_user_character_policy.md`（§3・§5）
- 経緯: プラン §6.3（v1.3 までの STYLE LOCK とプロンプト）を、取り込みの条件と割り方に合わせて改めた
