# 担当 H: 端末の中でのキャラの取り込み（受け取り・背景・切り分け・整え方・保存・持ち出し）

- 作成日: 2026-09-26（出典の確認日も同じ）
- 前提: 2026-09-26 の決定「利用者が自分の ChatGPT / Gemini / Claude でキャラの絵を作り、アプリに取り込む。アプリ内で生成 AI の API は呼ばない。取り込んだ画像は端末の中だけで処理する」。整えた後の形はいまの `tools/pipeline`・`design/chara.py`・`CTAssets/Catalog.swift`・`CTCore/Model.swift` のとおり（枠 130:180、接地線 93.33%、待受 @3x 585×810、mini @3x 273×378、まぶたの差分、寝息の覆い判定）
- 凡例: ✅ 一次情報（Apple の公式ドキュメント・WWDC・サンプルコード。外部ライブラリはその公式リポジトリ）/ 🔶 二次情報 / 🔷 推測・筆者の見解 / **未確認**。**✅実測** は本セッションで Mac（MacBook Air M1・8 GB、macOS 26.5.2、Xcode 26.6、Swift 6.3.3、最適化ビルド）で動かして確かめたもの。**iOS 実機の値ではない**
- 実験の材料: `design/` から焼いたピヨとモチの @3x（585×810）を、2048 四方に 3×3 で並べ（位置を最大 ±20 画素ずらして、生成 AI の不揃いな格子に似せた）、背景を「透明・白・#00FF00・絵本風の部屋・写真」にした合成画像。元の不透明さが分かっているので、結果を IoU（不透明さ 0.5 で二値にした重なりの割合）で比べた。**生成 AI の本物の出力ではない**（§10 の S3 で確かめる）

---

## 0. 要約

1. **Vision の被写体の切り抜きは、単色の地の 3×3 なら 9 体を 9 つの番号に分けた**（白・緑・透明・写真の地、IoU 0.91〜0.98）✅実測。ただし縁が柔らかく緑の地では緑がにじむ、離れた小さな部品（浮いたとさか）を落とす、絵の背景では 9 体中 2 体を落として窓を 1 体に混ぜた（IoU 0.69）、小さい・多い（24 体以上）と結果が空、**CPU 非対応でシミュレータでは動かない** ✅。→ **「ふつうの背景」の予備に回す** 🔷
2. **単色の地（緑・白）は、縁の色から背景色を推し量り、縁からつながる背景だけを柔らかく抜き、混ざった色を戻す処理を Swift で自作するのがよい**。IoU 0.992〜0.995、緑のにじみ無し、白い体のモチも残る（全体で色を抜くと IoU 0.33）。2048 四方で 0.1〜0.2 秒 ✅実測
3. **格子は等分に頼らず、不透明さの連結成分で見つける**（2048 四方で 40〜60 ms）。小さな成分は近くの体へ寄せ（とさか）、離れた隅の小片は捨てる（透かし）✅実測・🔷
4. 取り込みは **`PhotosPicker`（許可不要 ✅、`.current` ＋ `Data`）と `.fileImporter`（png・jpeg・heic・webP・svg ✅）の両方**。写真アプリ経由で PNG のアルファが残るかは **未確認**（S1）
5. ImageIO は PNG・JPEG・HEIC・AVIF を読み書き、WebP と JPEG XL は読むだけ、**SVG は読めない**。16bit・Display P3・アルファ付きの PNG も読めた ✅実測（macOS 26）
6. **iOS に SVG を画像にする公開 API は無い** 🔶。**SwiftDraw（Zlib、0.29.0）が iOS と macOS の両方で動き、同梱 60 コマで Chrome と縁の 0.4% 以外一致** ✅実測。ただし影・ぼかし（フィルタ）と破線は描かない ✅実測。WKWebView の透明なスナップショットは **未確認**
7. **縮める・広げるは乗算済みで行う**（`CGContext` の `.high` で 2 ms）。非乗算のまま vImage で縮めると、透明な画素に残った緑が縁ににじむ ✅実測（vImage の文書は非乗算を勧めるので、その場合は透明な画素の色を先に埋める ✅）
8. **解像度**: 待受の身長は @3x で約 583 画素 ✅（コードから計算）。1024 四方の 3×3（身長 約 275 画素）は約 2 倍に引き伸ばす → **3×3 は 2048 四方以上か、枚数を分ける** 🔷
9. **まぶたの差分は、生成 AI の 2 枚にはそのまま使えない**（2 枚は全体が少しずつ違う）🔷。目を開けた絵からまぶたを合成するか、位置を合わせて目の範囲だけ差分を取る（S6）
10. ウィジェットは App Group の **mini（展開 0.39 MiB/枚）だけを ImageIO で縮めて読む**。ファイルの保護等級は既定（初回のロック解除まで）で書く。`.complete` にするとロック中に読めない ✅
11. 持ち出しは独自の拡張子の 1 ファイル（UTType を `public.data`＋`public.content` に準拠 ✅）。**中身は Codable の二進 plist が最も簡単**（26 枚で 8 ms、増えは 0.2%）✅実測。zip は `.forUploading` で作れるが読む側は自作が要り、Apple Archive は両方向できる ✅

---

## 1. Vision の被写体の切り抜き

**API** ✅（Apple のドキュメント）
- `VNGenerateForegroundInstanceMaskRequest` は iOS 17・macOS 14 から。Swift 版の `GenerateForegroundInstanceMaskRequest` は iOS 18・macOS 15 から（`Sendable`、`async` の `perform(on:)` を URL・Data・`CGImage`・`CVPixelBuffer`・`CIImage` などに対して持つ）。アルゴリズムの版は `revision1` だけ（実測でも `supportedRevisions = [1]`）
- 結果は `InstanceMaskObservation`（旧 API は `VNInstanceMaskObservation`）1 つ。`allInstancesMask`（旧 `instanceMask`）は「1 画素は 1 つの番号にだけ属し、0 が背景、ほかは番号」。`allInstances` は背景を除く番号の `IndexSet`。`generateMask(for:)` は低解像度、`generateScaledMask(for:scaledToImageFrom:)` は元の大きさ、`generateMaskedImage(for:imageFrom:croppedToInstancesExtent:)` は切り抜いた絵、`instanceAtPoint(_:)` は指した点の番号
- WWDC23「Lift subjects from images in your app」: 「class agnostic（種類を問わない）」「柔らかいマスク（soft segmentation mask）」「番号は 1 から連番だが、**並び順は保証しない**」「被写体が 1 つ以上あれば、結果の配列に観測が 1 つ入る」「ハードウェアを活かすが重い処理なので裏のスレッドで」「Vision は同じプロセスで動き、VisionKit ほど画像の大きさに制限が無い」「出力は SDR。Core Image の `CIBlendWithMask` でマスクを掛ければ HDR を保てる」
- **CPU では動かないので、シミュレータでは動かない**（Apple の Frameworks Engineer、2024-09 のフォーラム）✅。Mac で `supportedComputeStageDevices` を見ると Neural Engine と GPU だけだった ✅実測
- iOS 27 からは、点・矩形・なぞり書きで範囲を指定して直していく `GenerateIterativeSegmentationRequest`（点は最大 13）が入る（WWDC26 セッション 237）✅。実機を iOS 26.1 に据え置く決定（D-15）があるので、いまは使えない 🔷

