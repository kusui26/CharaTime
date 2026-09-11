# アセットパイプライン

`design/` の SVG から、アプリが読む PNG と同梱データ JSON を作る。

```bash
python3 tools/pipeline/pipeline.py          # 全部焼き直す（2 分ほど）
python3 tools/pipeline/pipeline.py --check  # 焼かずに整合だけ見る
```

**画像を手で足さない**（`.claude/CLAUDE.md` §2）。足したいときはここを通す。

## 何を作るか

| 出力 | 中身 |
|---|---|
| `ios/.../Resources/Characters.xcassets` | 5 体 × 11 枚 × 3 倍率 |
| `ios/.../Resources/Items.xcassets` | アイテム 7 種 × 3 倍率 |
| `characters.json` の `poses` と `spriteGeometry` | コマの名前と、絵の枠 |
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
拡大縮小によるぼやけが出ない。1 回の起動で 11 枚を横に並べて焼き、Pillow で切り分ける。

## Phase 2 で生成 AI の絵に差し替えるとき

**出力の形（imageset の名前・倍率・接地の位置）は変えない。** 差し替えるのは入口の
`_character_svgs` だけでよい。`verify()` が JSON と Asset Catalog の食い違いを見るので、
差し替え漏れはそこで落ちる。
