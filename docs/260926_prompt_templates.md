# CharaTime キャラを作るプロンプトのテンプレート（v1、2026-09-26）

- 位置づけ: プラン（`docs/260910_dev_plan.md` v1.5）§9 Phase 2 の 2-C ④「作り方の手引き」の本文。決めごとは D-34・D-37
- 使い方: **自分の番のフェーズだけ読めばよい**（§0 の早見表）。プロンプトは枠ごとそのままコピーして貼る。iPhone の Safari で GitHub のこの文書を開くと、枠の右上にコピーのボタンが出る
- 版: **v1**。2-0（試し）の結果で割り方とまばたきの作り方を決めたら v2 にする（§6）。アプリで取り込んだキャラの記録に、どの版の手引きで作ったかを残す
- 凡例: ✅ 一次情報 / 🔶 二次情報 / 🔷 推測・設計判断（プランと同じ）

---

## 0. 早見表

| フェーズ | いつ | 誰が | どこで | 作るもの | 読む節 |
|---|---|---|---|---|---|
| **A 試し** | 2-0（09/28〜） | ユーザー | iPhone の ChatGPT（任意で Gemini・Claude） | ピヨ 1 体（試し） | §2 |
| **B 既定の 5 体** | 2-4（10/05〜） | ユーザー（生成）＋ Claude（採点・整える） | Mac の ChatGPT（Web かアプリ） | 5 体の本番の絵 | §3 |
| **C 本番運用** | 2-6〜（アプリに載せる） | 利用者 | iPhone（キャラ工房がプロンプトを組み立てる） | 自分の子 | §4 |

どのフェーズも、**同じ本文（§1.3）** を使う（D-34「既定のキャラも取り込んだキャラも同じ手引きで」）。違うのは、空欄をだれがどう埋めるかと、参照画像の有無だけ。

---

## 1. 共通のしくみ

### 1.1 アプリが要る絵（プロンプトが守らせること）

アプリは、取り込んだ絵を整えて（背景を外す・コマを見つける・枠にそろえる）から描く（プラン 2-C ⑤）。整える処理が確実に通るように、プロンプトで次を守らせる。

| アプリの都合 | プロンプトに書くこと | 守られないと |
|---|---|---|
| 背景を外す（透明ならそのまま、1 色の地なら縁から抜く。D-36） | ChatGPT は透明、Gemini は真っ白（白いキャラは緑）。床・影・模様を描かない | 模様や写真の地は Vision に回り、縁がにじむ・部品を落とす |
| コマを「つながった塊」で見つける | 絵どうし・画像の縁のあいだを広く空ける。枠線・格子の線を描かない | 触れ合った 2 体が 1 つになる（Vision でも同じ） |
| 接地線をそろえる（不透明ないちばん下の行を足元とみなす） | 影を描かない（足元の影も）。全身を描く | 影が足元とみなされ、キャラが浮く |
| 背を 1 つの倍率でそろえる（立ち姿が基準） | どのコマも同じ大きさ | 大きさが揃わず、コマを送るたびに伸び縮みする |
| 枠は縦長（130:180）。体は枠の高さの約 79%、幅の 8 割まで | 2 頭身の丸いキャラ。コマは縦長（3:4）に並べる | 横に広い姿勢は縮めて収めるので、小さく見える |
| まばたきは目のまわりだけを重ねる（D-17） | 目は小さな点（白い光を 1 つ）。閉じた目は細い弧 | 目が見つからず、まばたきが作れない |
| 歩きは左向きの 4 コマ（右は反転）。上下の揺れはアプリが足す | 横向き・左向き。頭と体の高さは 4 コマで同じ | 揺れが二重になる、体が伸び縮みする |
| 解像度（待受の体は @3x で約 583 画素、ウィジェットは約 300 画素） | 1 枚に詰めすぎない（§1.4） | 待受で引き伸ばされ、輪郭がにじむ |

### 1.2 プロンプトの 5 つの部品

1 回に貼るプロンプトは、次の 5 つを上から順につないだもの（D-37）。

