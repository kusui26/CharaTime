import Foundation

/// 一度だけ確かめること（プラン §9 Phase 3 の 3-E の表と、Gate 3 の「決めたとおりに落ちる」）。
///
/// 見るもの（期待）は、描画の段の梯子（3-C ⑤）どおりに書く。まばたきを見る項目は、切の日（2 日目）に
/// 置かない。確かめていない OS（D-22）は、上げると実機に入らなくなるので試さない（テストで守る）。
public extension WeekRunPlan {

    static let checks: [WeekRunCheckItem] = firstDay + secondDay + thirdDay + laterDays

    private static let firstDay = [
        WeekRunCheckItem(id: "afterInstall", day: 1, title: "入れ直した直後",
                         how: "この版を入れたら、ホーム画面の大を見る",
                         expected: "まばたき・寝息が動いている"),
        WeekRunCheckItem(id: "entrySwitch", day: 1, title: "5 分ごとの切り替わり",
                         how: "0 分・5 分・10 分…の切り替わりを 1 回見る",
                         expected: "2 秒ほどのうちに、新しい居場所か姿に変わる"),
        WeekRunCheckItem(id: "afterUnlock", day: 1, title: "ロックを解除したあと",
                         how: "画面を消して少し置き、ロックを解除してすぐに見る",
                         expected: "まばたき・寝息がすぐに動き出す"),
    ]

    /// 切の日。まばたきに関わらないことを見る。
    private static let secondDay = [
        WeekRunCheckItem(id: "transparent", day: 2, title: "透過背景（ライト・ダーク）",
                         how: "コントロールセンターでダークモードを入・切して、それぞれ見る",
                         expected: "大の中の壁紙が、外とずれていない"),
        WeekRunCheckItem(id: "standByNight", day: 2, title: "スタンバイ（夜）",
                         how: "暗い部屋で、充電しながら横向きに立ててロックする",
                         expected: "赤い表示で、キャラが見分けられる（動きは止まっていてよい）"),
    ]

    private static let thirdDay = [
        WeekRunCheckItem(id: "afterKill", day: 3, title: "アプリを閉じたあと",
                         how: "アプリの切り替え画面で CharaTime を上に払ってから、ホーム画面を見る",
                         expected: "まばたき・寝息が動いている"),
        WeekRunCheckItem(id: "lockedHour", day: 3, title: "1 時間ロックしたあと",
                         how: "ロックして 1 時間以上置き、解除してすぐに見る",
                         expected: "まばたき・寝息がすぐに動き出す"),
    ]

    private static let laterDays = [
        WeekRunCheckItem(id: "tinted", day: 4, title: "外観「色合い調整」",
                         how: "ホーム画面の「編集」→「カスタマイズ」→「色合い調整」で見る（見たら元に戻す）",
                         expected: "部屋の絵が外れ、キャラとアイテムが色つきで立ち、まばたきする"),
        WeekRunCheckItem(id: "clear", day: 4, title: "外観「クリア」",
                         how: "ホーム画面の「編集」→「カスタマイズ」→「クリア」で見る（見たら元に戻す）",
                         expected: "部屋の絵が外れ、キャラとアイテムが色つきで立ち、まばたきする"),
        WeekRunCheckItem(id: "idleTenMinutes", day: 5, title: "画面を点けたまま 10 分",
                         how: "設定 → 画面表示と明るさ → 自動ロックを「なし」にし、ホーム画面のまま 10 分置いて見る"
                             + "（見たら戻す）",
                         expected: "まばたき・寝息が動いている"),
        WeekRunCheckItem(id: "reduceMotion", day: 5, title: "視差効果を減らす",
                         how: "設定 → アクセシビリティ → 動作 →「視差効果を減らす」を入のまま（切なら入にして）、"
                             + "切り替わりを 1 回見る",
                         expected: "まばたき・寝息は動き、切り替わりではキャラが横にすべらず、その場で入れ替わる"),
        WeekRunCheckItem(id: "lowPower", day: 6, title: "低電力モード",
                         how: "設定 → バッテリー → 低電力モードを入にして見る（見たら切に戻す）",
                         expected: "キャラは見える。まばたきが止まったかを書く（次に作り直されると、5 分ごとの切り替えだけになる）"),
        WeekRunCheckItem(id: "afterRestart", day: 6, title: "再起動したあと",
                         how: "iPhone を再起動し、ロックを解除して見る",
                         expected: "キャラが見え、まばたき・寝息が動く（動き出すまでの時間も書く）"),
        WeekRunCheckItem(id: "standByDay", day: 6, title: "スタンバイ（昼）",
                         how: "明るい部屋で、充電しながら横向きに立ててロックする",
                         expected: "キャラが大きく見え、まばたきする"),
        WeekRunCheckItem(id: "crashLog", day: 7, title: "拡張が落ちていない",
                         how: "設定 → プライバシーとセキュリティ → 解析と改善 → 解析データ を開く",
                         expected: "「CharaTimeWidget」で始まる記録が無い"),
    ]
}