**Mac で試した結果** ✅実測（2048 四方・3×3・ピヨ 9 ポーズ、絵の枠〈余白込み〉の高さはコマの 82%）

| 地 | 番号の数 | IoU | 欠け | 余分 | 備考 |
|---|---|---|---|---|---|
| #00FF00 | 9 | 0.978 | 2.1% | 0.2% | 縁に緑がにじむ（下） |
| 白 | 9 | 0.982 | 1.2% | 0.7% | 白い体のモチも 0.982 |
| 透明（アルファのまま渡した） | 9 | 0.972 | 2.6% | 0.2% | アルファ付きのまま渡しても分かれた |
| 写真（海岸） | 9 | 0.909 | 8.8% | 0.4% | |
| 絵本風の部屋（壁・窓・床・敷物） | **7** | **0.688** | 14.0% | 25.0% | 寝姿 2 体を落とし、窓を立ち姿と 1 つにした |

- **数と大きさ**: 4×4・4×5・3×7（絵の枠の高さは画像の 20%）は 16・20・21 に分かれた。**4×6（24 体）と 5×5（25 体）は結果が空**。3×3 でも絵の枠を画像の高さの 13%（コマの 40%）まで小さくすると空、17% 以上なら 9。1 体だけなら 10% でも見つけた。触れ合う・重なるキャラは 1 つの番号にまとまった（2×6 → 2、重なった歩き 4 コマ → 1）
- **マスクの大きさ**: 低解像度のマスクは、入力が 1024 四方でも 4096 四方でも 2048×700 でも **常に 512×512（8bit）**。元の大きさのマスクは 32bit 浮動小数
- **速さ**: プロセスで最初の 1 回はモデルの読み込みで 0.8〜6.4 秒（起動を重ねると短くなった）、2 回目からは 1024 四方 23 ms、2048 四方 21〜40 ms、4096 四方 46〜49 ms。Swift 版の API も同じ（初回 95 ms 以降 27 ms）。プロセスのメモリは 2048 四方で約 36 MB 増え、4096 四方では約 160 MB 増えた
- **縁**: 緑の地の切り抜きを暗い地に置くと、輪郭の外側に数画素の緑の帯が出た（縁の半透明の画素のうち 32,741 個で緑が勝つ）。**すわる姿の浮いたとさか（離れた小さな部品）はマスクから落ちた**
- **macOS のコマンドラインでも動く**（`swiftc` で作った CLI で上をすべて測った）。実行は `ImageRequestHandler(cgImage)` → `handler.perform(GenerateForegroundInstanceMaskRequest())` → 空なら `nil`（被写体なし）→ `observation.generateScaledMask(for: observation.allInstances, scaledToImageFrom: handler)` で動いた

**CharaTime での使い方の推奨** 🔷
- (a) 透明 PNG・(b) 単色の地・(c) SVG には使わない（§2 のほうが縁が硬く、離れた部品も残り、シミュレータと `swift test` でも同じ結果になる）。**(d) ふつうの背景の画像だけの予備**にし、番号ごとの切り抜きを並べて「要らないものをタップで外す」（`instanceAtPoint`）確認を必ず挟む。結果が空のときは「無地の背景で作り直す」案内を出す
- 太い輪郭線の絵でも単色の地なら IoU 0.97〜0.98 は出るが、縁の柔らかさとにじみは残るので、使うなら §2 の「混ざりを戻す」「縁の色を内側から広げる」を後に掛ける
- Vision を呼ぶ処理はプロトコルの向こうに置き、単体テストでは差し替える（シミュレータで動かない ✅。CI の macOS の仮想機で動くかは **未確認**）

## 2. ほかの背景の外し方（クロマキー・背景色の推定・にじみ）

**Apple の資料** ✅
- 記事「Applying a Chroma Key Effect」: `CIColorCube` の 3 次元の色表で、色相が 108°〜144° の色を不透明さ 0 にする。**色表は乗算済みで書く**（`CIColorCube` が要求）。記事は色相を `UIColor` で求めているが、共有の処理には UIKit を入れない決まり（CLAUDE.md §2）なので、色相の式を自分で書く 🔷
- `CIImage.premultiplyingAlpha()`: 「Core Image のフィルタは入力が乗算済みであることを求める」
- vImage の形態処理（膨張・収縮）は `vImageMax_Planar8`・`vImageDilate_Planar8`（SDK のヘッダ `Morphology.h`）と、iOS 16 からの `vImage.PixelBuffer.applyMorphology(operation:destination:)`

**Mac で比べた結果** ✅実測（2048 四方の 3×3）

| 方法 | 緑の地 | 白の地 | 白の地・白い体（モチ） | 時間 |
|---|---|---|---|---|
| Vision の切り抜き（参考） | 0.978・縁に緑 | 0.982 | 0.982 | 21〜40 ms |
| `CIColorCube`（記事の作り方。0/1 で抜く） | 0.994・にじみ無し・縁はぎざぎざ | — | — | 42 ms（初回 312 ms） |
| 色の距離で柔らかく抜く＋混ざりを戻す＋緑を抑える（全体） | 0.995 | 0.992 | **0.334**（体が消えた） | 45〜134 ms |
| 同上・**縁からつながる背景だけ**抜く | 0.995 | 0.993 | **0.992** | 152〜199 ms |

