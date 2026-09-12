# 調査 E: iOS キャラクターアニメーション実装技術とアセット制作パイプライン

- プロジェクト: CharaTime（au「ケータイパートナー」の再現。iPhone 17 Pro / iOS 26 系 / Xcode 26.6 / Swift 6.3 / SwiftUI）
- 調査日: 2026-09-10（本文中の「確認日」はすべて 2026-09-10）
- 凡例: ✅ 一次情報（公式ドキュメント・公式価格ページ・公式リポジトリ）で確認 / 🔶 二次情報（技術ブログ・フォーラム・比較サイト）/ 🔷 推測・筆者の設計提案（要検証）
- 調査手段: WebSearch 約 50 回（セッション上限に到達）+ WebFetch 約 95 回。live2d.com・meshy.ai・apple.com（製品ページ）・photoroom.com・lilting.ch・anysplit.net はフェッチがブロックされたため、該当箇所は 🔶/🔷 または「10. 未確認事項」に記載。

---

## 0. 要約

1. **MVP の描画は SwiftUI 単体（`TimelineView` + `Canvas` / `Image` フレーム切替）を第一候補**にする。SpriteKit は非推奨化されていないが（✅）、SceneKit が iOS 26 で正式 deprecated（✅）、かつ iOS 26.x で「SpriteKit + SwiftUI」のフレームレート退行が 2026-03 時点で未解決（🔶 FB20287404 / FB20808104 / FB21914640）。SwiftUI 単体ならウィジェットと描画コードを共有できる。
2. **アセットは「PNG フレームアニメ（スプライト）」に一本化**する。Rive / Spine / Live2D の骨アニメはウィジェット（静的 SwiftUI スナップショット）で再生できず、AI 画像のパーツ分割+リグは工数が大きい。将来のアプリ内リッチ化には Rive（ランタイム MIT、エディタは Cadet $9/月で .riv 書き出し ✅）を第一候補として温存。
3. **ウィジェット側は「5 分間隔の静止画タイムライン」を正とし、`Text(timerInterval:)` + カスタムフォント（マスク方式）による 1〜8fps の疑似アニメは feature flag 付きの実験枠**にする。公開 API のみで 8fps 実証・最大 30fps（✅ Bryce Bostwick リポジトリ）だが非公式ハックで、電池・30MB メモリ上限（🔶 クラッシュログ `limit=30 MB`）に注意。
4. **生成 → 加工パイプラインは全部 CLI で自動化可能**: OpenAI 画像 API は `background: "transparent"` の PNG 出力に対応（✅）、Gemini 3.1 Flash Image は参照画像最大 14 枚でキャラ一貫性（✅）→ rembg（`isnet-anime`）→ ImageMagick `-trim` / `-gravity South -extent` で足元基準の正規化 → `montage` or Pillow でシート化 → Asset Catalog（SwiftUI は個別 imageset、SpriteKit なら `.spriteatlas`）。
5. **最小アニメセットは 13 枚**（idle 2 / walk 4（左向きのみ、右は `-flop` or `scaleEffect(x:-1)`）/ sit 1 / sleep 2 / happy 2 / react 2）。squash & stretch・bob・イージング・影とエフェクトの分離で「動いて見せる」。
6. **自律行動は「決定論的 FSM + ユーティリティ（重み付き乱数）」**。SplitMix64 をユーザーシード × 5 分スロットで種付けし、アプリとウィジェットが同じ `stateAt(date:)` を評価することで表示を一致させる。文脈: 時刻、バッテリー、歩数（HealthKit は本体アプリで取得し App Group へ）、天気（WeatherKit 50 万コール/月無料 ✅）、カレンダー。
7. **3D ルートは非推奨**（ガラケー再現に不自然・RealityView は iOS 18+ ✅・リグ後処理の工数大）。動画→スプライト（Viggle 等 + ffmpeg `chromakey`）は補助手段。
8. **プロジェクトは XcodeGen 2.46.0（✅ 2026-07-16）+ ローカル SwiftPM 4 分割**（CharaCore = 純粋シミュレーション / CharaAssets / CharaUI / Widget）。

---

## 1. 2D 実装選択肢の比較表と詳細

### 1.1 比較表

| 選択肢 | メンテ状況 / 最新版 | ライセンス・費用 | SwiftUI 統合 | AI 生成画像との相性 | ウィジェットとの資産共有 | Swift 6 | 学習コスト | 判定 |
|---|---|---|---|---|---|---|---|---|
| **SwiftUI 単体**（TimelineView + Canvas / Image 切替 / phaseAnimator / keyframeAnimator） | OS 同梱。phaseAnimator / keyframeAnimator は iOS 17+ ✅ | 無料 | ネイティブ | ◎ PNG フレームをそのまま使う | ◎ 同じ View/描画関数をウィジェットで静的に描ける | ◎ | 低 | **MVP 採用** |
| **SpriteKit**（`SpriteView`） | 非推奨化なし ✅（iOS 7+、visionOS ネイティブは非推奨 ✅）。iOS 26.x で SwiftUI 併用時の fps 退行が未解決 🔶 | 無料 | `SpriteView`（iOS 14+、`@MainActor @preconcurrency` ✅） | ◎ `.spriteatlas` + `SKAction.animate` | △ ウィジェットでは SKView 不可。フレーム PNG 自体は共有可 | ○（クラスは非 Sendable、Main Actor 前提） | 低〜中 | 物理・パーティクルが必要になったら |
| **Rive**（rive-ios） | 6.26.0（✅ 2026-09-09）、iOS 14+、バイナリ xcframework ✅ | ランタイム MIT ✅。エディタ Free は 2025-10-20 以降 .riv 書き出し不可、Cadet $9/月（年払い）で無制限書き出し ✅ | `RiveViewModel(...).view()` ✅ | ○ PNG パーツにメッシュ+ボーン（Auto-Trace あり ✅） | × ランタイム描画はウィジェット不可（🔷 docs に extension 記載なし） | ○ | 中 | **将来のアプリ内リッチ化候補** |
| **Spine**（spine-ios） | 4.3 系（✅ tags 4.3.13）、iOS 13+、C++ ソース SwiftPM ✅ | Essential $69 / Professional $379（買い切り、ランタイム利用権込み）✅。Essential はメッシュ・IK・ウェイト不可 ✅ | `SpineView` ✅ | ○ メッシュ変形は Pro 必須 | × | ○ | 中 | 費用対効果で Rive に劣後 |
| **Live2D Cubism SDK** | Cubism 5.3、Native SDK は C++（Metal/OpenGL サンプル）✅。Swift ラッパーなし ✅ | SDK DL 無料。個人・小規模事業者は出版ライセンス料免除（Expandable Application を除く）✅。エディタ PRO indie 約 $100/年 🔶 | × 自前で C++ ブリッジ | △ 顔・上半身の変形向き。全身歩行は不得手 🔷 | × | △ | 高 | 不採用 |
| **DragonBones** | 開発停止・DL リンク切れ 🔶 | 無料 | × | – | × | – | – | 不採用 |
| **Lottie**（lottie-ios） | 4.6.1（✅ 2026-06-13）、Apache-2.0 ✅ | 無料 | `LottieView` 🔶 | △ ベクター（AE/Bodymovin）前提。ラスターは利点薄 🔷 | × | ○ | 中 | 不採用（UI 演出のみ） |
| **RealityKit / SceneKit（3D）** | SceneKit は iOS 26 で deprecated ✅。RealityView は iOS 18+ ✅ | 無料 | `RealityView` | △ image-to-3D 経由 | × | ○ | 高 | 不採用（§5） |
| **Unity / Godot** | Unity Personal は年商・調達 $200K 未満で無料 ✅ / Godot MIT ✅ | – | × 埋め込み構成が重い 🔷 | ○ | × | – | 高 | 過剰 |

### 1.2 SpriteKit

- **メンテ状況**: Apple 公式ドキュメント上、SpriteKit に deprecated フラグはない（iOS 7.0+、visionOS はネイティブアプリでの使用非推奨）✅ [S1]。一方 SceneKit は「Deprecated at 26.0 / use RealityKit instead（WWDC25 session 288）」✅ [S2]。コミュニティでは「SpriteKit も遠くない」との懸念（Paul Hudson 🔶 [S3]）。
- **iOS 26.x の性能退行**: Apple Developer Forums で「単純なシーンで 60→40fps」「SwiftUI メニュー開閉で SKView/ARView が落ちる」が報告され、iOS 26.2 beta 3 で一旦修正→26.2.1 / 26.3 で再発、2026-03 時点で未解決（FB20287404, FB20808104, FB21914640）🔶 [S4][S5]。→ 本アプリはフルスクリーン待受で SwiftUI オーバーレイ（時計・吹き出し・設定ボタン）を重ねるため影響が大きい。
- **SwiftUI 統合**: `SpriteView(scene:transition:isPaused:preferredFramesPerSecond:options:debugOptions:shouldRender:)`、iOS 14+、`@MainActor @preconcurrency` ✅ [S6]。
- **テクスチャアトラス**: Asset Catalog の `.spriteatlas`（imageset のフォルダ。`provides-namespace`、`compression-type` を Contents.json で指定）を `SKTextureAtlas(named:)` → `textureNamed(_:)` で読む ✅ [S7]。フレームアニメは `SKAction.animate(with: textures, timePerFrame: 0.1)` ✅ [S8]。移動は `SKAction.move(to:duration:)` + `SKAction.sequence` で物理不要（標準 API 🔶）。
- **Swift 6**: SpriteKit の各クラスは非 Sendable で、`update(_:)` 等はメインスレッド呼び出し。Swift 6.2 以降の「既定 MainActor 分離（approachable concurrency）」を有効にすれば警告は大幅に減る 🔶 [S9][S10]。SpriteKit 固有の Swift 6 問題は公式情報なし（検索予算切れ、10. 参照）。