| 部品 | 中身 | 変えてよいか |
|---|---|---|
| ① 段の指示 | 何を作るか（シート・ポーズ・歩く）、縦横比、コマの数と並び。参照画像を添えるときの 1 行 | 変えない（割り方は 2-0 で決める） |
| ② キャラカード | 名前・何の生き物か・色（HEX）・守る特徴。**毎回そのまま貼る** | キャラごとに埋める |
| ③ 画風 | まるっとフラット（2 頭身・太い一定の輪郭線・平塗り） | 変えてよい（既定はこのまま） |
| ④ 取り込みの条件 | 全身・同じ大きさ・同じ接地線・広い余白・影なし・文字や枠線なし | **変えない**（アプリが頼る約束） |
| ⑤ 背景の 1 行 | サービスごとに違う（§1.3） | サービスで選ぶ |

### 1.3 本文（正本）

`{…}` を埋めて、①〜⑤ を順につなぐ。フェーズ A はピヨで埋めたもの（§2）、B は 5 体のカード（§3.2）、C はアプリが利用者の入力で埋める（§4）。

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

**④ 取り込みの条件**

```text
Rules: every drawing is full body and the same size; in each row, all drawings rest on the same ground line.
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

**① 段の指示**（どれを使うかは §1.4。参照画像を添える段は、先頭に「参照の 1 行」を付ける）

参照の 1 行:

```text
Image 1 is the reference sheet of this character. Keep the design exactly the same: shapes, colors, face and proportions. Do not redesign it.
```

S1 キャラシート（正方形 1:1。**これだけで 1 枚の絵のキャラ（Tier 0）になる**。いちばん左の正面を使う）:

```text
Make a character reference sheet of this character. Square image (1:1).
Three full-body views side by side, left to right: FRONT, SIDE (facing left), BACK.
```

P9 ポーズ 9 コマ（3×3、縦 3:4。まばたきと寝息の 2 コマ目も AI が描く）:

```text
Make ONE portrait image (3:4) with exactly 9 poses of this character in 3 rows x 3 columns:
Row 1: (1) standing, front view, arms at the sides, eyes open. (2) exactly the same as (1), only the eyes closed. (3) sitting on the floor, front view, feet forward, eyes open.
Row 2: (4) exactly the same as (3), only the eyes closed. (5) lying on its belly asleep, side view facing left, eyes closed. (6) exactly the same as (5), body slightly rounder (breathing in).
Row 3: (7) happy, eyes closed in a big smile, both arms raised, feet on the ground. (8) happy, eyes closed in a big smile, arms spread out, feet on the ground. (9) standing, front view, looking up.
```

P6 ポーズ 6 コマ（3×2、正方形 1:1。まばたきと寝息の 2 コマ目はアプリが作る）:

```text
Make ONE square image (1:1) with exactly 6 poses of this character in 2 rows x 3 columns:
Row 1: (1) standing, front view, arms at the sides, eyes open. (2) sitting on the floor, front view, feet forward, eyes open. (3) lying on its belly asleep, side view facing left, eyes closed.
Row 2: (4) happy, eyes closed in a big smile, both arms raised, feet on the ground. (5) happy, eyes closed in a big smile, arms spread out, feet on the ground. (6) standing, front view, looking up.
```

P4 ポーズを 2 枚に分ける（2×2 を 2 枚、縦 3:4。**どちらにも同じ立ち姿を入れて、2 枚の背をそろえる基準にする**。2 枚目は、シートと 1 枚目の絵を添える）:

```text
Make ONE portrait image (3:4) with exactly 4 poses of this character in 2 rows x 2 columns:
(1) standing, front view, arms at the sides, eyes open. (2) sitting on the floor, front view, feet forward, eyes open.
(3) lying on its belly asleep, side view facing left, eyes closed. (4) happy, eyes closed in a big smile, both arms raised, feet on the ground.
```

```text
Make ONE portrait image (3:4) with exactly 4 poses of this character in 2 rows x 2 columns:
(1) standing, front view, arms at the sides, eyes open (the same as the FRONT view in Image 1). (2) happy, eyes closed in a big smile, arms spread out, feet on the ground.
(3) standing, front view, looking up. (4) exactly the same as (1), only the eyes closed.
```

W4 歩く 4 コマ（2×2、縦 3:4）:

```text
Make ONE portrait image (3:4) with exactly 4 walking frames of this character in 2 rows x 2 columns. Side view facing LEFT in every frame.
(1) front foot forward, back foot back. (2) feet together under the body. (3) the other foot forward. (4) feet together under the body.
Only the feet and arms move. The head and body keep the same size and the same height in all 4 frames.
```

**歩きを 2×2 にする理由**: 横 1 列（1×4、横長 3:1）よりコマが縦に長く、同じ画像の大きさで体が約 1.5 倍大きく描ける（§1.4）。上下の揺れはアプリが足すので、絵では頭と体の高さを変えない（`design/chara.py` の歩きと同じ）。

### 1.4 割り方と解像度

体の高さ（画素）は、画像の長辺 L のおよそ k 倍になる 🔷（キャラがコマの 85% に収まるとして計算。`research/G` §2.2・`research/H` §6 と同じ考え方）。

| 段 | 縦横比 | コマ | k | L = 1024 | L = 1536 | L = 2048 |
|---|---|---|---|---|---|---|
| S1 シート（正面） | 1:1 | 横に 3 体 | 約 0.31 | 約 320 | 約 480 | 約 640 |
| P9 | 3:4 | 3×3 | 0.225 | 230 | 345 | 460 |
| P6 | 1:1 | 3×2 | 0.311 | 320 | 480 | 640 |
| P4（2 枚） | 3:4 | 2×2 | 0.338 | 345 | 520 | 690 |
| W4 | 3:4 | 2×2 | 0.338 | 345 | 520 | 690 |
| 参考: 横 1 列の歩き | 3:1 | 1×4 | 0.225 | 230 | 345 | 460 |

- 目安: **待受で等倍は約 583 画素**、**400 画素以上なら十分**、**300 画素未満はウィジェットでもぼやける**（プラン 2-C ①④）
- **決め方（2-0 のあと、v2 で決める）**: まず、まばたきの作り方を決める（AI が描いた閉じた目を位置合わせして使うか、アプリが作るか。プラン 2-C ⑤-6）。次に、**体の高さが 400 画素以上になる、いちばん少ない枚数の割り方**を選ぶ（同じ枚数なら体が大きいほう）。AI のまばたきを使うなら P9、アプリが作るなら P6。400 画素に届かなければ P4 の 2 枚に分ける
- ChatGPT と Gemini のアプリが、それぞれの縦横比で何画素の絵を保存するかは**未確認**（G §3.4・§4.3）。2-0 で測る

### 1.5 変えてよい所・変えてはいけない所

- **変えない**: ④ 取り込みの条件、⑤ 背景の 1 行、① のコマの数と並び。アプリの取り込み（コマの割り当て・知らせ）がこれに頼る
- **埋める**: ② キャラカード
- **変えてよい**: ③ 画風（ただし太い輪郭線と平塗りは、背景を外す処理を助けるので残すのが望ましい）
- **書かない**: 既存の作品名・キャラクター名・作家名・ブランド名（似すぎを避ける。`research/I` §3.1・§5.1）。例は既定の 5 体だけにする

---

## 2. フェーズ A: 試し（2-0。ピヨ 1 体）

**ねらい**: (1) 手引きが迷わず使えるか、(2) ChatGPT が保存する絵の形式・画素数・透明かどうか、(3) 本物の生成 AI の絵で、背景・切り分け・まばたきの作り方を試す（プラン 2-D の 2-0、H の S3・S6）。
**かかる時間**: 30〜60 分（必須の 3 つ）。iPhone に新しい版を入れる作業は無いので、1 週間の運用（3-7）には触れない。

### 2.1 手順（ChatGPT の iPhone アプリ）

1. ChatGPT のアプリで**新しいチャット**を開き、**A-1** を貼って送る。気に入らなければ作り直してよい（「もう一度」か、同じプロンプトを送り直す）
2. 気に入ったら、その絵を**2 通りで保存**する: 「保存」（写真に入る）と、「共有」→「"ファイル"に保存」
3. **新しいチャット**で、「＋」から A-1 の絵を添えて **A-2** を送る → 2 と同じく 2 通りで保存
4. **新しいチャット**で、「＋」から A-1 の絵を添えて **A-3** を送る → 2 と同じく保存
5. 保存した絵を Mac に AirDrop で送る（§2.4）。終わったら、何回作り直したか・どこで迷ったかを教える（§2.5）

縦横比はプロンプトに書いてあるので、選ばなくてよい（選べるなら同じものを選ぶ）。

### 2.2 プロンプト（そのまま貼る）

**A-1 キャラシート**（最初に送る。これが以後の参照になる）

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

**A-2 ポーズ 9 コマ**（新しいチャットで、A-1 の絵を添えて送る）

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

**A-3 歩く 4 コマ**（新しいチャットで、A-1 の絵を添えて送る）

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

### 2.3 任意（時間があれば）

**Gemini（A-4・A-5）**: 先に、Gemini の設定で「Media Watermark」（見える透かし）を切る（G §4.2）。モデルは Flash か Pro にする（Flash-Lite は参照画像に向かない ✅ G §4.1）。保存は、絵を長押し →「保存」（「共有」は公開リンクになる ✅ G §4.3）。参照画像を使う編集は 18 歳以上 ✅。A-4 を送り、新しいチャットで A-4 の絵を添えて A-5 を送る。A-1・A-2 と違うのは、最後の背景の行だけ（白い地）。

**A-4 キャラシート（Gemini）**

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

Background: solid pure white #FFFFFF everywhere. No gradient, no texture, no floor.
```