- **背景色の推し量り**: 画像の縁から 8 画素の帯の中央値を背景色とし、その色から距離 0.1 以内の画素の割合を「一様さ」とした。緑・白の地では (0,255,0)・(255,255,255)、一様さ 1.000、5〜9 ms
- **柔らかく抜く**: 背景色からの距離 d が 0.10 未満は透明、0.30 以上は不透明、間は比例。観測した色 C＝αF＋(1−α)K から前景の色 F を戻し（K は背景色）、背景色でいちばん強い成分（緑）を残りの大きいほうまで抑える
- **縁からつながる背景だけ**: 縁から塗りつぶして届いた背景色だけを抜く。輪郭線で囲まれた内側の白（白目・白い体）や緑（緑のキャラ）は残る。白い体のモチは、全体で抜くと消え、つながりで抜くと残った
- **残った 1 画素の線**: 閾値のすぐ外（d ≥ 0.30）の縁の画素は、混ざった色のまま不透明で残り、暗い地では細い緑（白の地では白）の線に見えた。**背景から 2 画素以内の縁の色を、内側（輪郭線）の色で置き換える処理（defringe）で消えた**（Python の試作で確認）
- 最適化しないビルド（`swift test` の既定）では、同じ Swift の二重ループが 2.4〜6.2 秒かかった（30〜60 倍遅い）。vImage と `CGContext` は変わらず数 ms ✅実測

**生成 AI の出力に特有のこと**
- Gemini に「透明」と頼むと市松模様を描く（`research/C` §1.2）🔶。縁の帯に 2 色が規則的に並ぶなら、2 色とも背景として同じ塗りつぶしで抜ける 🔷
- Gemini の見える透かし（隅のきらめき）は、2026-08-14 から設定の「Media watermark」で消せるようになった（見える表示を法で求める国では消せない）🔶。見えない SynthID と C2PA は残る 🔶。取り込み時に PNG を書き直すのでメタデータは落ちるが、端末の外に出さないので問題にならない 🔷

**CharaTime での使い方の推奨** 🔷
- 判定の順: (1) アルファがあり、縁の帯の 9 割以上が透明 → そのまま (2) 縁の一様さが 0.9 以上 → 単色として「縁からつながる・柔らかく・混ざりを戻す・色を抑える・defringe」(3) 縁が 2 色の市松 → 2 色で同じ処理 (4) それ以外 → Vision（§1）
- 画素の二重ループは vImage に寄せるか、`swift test` では 64〜256 画素の小さな合成画像で試す（デバッグビルドで遅いため）

## 3. 取り込み（写真アプリ・ファイル App・形式）

- `PhotosPicker` は iOS 16 から。`preferredItemEncoding` は `.automatic`（最良の形式）・`.current`（**変換を避ける、できれば**）・`.compatible`（変換してでも互換の形式）✅。`Image` の `Transferable` は PNG と JPEG だけなので、`Data` で受ける ✅
- **写真のアクセス許可は要らない**: 「ピッカーは別のプロセスで動くので既定で私的。利用者がアプリに写真の選択を許可する必要はない」✅（Apple の記事）。このアプリも `NSPhotoLibraryUsageDescription` を持たずに `PhotosPicker`（`photoLibrary: .shared()`）で壁紙を取り込めており、3-3 では `.current` ＋ `Data` で受け取った壁紙のスクショで、ウィジェットの中と外の壁紙が 0 画素でそろった ✅（プラン §9 の 3-3）
- **PNG のアルファが残るか**: `.current` は変換を避けるので残るはず 🔷。`.compatible` は JPEG などへ変換しうるので、アルファを失う 🔷。ChatGPT・Gemini の iOS アプリが「写真に保存」するとき PNG のまま保存するかは **未確認**（→ 2026-09-26 の A-7 で確かめた: iPhone の ChatGPT から写真に保存し AirDrop で送った絵は、Mac で保存した絵と 1 バイトも違わない透明の PNG だった。`docs/260926_prompt_templates.md` §2.2）
- `.fileImporter(isPresented:allowedContentTypes:allowsMultipleSelection:onCompletion:)` は iOS 14 から。渡される URL はセキュリティスコープ付きで、`startAccessingSecurityScopedResource` と `stop…` で囲んで読む ✅。型は `.png`・`.jpeg`・`.heic`（`public.heic`）・`.webP`（`org.webmproject.webp`）・`.svg`（`public.svg-image`、`public.image` に準拠）✅
- **ImageIO が読める形式**（macOS 26.5.2 の `CGImageSourceCopyTypeIdentifiers()`）✅実測: 読み 62 種・書き 22 種。PNG・JPEG・HEIC・HEICS・AVIF・GIF・TIFF は読み書き、**WebP と JPEG XL は読むだけ**、**SVG は無い**。WebP は Safari 14（iOS 14・macOS 11）で対応が入った ✅（リリースノート）。iOS 26 の一覧は **未確認**（同じ ImageIO なので同等と見込む 🔷）
- 読んだときの形 ✅実測: PNG・WebP・HEIC のアルファ付きは 8bit・非乗算（`alphaInfo = .last`）で出てくる。縮小版（`CGImageSourceCreateThumbnailAtIndex`）の形は形式で違い、PNG・WebP は乗算済み（`premultipliedFirst`）、HEIC は非乗算のまま、16bit の PNG は 16bit の乗算済みになった。**16bit・Display P3・アルファ付きの PNG も 16bit・P3 のまま読めた**。ICC の無い PNG は sRGB として扱われた

**CharaTime での使い方の推奨** 🔷
- 入口は 2 つ: 写真アプリ（`matching: .images`、`.current`、`Data`）と「ファイル」（`[.png, .jpeg, .heic, .webP, .svg]`、複数選択可）。透明 PNG は「ファイルに保存 → ファイルから選ぶ」を確実な道として案内する
- 読む前に `CGImageSourceCopyPropertiesAtIndex` で幅・高さを見て、長辺 8192 を超えるものは断る（展開だけで 256 MB になるため）。処理は長辺 4096 まで（展開 64 MB）に抑える
- 取り込んだら「アルファがあるか」を必ず見て、無ければ §2 の判定へ回す（写真アプリがアルファを落としても、地が単色なら救える）

## 4. SVG を画像にする（iOS と macOS）

