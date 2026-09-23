# -*- coding: utf-8 -*-
"""ウィジェット疑似アニメのスパイク用マスクフォントを作る（プラン §9 Phase 0 の 0-9）。

**なぜフォントなのか。** ウィジェット拡張は自分では動けない。1 日 40〜70 回の
更新予算があるだけで、秒単位の描画はできない。ただ `Text(timerInterval:)` だけは
**拡張が止まっていても OS が毎秒描き直す**（`research/B` §S21/S22）。
そこにカスタムフォントを当てて、秒の値ごとに「塗りつぶし」か「空」のグリフを返させる。
その文字で絵をマスクすれば、絵が毎秒出たり消えたりする。

**合字は使わない。** `research/E` §2.3 は「`:` + 2 桁を合字で 1 グリフにする」案を
書いているが、手元（Xcode 26.6 / iOS 26.5 シミュレータ）で試すと
**`Text(timerInterval:)` には合字（GSUB の `liga`）が適用されなかった**。
ふつうの `Text("05:24")` では合字が効くので、タイマーの文字だけが
別の経路で組まれているらしい。

代わりに **1 文字ずつの字形だけで決める**。秒の一の位の偶奇は秒の偶奇と同じなので、

- 偶数の数字（0,2,4,6,8）→ 1em の塗りつぶし
- 奇数の数字（1,3,5,7,9）→ 空

としたフォントを当て、**文字列の右端 1em だけを切り出す**（秒の一の位）。
合字に頼らないぶん、こちらのほうが壊れにくい。

    python3 tools/spike/make_mask_fonts.py

出典: Bryce Bostwick が 2025-05 に公開 API のみで実証（`research/E` §2.3、`research/F` §2）。
**公式に保証された手法ではない。** 実機で確かめるためのスパイクなので、
ここで作ったフォントは製品には入れない。

**スパイク F（プラン §9 Phase 3 の 3-0b）で 3 本足した。** 本番の組み方（3-C ④ 原則 3）を確かめるため。

- 数字の集まりごとの書体（{2, 7} と {0, 1, 2}）。集まりに入る数字だけが 1em の塗りつぶし。
  秒の一の位に {2, 7} を当てると 5 秒に 2 回、秒の十の位に {0, 1, 2} を当てると 1 分のうち前半の 30 秒だけ開く
- 数字を棒の高さで見せる書体（`CTSpikeGauge`）。数字 d が高さ (d+1)/10 em の棒になる。
  桁の切り出しが正しいかを、スクリーンショットの棒の高さで読む

**出力は毎回同じバイト列にする**（作成日時を固定する）。作り直しても、中身が変わらなければ差分が出ない。
"""
import pathlib
import sys

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

# フォントの座標系。1000 単位を 1em とする慣習に合わせる。
UNITS_PER_EM = 1000
# 棒の書体の、左右の余白。隣の棒とくっつかず、1 本ずつ数えられるようにする。
GAUGE_INSET = 150
# フォントに書く作成・更新日時（1904 年からの秒）。固定しないと、作り直すたびにバイト列が変わる。
# 値は、偶数・奇数の 2 本を最初に作った日時（2026-09-12 09:06:09）。この値なら 2 本はバイト単位で元どおりになる。
FIXED_TIMESTAMP = 3872016369

OUTPUT = pathlib.Path(__file__).resolve().parents[2] / "ios/CharaTimeSpikeWidget/Fonts"
FAMILY = "CTSpikeMask"


def filled_square():
    """1em いっぱいの塗りつぶし。マスクの「見せる」側。"""
    pen = TTGlyphPen(None)
    pen.moveTo((0, 0))
    pen.lineTo((UNITS_PER_EM, 0))
    pen.lineTo((UNITS_PER_EM, UNITS_PER_EM))
    pen.lineTo((0, UNITS_PER_EM))
    pen.closePath()
    return pen.glyph()


def empty():
    """何も描かないグリフ。マスクの「隠す」側。"""
    return TTGlyphPen(None).glyph()