**A-5 ポーズ 9 コマ（Gemini）**

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

Background: solid pure white #FFFFFF everywhere. No gradient, no texture, no floor.
```

**Claude（A-6）**: Claude は画像を作れないので、SVG のコードを書かせる（Q-20。試しでは Mac の Chrome で絵にするので、パッケージを足さずに試せる）。返事を長押しでコピーし、Mac の Claude Code の画面に貼るだけでよい（同じ Apple ID ならユニバーサルクリップボードで貼れる）。

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

座標の出どころ: いまの絵の枠（`design/chara.py`。130×180、接地線 y = 168、頭のてっぺん y ≈ 25、中心 x = 65）✅。

### 2.4 保存と送り方

- **ファイル**に保存した絵: 「ファイル」App で選んで、共有 → AirDrop → Mac
- **写真**に保存した絵: 写真 App で選んで、共有 → 上の「オプション」に「すべての写真データ」があれば入にして（元の形式のまま送るため 🔷）→ AirDrop → Mac
- Mac では「ダウンロード」に入る。**名前は変えなくてよい**。Claude が `iPhone/2-0/` に移す（`iPhone/` は git に入れない）

### 2.5 残してほしいこと（1〜2 行ずつでよい）

| 項目 | 例 |
|---|---|
| 使ったプラン | ChatGPT Plus |
| A-1〜A-3 それぞれ、何回作り直したか | A-1 2 回、A-2 3 回（コマがくっついた）、A-3 1 回 |
| かかった時間（合わせて） | 40 分 |
| 迷った所・困った所 | 「＋」から絵を添える場所が分からなかった |
| （任意）Gemini・Claude をやったか | Gemini の A-4 だけ |

画素数・形式・透明かどうかは、Claude が届いたファイルで測る。

### 2.6 Claude がそのあと確かめること

1. 形式・画素数・透明かどうかを、保存の仕方（写真・ファイル）ごとに測る（S1 の前段）
2. 背景の外し方とコマの切り分けを、Mac で本物の絵に試す（S3。9 コマ・4 コマが手直しなしで切り分けられるか）
3. まばたきの作り方を比べる（S6。A-2 の (2)(4) を位置合わせして使う / (1)(3) から作る）
4. 測った画素数で §1.4 の表を埋め、割り方とまばたきの既定を決めて、この文書を v2 にする（Claude の SVG があれば、Chrome で絵にして同じく試す）

---

## 3. フェーズ B: 既定の 5 体（2-4）

**ねらい**: 既定の 5 体を本番の絵にする。**利用者と同じ本文（§1.3）** を使い、いまの絵を参照に添える点だけが違う（Q-18 の推奨 (a)）。
**場所**: Mac の ChatGPT（Web かアプリ）。参照画像を添えやすく、大きな絵をそのまま保存できる。
**割り方**: 2-0 で決めたもの（§1.4。v2 でこの節を組み上げた版に差し替える）。

### 3.1 手順（1 体ぶん）

1. Claude が、いまの絵（Asset Catalog の `<id>_idle_01@3x.png` と `<id>_walk_01@3x.png`）を `assets-src/characters/<id>/ref/` に置く
2. **B-1 シート**: 新しいチャットで、ref の 2 枚を添え、「参照の行（いまの絵）」＋ S1 ＋ カード（§3.2）＋ 画風 ＋ 条件 ＋ 背景（ChatGPT）を送る。気に入るまで作り直す
3. **B-2 ポーズ**: 新しいチャットで、B-1 の絵を添え、参照の 1 行 ＋ 決めた割り方（P9 / P6 / P4）＋ カード ＋ 画風 ＋ 条件 ＋ 背景 を送る
4. **B-3 歩く**: 新しいチャットで、B-1 の絵を添え、参照の 1 行 ＋ W4 ＋ カード ＋ 画風 ＋ 条件 ＋ 背景 を送る
5. 生成そのままの絵を `assets-src/characters/<id>/raw/` に置く（git に入れない）
6. Claude が採点し（§3.3）、似たキャラを確かめ（§3.4）、Mac の道具で整えてコンタクトシートを見る。直しは §5 のプロンプトで
7. 記録を `assets-src/characters/<id>/prompts.md` に残す（§3.5）

参照の行（いまの絵。B-1 だけ、先頭に付ける）:

```text
Image 1 and Image 2 are the current simple drawings of this character (front and side). Keep the same character — shapes, colors and features — and redraw it as a clean, higher-quality character reference sheet.
```

組み上げた例（ピヨの B-1。ref の 2 枚を添えて送る）:

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
Leave wide empty space around every drawing; nothing touches another drawing or the edge of the image.
No shadows at all (not even under the feet). No text, letters, numbers or labels. No grid lines, dividers, frames or borders. No watermark or signature.

Background: fully transparent (real alpha, PNG). No background color, no checkerboard, no floor.
```