- **iOS に SVG のデータを画像にする公開 API は無い**: `UIImage(data:)` は iOS 18 で SVG に `nil` を返したという報告 🔶、SVG が使えるのは Asset Catalog 経由だけという報告 🔶。描いているのは非公開の CoreSVG 🔶。ImageIO も SVG を読めない ✅実測
- **macOS の `NSImage(data:)` は SVG を読む**（`_NSSVGImageRep`）✅実測（macOS 26.5.2）。ただし Apple の文書に明記は無い 🔶（フォーラムに Apple の回答なし）
- **WKWebView**: `takeSnapshot(with:)` と `WKSnapshotConfiguration`（`rect`・`snapshotWidth`・`afterScreenUpdates`）は iOS 11 から ✅。`isOpaque = false` で**透明のまま撮れるかは未確認**（公式の記述なし）。iPhone で縦 3000 画素ほどを超えると白紙になる報告 🔶、実機で 1 回 70 MiB 超を確保した報告（3 倍で撮るため。`snapshotWidth` で抑えた）🔶。スナップショットはソフトウェアで描くので、ハードウェアで描く要素は写らない ✅（WebKit の不具合票 161450）
- **SwiftDraw**（swhitty/SwiftDraw）✅（公式リポジトリ）: 純 Swift の SVG の解析と描画（Core Graphics）。**Zlib ライセンス**（商用可。製品の文書での表記は任意、ソースの注記は消さない）、0.29.0（2026-07-19）、最終更新 2026-08-25、iOS 13・macOS 10.15 から、Swift 6。`g`・`path`・`circle`・`ellipse`・`rect`・`line`・`polyline`・`polygon`・`text`・`use`・`image`・`clip-path`・`mask`・グラデーション・パターンを読む。`<image>` は `data:` の埋め込みだけを使い、ネットワークには出ない（ソースで確認）。コマンドの道具（PNG・PDF 書き出し）もある
- **比べた結果** ✅実測
  - `design/chara.py` の 60 コマ（5 体 × 12）を SwiftDraw で 585×810 に描き、いまの Chrome で焼いた Asset Catalog と比べた: 平均の差 0.09/255、差が 16 を超える画素は平均 0.37%（最大 0.46%、すべて縁のなめらかさ）、不透明さの IoU は 0.999 以上。目で見て区別できない。起動込みで 1 コマ約 60 ms
  - 生成 AI が書きがちな要素を詰めた SVG（グラデーション・`clip-path`・`use`・`transform`・破線・影・ぼかし・文字）: SwiftDraw は **`feDropShadow` を描かず、`feGaussianBlur` は警告を出して描かず、空白区切りの `stroke-dasharray` を実線で描いた**。`NSImage` は影を描かず、ぼかしと破線は描いた
- ほかの候補 ✅（各リポジトリ）: exyte/SVGView（MIT、SwiftUI で描く、リリース無し、未解決 44 件）、SVGKit（GitHub がライセンスを判定できない表記、最終リリース 2021-04、未解決 277 件）、Macaw（MIT、最終更新 2024-02）、resvg（Rust、Apache-2.0、0.48.1）。resvg は Rust の道具と C の橋渡しが要る 🔷

**CharaTime での使い方の推奨** 🔷
- **SVG は SwiftDraw で、目標の画素数に直接描く**（縮小のぼやけが出ない）。iOS と Mac の道具で同じコードになり、いまの Chrome 依存も外せる。依存を足すかは利用者の判断（CLAUDE.md §4）。足さないなら、Claude に書かせる SVG を「`path`・`circle`・`ellipse`・`rect`・単色の塗りと線・`linejoin`/`linecap`・`transform`」に絞るプロンプトにして、その部分集合だけを Core Graphics で描く自前の描画（数百行）にする
- Claude 向けのプロンプトに「フィルタ・影・ぼかし・破線・文字を使わない」「背景の四角を描かない」を入れる。全面を覆う最初の `rect` は背景とみなして外す
- WKWebView は透明の可否が未確認で、重く（別プロセス）、メインスレッドに縛られるので、第三の候補にとどめる

## 5. 格子の切り分け（等分に頼らない）

**Mac で試した結果** ✅実測（§2 で抜いた緑の地の 3×3）
- 不透明さ 0.5 以上を 8 近傍でつなぐ union-find（Swift・1 スレッド）: **2048 四方で 37〜63 ms**（デバッグビルドでは 2.5 秒）。成分は 11 個: 体 9 個（57,000〜120,000 画素）と、**すわる姿の浮いたとさか 2 個（約 2,800 画素）**
- 「面積が中央値の 1/10 以上」で体の 9 個だけが残った。とさかのような離れた部品を捨てると絵が欠けるので、**捨てずに近くの体へ寄せる**必要がある
- Vision の番号の順は保証されない ✅（§1）。実測でも格子の読み順と番号の順は食い違った（1 3 2 4 5 6 9 8 7）

**手順の案** 🔷
1. 不透明さで二値にし、画像の短辺の 0.5% ほどの膨張（`vImageMax_Planar8`）で、線の切れ目を閉じてから連結成分を取る
2. 面積が「体の面積の中央値」の 1/10 未満のものは、いちばん近い体の外接矩形から短辺の 5% 以内なら寄せる（とさか・汗・z）。それより遠く、画像の隅にあるものは透かしとして捨てる。数画素のものはゴミとして捨てる
3. 期待する数（3×3 なら 9、帯なら 4。取り込み画面で選ぶ）と比べる。少なければ触れ合って 1 つになったものを、その成分の中の縦・横の不透明さの合計の谷で割る。多ければ小さいものから寄せる
4. 中心の y を行にまとめ（行の数だけの 1 次元のまとまり）、行の中を x で並べる。生成した並び（プラン §6.2 の 9 コマの順）を既定の割り当てにして、**利用者がポーズを並べ替えられる**画面を必ず挟む
5. 触れ合うのを減らすため、プロンプトに「コマの間を広く空ける」「枠線を描かない」を入れる。枠線が描かれたら、画像の端から端まで続く細い直線を先に消す

## 6. Swift での画素処理（縮小・乗算済み・色空間）

- **`CGContext` は 8bit の RGBA では乗算済みしか描けない**（Quartz 2D の対応表で、アルファ付きの 8bit RGB は `PremultipliedFirst`・`PremultipliedLast` だけ）✅。取り出した画素は乗算済みなので、色を比べる前に割り戻す
- **`vImageScale_ARGB8888`**: 「高周波の部分の乱れを避けるには、非乗算か、全体で一定のアルファの画像を渡す」「高品質にするなら `kvImageHighQualityResampling`」「`kvImageLeaveAlphaUnchanged` は無視する」✅。iOS 16 からは Swift の `vImage.PixelBuffer` でも拡大縮小と形態処理ができる ✅
- **4 つの成分を別々に補間する**: 不透明の赤と「色だけ緑の透明」の境目を 2 倍にすると、(R200,G55,α200)・(R55,G200,α55) の画素ができた ✅実測。つまり非乗算の画像で透明な画素に色（生成 AI の緑など）が残っていると、それが縁ににじむ
- 実画像で比べた（350×509 のコマを身長 643 画素へ）✅実測: **非乗算・透明な画素が緑のまま**だと、縁（不透明さ 1〜60）の平均の色が (15,118,10) の緑になった。**乗算済み**なら (38,24,24) で輪郭の茶色 (59,43,43) に近い（低いアルファで暗くなるのは 8bit の乗算済みの丸めで、表示では見えない 🔷）。乗算済みで高品質に補間すると、色がアルファを超える画素が 0〜7 個出た（負の裾による行き過ぎ）ので、最後に色をアルファで頭打ちにする
- 速さ（同じ拡大 / 身長 300 画素への縮小）✅実測: vImage 高品質・乗算済み 2.4〜6.0 ms / 0.4 ms、**`CGContext` の `.high` 1.9 ms / 1.6〜2.3 ms**、`CILanczosScaleTransform` 18.6〜66 ms / 8.2〜36.5 ms（`CIContext` を作る時間込み）。`.high` の中身の算法は文書に無い（「遅くなりうる」とだけ）✅ / **未確認**
- **色空間**: ICC の無い PNG は sRGB として読まれ、P3 の PNG は P3 のまま読まれる ✅実測。sRGB の `CGContext` に描けば色を合わせて変換される 🔷。同梱の PNG（Pillow が書いた）は sRGB 扱い ✅実測

