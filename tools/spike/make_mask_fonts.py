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
"""
import pathlib
import sys

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

# フォントの座標系。1000 単位を 1em とする慣習に合わせる。
UNITS_PER_EM = 1000

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


def build(name, shows_even_digits):
    """偶数（または奇数）の数字だけ四角を返すフォントを作る。

    **すべてのグリフを 1em 幅にそろえる。** 右端 1em を切り出すだけで
    「秒の一の位」を取り出せるようにするため。
    """
    order = [".notdef", "space", "colon"] + [f"d{digit}" for digit in range(10)]
    glyphs = {glyph: empty() for glyph in order}
    for digit in range(10):
        if (digit % 2 == 0) == shows_even_digits:
            glyphs[f"d{digit}"] = filled_square()

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

    OUTPUT.mkdir(parents=True, exist_ok=True)
    path = OUTPUT / f"{name}.ttf"
    builder.save(str(path))
    return path


def main():
    made = [
        build(f"{FAMILY}Even", shows_even_digits=True),
        build(f"{FAMILY}Odd", shows_even_digits=False),
    ]
    for path in made:
        print(f"  {path.name}  {path.stat().st_size // 1024} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