### 3.2 キャラカード（5 体。色は `design/chara.py` のパレット ✅）

**ピヨ（piyo）**

```text
Character: "Piyo", a round chick-like creature. An original character, not based on any existing character or brand.
Colors: body soft yellow #FFE066, wings a slightly deeper yellow #FFCF4D, beak and feet orange #FF9F43, cheeks pink #FFB3C6. Outline: dark brown #3B2B2B.
Keep these features exactly: one small curved crest feather on top of the head; two small black dot eyes with a tiny white highlight; a small triangle beak; small rounded wings; short orange feet.
```

**モチ（mochi）**（白いキャラ。Gemini なら緑の地）

```text
Character: "Mochi", a round, soft, cat-like creature. An original character, not based on any existing character or brand.
Colors: body off-white #FFF6EE, arms and feet cream #FFEADD, inside of the ears pink #FFC9D9, cheeks pink #FFB3C6. Outline: dark brown #3B2B2B.
Keep these features exactly: two small triangle ears with pink insides; two small black dot eyes with a tiny white highlight; a small smiling mouth that is always visible; tiny rounded arms and feet. No ribbon, bow or other accessory.
```

**クマオ（kumao）**

```text
Character: "Kumao", a round bear-like creature. An original character, not based on any existing character or brand.
Colors: body warm brown #C89464, arms and feet a slightly darker brown #B8814F, muzzle and inside of the ears cream #F2DCC2, cheeks #E79A86. Outline: dark brown #3B2B2B.
Keep these features exactly: two round ears with cream insides; a cream oval muzzle with a small dark nose; two small black dot eyes with a tiny white highlight; short rounded arms and feet.
```