**CharaTime での使い方の推奨** 🔷
- 作業用の形は「sRGB・8bit・乗算済み RGBA」の 1 つに決め、入口で必ずそれに描き直す（16bit や P3 はここで落とす。パステルの平塗りでは差が見えない）
- 大きさを変えるのは `CGContext`（`.high`、乗算済み）を標準にする。vImage を使うときは乗算済みで渡し、色をアルファで頭打ちにする。非乗算で渡すなら、先に透明な画素の色を近くの不透明な色で埋める
- **解像度の目安**: 待受ではキャラの枠を画面の高さの 0.28 倍（iPhone 17 Pro で約 245pt、@3x で約 734 画素）で描くので ✅（`SceneLayout.characterHeightRatio`）、枠の 79.4%（143/180）の身長は約 583 画素。元の絵の身長がこれ以上なら引き伸ばさずに済む 🔷。体がコマの高さの 8 割を占めるとして、3×3 を 2048 四方で作ると身長は約 550 画素（ほぼ等倍）、1024 四方だと約 275 画素（約 2 倍に引き伸ばす）。取り込み時に「身長が 400 画素未満」なら作り直しを勧める。mini（身長 約 300 画素）は 1024 四方でも足りる
- 生成サービスごとの出力の画素数（ChatGPT・Gemini のアプリで選べる大きさ）は **未確認**（API の上限は `research/C` §1）（→ 2026-09-26 の 2-0 で測った: ChatGPT は約 157 万画素。1:1 は 1254×1254、3:4 は 1086×1448。Web から保存。`docs/260926_prompt_templates.md` §2.1）

## 7. ウィジェットで読む

- **App Group**: iOS では `containerURL(forSecurityApplicationGroupIdentifier:)` が無効な識別子で `nil` を返す。システムが作るのは `Library/Caches` だけ。グループのアプリがすべて消えるとフォルダも消える ✅。iCloud と Finder のバックアップに含まれる、と Apple の DTS が「私の理解では」と答えている 🔶
- **ファイルの保護**: 既定は「初回のユーザー認証まで完全」（起動後に一度ロックを外せば、再起動まで読める）。`Complete` はロック解除中しか読めない ✅。Apple の記事は利用者が作ったファイルに `Complete` を勧めるが、**ウィジェットはロック中にも描くので、キャラの絵は既定のままにする** 🔷（`Data.write(options: .completeFileProtection)` を使わない。既定の保護を上げる entitlement も付けない）
- **縮めて読む**: `CGImageSourceCreateThumbnailAtIndex` に `kCGImageSourceCreateThumbnailFromImageAlways`・`kCGImageSourceThumbnailMaxPixelSize`（無いと元の大きさになる）を渡す。`kCGImageSourceShouldCacheImmediately` は作るときに展開する ✅。WWDC18「Image and Graphics Best Practices」のスライドは、読み元を `kCGImageSourceShouldCache: false` で作り、縮小に `ShouldCacheImmediately: true` を付ける形を示す ✅
- **1 枚の展開の大きさ**（幅 × 高さ × 4 バイト）: mini @3x 273×378 = 412,776 バイト（0.39 MiB）、待受 @3x 585×810 = 1,895,400 バイト（1.81 MiB）、取り込んだ元の 2048 四方 = 16 MiB 🔷（計算）。拡張の上限は約 30 MB、実機の最大は 13.7 MB（3-2c）✅（プロジェクトの記録）

**CharaTime での使い方の推奨** 🔷
- 置き場は `App Group/characters/<UUID>/` に `character.json`（`Character` を Codable のまま。`origin: .user(createdAt:)` は `Model.swift` に既にある）、`frames/`（@3x のみ）、`mini/`（@3x のみ）、`eyelid/`。**取り込んだ元の画像は App Group に置かない**（ウィジェットが誤って読むと 16 MiB）。作り直しに要るなら本体側のコンテナへ
- 書く順は「画像 → `character.json`」、どちらも `.atomic`。ウィジェットは json が読めて画像がそろったキャラだけを描き、欠けたら同梱のキャラか止めた 1 枚に落ちる（`StateStore.load` の作法）。書き終えたら `WidgetCenter.reloadTimelines(ofKind:)`
- 拡張では mini だけを、描く画素数を `ThumbnailMaxPixelSize` に渡して読む（いまの `ImageStore.thumbnail(_:maxPixelSize:)` の形）。いまの描画は Asset Catalog の名前（`Image(decorative:bundle:)`）で引いているので、「同梱は名前・取り込みはファイル」を分ける小さな型が CTRender に要る
- 整える処理のパッケージ（§9）は拡張にリンクしない（Vision・Core Image を拡張に持ち込まない）

```swift
// ウィジェット拡張: mini を描く大きさで 1 回だけ展開する（WWDC18 219 の形）
let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary)
let options = [kCGImageSourceCreateThumbnailFromImageAlways: true,
               kCGImageSourceShouldCacheImmediately: true,
               kCGImageSourceThumbnailMaxPixelSize: maxPixels] as CFDictionary
let image = source.flatMap { CGImageSourceCreateThumbnailAtIndex($0, 0, options) }   // 失敗は nil で受ける
```

## 8. キャラの持ち出しと持ち込み（自分の端末どうし・予備）