### 1.3 SwiftUI 単体

- `TimelineView(.animation)` はディスプレイのリフレッシュレート（ProMotion で最大 120Hz）で tick し、`Canvas` と組み合わせて 60/120fps の即時描画ができる 🔶 [S11][S12]。`Canvas` 内では `context.draw(context.resolve(Image("walk_0")), at: point)` でスプライトを直接描画できる（標準 API 🔶）。
- `PhaseAnimator`（iOS 17+）✅ [S13]、`keyframeAnimator`（iOS 17+）✅ [S14] は「squash & stretch」「bob」などの補間に使える。
- **フレーム切替の実装案（🔷）**:

```swift
// CharaUI/SpriteFrameView.swift（アプリ・ウィジェット共通）
struct SpriteFrameView: View {
    let state: SimState          // CharaCore が返す決定論的な状態
    let date: Date               // TimelineView の context.date / ウィジェットは entry.date
    var body: some View {
        let f = SpriteResolver.frame(for: state, at: date)   // (imageName, offset, scale, flipped)
        Image(f.imageName, bundle: .charaAssets)
            .resizable().interpolation(.none)                // ドット絵なら .none、AI 絵なら .high
            .scaleEffect(x: f.flipped ? -f.scale.width : f.scale.width, y: f.scale.height, anchor: .bottom)
            .offset(f.offset)
    }
}
// アプリ: TimelineView(.animation) { ctx in SpriteFrameView(state: sim.state(at: ctx.date), date: ctx.date) }
// ウィジェット: SpriteFrameView(state: entry.state, date: entry.date)   // 静止画
```

- **パフォーマンス上の注意（🔶/🔷）**: 1 キャラ + 影 + 数個のアイテム程度なら `Image` の差し替えで十分。多数のパーティクルを出すなら `Canvas` にまとめて描く。`Image` はシステムがデコード結果をキャッシュするが、初回表示のヒッチを避けるため起動時に全フレームを一度描画しておく（🔷）。

### 1.4 Rive

- **価格（✅ [S15][S16]）**: Free $0（3 collaborative files、**2025-10-20 以降 .riv の本番書き出し不可**）、Cadet $9/月（年払い、無制限書き出し、3 席まで）、Voyager $32/月、Enterprise $120/月（年商 $10M+）。「Runtimes remain open-source under MIT. No runtime fee. Your exports keep working forever.」（Rive ブログ ✅ [S16]）。
- **rive-ios（✅ [S17][S18][S19]）**: 最新 6.26.0（2026-09-09）、MIT、SwiftPM はバイナリ xcframework 配布、iOS 14.0+ / visionOS 1.0+ / tvOS 16.0+ / macOS 13.1+。SwiftUI は `RiveViewModel(fileName:).view()`、新 API は `Worker` + `File` の非同期構成。State Machine、データバインディング対応。
- **ウィジェットでの利用**: 公式 docs に app extension / 静的レンダリングの記載なし（✅ 記載なしを確認）。WidgetKit は SwiftUI ビューの静的アーカイブを表示するため、GPU 描画ビューは不可（🔷）。→ Rive を使う場合も **ウィジェット用にはフレーム PNG を別途書き出す**（エディタからの連番書き出し、またはアプリ内で `ImageRenderer`/スナップショット）🔷。
- **AI 画像パーツをリグする手順（✅ [S20][S21]）**: PNG を取り込み → 画像を選択し Inspector の Deform で「Mesh」を追加（透過に基づく **Auto-Trace** で輪郭自動生成、`Generate` で頂点追加）→ Bone ツール（B）でクリックして骨チェーン作成（最初が root）→ 要素を選び「Bind Bones」の + → Cmd+Shift で骨選択 → 自動ウェイト、必要なら Edit Weights / Smooth。→ 所要時間の目安: 初回で 2〜3 ボーン + 歩行ループ 1 本に 2〜4 時間（🔷）。

### 1.5 Spine

- **価格（✅ [S22]）**: Essential $69（メッシュ・ウェイト・IK 等は不可）、Professional $379（全機能）。年商 $500K 以上は Enterprise（$2,499/年〜）。すべてランタイム利用権込み。
- **spine-ios（✅ [S23][S24]）**: iOS 13 / tvOS 13 / macCatalyst 13 / visionOS 1 / macOS 10.15 / watchOS 6。SwiftPM（`spine-runtimes.git`、エディタと同じ `4.3` ブランチ）、`SpineView`（SwiftUI）/ `SpineUIView`（UIKit）。プロダクトは `SpineC`（C++ ソース）/ `SpineSwift` / `SpineiOS`。最新タグは 4.3.13 系 ✅。
- 判定: 画像パーツをメッシュ変形するなら Pro（$379）が必要で、Rive（$9/月）に対し初期費用が大きい。ウィジェット非対応は同じ。

### 1.6 Live2D Cubism

- **SDK ライセンス（✅ [S25]）**: SDK は無料で開発開始可。「個人および小規模事業者は出版ライセンス契約と支払いが免除（Expandable Application を除く）」。トラッキングソフト等は売上 2,000 万円超で契約要。小規模事業者の定義（年商 1,000 万円未満）は二次情報 🔶 [S26]（公式ページはフェッチ不可、10. 参照）。
- **エディタ**: FREE 版あり、PRO indie 約 $100/年 または $15/月、42 日間トライアル 🔶 [S26]。
- **SDK 実装**: Cubism 5.3 対応の Native サンプルは C++（Metal / OpenGL / DirectX / Vulkan）、Swift/SwiftUI 記載なし ✅ [S27]。
- **AI 画像からのモデル化**: 「See-through」（SIGGRAPH 2026、1 枚絵→23 層 PSD、隠れ部分を inpaint、2026-03 に GitHub 公開）🔶 [S28]、anysplit / live2dlayer / imagetolayers（Web サービス、PSD 出力）🔶 [S28]。ただし Live2D は「顔・上半身の擬似 3D 変形」に強く、2 頭身キャラの歩行・座り・寝るといった全身動作はパペット的で、フレームアニメの方が自然（🔷）。

### 1.7 DragonBones / Lottie / 3D / Unity・Godot

- DragonBones: 「開発者が数年応答なし、ダウンロードリンクが機能しない」🔶 [S29]。不採用。
- Lottie: lottie-ios 4.6.1（2026-06-13）、Apache-2.0 ✅ [S30][S31]。4.6.1 で `staticRendering` モード（スナップショット用）追加 ✅。AE ベクター前提でラスター AI 画像の利点が薄く、ウィジェットでは再生不可（🔷）。UI 演出（吹き出し・ハート）用に将来検討可。
- 3D: §5 参照。SceneKit deprecated ✅、RealityView は iOS 18+ ✅ [S32]。
- Unity Personal: 直近 12 か月の収益/調達 $200K 未満なら無料、Pro $2,310/年/席 ✅ [S33]。Godot: MIT ✅ [S34]。どちらも SwiftUI アプリ + WidgetKit との資産共有ができず、バイナリ・ビルド構成が過剰（🔷）。

---

## 2. ウィジェット / Live Activity 側の描画とフォントハック手順

### 2.1 前提となる公式仕様