**フワ（fuwa）**

```text
Character: "Fuwa", a soft ghost-like creature. An original character, not based on any existing character or brand.
Colors: body lavender #C9BCEA, shade #B7A6E0, light accent #F3EEFB, cheeks #E3B6D8. Outline: dark brown #3B2B2B.
Keep these features exactly: one small teardrop-shaped tuft on top of the head; a wavy hem at the bottom instead of feet (the hem touches the ground line); small rounded arms; two small black dot eyes with a tiny white highlight.
```

**チップ（chip）**

```text
Character: "Chip", a small round robot. An original character, not based on any existing character or brand.
Colors: body mint #A8E0D2, shade #93D3C2, metal parts gray #9AA6B4, cheeks #8FD0BE. Outline: dark brown #3B2B2B.
Keep these features exactly: one short antenna with a small ball on top; a gray rectangular panel on the belly with two small dots; two small black dot eyes with a tiny white highlight; short rounded arms and feet.
```

フワは足が無いので、ポーズの「feet on the ground」「sitting … feet forward」「front foot forward」は、そのまま送ってよい（裾で読み替えてくれる 🔷）。崩れたら §5 の「F-SAME」に「the wavy hem instead of feet」を足して直す。

### 3.3 採点（Claude に絵を渡して頼む）