- **zip**: `NSFileCoordinator` の `.forUploading` で読むと、フォルダは「中身を zip にした新しいファイル」のスナップショットになる。URL はブロックの中だけ有効 ✅。macOS で 26 枚（0.68 MB）のフォルダが 115 ms で `chara.zip`（deflate、668,937 バイト）になった ✅実測。**zip を読む公開 API は無い** 🔷（`Compression` の `COMPRESSION_ZLIB` は生の DEFLATE（RFC 1951）なので ✅、zip の中央ディレクトリを読む小さな読み手は書ける 🔷）
- **Apple Archive**: iOS 14・macOS 11 から、フォルダをまとめて圧縮・展開できる ✅。同じフォルダが 12 ms で 680,675 バイトの `.aar` になり、展開して 26 枚が戻った ✅実測。「ファイル」App が `.aar` を開けるかは **未確認**
- **二進 plist**: `PropertyListEncoder`（`.binary`）で「manifest と画像の `Data`」を 1 つの Codable の型にすると、678,703 バイト（画像の合計より 0.2% 増えただけ）、書いて読み戻して 8 ms ✅実測。PNG は既に圧縮されているので、zip や aar でも小さくならない
- **独自の型**: `UTExportedTypeDeclarations` で逆 DNS の識別子（`public`・`dyn`・`com.apple` で始めない）を宣言し、「ファイル」App が扱えるよう `public.data` に、AirDrop で送れるよう `public.content` に準拠させる。拡張子は `UTTypeTagSpecification` ✅
- **送る・開く**: `ShareLink` は iOS 16 から。メール・メッセージ・AirDrop などはファイルしか受けないことがあるので `FileRepresentation` を持たせる ✅。受ける側は `CFBundleDocumentTypes`、`onOpenURL`（iOS 14）、`LSSupportsOpeningDocumentsInPlace`（原本を開くかコピーを受けるか）✅。アプリの中からは `.fileImporter` で同じ型を選ぶ

**CharaTime での使い方の推奨** 🔷
- 形式は `.charatime`（識別子は例えば `app.charatime.character`）の 1 ファイル。中身は **`schemaVersion`・`Character`・`[ファイル名: Data]` を持つ Codable の型 1 つを二進 plist にしたもの**。外部ライブラリ無しで読み書きでき、`swift test` で往復を試せる（CLAUDE.md の「JSON の形は Codable の型ひとつから導く」に合う）。中身を PC で見たい需要が出たら、書き出しにだけ zip を足す
- 持ち込むときは、画像をすべて ImageIO で開き直して大きさ・枚数・ポーズ名を確かめ、PNG に書き直してから置く（壊れたファイルで落ちない）。識別子は新しい UUID にし、同じキャラの 2 回目は「上書き / 別に置く」を選ばせる
- 機種変更は、App Group がバックアップに入るなら自動で移る 🔶。書き出しは「予備」と「バックアップを使わない引っ越し」のため
- `project.yml`（XcodeGen）の `info.properties` に型の宣言を足す（Info.plist を手で書かない）

## 9. 推奨する処理の流れ（取り込み → 背景 → 切り分け → 整える → mini とまぶた → 保存 → ウィジェット）

**置き場所**: 整える処理を新しいローカルパッケージ（仮に `CTForge`。プラン v1.4 では `CTStudio` と名付けた。D-35。Foundation・CoreGraphics・ImageIO・Accelerate、(d) のときだけ Vision と Core Image）に 1 か所で書き、アプリの取り込みと、同梱キャラを焼く Mac の道具（`swift run` の実行ターゲット）が同じ関数を呼ぶ。依存は `CTCore ←（CTAssets）← CTForge ← アプリ / Mac の道具`、**ウィジェット拡張には入れない** 🔷。この形は成り立つ: 上の処理はすべて macOS の CLI で動き ✅実測、`swift test` でも試せる（Vision を除く）🔷

1. **取り込み**（アプリ）: 写真アプリ（`.current`・`Data`）か「ファイル」（png・jpeg・heic・webP・svg、複数）。Mac の道具は `design/` の SVG か、ファイルの引数。寸法を先に読み、長辺 8192 超は断る
2. **画素にする**: ラスタは ImageIO で開き、向きを解いて、長辺 4096 以下の sRGB・8bit・乗算済みに描き直す。SVG は SwiftDraw で目標の画素数に直接描く（全面の背景の四角は外す）
3. **背景**: 透明 → そのまま / 縁が一様な単色 → 縁からつながる背景だけ柔らかく抜き、混ざりを戻し、背景色の成分を抑え、縁の色を内側から広げる / 市松 → 2 色で同じ処理 / それ以外 → Vision、番号ごとの切り抜きを見せて要らないものを外す
4. **切り分け**: 連結成分 → 小片を体へ寄せる・隅の小片とゴミを捨てる → 期待数に合わせる → 行・列の順に並べる → 利用者がポーズを割り当て、向き（左向き）を確かめる
5. **整える**: 立ち姿（目を開けた絵）の身長を枠の 79.4%（143/180）に合わせる倍率を、そのキャラの全コマに共通で使う。接地線（不透明さ 0.5 以上のいちばん下の行。足元の影は除く）を枠の 93.33% に、横は頭と胴（上 6 割）の中心を枠の中央に。**コマごとに余白を詰めない**。枠からはみ出す姿勢（寝そべり）だけは、その姿勢を枠に収まるまで縮めて知らせる。@3x 585×810 に `CGContext` の `.high` で描き、色をアルファで頭打ちにする
6. **mini とまぶた**: mini は同じ整えたコマを @3x 273×378 に。まぶたは、目を開けた絵の目（頭の中の暗い塊）を見つけ、周りの肌の色で埋めて弧を描いた差分を作る（2 枚目の絵と位置が必ずそろう）か、2 枚目を 1 枚目に位置合わせしてから目の範囲だけの差分を取る（→ 2-0 の S6 で、目を開けた絵から作るほうに決めた。ChatGPT の 2 枚目は輪郭ごと 1〜2 画素ずれていた。プラン D-38）（S6 で選ぶ）。目の範囲が見つからなければ、利用者に指で囲ませるか、まばたき無しにする（`eyelids` が空なら、その姿勢は 1 コマ目だけで描かれ、ほかの動きは残る。`AmbientCue.blinking` の作り ✅）。寝息の覆い判定は `tools/pipeline/art.py` の `covers` をそのまま移す
7. **保存**: `App Group/characters/<UUID>/` に PNG（@3x のみ）→ `character.json` の順に `.atomic` で書く。保護等級は既定。書き終えたらウィジェットに作り直しを頼む
8. **ウィジェット**: mini とまぶただけを、描く画素数で ImageIO で縮めて読む。読めなければ同梱キャラか止めた 1 枚へ落ちる
9. **持ち出し**: `.charatime`（二進 plist）を `ShareLink`、持ち込みは `onOpenURL` と `.fileImporter`