| 項目 | 内容 | 出典 |
|---|---|---|
| リロード予算 | 頻繁に見られるウィジェットで **1 日あたり約 40〜70 回**（15〜60 分に 1 回相当）。学習期間は多め。ウィジェットのインスタンスごとに別予算 | ✅ [S35] |
| エントリ間隔 | タイムラインのエントリは **約 5 分以上**離す。複数ウィジェットのリロードは合流されることがある | ✅ [S35] |
| 予算に数えられない更新 | 本体アプリがフォアグラウンド、App Intent 実行（ボタン/トグル）、アニメーション、ロケール/Dynamic Type 変更 | ✅ [S35] |
| 拡張が動かなくても更新される表示 | `Text(date, style: .timer / .relative / .offset)`、`Text(timerInterval:pauseTime:countsDown:showsHours:)`（iOS 16+）は拡張プロセスが停止していてもライブ更新 | ✅ [S35][S36][S37] |
| Live Activity | アニメーション修飾子は無視される（`withAnimation` / `.animation`）。数値は `ContentTransition.numericText`。ContentState + 静的属性 **4KB 以内**、**最長 8 時間**（ロック画面残置 +4 時間）、画像はプレゼンテーションサイズ以下、**ネットワーク・位置情報不可**、高さ 160pt 超は切り詰め | ✅ [S38] |
| メモリ上限 | ウィジェット拡張は **30MB**（クラッシュログ `EXC_RESOURCE RESOURCE_TYPE_MEMORY (limit=30 MB)`）。Apple エンジニアの助言: 画像は `URLSession` で DL しファイル URL を渡す、`UIImage.preparingThumbnail(of:)` で縮小、エントリ数を減らす | 🔶 [S39][S40] |
| iOS 26 の表示モード | ホーム画面が「クリア/ティント」の場合 **accented** レンダリング（内容が白/ティント化、背景除去）。`@Environment(\.widgetRenderingMode)` と `.widgetAccentedRenderingMode(.fullColor / .accented / .desaturated / .accentedDesaturated)` で画像ごとに制御 | ✅ [S41] |
| StandBy / ロック画面 | ロック画面は **vibrant**（脱色モノクロ）✅ [S42]。StandBy は背景除去で拡大表示、ナイトモードは赤ティントの vibrant 🔶 [S43]。`containerBackground(for: .widget)` で背景を除去可能にする ✅ [S43] | |
| iOS 26 その他 | ウィジェット push 更新（`WidgetPushHandler`）、CarPlay（systemSmall を StandBy 風に）、visionOS、macOS メニューバー Live Activity | ✅ [S41] |

**設計への含意**: ロック画面（vibrant）とティント時ホーム画面（accented）ではキャラはシルエット/単色になる。→ 輪郭が太く 2 頭身で形が分かるデザインが有利。ホーム画面フルカラー時は `.widgetAccentedRenderingMode(.fullColor)` で色を保つ（🔷、要実機確認）。

### 2.2 静止画タイムライン（MVP の正）

1. `TimelineProvider.timeline(in:)` で **5 分刻み × 4〜6 時間分（48〜72 エントリ）** を返し `.atEnd` で再取得（予算 40〜70 回/日に対し 4〜6 回/日で十分 🔷）。
2. 各エントリは `SimState`（行動・x 座標・向き・フレーム番号・所持アイテム）を **CharaCore の決定論的シミュレーションで再計算**して詰める（§8）。
3. 本体アプリで状態が変わる操作（アイテム購入・名前変更・着せ替え）をした時だけ `WidgetCenter.shared.reloadTimelines(ofKind:)`（アプリがフォアグラウンドなら予算に数えられない ✅）。
4. メモリ: エントリの View は配信時にアーカイブされる（🔶 「エントリ数を減らせ」との助言から推測）。ウィジェット用には **小さめ imageset（キャラ高 ≤ 240px @3x 相当）** を別名で用意し、シートではなく個別 PNG を `Image(name)` で参照する（🔷）。フル解像度の 1024² PNG をウィジェットで読まない。

### 2.3 カスタムフォント + タイマーによる疑似アニメ（実験枠）

**原理**（🔶 [S44][S45][S46] / ✅ [S47]）: `Text(timerInterval:)` は拡張が動かなくても毎秒更新される唯一の「動く」テキスト。これにカスタムフォントを当て、**数字（秒）ごとに異なるグリフ（= アニメフレーム）** を表示させる。Bryce Bostwick が 2025-05 に公開 API のみで実証（「30 秒ループ、例は 8fps、同じ手法で最大 30fps」✅ [S47]）。Hackaday 記事 🔶 [S44]、解説ブログ 🔶 [S45]、GitHub サンプル（Glyphs で ttf を作り `00`〜`59` を合字で 1 グリフに）🔶 [S46]。

**推奨実装方式 = 「マスク方式」**（🔶 [S45] のコード断片 `Image("Frame1").mask(BlinkingView(offset: 0.0))` に基づく + 🔷 筆者再構成）:

- フォントは **モノクロのアウトライン TTF** で良い（カラーフォント不要）。グリフは「塗りつぶし四角」か「空」の 2 種類のみ。
- フレーム k 用フォント `CharaMask{k}` は「秒 s が `s % N == k` のときだけ四角、それ以外は空」を返す。`Image("walk_k").mask(Text(timerInterval:...).font(.custom("CharaMask\(k)", size: S)))` を N 枚 `ZStack` で重ねると、毎秒 1 枚だけが見える。
- 分・時の数字と `:` は **送り幅 0 の空グリフ**にして非表示化。秒だけを拾うには GSUB `liga` で「`:` + 十の位 + 一の位」の 3 文字合字を `s00`〜`s59` に置換する（🔷 筆者再構成。Bryce の実装は動画で要確認 [S47]）。
  - **2026-09-12 追記（実測）**: この合字案は **`Text(timerInterval:)` では効かなかった**（Xcode 26.6 / iOS 26.5 シミュレータ）。ふつうの `Text("05:24")` では効くので、タイマーの文字だけが別経路で組まれているらしい。代わりに **すべてのグリフを 1em 幅にそろえ、文字列の右端 1em だけを切り出す**方式にすると動いた（右端は必ず秒の一の位で、偶奇が秒の偶奇と一致する）。詳細は `docs/260912_spike.md` §5。
  - **2026-09-12 追記（実測）**: fontTools で作るときは **PostScript 名（name ID 6）を必ず入れる**。無いと `UIAppFonts` に書いても iOS が登録せず、`Font.custom` が黙ってシステムフォントに落ちる。`showsHours: false` にして `H:MM:SS` 形式を避ける（✅ パラメータ存在 [S37]）。
- **1fps 超**: 開始時刻を 1/M 秒ずつずらした `Text` タイマーを M 本重ねる（例 0.25s ずつ 4 本 → 4fps）。「タイマーは約 200 個まで」「複数フォントに n フレームごとに分ける」「重なりのアーティファクト防止に不透明背景」🔶 [S45]。
- Core Text は `liga` を既定で有効化するため SwiftUI 側の追加指定は不要（🔶 一般知識、要実機確認）。

**フォント生成（Claude Code で全自動化可能な Python / fontTools 案 🔷）**:

```python
# Scripts/make_mask_fonts.py  —  pip install fonttools
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.feaLib.builder import addOpenTypeFeaturesFromString

N = 4  # フレーム数（walk 4f）

def rect():
    p = TTGlyphPen(None); p.moveTo((0,0)); p.lineTo((1000,0)); p.lineTo((1000,1000)); p.lineTo((0,1000)); p.closePath(); return p.glyph()
def empty():
    return TTGlyphPen(None).glyph()

for k in range(N):
    order = [".notdef","space","colon"] + [f"d{i}" for i in range(10)] + [f"s{s:02d}" for s in range(60)]
    glyphs = {g: empty() for g in order}
    for s in range(60):
        if s % N == k: glyphs[f"s{s:02d}"] = rect()
    metrics = {g: (1000 if g.startswith("s") else 0, 0) for g in order}   # 数字・コロンは送り幅 0
    cmap = {ord(":"): "colon", ord(" "): "space", **{ord(str(i)): f"d{i}" for i in range(10)}}
    fb = FontBuilder(1000, isTTF=True)
    fb.setupGlyphOrder(order); fb.setupCharacterMap(cmap); fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics(metrics); fb.setupHorizontalHeader(ascent=1000, descent=0)
    fb.setupNameTable({"familyName": f"CharaMask{k}", "styleName": "Regular"}); fb.setupOS2(); fb.setupPost()
    fea = "feature liga {\n" + "".join(f"  sub colon d{s//10} d{s%10} by s{s:02d};\n" for s in range(60)) + "} liga;\n"
    addOpenTypeFeaturesFromString(fb.font, fea)
    fb.save(f"Packages/CharaAssets/Sources/CharaAssets/Fonts/CharaMask{k}.ttf")
```

**SwiftUI 側（🔷）**:

```swift
struct AnimatedSprite: View {
    let frames: [String]        // ["walk_0","walk_1","walk_2","walk_3"]
    let anchor: Date            // entry.date（エントリごとに再アンカー → 常に 60 分未満）
    let size: CGFloat
    var body: some View {
        ZStack {
            ForEach(frames.indices, id: \.self) { k in
                Image(frames[k], bundle: .charaAssets).resizable().frame(width: size, height: size)
                    .mask(
                        Text(timerInterval: anchor...anchor.addingTimeInterval(3600), countsDown: false, showsHours: false)
                            .font(.custom("CharaMask\(k)", size: size))
                            .frame(width: size, height: size, alignment: .bottomLeading)
                    )
            }
        }
    }
}
```