def gauge_bar(digit):
    """数字 d を、下から高さ (d+1)/10 em の棒にする。0 でも棒が見える（`:` の空と見分けられる）。"""
    height = UNITS_PER_EM * (digit + 1) // 10
    pen = TTGlyphPen(None)
    pen.moveTo((GAUGE_INSET, 0))
    pen.lineTo((UNITS_PER_EM - GAUGE_INSET, 0))
    pen.lineTo((UNITS_PER_EM - GAUGE_INSET, height))
    pen.lineTo((GAUGE_INSET, height))
    pen.closePath()
    return pen.glyph()


def build(name, filled_digits):
    """`filled_digits` に入る数字だけ四角を返すマスク書体を作る。"""
    return save(name, {digit: filled_square() for digit in filled_digits})


def build_gauge(name):
    """数字を棒の高さで見せる書体を作る（マスクではなく、そのまま字として描く）。"""
    return save(name, {digit: gauge_bar(digit) for digit in range(10)})


def save(name, digit_glyphs):
    """数字のグリフを受け取り、残り（`:`・空白・数字の残り）を空にしてフォントを書き出す。

    **すべてのグリフを 1em 幅にそろえる。** 右端から k 字目を切り出すだけで
    「秒の一の位」「秒の十の位」などを取り出せるようにするため。
    """
    order = [".notdef", "space", "colon"] + [f"d{digit}" for digit in range(10)]
    glyphs = {glyph: empty() for glyph in order}
    for digit, glyph in digit_glyphs.items():
        glyphs[f"d{digit}"] = glyph

    metrics = {glyph: (UNITS_PER_EM, 0) for glyph in order}
    cmap = {ord(":"): "colon", ord(" "): "space"}
    cmap.update({ord(str(digit)): f"d{digit}" for digit in range(10)})

    builder = FontBuilder(UNITS_PER_EM, isTTF=True)
    builder.setupGlyphOrder(order)
    builder.setupCharacterMap(cmap)
    builder.setupGlyf(glyphs)
    builder.setupHorizontalMetrics(metrics)
    builder.setupHorizontalHeader(ascent=UNITS_PER_EM, descent=0)
    # **PostScript 名とフルネームを必ず入れる。** これが無いと iOS の
    # `UIAppFonts` はフォントを登録できず、`Font.custom` が黙ってシステム
    # フォントに落ちる。マスクが数字の形になって、点滅しているように見えない。
    builder.setupNameTable({
        "familyName": name,
        "styleName": "Regular",
        "fullName": name,
        "psName": name,
        "uniqueFontIdentifier": f"{name};CharaTime;1.0",
        "version": "Version 1.0",
    })
    builder.setupOS2(sTypoAscender=UNITS_PER_EM, usWinAscent=UNITS_PER_EM, usWinDescent=0)
    builder.setupPost()
    builder.updateHead(created=FIXED_TIMESTAMP, modified=FIXED_TIMESTAMP)

    OUTPUT.mkdir(parents=True, exist_ok=True)
    path = OUTPUT / f"{name}.ttf"
    builder.save(str(path))
    return path


def main():
    made = [
        build(f"{FAMILY}Even", filled_digits={0, 2, 4, 6, 8}),
        build(f"{FAMILY}Odd", filled_digits={1, 3, 5, 7, 9}),
        # スパイク F: 5 秒に 2 回の短いまばたき（入れ子の「かつ」で 0.25 秒だけ開く）
        build(f"{FAMILY}Set27", filled_digits={2, 7}),
        # スパイク F: 秒の十の位に当てて、1 分のうち前半の 30 秒だけ開く（時報の窓）
        build(f"{FAMILY}Set012", filled_digits={0, 1, 2}),
        # スパイク F: 桁の切り出しを目で確かめる
        build_gauge("CTSpikeGauge"),
    ]
    for path in made:
        print(f"  {path.name}  {path.stat().st_size // 1024} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