時間の見込み（2048 四方 1 枚、最適化ビルド）: 背景 0.1〜0.2 秒、切り分け 0.05 秒、12 コマの整えと mini 0.1 秒未満、PNG の書き出し 0.1〜0.3 秒 🔷（Mac の実測からの見込み。iPhone 17 Pro は未測）。Vision を使うときだけ初回に数秒を足す

## 10. 試作で確かめるべきこと（スパイクの候補）

| # | 何を | どう確かめる | 通る目安 |
|---|---|---|---|
| S1 | 写真アプリ経由の PNG のアルファと、iOS 26 の ImageIO の形式 | 実機で ChatGPT アプリ・Gemini・Safari で保存した透明 PNG を `PhotosPicker`（`.current`・`.automatic`）と「ファイル」から取り込み、`kCGImagePropertyHasAlpha` と形式を記録。`CGImageSourceCopyTypeIdentifiers()` も記録 | `.current` でアルファが残る。WebP・HEIC・16bit PNG が読める |
| S2 | Vision の実機の速さとメモリ | iPhone 17 Pro（iOS 26.1）で 2048 四方の 3×3 を初回・2 回目で測り、Mac と同じ番号の数になるか見る | 2 回目 100 ms 未満、初回 3 秒未満 |
| S3 | 本物の生成 AI の出力での自動の成功率 | ChatGPT の透明 PNG・Gemini の緑の地・Claude の SVG を各 5 枚以上作り、Mac の道具で §9 を流す | 9 コマ・4 コマが手直し無しで 8 割以上切り分けられる。影・市松・透かしの扱いが分かる |
| S4 | SwiftDraw をアプリに入れたときの大きさと、Claude の SVG の描け方 | 空のアプリとの差（容量・起動時間）、Claude に 10 枚書かせて警告の出る要素を数える | 容量の増えが 1 MB 前後。警告の出る要素をプロンプトで避けられる |
| S5 | （S4 を採らないとき）WKWebView の透明なスナップショット | 実機で `isOpaque = false`・`backgroundColor = .clear` の Web ビューに SVG を出し、隅の画素のアルファを見る | アルファが 0 |
| S6 | まぶたの作り方 | 生成 AI の目開き・目閉じの 2 枚で「差分」と「合成」を作り、ウィジェットで 0.25 秒のまばたきを収録して継ぎ目を見る | 継ぎ目が見えない方を採る |
| S7 | ウィジェットがファイルの mini を読むとき | 取り込んだキャラで「ウィジェットの記録」のメモリを見る。再起動後のロック中・初回解除後に描けるか | 15 MB 以下、初回解除後はロック中も描ける |
| S8 | 持ち出しと持ち込みの往復 | AirDrop で Mac に送り、iCloud Drive から別の端末で開く。`.charatime` がアプリで開くか | 絵と性格が同じに戻る |
| S9 | テストの速さ | `CTForge` のテストを `scripts/check.sh` で回し、合成画像の大きさと時間を見る | 全体で数秒の増えに収まる |

## 11. 未確認事項

- iOS 26 実機で `PhotosPicker`（`.current`）が PNG のアルファを保つか。ChatGPT・Gemini の iOS アプリが写真に何の形式で保存するか（S1）（→ ChatGPT の保存は透明の PNG のまま、と A-7 で確かめた。`PhotosPicker` での受け取りは 2-6 のあと実機で）
- iOS 26 の ImageIO が読める形式の一覧（macOS 26.5.2 でだけ確かめた）（S1）
- Vision の実機での初回の時間・2 回目の時間・メモリ、Mac と同じ判定になるか（S2）。GitHub Actions の macOS の仮想機で Vision が動くか
- Vision が「結果が空」を返す条件（小さい・多いの境目）。Apple の文書に数の上限の記述は無い
- WKWebView の `takeSnapshot` が非不透明のとき透明のまま撮れるか、大きさの上限（S5）
- `CGInterpolationQuality.high` の算法（文書に無い）
- ChatGPT・Gemini のアプリで選べる出力の画素数（格子の 1 コマの解像度が決まる）（→ 2026-09-26 の 2-0 で測った: ChatGPT は約 157 万画素。1:1 は 1254×1254、3:4 は 1086×1448。Web から保存。`docs/260926_prompt_templates.md` §2.1）
- 「ファイル」App が `.aar` を開けるか
- App Group のファイルが iCloud バックアップに必ず含まれるか（DTS の回答は「私の理解では」）
- 生成 AI の透明 PNG に足元の半透明の影が入るか、入ったときに接地線の検出がずれるか（S3）（→ 2-0 の ChatGPT の 3 枚には影が無かった。ただし体の中の不透明さは 253〜254 で 255 にならず、縁の外に 1〜31 の薄いにじみがあった）

## 12. 出典一覧（確認日はすべて 2026-09-26）

**Apple（Vision）**
- ✅ VNGenerateForegroundInstanceMaskRequest: https://developer.apple.com/documentation/vision/vngenerateforegroundinstancemaskrequest
- ✅ GenerateForegroundInstanceMaskRequest: https://developer.apple.com/documentation/vision/generateforegroundinstancemaskrequest
- ✅ VNInstanceMaskObservation（instanceMask ほか）: https://developer.apple.com/documentation/vision/vninstancemaskobservation
- ✅ InstanceMaskObservation（allInstancesMask・generateScaledMask(for:scaledToImageFrom:)・instanceAtPoint）: https://developer.apple.com/documentation/vision/instancemaskobservation
- ✅ GenerateIterativeSegmentationRequest（iOS 27）: https://developer.apple.com/documentation/vision/generateiterativesegmentationrequest ／ サンプル（WWDC26 237）: https://developer.apple.com/documentation/vision/segmenting-objects-using-taps-scribbles-or-rectangles
- ✅ サンプル Applying visual effects to foreground subjects: https://developer.apple.com/documentation/vision/applying-visual-effects-to-foreground-subjects
- ✅ WWDC23 10176 Lift subjects from images in your app: https://developer.apple.com/videos/play/wwdc2023/10176/
- ✅ シミュレータで動かない（Apple Frameworks Engineer、2024-09）: https://developer.apple.com/forums/thread/764948