**手順まとめ**: ① `make_mask_fonts.py` で N 本の TTF 生成 → ② ウィジェット拡張ターゲットにバンドルし Info.plist `UIAppFonts` に列挙（または `CTFontManagerRegisterFontsForURL` で登録 🔶）→ ③ 上記 View をエントリに載せる → ④ 実機で 30MB・電池・Always-On（`isLuminanceReduced` ✅ [S38]）を検証 → ⑤ 問題があれば feature flag で静止画にフォールバック。

**代替: sbix カラービットマップフォント**（Apple 形式。Glyphs で PNG を `iColor 128` 等のレイヤーに配置して書き出し ✅ [S48]）。フレーム PNG をグリフに直接埋め込めるためマスク不要だが、Glyphs は有償、FontForge は sbix 非対応（COLR も未対応 🔶 [S49]）、ウィジェット内でのカスタムフォントは 30MB 問題の報告あり 🔶 [S40]。→ マスク方式を推奨。

**リスク**: Apple が塞ぐ可能性（Hackaday 「don't expect it to work forever」🔶 [S44]）、電池消費 🔶 [S44][S46]、審査は公開 API のみなので低リスク（🔷）。日本語の解説記事は検索で見つからず（10. 参照）。

### 2.4 App Group で状態共有し、アプリとウィジェットの表示を一致させる

- App Group（`group.jp.<domain>.charatime`）で `UserDefaults(suiteName:)` と共有コンテナ `containerURL(forSecurityApplicationGroupIdentifier:)` を利用 ✅ [S50]。
- 共有するのは **画像ではなく `SimSnapshot`（JSON 数百バイト）**: `userSeed`, `epoch`, `inventory`, `lastKnownContext`（バッテリー・歩数・天気のキャッシュと取得時刻）, `overrides`（ユーザー操作の履歴）。ウィジェットはこれを読み `stateAt(date:)` を評価するだけ（§8.4）。
- Live Activity を使う場合は 4KB 制限 ✅ [S38] のため `ContentState` は `behavior`, `frameIndex`, `x`, `facing` 程度に絞る。8 時間で終了するため「常設ペット」には不向きで、ロック画面ウィジェット（vibrant）の方が現実的（🔷）。

---

## 3. アセット制作パイプライン（コマンド例付き）

### 3.1 生成（画像生成 AI）

- **OpenAI Images API**（✅ [S51]）: 現行モデルは `gpt-image-2.5-sunburst`（編集精度重視）/ `gpt-image-2.5-flare`（高速）。`background: "transparent"` + `output_format: "png" | "webp"` で **透過 PNG を直接出力**。サイズは 1024×1024 / 1536×1024 / 1024×1536 / 任意（16 の倍数、縦横比 1:3〜3:1、最大 3840px）。複数参照画像を渡す edits でキャラ一貫性を確保。価格はページに記載なし。
- **Gemini API（Nano Banana 系）**（✅ [S52]）: `gemini-3.1-flash-image`（参照画像最大 14 枚 = 物体 10 + キャラ 4 + スタイル 3）、`gemini-3-pro-image`、`gemini-3.1-flash-lite-image`、旧 `gemini-2.5-flash-image`。解像度 0.5K/1K/2K/4K、縦横比 1:1〜21:9。透過出力の記載なし → rembg で除去。
- **プロンプト設計（🔷）**: ①「マスター 1 枚」を作って以後は参照画像に添付 ②ポーズは 1 枚 1 ポーズで指示（「2 頭身、太い輪郭、フラット塗り、左向き側面、歩行サイクル 4 枚中 1 枚目（接地ポーズ）、足は同じ地面ライン、単色背景 #00FF00 または透過」）③4×2 グリッドで一括生成 → `magick sheet.png -crop 4x2@ +repage +adjoin f_%d.png` で分割（🔷）。グリッド生成は縮尺の一貫性が高い反面、コマごとの位置ズレが出るため §3.3 の正規化が必須。

### 3.2 背景除去

- **rembg** v2.0.84（✅ 2026-09-08 [S53][S54]）: MIT（モデル重みは別ライセンス、商用可否は各モデルで確認 ✅）。Python 3.11–3.13。

```bash
pip install "rembg[cpu,cli]"
rembg i -m isnet-anime in.png out.png              # アニメ・イラスト向けモデル
rembg p -m isnet-anime raw/ cut/                   # フォルダ一括
rembg i -m birefnet-general -a -ae 15 in.png out.png   # 高精度（約 1GB）+ アルファマッティング
rembg i -m bria-rmbg -dc in.png out.png            # 既定モデル + 色にじみ除去
```

- 生成 AI 側で透過出力できる場合（OpenAI）は省略可。それでもエッジのハロー除去に `-dc` が有効（🔶 [S53]）。

### 3.3 トリミング → 足元基準の正規化 → 縮尺統一（ImageMagick 7）

```bash
# 1) 余白トリム（透過/単色余白）。-fuzz で近似色も余白扱い、+repage でキャンバス情報を捨てる
magick cut/walk_0.png -fuzz 2% -trim +repage tmp/walk_0.png                 # ✅ [S55]

# 2) 高さを基準値に統一（例: 立ちポーズの高さ 360px @3x を基準に、他ポーズは相対倍率で）
magick tmp/walk_0.png -resize x360 tmp/walk_0.png                            # 標準オプション 🔶

# 3) 足元基準で固定キャンバスに配置（下寄せ = -gravity South、透過パディング = -background none）
magick tmp/walk_0.png -background none -gravity South -extent 300x400 +repage norm/walk_0@3x.png   # ✅ [S55]

# 4) 右向きは左向きを反転
magick norm/walk_0@3x.png -flop norm/walk_0_r@3x.png                          # 標準オプション 🔶

# 5) @2x 派生
magick norm/walk_0@3x.png -resize 66.6667% norm/walk_0@2x.png
```

- 「座り」「寝る」は立ちより低いので **高さではなく頭のサイズ or 体幅**で縮尺を合わせる方が自然。Pillow スクリプトで「マスター立ち絵の頭幅」を測って倍率を決める（🔷）。

```python
# Scripts/normalize.py（🔷）— pip install pillow
from PIL import Image
import json, sys, pathlib

CANVAS = (300, 400)      # @3x, 幅×高さ。足元は下端から 8px 上
FOOT_MARGIN = 8

def normalize(src: pathlib.Path, dst: pathlib.Path, scale: float):
    im = Image.open(src).convert("RGBA")
    bbox = im.getbbox()                       # 透過を除いた外接矩形
    im = im.crop(bbox)
    im = im.resize((round(im.width*scale), round(im.height*scale)), Image.LANCZOS)
    canvas = Image.new("RGBA", CANVAS, (0,0,0,0))
    x = (CANVAS[0]-im.width)//2
    y = CANVAS[1]-FOOT_MARGIN-im.height       # 足元基準
    canvas.alpha_composite(im, (x, y))
    canvas.save(dst)

manifest = json.load(open("assets/manifest.json"))   # {"walk_0": {"scale": 0.35}, ...}
for name, meta in manifest.items():
    normalize(pathlib.Path(f"cut/{name}.png"), pathlib.Path(f"norm/{name}@3x.png"), meta["scale"])
```

### 3.4 スプライトシート化 / アトラス

| ツール | 費用 | CLI | 用途・所感 |
|---|---|---|---|
| ImageMagick `montage` | 無料 | ◎ | `magick montage norm/walk_*@3x.png -tile 4x -geometry +0+0 -background none -mode Concatenate walk@3x.png` ✅ [S56]。単純なグリッドシートに最適。 |
| Python Pillow | 無料 | ◎ | 上記 normalize と同じスクリプトで JSON マニフェスト（フレーム名・矩形・duration・anchor）を同時生成できる（🔷）。 |
| TexturePacker | Pro $49.99 買い切り（更新 1 年）✅ [S57]。Essential（無料）は非商用・基本機能のみだが **CLI クライアントを含む** ✅ [S58] | ◎ `/Applications/TexturePacker.app/Contents/MacOS/TexturePacker --format spritekit --sheet out.png --data out.atlasc folder` ✅ [S59] | SpriteKit `.atlasc` + Swift ヘルパー出力、@2x/@1x スケーリングバリアント、トリム、ピボット ✅ [S8]。SpriteKit を使う場合のみ。 |
| Aseprite | $19.99 ✅ [S60]（ソースからのビルドは無料）| ◎ `aseprite -b anim.ase --sheet sheet.png --data sheet.json --format json-array --sheet-type packed --split-tags --trim` ✅ [S61] | ドット絵に寄せる場合。AI 絵中心なら不要。 |

**結論（🔷）**: SwiftUI 描画なら **シートは不要**。個別 PNG を imageset として Asset Catalog に入れ、`manifest.json`（フレーム順・duration・足元アンカー）を Pillow スクリプトで生成する。SpriteKit に切り替える場合だけ `.spriteatlas`（Asset Catalog）に同じ PNG を入れる。

### 3.5 Xcode Asset Catalog

