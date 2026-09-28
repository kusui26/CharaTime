# アセットパイプライン

`design/` の SVG と、chara-bake が整えた絵（`assets-src/characters/<id>/final/`）から、アプリが読む PNG と
同梱データ JSON を作る。

```bash
python3 tools/pipeline/pipeline.py          # 全部焼き直す（2 分ほど）
python3 tools/pipeline/pipeline.py --check  # 焼かずに整合だけ見る
python3 -m unittest discover -s tools/pipeline -p 'test_*.py'   # final/ の入れ方のテスト（数秒）
```

**画像を手で足さない**（`.claude/CLAUDE.md` §2）。足したいときはここを通す。

## 何を作るか

| 出力 | 中身 |
|---|---|
| `ios/.../Resources/Characters.xcassets` | 5 体 × 12 枚 × 3 倍率。同じ 12 枚のウィジェット用の小さい版（mini）と、まぶたの差分（立ち姿とすわる姿。mini） |
| `ios/.../Resources/Items.xcassets` | アイテム 7 種 × 3 倍率 |
| `characters.json` の `poses`・`miniPoses`・`eyelids`・`sleepFrameCoversBase`・`spriteGeometry` | コマの名前、まぶたの差分、寝息の 2 コマ目が 1 コマ目を覆えるか、絵の枠 |
| `ios/Shared/Fonts` と `mask_fonts.json` | 疑似アニメのマスク書体 7 本（`masks.py`。プラン D-29） |
| `items.json` の `assetName` と `aspectRatio` | アセット名と縦横比 |

**性格・表示名・大きさの比は人が調整した値なので触らない。** パイプラインが書き換えるのは
上の欄だけで、残りは既にある JSON を尊重する。

## 決めごと

- **姿勢ごとに同じ枠で焼き、余白を詰めない。** 詰めると原点が姿勢ごとにずれ、
  コマを送るたびにキャラが跳ねて見える。
- 枠は 130×180 単位（絵は 120×170 ＋ 四方 5 の余白）。余白が無いと、
  ピヨのとさかとチップのアンテナが輪郭線の太さぶん切れる。
- 接地線は枠の上から 93.3%。アプリはこの値で足元を床に合わせる（`spriteGeometry`）。
- @1x は 1.5 倍（195×270pt）。画面では 170pt 前後で描くので、@3x がほぼ等倍になる。
- コマの枚数と順番の出どころは `design/chara.py` の `FRAMES` ひとつ。

## SVG を PNG にする方法

この機械には rsvg-convert も cairosvg も Inkscape も入っていないので、
**headless Chrome** を使う（`rasterize.py`）。`--default-background-color=00000000` で
背景を透明にしたまま、指定した画素数にベクタから直接描く。倍率ごとに描き直すので
拡大縮小によるぼやけが出ない。1 回の起動で 12 枚を横に並べて焼き、Pillow で切り分ける。

**Chrome の描き方は、列の中の位置で縁の画素がわずかに変わる**（同じ絵を別の位置に置くと、輪郭の
なめらかさの値が最大 100 ほど違う。256 画素ごとにそろえても消えない）。同じ位置なら毎回同じバイトになるので、
焼き直しても差分は出ない。ただし **コマを途中に足すと、その後ろのコマが 1 つずつずれて、縁の画素が変わる**
（3-2b ですわる姿のまばたきを足したとき、ねる・よろこぶの PNG が変わった。見た目には分からない）。
1 枚ずつ Chrome を起動すれば位置に依らなくなるが、焼く時間が 3 倍になるので、そうしていない。

## 生成 AI の本番の絵（final/）

既定の 5 体の本番の絵は、Mac の道具 `chara-bake`（CTStudio。利用者の取り込みと同じ処理。プラン D-35）が
`assets-src/characters/<id>/final/` に整える。**final/ があるキャラはそこから、無いキャラは SVG から焼く**
（1 体ずつ置き換えられる）。どちらでも**出力の形（imageset の名前・倍率・接地の位置）は変えない**。

```bash
swift run --package-path ios/Packages/CTStudio chara-bake piyo      # raw/ の生の絵を整えて final/ に書く
python3 tools/pipeline/pipeline.py                                   # final/ を Asset Catalog に入れる
```

| final/ の中身（@3x だけ） | Asset Catalog へ |
|---|---|
| `hero/idle_01.png`（585×810） | `piyo_idle_01`。@3x はそのまま写し、@2x・@1x は縮める（Pillow の Lanczos。乗算済みで縮めるので縁に色がにじまない） |
| `mini/idle_01.png`（273×378） | `piyo_idle_01_mini`。同じ |
| `mini/idle_eyelid.png` | `piyo_idle_eyelid_mini`。@3x はそのまま、@2x・@1x は縮めた mini どうしを比べて作り直す（`art.eyelid`。@3x の差分の外接矩形を縮め、3 画素広げた範囲で比べる） |
| `spare/`（見上げる・驚く）と `bake.json`（整えたときの記録） | 入れない |

- **形は SVG のキャラと同じでなければ止める**（`design/chara.py` の FRAMES と BLINK_OF。足りない・大きさが違う・
  余りの絵があれば、どのファイルかを添えて、Asset Catalog を空にする前に止まる）
- 寝息の 2 コマ目が覆えるかは、SVG のキャラと同じく @3x の mini で見る（`art.covers`）
- `--check` は、Asset Catalog の @3x が final/ と 1 バイトでも違えば落ちる（整え直したのに回し忘れた）
- 作り替えのとき、SVG のキャラ・アイテム・マスク書体・`characters.json` は 1 バイトも変わらないことを確かめた（2-3）

## 背景（写真・ホーム画面）

`design/` とは別で、ユーザーが選んだ画像は `CTStore.ImageStore` が App Group に置く。
長辺 2800 画素で縮め、PNG にそろえる。ホーム画面のスクリーンショットはアイコンの縁が
はっきりしているので、非可逆だと縁に滲みが出る。

読み書きは ImageIO で行い、UIKit を持ち込まない。Phase 3 のウィジェット拡張でも
同じコードが動くようにしてある。