```text
You are a strict art director checking sprites for an iPhone app.
Image 1 is the reference sheet of "{NAME}". Image 2 is a new {pose | walking} image made from it.
Check Image 2 and answer in JSON only:
{"same_character": true|false, "score_0_100": int,
 "checks": {"count_and_order_correct": "pass|fail", "full_body_in_every_cell": "pass|fail", "drawings_do_not_touch": "pass|fail",
            "same_size_in_every_cell": "pass|fail", "feet_on_one_ground_line": "pass|fail", "outline_even_dark_brown": "pass|fail",
            "colors_match_the_card": "pass|fail", "flat_shading": "pass|fail", "background_clean": "pass|fail", "no_shadow": "pass|fail",
            "no_text_lines_or_watermark": "pass|fail", "closed_eye_cells_differ_only_in_eyes": "pass|fail|n/a", "walk_faces_left": "pass|fail|n/a"},
 "problems": ["..."], "fix_prompt": "one short edit instruction in English"}
Be strict: "close enough" is a fail. Accept only score >= 85 with no "fail".
```

プラン §6.3 のルーブリックを、取り込みの条件（④）に合わせて改めたもの。

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

## B-2 ポーズ（P6）・B-3 歩く（W4）
- 作った回数: … ／ 採点: 91 点（fail なし）／ 直し: F-SPACE を 1 回

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
- 目の既定を「小さな点」にしておくのは、まばたきをアプリが作りやすくするため（プラン 2-C ⑤-6）。利用者がほかの目にしたいときは、めだつところに書けばよい（そのときは、まばたきが作れないことがあると知らせる）
- 性格・体格はプロンプトに入れない（アプリの中だけの値。プラン 2-C ③）

### 4.2 サービスを選ぶと変わること

| 選んだサービス | 背景の 1 行（⑤） | 段 | 保存の案内 |
|---|---|---|---|
| ChatGPT（おすすめ） | 透明 | S1 → ポーズ → W4 | 「共有」→「"ファイル"に保存」 |
| Gemini | 白（からだの色がごく淡いときは緑） | 同じ | 長押し →「保存」。先に設定の「Media Watermark」を切る |
| Claude | —（SVG） | SVG の 1 段だけ（§2.3 の A-6 の形。Q-20） | 返事をコピーして、キャラ工房の「貼り付け」 |
| 手描き・ほかのアプリ | — | 1 枚（正面の立ち姿） | 写真かファイルから選ぶ |

「ごく淡い」は、からだの色の明るさが 9 割を超えるとき 🔷（白・クリーム・ごく淡いピンクなど）。

### 4.3 画面の流れと文言