- `.spriteatlas` = imageset のフォルダ。`Contents.json` に `provides-namespace`（アトラス名を名前空間に）、`compression-type`、`on-demand-resource-tags`。`SKTextureAtlas(named:)` / `UIImage(named:)`（iOS 9+）で読める ✅ [S7]。
- **@2x/@3x**: iPhone 17 Pro は 6.3 インチ 2622×1206px・460ppi・@3x（🔶 apple.com がフェッチ不可のため二次記憶）。現行 iPhone は SE 系を除き @3x。Asset Catalog に @2x/@3x を両方入れ、App Thinning に任せる（デバイス向け資産のタグ付けで削減 ✅ [S62]）。@3x のみ配置しても動くが、@2x 端末で実行時縮小になる（🔷）。
- **圧縮**: Asset Catalog の各 imageset に Compression（Automatic / Lossless / Lossy / GPU 系）属性がある（Xcode インスペクタの一般知識 🔶。公式 doc は ASTC 言及のみ ✅ [S62]）。キャラは透過が必要なので Lossless（PNG）または Automatic。
- SwiftPM パッケージのリソースとして `.xcassets` を置くと `Image("name", bundle: .module)` で参照可（Xcode 12+ の標準機能 🔶）。`.spriteatlas` をパッケージ内に置けるかは未確認（10. 参照）。

### 3.6 Claude Code で自動化する前提の CLI 選定

- 採用: `magick`（brew）、`rembg`、Python（Pillow / fontTools）、`ffmpeg`（§6）、`xcodegen`。GUI 必須ツール（Glyphs, Aseprite の GUI, TexturePacker GUI）は避ける。
- `Makefile` の `make assets` = 生成 API 呼び出し（任意）→ rembg → normalize.py → manifest.json → Asset Catalog の `Contents.json` 生成（imageset ごとに `{"images":[{"idiom":"universal","scale":"2x","filename":...},{"scale":"3x",...}]}`）→ make_mask_fonts.py。すべて冪等にして差分だけ再生成（🔷）。

---

## 4. パーツ分割 + 骨アニメに AI 画像を使う場合

- **パーツ個別生成のプロンプト**は縮尺・塗り・線幅が揃わず実用性が低い（🔷）。現実的なのは「完成キャラ 1 枚 → AI レイヤー分割」。
- **AI レイヤー分割ツール**:
  - LayerDiffuse（lllyasviel、「latent transparency」で透過レイヤー生成。Runware 等の API 経由でも可）🔶 [S63][S64]
  - See-through（SIGGRAPH 2026、1 枚絵 → 23 層 PSD、前髪/後ろ髪分離、顔 7 パーツ、隠れ領域 inpaint。arXiv 2026-02、GitHub 2026-03）🔶 [S28]
  - anysplit / live2dlayer / imagetolayers（Web サービス、Live2D/Spine 向け PSD 出力）🔶 [S28]（価格はフェッチ不可）
  - Krita AI Diffusion プラグイン（GPL-3.0、ComfyUI バックエンド、ローカルは NVIDIA 6GB VRAM 推奨、macOS 14+ の MPS 対応だが CPU は「very slow」、クラウド生成あり）✅ [S65]。インペイント/領域生成に有用、レイヤー分割は別プラグイン。
  - Photoshop 生成レイヤー / Photoroom API / Procreate: 今回は未検証（10. 参照）。
- **Rive での簡易リグ手順**: §1.4 参照（Mesh → Auto-Trace → Bone → Bind → Auto-Weights ✅ [S20][S21]）。2 頭身キャラなら **root（腰）→ 胴 → 頭、+ 左右脚 2 本** の 3〜5 ボーンで「歩く（脚の前後 + 体の上下）」「座る（脚を折る）」「寝る（全体回転）」が作れる（🔷）。所要: 初回 半日、2 回目以降 2〜3 時間（🔷）。
- **判断**: MVP ではやらない。キャラデザインが固定した後、アプリ内フルスクリーン待受の「なめらか版」として Rive を検討。ウィジェット向けには Rive からフレーム PNG を書き出して §3 パイプラインに合流させる（🔷）。

---

## 5. 3D ルート

| サービス | 価格・条件 | リグ/アニメ | 出力 | 出典 |
|---|---|---|---|---|
| Meshy | Free 100 クレジット/月（出力は CC BY 4.0）、Pro 1,000 クレジット/月（私有資産、API）✅。Pro $20/月・Premium $40・Ultra $100 🔶。画像→3D は 20 クレジット 🔶。オートリグ・アニメは 0 クレジット 🔶 | 人型オートリグ + アニメプリセット | fbx / obj / usdz / glb / stl / blend ✅ | [S66][S67] |
| Tripo | API は 1 クレジット = $0.01、画像→3D 20〜30、Auto Rig 25、アニメリターゲット 10 クレジット ✅。消費者向け Free 300 クレジット/月は非商用 🔶 | Auto Rigging + モーションライブラリ | GLB / FBX / OBJ / STL / USDZ 🔶 | [S68][S69] |
| Rodin（Hyper3D） | Free あり、Creator $30/月〜 🔶。T/A ポーズ生成 🔶 | ポーズ指定のみ | – | [S70] |
| Hunyuan3D-2 / 2.1（Tencent） | **Tencent Hunyuan 3D 2.0 Community License**（EU・英国・韓国は対象外、MAU 100 万超は別途契約、商用可）✅。形状 6GB VRAM / 形状+テクスチャ 16GB ✅。macOS 対応、MLX 移植で Apple Silicon 実行可（形状のみ、2〜5 分）🔶 | なし（別途 Blender/Mixamo 等） | glb 等 | [S71][S72] |
| Google | image-to-3D 製品を今回確認できず（検索予算切れ） | – | – | 10. 参照 |

- **iOS 表示**: `RealityView`（iOS 18+ ✅ [S32]）で `ModelEntity(named:)` を読み、USDZ のスケルタルアニメを `availableAnimations` → `playAnimation` で再生（標準 API 🔶）。SceneKit は deprecated ✅ [S2]。
- **MacBook Air での作業**: クラウド（Meshy/Tripo）なら問題なし。ローカル Hunyuan3D は 16GB 以上のユニファイドメモリ推奨・低速（🔷）。
- **トレードオフ（🔷）**: 3D は「トゥーンシェーディングで 2D 風に見せる」追加工数、リグ後の破綻修正、USDZ 変換、そしてウィジェットでは結局 PNG 化が必要。ガラケーの 2D ドット/セル画の質感を再現するには 2D が自然。3D を使うなら「Blender でターンテーブル/歩行を PNG 連番にレンダリングして §3 に合流」が唯一の合理的用途。

---

## 6. 動画→スプライト

- **Viggle**（✅ [S73]）: Free $0（0 クレジット）、Pro $7.99/月（80 クレジット、透かしなし）、Live $15.99/月（200）、Max $63.99/月（800）。API は約 $0.01/秒 🔶。グリーンスクリーン機能あり 🔶 [S74]。商用条件は価格ページに記載なし（要 ToS 確認）。
- Kling / Veo: 今回未検証（10. 参照）。共通手順は「単色グリーン背景で生成 → ffmpeg でクロマキー」。
- **ffmpeg `chromakey`**（✅ [S75]）: `color`（RGB 名 or `yuv=1` で YUV 16 進）、`similarity`（0.01 = 完全一致のみ〜1.0 = 全部）、`blend`（0 = 二値、大きいほど半透明）。`colorkey` は RGB 空間版。

```bash
# 抽出 + クロマキー + スピル除去 + 縮小（8fps、透過 PNG 連番）   🔷（標準フィルタの組み合わせ）
ffmpeg -i viggle.mp4 -vf "fps=8,chromakey=0x00FF00:0.25:0.08,despill=type=green,scale=-1:400:flags=lanczos" \
       -start_number 0 frames/f_%03d.png

# 区間切り出し（ループ候補 1.5 秒）と間引き（3 枚に 1 枚）
ffmpeg -ss 2.0 -t 1.5 -i viggle.mp4 -vf "select='not(mod(n,3))',chromakey=green:0.25:0.08" -fps_mode vfr loop/f_%03d.png

# 確認用 GIF / APNG ループ
ffmpeg -framerate 8 -i loop/f_%03d.png -plays 0 preview.apng
```

- **品質上の注意（🔷）**: 動画生成はフレーム間で輪郭・縮尺がゆらぐ（小さく表示すれば目立たない）、モーションブラーが残る、緑のスピルは `despill` で軽減、ループ端は「最初と最後が同ポーズの区間」を選ぶか 1 フレームをクロスフェード。歩行を「左向きのみ・4 枚」に間引いてから §3.3 で足元正規化する。

---

## 7. 最小アニメセットと procedural テクニック

### 7.1 実例