**Apple（Core Image・vImage・Core Graphics）**
- ✅ Applying a Chroma Key Effect: https://developer.apple.com/documentation/coreimage/applying-a-chroma-key-effect ／ CIColorCube: https://developer.apple.com/documentation/coreimage/cicolorcube
- ✅ premultiplyingAlpha(): https://developer.apple.com/documentation/coreimage/ciimage/premultiplyingalpha() ／ CILanczosScaleTransform: https://developer.apple.com/documentation/coreimage/cilanczosscaletransform
- ✅ vImageScale_ARGB8888: https://developer.apple.com/documentation/accelerate/vimagescale_argb8888(_:_:_:_:) ／ Resampling in vImage: https://developer.apple.com/documentation/accelerate/resampling-in-vimage
- ✅ vImagePremultiplyData_RGBA8888: https://developer.apple.com/documentation/accelerate/vimagepremultiplydata_rgba8888(_:_:_:) ／ vImage.PixelBuffer: https://developer.apple.com/documentation/accelerate/vimage/pixelbuffer
- ✅ vImage の形態処理: macOS 26 SDK の `Accelerate.framework/Frameworks/vImage.framework/Headers/Morphology.h`（`vImageDilate_Planar8`・`vImageMax_Planar8`）
- ✅ CGInterpolationQuality: https://developer.apple.com/documentation/coregraphics/cginterpolationquality
- ✅ Quartz 2D Programming Guide（Graphics Contexts、表 2-1）: https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/dq_context/dq_context.html

**Apple（取り込み・形式・ウィジェット）**
- ✅ PhotosPicker: https://developer.apple.com/documentation/photosui/photospicker ／ EncodingDisambiguationPolicy: https://developer.apple.com/documentation/photosui/photospickeritem/encodingdisambiguationpolicy
- ✅ Delivering an Enhanced Privacy Experience in Your Photos App: https://developer.apple.com/documentation/photokit/delivering-an-enhanced-privacy-experience-in-your-photos-app
- ✅ fileImporter: https://developer.apple.com/documentation/swiftui/view/fileimporter(ispresented:allowedcontenttypes:allowsmultipleselection:oncompletion:)
- ✅ UTType.svg / webP / heic: https://developer.apple.com/documentation/uniformtypeidentifiers/uttype-swift.struct/svg （同じ階層の webp・heic）
- ✅ Safari 14 Release Notes（WebP）: https://developer.apple.com/documentation/safari-release-notes/safari-14-release-notes
- ✅ CGImageSourceCreateThumbnailAtIndex: https://developer.apple.com/documentation/imageio/cgimagesourcecreatethumbnailatindex(_:_:_:) ／ kCGImageSourceThumbnailMaxPixelSize・kCGImageSourceShouldCacheImmediately・kCGImageSourceCreateThumbnailFromImageAlways（同じ階層）
- ✅ WWDC18 219 Image and Graphics Best Practices（スライド）: https://devstreaming-cdn.apple.com/videos/wwdc/2018/219mybpx95zm9x/219/219_image_and_graphics_best_practices.pdf
- ✅ completeUntilFirstUserAuthentication: https://developer.apple.com/documentation/foundation/fileprotectiontype/completeuntilfirstuserauthentication ／ Encrypting Your App's Files: https://developer.apple.com/documentation/uikit/encrypting-your-app-s-files
- ✅ containerURL(forSecurityApplicationGroupIdentifier:): https://developer.apple.com/documentation/foundation/filemanager/containerurl(forsecurityapplicationgroupidentifier:)
- 🔶 App Group とバックアップ（DTS、2021-11）: https://developer.apple.com/forums/thread/693766

**Apple（SVG・WebKit）**
- ✅ takeSnapshot(with:completionHandler:): https://developer.apple.com/documentation/webkit/wkwebview/takesnapshot(with:completionhandler:) ／ WKSnapshotConfiguration: https://developer.apple.com/documentation/webkit/wksnapshotconfiguration
- ✅ WebKit Bug 161450: https://bugs.webkit.org/show_bug.cgi?id=161450
- 🔶 スナップショットが白紙になる大きさ: https://developer.apple.com/forums/thread/727992 ／ 1 回 70 MiB 超: https://developer.apple.com/forums/thread/718092
- 🔶 NSImage は SVG を読むが iOS は nil: https://developer.apple.com/forums/thread/740218 ／ SVG は Asset Catalog だけ: https://developer.apple.com/forums/thread/659122

**Apple（持ち出し・持ち込み）**
- ✅ NSFileCoordinator.ReadingOptions.forUploading: https://developer.apple.com/documentation/foundation/nsfilecoordinator/readingoptions/foruploading
- ✅ Apple Archive: https://developer.apple.com/documentation/applearchive ／ COMPRESSION_ZLIB: https://developer.apple.com/documentation/compression/compression_zlib
- ✅ Defining file and data types for your app: https://developer.apple.com/documentation/uniformtypeidentifiers/defining-file-and-data-types-for-your-app
- ✅ ShareLink: https://developer.apple.com/documentation/swiftui/sharelink ／ FileRepresentation: https://developer.apple.com/documentation/coretransferable/filerepresentation ／ onOpenURL: https://developer.apple.com/documentation/swiftui/view/onopenurl(perform:) ／ LSSupportsOpeningDocumentsInPlace: https://developer.apple.com/documentation/bundleresources/information-property-list/lssupportsopeningdocumentsinplace

**外部ライブラリ・報道**
- ✅ SwiftDraw（README・LICENSE.txt・Package.swift・ソース、0.29.0）: https://github.com/swhitty/SwiftDraw
- ✅ SVGView: https://github.com/exyte/SVGView ／ SVGKit: https://github.com/SVGKit/SVGKit ／ Macaw: https://github.com/exyte/Macaw ／ resvg: https://github.com/linebender/resvg （いずれも GitHub API で状態を確認）
- 🔶 Gemini の見える透かしを消せるようになった（2026-08-14）: https://techcrunch.com/2026/08/14/google-will-now-allow-users-to-remove-visible-watermark-from-its-ai-generations/ ／ 設定の場所と国の制限: https://www.androidheadlines.com/2026/08/google-gemini-turn-off-corner-media-watermarks-3-7-flash.html

**プロジェクトの中**
- `docs/260910_dev_plan.md` §6.2・§6.7・§9（3-2c・3-3）、`docs/research/C_ai_character_pipeline.md` §1・§4、`tools/pipeline/pipeline.py`・`art.py`・`rasterize.py`、`design/chara.py`、`ios/Packages/CTAssets/Sources/CTAssets/Catalog.swift`、`ios/Packages/CTCore/Sources/CTCore/Model.swift`、`ios/Packages/CTStore/Sources/CTStore/ImageStore.swift`、`ios/Packages/CTRender/Sources/CTRender/SceneLayout.swift`