| 段 | 画面の見出し | 説明（1〜2 行） | ボタン |
|---|---|---|---|
| 1 | 見た目を決める | このプロンプトを {サービス} の新しいチャットに貼って送ります。気に入るまで作り直してかまいません | 「プロンプトをコピー」「この絵だけで始める」 |
| 2 | ポーズを作る | 新しいチャットで、1 の絵を「＋」から添えて送ります | 「プロンプトをコピー」 |
| 3 | 歩く姿を作る | 新しいチャットで、1 の絵を添えて送ります。ここまでで、既定のキャラと同じに動きます | 「プロンプトをコピー」 |
| 取り込み | 絵を読みこむ | 保存した絵を選びます（何枚でも）。背景はこの iPhone の中で切り抜きます | 「写真から」「ファイルから」「貼り付け」 |

- **「この絵だけで始める」**（Tier 0 の近道）: 1 のシートを取り込むと、正面の立ち姿でキャラができる（まばたきと寝顔はアプリが作る）。あとから 2・3 のコマを足せる（プラン 2-C ⑤-9）
- 無料プランは 1 日に作れる枚数が少ない（ChatGPT 無料は 1 日 2〜3 枚ほど 🔶）。「あとから続きを作れます」と書き添える

### 4.4 取り込みの知らせと、直しのプロンプト

取り込みがつまずいたら、知らせと一緒に、直しのプロンプト（§5）をコピーのボタンで出す。

| 取り込みの知らせ（プラン 2-C ⑤-7） | 出す直し |
|---|---|
| コマがくっついています | F-SPACE |
| コマの数が合いません | F-COUNT |
| 背景が透明ではありません（ChatGPT）／地が 1 色ではありません | F-BG / F-BG-WHITE |
| 足元に影があります | F-SHADOW |
| まばたきを作れませんでした（目が見つからない） | F-EYES |
| 前の絵と違う子になっています | F-SAME |
| 体が小さく、ぼやけます（300 画素未満） | 「コマを 2 枚に分ける」案内（P4 のプロンプトを出す） |
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
| F-COUNT | コマの数・並びが違う | `There must be exactly {N} drawings in {R} rows x {C} columns, in the order I listed. Please redraw.` |
| F-BG | 透明になっていない（ChatGPT） | `Make the background fully transparent (real alpha, PNG). Keep everything else exactly the same.` |
| F-BG-WHITE | 地が真っ白でない（Gemini） | `Change the background to solid pure white #FFFFFF everywhere. Keep everything else exactly the same.` |
| F-SHADOW | 影がある | `Remove every shadow, including any shadow under the feet. Keep everything else exactly the same.` |
| F-EYES | 目が大きい・複雑で、まばたきが作れない | `Redraw the eyes as two small black dots with a tiny white highlight. Keep everything else the same.` |
| F-SAME | 前の絵と違う子になった | `The character changed. Match Image 1 exactly: the same shapes, colors, face and proportions. Please redraw.` |
| F-BLINK | 目だけを閉じた絵がほしい（編集） | `Edit this image: close ONLY the eyes (gentle curved lines). Keep everything else exactly the same: outline, colors, pose, size, position and background.` |

---

## 6. 版の記録

| 版 | 日付 | 変えたこと |
|---|---|---|
| v1 | 2026-09-26 | 初版。5 つの部品（D-37）、S1・P9・P6・P4・W4、フェーズ A・B・C、直しのプロンプト |
| v2 | （2-0 のあと） | 2-0 で測った画素数とまばたきの比べで、割り方とまばたきの既定を決める。フェーズ B を 5 体ぶん組み上げた版にする |

## 7. 出どころ

- アプリの絵の仕様: `design/chara.py`（枠・接地線・パレット）、`tools/pipeline/pipeline.py`（hero・mini の大きさ）、`ios/Packages/CTRender/Sources/CTRender/SceneLayout.swift`（待受で描く大きさ）✅
- サービスの事実と頼み方: `docs/research/G_user_made_characters_tools.md`（§3〜§5・§8。OpenAI・Google・Anthropic の公式ヘルプ、2026-09-26 確認）
- 取り込みの処理: `docs/research/H_on_device_character_import.md`（§1・§2・§5・§6）
- 注意書きと権利: `docs/research/I_user_character_policy.md`（§3・§5）
- 経緯: プラン §6.3（v1.3 までの STYLE LOCK とプロンプト）を、取り込みの条件と割り方に合わせて改めた