- Shimeji: 古典レイアウトは `shime1.png`〜`shime46.png` の 46 枚（128×128）+ `actions.xml` / `behaviors.xml` 🔶 [S76]。歩行は stand 1 枚 + walk 2 枚の 3 枚ループ（`shime1〜3`）🔶 [S77]。座る・寝る・落ちる・登る・つかまれる等に残りを配分（内訳は 🔷）。
- Tamagotchi: LCD 世代は 1 キャラ数枚（idle の 2 コマ跳ね）で成立。Spriters Resource にシート収録 🔶 [S78]（詳細内訳は未確認）。
- 一般目安: idle 2〜4、walk 4〜6（小サイズは 4）、run 6〜8、jump 3〜5。「フレーム数よりタイミング（可変尺）」🔶 [S79]。

### 7.2 提案する最小セット（合計 13 枚、左向きのみ）

| 状態 | 枚数 | 尺（ms） | 補足 |
|---|---|---|---|
| idle | 2 | 600 / 600 | 呼吸（2 枚目は縦 3% 縮み）。目パチは別レイヤー（目閉じ 1 枚）で 3〜6 秒に 1 回 |
| walk | 4 | 150 each | 接地・通過・接地・通過。右向きは反転 |
| sit | 1 | – | 座り中は bob（sin）で上下 1〜2px |
| sleep | 2 | 1000 / 1000 | 「Zzz」は別テキスト/画像 |
| happy | 2 | 120 each | 跳ねはコードで offset。ハート/音符は別エフェクト |
| react（アイテム反応） | 2 | 200 each | ミラーボール: キャラはこの 2 枚を交互 + 画面全体の色相回転（Canvas） |

### 7.3 少ないフレームでリッチに見せる（SwiftUI 実装の当てはめ 🔷）

- **squash & stretch**: 着地/跳ねで `scaleEffect(x: 1.08, y: 0.92, anchor: .bottom)` → `spring` で戻す。
- **bob**: `offset(y: sin(t * 2π / 1.2) * 2)`。歩行時は歩幅に同期。
- **easing**: 移動は `TimelineView` の t から `easeInOut` を自前計算（位置は決定論的関数にする）。
- **影の分離**: 楕円 `Ellipse().fill(.black.opacity(0.2))` をキャラの下に別描画し、ジャンプ時は縮小。
- **吹き出し・エフェクトの分離**: `PhaseAnimator` で「ポン」と出す。キャラ絵に描き込まない。
- **パーティクル**: `Canvas` + `TimelineView(.animation)` でミラーボールの光点・ハート。
- **向き**: 左向き素材のみ、右向きは `scaleEffect(x: -1)`。
- **目パチ/口パク**: 顔だけの差分小画像を重ねる（AI 生成時に「目閉じ版」を edits で作る）。

---

## 8. 自律行動の設計

### 8.1 方式比較

| 方式 | 長所 | 短所 | 本件での評価 |
|---|---|---|---|
| FSM | 単純・デバッグ容易 | 状態数増で遷移が爆発 | ポーズ（idle/walk/sit/sleep/happy/react）の管理に最適 |
| ビヘイビアツリー | 階層化・再利用 | この規模では過剰 | 不要 |
| ユーティリティ AI | 文脈スコアで自然な選択、拡張容易 | 調整に感覚が要る | 「次に何をするか」の選択に最適（重み付き乱数） |

出典: GameAIPro「Building Utility Decisions into Your Existing Behavior Tree」🔶 [S80]、Nez docs（FSM/BT/GOAP/Utility 比較）🔶 [S81]、arXiv「Comparison between BT and FSM」🔶 [S82]。Shimeji の `behaviors.xml` も「条件 + Frequency（頻度重み）」で次行動を抽選しており、同型（🔷）。

**推奨**: `Behavior`（FSM の状態）× `Utility`（スコア表）× 決定論 RNG。

### 8.2 iOS で取れる文脈と反映例

| 文脈 | 取得手段 | ウィジェット拡張から直接取れるか | 行動への反映例 |
|---|---|---|---|
| 時間帯 | `Calendar` | ○ | 23〜6 時は sleep 重み 0.8、朝は伸び（happy）|
| バッテリー残量 | `UIDevice.batteryLevel`（本体アプリ）| △ 未確認 → 本体で取得し App Group に保存（🔷） | 20% 未満で「ぐったり」、充電中は「元気」 |
| 歩数 | HealthKit（`HKStatisticsQuery`）| 公式 doc に拡張での可否記載なし ✅（記載なしを確認 [S83]）→ 本体アプリで取得しキャッシュ（🔶） | 5,000 歩超で walk 頻度↑、happy |
| 天気 | WeatherKit（50 万コール/月無料、要 Apple Weather 表記 ✅ [S84]） | ウィジェットはネットワーク可、Live Activity は不可 ✅ [S38] | 雨: 傘アイテム/室内で sit、晴れ: walk |
| カレンダー | EventKit | 本体で取得しキャッシュ（🔷） | 予定 10 分前にソワソワ（react） |
| 通知/着信 | 不可（ガラケー版は着信で吹き出し ✅ [S85]） | – | 代替: 本体アプリ起動時の挨拶 |

### 8.3 決定論的シミュレーション（アプリとウィジェットで同じ行動を再現）

- **時間を 5 分スロットに離散化**し、スロットごとに「マクロ行動」を抽選、スロット内の「ミクロ動き」（歩行経路・bob）は経過秒数の決定論的関数にする。ウィジェットのエントリ日時でもアプリの 60fps でも同じ `stateAt(date:)` を呼ぶ。
- **RNG**: SplitMix64（定数は Vigna の標準実装 ✅ 一般知識）。GameplayKit の `GKMersenneTwisterRandomSource(seed:)` も deprecated ではなく利用可 ✅ [S86] だが、フレームワーク依存を避けて純 Swift にする。

```swift
// CharaCore/SplitMix64.swift
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

public struct SimContext: Codable, Sendable {  // App Group に保存されるキャッシュ
    public var hour: Int; public var battery: Double?; public var steps: Int?
    public var weather: Weather?; public var items: [ItemID]
}

public enum Behavior: String, Codable, Sendable { case idle, walk, sit, sleep, happy, react }

public struct SimState: Codable, Sendable {
    public var behavior: Behavior; public var x: Double; public var facing: Facing
    public var slotStart: Date; public var frameIndex: Int
}

public enum Simulation {
    static let slot: TimeInterval = 300
    public static func stateAt(_ date: Date, seed userSeed: UInt64, ctx: SimContext, prev: SimState?) -> SimState {
        let slotIndex = UInt64(date.timeIntervalSince1970 / slot)
        var rng = SplitMix64(seed: userSeed ^ (slotIndex &* 0x9E37_79B9_7F4A_7C15))
        let behavior = Utility.pick(ctx: ctx, prev: prev, rng: &rng)        // 重み付き抽選
        let t = date.timeIntervalSince1970 - Double(slotIndex) * slot         // スロット内経過秒
        return Kinematics.integrate(behavior, from: prev, t: t, rng: &rng)    // 経路・向き・フレーム番号
    }
}
```

- `Utility.pick` の例（🔷）: `score(sleep) = isNight ? 0.8 : 0.05 + (battery < 0.2 ? 0.4 : 0)`、`score(walk) = 0.4 + min(steps/10000, 0.3)`、`score(react) = items.contains(.mirrorBall) ? 0.9 : 0`、`score(sit) = 0.3`、`score(idle) = 0.3`、`score(happy) = isMorning ? 0.3 : 0.1`。前スロットと同じ行動に -0.1 して単調さを避ける。
- **一致の担保**: ウィジェットは `SimSnapshot`（userSeed + ctx）を App Group から読み、各エントリ日時で `stateAt` を評価。本体アプリは `TimelineView` の `context.date` で同じ関数を毎フレーム評価（prev をスロット境界でのみ更新）。ctx（バッテリー等）が変わったら本体が snapshot を更新して `reloadTimelines` → 以後のスロットだけが変わる。
- **テスト**: `XCTest` で「同じ seed・ctx・date → 同じ SimState」「連続 1 週間分の遷移に不正がない」をゴールデンテスト化（🔷）。

---

## 9. 推奨構成とプロジェクト構成案

### 9.1 MVP（何を使い、どう作るか）

1. **描画**: SwiftUI 単体。フルスクリーン待受は `TimelineView(.animation)` + `Image` 差し替え + `Canvas`（影・パーティクル）。SpriteKit は使わない（iOS 26.x 退行 🔶 と将来性 🔶）。
2. **アセット**: OpenAI 画像 API（透過 PNG ✅）または Gemini 3.1 Flash Image（参照 14 枚 ✅）で 13 枚 + 顔差分 → rembg → normalize.py → Asset Catalog（@2x/@3x）+ manifest.json。ウィジェット用は縮小版 imageset を別名で持つ。
3. **ウィジェット**: 5 分刻み静止画タイムライン（48〜72 エントリ、`.atEnd`）。accented/vibrant を考慮したシルエット設計。フォントハックは `FeatureFlags.widgetPseudoAnimation` の裏で実験。
4. **ロジック**: CharaCore（純 Swift、UI 非依存）に FSM + Utility + SplitMix64 の決定論シミュレーション。App Group に `SimSnapshot`。
5. **文脈**: 時刻（即）、バッテリー（本体で取得）、天気（WeatherKit、1 日数回）、歩数（HealthKit、本体でバックグラウンド配信 → キャッシュ）。

### 9.2 将来の拡張

- アプリ内リッチ化: Rive（Cadet $9/月、MIT ランタイム）で歩行・表情を State Machine 化。ウィジェット用は Rive からフレーム書き出し。
- 物理・パーティクルが必要になったら SpriteKit（`SpriteView`）を「フルスクリーン待受のみ」に限定して導入（iOS 26.x 退行の解消を確認してから）。
- ロック画面/StandBy 専用シルエットアセット、Live Activity（イベント時のみ 8 時間）、ウィジェット push 更新（複数端末同期 ✅ [S41]）。
- 3D は採用しない。

### 9.3 Xcode プロジェクト構成案（XcodeGen 2.46.0 ✅ [S87] + ローカル SwiftPM）

```
CharaTime/
├── project.yml                     # XcodeGen
├── App/                            # CharaTime (iOS app target)
├── Widget/                         # CharaTimeWidget (WidgetKit extension)
├── Packages/
│   ├── CharaCore/                  # シミュレーション・RNG・状態・Utility（UI 非依存、テスト充実）
│   ├── CharaAssets/                # Assets.xcassets（@2x/@3x）・manifest.json・Fonts/CharaMask*.ttf
│   └── CharaUI/                    # SwiftUI 描画（SpriteFrameView / SceneView / エフェクト）— App と Widget で共有
├── Scripts/                        # generate.py / normalize.py / make_mask_fonts.py / build_xcassets.py
└── docs/research/
```

```yaml
# project.yml（🔷 ドラフト）
name: CharaTime
options:
  bundleIdPrefix: jp.example.charatime
  deploymentTarget: { iOS: "26.0" }
settings:
  base:
    SWIFT_VERSION: "6.0"
    SWIFT_STRICT_CONCURRENCY: complete
    SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor      # Swift 6.2+ の既定 MainActor 分離（設定名は要確認 🔶）
packages:
  CharaCore:   { path: Packages/CharaCore }
  CharaAssets: { path: Packages/CharaAssets }
  CharaUI:     { path: Packages/CharaUI }
targets:
  CharaTime:
    type: application
    platform: iOS
    sources: [App]
    dependencies:
      - package: CharaCore
      - package: CharaAssets
      - package: CharaUI
      - target: CharaTimeWidget
    entitlements:
      path: App/CharaTime.entitlements
      properties:
        com.apple.security.application-groups: [group.jp.example.charatime]
        com.apple.developer.healthkit: true
        com.apple.developer.weatherkit: true
  CharaTimeWidget:
    type: app-extension
    platform: iOS
    sources: [Widget]
    dependencies:
      - package: CharaCore
      - package: CharaAssets
      - package: CharaUI
    info:
      path: Widget/Info.plist
      properties:
        NSExtension: { NSExtensionPointIdentifier: com.apple.widgetkit-extension }
        UIAppFonts: [CharaMask0.ttf, CharaMask1.ttf, CharaMask2.ttf, CharaMask3.ttf]
    entitlements:
      path: Widget/CharaTimeWidget.entitlements
      properties:
        com.apple.security.application-groups: [group.jp.example.charatime]
```

- CharaCore の `Package.swift` は `swiftLanguageModes: [.v6]`、`platforms: [.iOS(.v26)]`、依存なし。CharaUI は CharaCore + CharaAssets に依存。Widget 拡張は 30MB 制約のため CharaUI の「軽量ビュー」だけを使い、`Canvas` パーティクル等は `#if !WIDGET` で除外（🔷）。
- XcodeGen はローカル/リモート Swift Package と package traits に対応 ✅ [S87][S88]。Xcode 26 固有の問題は未確認（10. 参照）。

---

## 10. 未確認事項（要フォローアップ）

1. **HealthKit をウィジェット拡張から直接クエリできるか**: 公式 doc に記載なし（HKHealthStore / Setting up HealthKit / framework root を確認 ✅ 記載なし）。実機で検証。安全策は本体アプリで取得 → App Group。
2. **フォントハックの「秒だけを拾う」合字設計**: 本レポートの `:`+2 桁合字案は筆者再構成（🔷）。Bryce Bostwick の動画（YouTube `NdJ_y1c_j_I`）とリポジトリで実装を照合すること。`UIAppFonts` がウィジェット拡張の Info.plist で有効かも実機確認。
3. **iOS 26.5 以降で SpriteKit + SwiftUI の fps 退行が解消したか**（フォーラムは 2026-03 時点で未解決 🔶）。
4. **Rive / Lottie がウィジェットで明示的に非対応と書かれた一次情報**: 見つからず（docs に extension 記載なし）。設計上不可と判断（🔷）。
5. **Live2D の小規模事業者定義（年商 1,000 万円未満）と PRO indie 価格**: live2d.com がフェッチ不可のため二次情報のみ 🔶。
6. **Meshy の各プラン価格・リグのクレジット消費**: 公式ページは一部のみ取得（Free 100 クレジット・Pro 1,000 クレジット・出力形式 ✅）。$20/$40/$100 と「リグ 0 クレジット」は比較サイト 🔶。
7. **iPhone 17 Pro の画面仕様**: apple.com がフェッチ不可。2622×1206 / 460ppi / @3x は二次記憶 🔶。
8. **Google の image-to-3D 製品、Kling / Veo の透過・ループ機能、Photoroom API 価格、Photoshop 生成レイヤー、anysplit / See-through の価格・ライセンス**: 検索予算切れ・ドメインブロックで未確認。
9. **Asset Catalog の圧縮オプション（Automatic / Lossless / Lossy）と `.spriteatlas` の SwiftPM パッケージ内配置可否**: 公式 doc で未確認 🔷。
10. **StandBy の厳密なレンダリングモード**（昼はフルカラー、夜は赤 vibrant という理解 🔶）: WWDC23 セッション要約の粒度が粗い。実機確認。
11. **Swift 6.3 / Xcode 26.6 の `SWIFT_DEFAULT_ACTOR_ISOLATION` 設定名**: Xcode 26.6 リリースノートには言及なし ✅（Swift 6.3・iOS 26.5 SDK・macOS 26.2 以上は確認 ✅ [S89]）。
12. **日本語の一次解説**: 「ウィジェット + カスタムフォント + timerInterval」の日本語記事は検索で見つからず。KDDI の「ケータイパートナー（β）→ au one キャラタイム」の公式リリースは取得 ✅ [S85]（キャラが着信で吹き出し表示、ライフタイプ 525 円など。ミラーボール等のアイテム仕様は未確認）。

---

## 11. 出典一覧（確認日: すべて 2026-09-10）

| ID | 出典 | 種別 |
|---|---|---|
| S1 | https://developer.apple.com/documentation/spritekit （JSON: /tutorials/data/documentation/spritekit.json） | ✅ |
| S2 | https://developer.apple.com/documentation/scenekit （JSON。「Deprecated at 26.0, use RealityKit」） | ✅ |
| S3 | https://x.com/twostraws/status/1935675784150052921 | 🔶 |
| S4 | https://developer.apple.com/forums/thread/800952 （SpriteKit framerate drop on iOS 26.0） | 🔶 |
| S5 | https://developer.apple.com/forums/thread/804973 （SpriteKit/RealityKit + SwiftUI regression） | 🔶 |
| S6 | https://developer.apple.com/documentation/spritekit/spriteview （JSON） | ✅ |
| S7 | https://developer.apple.com/library/archive/documentation/Xcode/Reference/xcode_ref-Asset_Catalog_Format/SpriteAtlasType.html | ✅ |
| S8 | https://www.codeandweb.com/texturepacker/tutorials/spritekit-textureatlases-with-swift | ✅（ベンダー公式） |
| S9 | https://blakecrosley.com/blog/swift-6-2-concurrency-in-practice | 🔶 |
| S10 | https://www.hackingwithswift.com/swift/6.0/concurrency | 🔶 |
| S11 | https://swiftcrafted.dev/article/swiftui-canvas-timelineview-custom-drawings-animated-graphics-ios-26 | 🔶 |
| S12 | https://swiftui-lab.com/swiftui-animations-part5/ | 🔶 |
| S13 | https://developer.apple.com/documentation/swiftui/phaseanimator （JSON） | ✅ |
| S14 | https://developer.apple.com/documentation/swiftui/view/keyframeanimator(initialvalue:repeating:content:keyframes:) （JSON） | ✅ |
| S15 | https://rive.app/pricing | ✅ |
| S16 | https://rive.app/blog/rive-s-new-9-mo-plan （2025-10-20） | ✅ |
| S17 | https://github.com/rive-app/rive-ios （MIT） | ✅ |
| S18 | https://raw.githubusercontent.com/rive-app/rive-ios/main/Package.swift / https://api.github.com/repos/rive-app/rive-ios/releases/latest （6.26.0, 2026-09-09） | ✅ |
| S19 | https://rive.app/docs/runtimes/apple/apple | ✅ |
| S20 | https://rive.app/docs/editor/manipulating-shapes/bones | ✅ |
| S21 | https://rive.app/docs/editor/manipulating-shapes/meshes | ✅ |
| S22 | https://esotericsoftware.com/spine-purchase | ✅ |
| S23 | https://en.esotericsoftware.com/spine-ios | ✅ |
| S24 | https://raw.githubusercontent.com/EsotericSoftware/spine-runtimes/4.3/Package.swift / https://api.github.com/repos/EsotericSoftware/spine-runtimes/tags | ✅ |
| S25 | https://www.live2d.com/en/sdk/license/ | ✅ |
| S26 | https://kudos.tv/blogs/stream-blog/live2d | 🔶 |
| S27 | https://github.com/Live2D/CubismNativeSamples | ✅ |
| S28 | https://lilting.ch/en/articles/see-through-anime-layer-decomposition ／ https://www.anysplit.net/faq.html ／ https://live2dlayer.com/ ／ https://www.imagetolayers.com/character-to-layers/live2d （検索スニペットのみ） | 🔶 |
| S29 | https://github.com/DragonBones/dragonbones.github.io/issues/26 ／ https://alternativeto.net/software/dragonbones/about | 🔶 |
| S30 | https://github.com/airbnb/lottie-ios （Apache-2.0） | ✅ |
| S31 | https://api.github.com/repos/airbnb/lottie-ios/releases/latest （4.6.1, 2026-06-13） | ✅ |
| S32 | https://developer.apple.com/documentation/realitykit/realityview （JSON） | ✅ |
| S33 | https://unity.com/pricing | ✅ |
| S34 | https://godotengine.org/license/ | ✅ |
| S35 | https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date （JSON） | ✅ |
| S36 | https://developer.apple.com/documentation/widgetkit/displaying-dynamic-dates （JSON） | ✅ |
| S37 | https://developer.apple.com/documentation/swiftui/text/init(timerinterval:pausetime:countsdown:showshours:) （JSON） | ✅ |
| S38 | https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities （JSON） | ✅ |
| S39 | https://developer.apple.com/forums/thread/713561 （limit=30 MB） | 🔶 |
| S40 | https://github.com/feedback-assistant/reports/issues/177 ／ https://developer.apple.com/forums/thread/733347 ／ https://developer.apple.com/forums/thread/650204 | 🔶 |
| S41 | https://developer.apple.com/videos/play/wwdc2025/278/ （What's new in widgets） | ✅ |
| S42 | https://developer.apple.com/documentation/widgetkit/widgetrenderingmode （JSON） | ✅ |
| S43 | https://developer.apple.com/videos/play/wwdc2023/10027/ （Bring widgets to new places） | ✅（要約は粗い） |
| S44 | https://hackaday.com/2025/05/17/animated-widgets-on-apple-devices-via-a-neat-backdoor/ | 🔶 |
| S45 | https://blog.andreszenteno.com/notes/apples-widget-backdoor | 🔶 |
| S46 | https://github.com/liudhzhyym/WidgetAnimationSample （検索スニペット。直接フェッチは 404） | 🔶 |
| S47 | https://github.com/brycebostwick/WidgetAnimation ／ https://bryce.co/widget-animations/ ／ https://www.youtube.com/watch?v=NdJ_y1c_j_I | ✅ |
| S48 | https://glyphsapp.com/learn/creating-an-apple-color-font ／ https://handbook.glyphsapp.com/color-fonts/sbix/ | ✅（ベンダー） |
| S49 | https://github.com/fontforge/fontforge/issues/677 ／ https://blog.fontlab.com/2026/05/03/color-fonts-in-2026/ | 🔶 |
| S50 | https://developer.apple.com/documentation/xcode/configuring-app-groups （JSON） | ✅ |
| S51 | https://developers.openai.com/api/docs/guides/image-generation | ✅ |
| S52 | https://ai.google.dev/gemini-api/docs/image-generation | ✅ |
| S53 | https://github.com/danielgatis/rembg | ✅ |
| S54 | https://api.github.com/repos/danielgatis/rembg/releases/latest （v2.0.84, 2026-09-08）／ https://knightli.com/en/2026/04/19/rembg-background-removal-notes/ | ✅ / 🔶 |
| S55 | https://usage.imagemagick.org/crop/ | ✅ |
| S56 | https://usage.imagemagick.org/montage/ | ✅ |
| S57 | https://www.codeandweb.com/store/texturepacker-single | ✅ |
| S58 | https://www.codeandweb.com/texturepacker/licenses-comparison | ✅ |
| S59 | https://www.codeandweb.com/texturepacker/documentation/commandline | ✅ |
| S60 | https://dacap.itch.io/aseprite | ✅ |
| S61 | https://www.aseprite.org/docs/cli/ | ✅ |
| S62 | https://developer.apple.com/documentation/xcode/doing-basic-optimization-to-reduce-your-app-s-size （JSON） | ✅ |
| S63 | https://github.com/lllyasviel/LayerDiffuse ／ https://arxiv.org/abs/2402.17113 | 🔶 |
| S64 | https://runware.ai/blog/introducing-layerdiffuse-generate-images-with-built-in-transparency-in-one-step | 🔶 |
| S65 | https://github.com/Acly/krita-ai-diffusion | ✅ |
| S66 | https://www.meshy.ai/pricing （部分取得） | ✅（部分） |
| S67 | https://3dcreatorhub.com/meshy-ai-pricing ／ https://meshyiai.com/pricing/ | 🔶 |
| S68 | https://developers.tripo3d.ai/en/pricing | ✅ |
| S69 | https://lorphic.com/tripo-ai-pricing-3d-models-full-guide-and-review/ ／ https://www.tripo3d.ai/features/image-to-3d-model | 🔶 |
| S70 | https://www.therundown.ai/tools/rodin ／ https://www.jaiportal.com/model/hyper3d-rodin-v2 | 🔶 |
| S71 | https://github.com/Tencent-Hunyuan/Hunyuan3D-2 ／ LICENSE（Community License, 2025-01-21） | ✅ |
| S72 | https://www.tencentcloud.com/techpedia/146529 ／ https://codersera.com/blog/how-to-install-and-run-hunyuan3d-2-on-macos-a-step-by-step-guide/ | 🔶 |
| S73 | https://viggle.ai/pricing | ✅ |
| S74 | https://viggle.ai/tools/ai-green-screen | 🔶 |
| S75 | https://ayosec.github.io/ffmpeg-filters-docs/7.1/Filters/Video/chromakey.html （FFmpeg 公式フィルタ文書のミラー） | ✅ |
| S76 | https://openpets.dev/alternatives/shimeji ／ https://shimejimascot.gumroad.com/l/yuri-briar | 🔶 |
| S77 | https://kilkakon.com/shimeji/affordances.php | 🔶 |
| S78 | https://www.spriters-resource.com/lcd_handhelds/tamagotchioriginalp1p2/ | 🔶 |
| S79 | https://www.sprite-ai.art/blog/sprite-animation-frames | 🔶 |
| S80 | https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter10_Building_Utility_Decisions_into_Your_Existing_Behavior_Tree.pdf | 🔶 |
| S81 | https://anshuman-kumar.gitbook.io/nez-doc/ai-fsm-behavior-tree-goap-utility-ai | 🔶 |
| S82 | https://arxiv.org/abs/2405.16137 | 🔶 |
| S83 | https://developer.apple.com/documentation/healthkit/hkhealthstore ／ /healthkit/setting-up-healthkit ／ /healthkit （JSON。拡張の可否は記載なし） | ✅（記載なし） |
| S84 | https://developer.apple.com/weatherkit/get-started/ | ✅ |
| S85 | https://www.kddi.com/corporate/news_release/2011/0413/besshi.html （ケータイパートナー終了 / au one キャラタイム） | ✅ |
| S86 | https://developer.apple.com/documentation/gameplaykit （JSON。非推奨なし） | ✅ |
| S87 | https://api.github.com/repos/yonaskolb/XcodeGen/releases/latest （2.46.0, 2026-07-16） | ✅ |
| S88 | https://github.com/yonaskolb/XcodeGen/pull/624 ／ https://xcodegen.com/ | 🔶 |
| S89 | https://developer.apple.com/documentation/xcode-release-notes/xcode-26_6-release-notes （JSON。Swift 6.3 / iOS 26.5 SDK / macOS 26.2+） | ✅ |
| S90 | https://developer.apple.com/videos/play/wwdc2025/288/ （Bring your SceneKit project to RealityKit） | ✅ |
| S91 | https://dev.classmethod.jp/en/articles/ios27-xcode27-migration-preparation-guide/ （SceneKit 非推奨の整理） | 🔶 |
| S92 | https://www.itmedia.co.jp/mobile/articles/1104/13/news089.html （au one キャラタイム） | 🔶 |
