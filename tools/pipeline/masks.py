# -*- coding: utf-8 -*-
"""ウィジェットの疑似アニメのマスク書体を焼く（プラン §9 Phase 3 の 3-2b。スパイクの作りを移した）。

**なぜ書体なのか。** ウィジェット拡張は自分では動けない。ただ `Text(timerInterval:)` だけは、
拡張が止まっていても OS が毎秒描き直す。そこに「数字の集まりに入る数字だけが 1em の塗りつぶし、
ほかは空」の書体を当てて 1 字だけ切り出し、それをマスクにして絵を出し入れする（3-C ④）。

**一族は 7 本**（CTCore の `MaskFontFamily.digitSets` と同じ並び）。秒の一の位の集まりは、整数秒
進めれば回した集まりと同じ時刻に開くので、まばたきの 15 通りも奇数も、この 7 本で足りる。
一覧を変えたら CTCore の側も変える。CTAssets のテストが `mask_fonts.json` と突き合わせる。

作りのきまり（スパイクで分かったこと。docs/260912_spike.md §5）:

- **合字は使わない。** `Text(timerInterval:)` には合字（GSUB の liga）が効かない
- **PostScript 名を必ず入れる。** 無いと iOS は `UIAppFonts` から登録せず、黙ってシステムの字に落ちる
- **すべての字を 1em 幅にそろえる。** 右から k 字目を切り出すだけで、秒や分の桁を取り出せる
- **作成日時を固定する。** 作り直しても、中身が同じならバイト列も同じ
"""
import json
import pathlib

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

ROOT = pathlib.Path(__file__).resolve().parents[2]
# 書体の置き場。アプリとウィジェット拡張の両方に入れる（ios/project.yml の UIAppFonts）。
FONT_DIR = ROOT / "ios/Shared/Fonts"
# 書体の一覧。アプリとウィジェットはこの名前で書体を引く（CTAssets の Catalog.maskFonts）。
MANIFEST = ROOT / "ios/Packages/CTAssets/Sources/CTAssets/Resources/mask_fonts.json"

FAMILY_PREFIX = "CTMask"
# 書体の座標系。1000 単位を 1em とする慣習に合わせる。
UNITS_PER_EM = 1000
# 書体に書く作成・更新日時（1904 年からの秒）。スパイクの書体と同じ値にしてある。
FIXED_TIMESTAMP = 3872016369

# 一族の数字の集まり（CTCore の MaskFontFamily.digitSets と同じ並び）。
DIGIT_SETS = [
    (0, 5),                 # まばたき（2 つ組を回した形）
    (0, 3, 6),              # まばたき（3 つ組を回した形）
    (0, 2, 4, 6, 8),        # よろこぶの出し分け・光の粒（奇数は 1 秒進めた偶数）
    (0, 1, 5, 6),           # 寝息
    (0, 1, 2, 5, 6, 7),     # 寝息の残りを回した形（2 コマ目が 1 コマ目を覆えないとき）
    (0,),                   # 時報（分の一の位）
    (0, 1, 2),              # 時報（秒の十の位）
]


def font_name(digits):
    """`CTMask05` の形。Swift の側も同じ規則で名前を作る（`MaskFont.name(for:)`）。"""
    return FAMILY_PREFIX + "".join(str(digit) for digit in digits)


def _filled_square():
    """1em いっぱいの塗りつぶし。マスクの「見せる」側。"""
    pen = TTGlyphPen(None)
    pen.moveTo((0, 0))
    pen.lineTo((UNITS_PER_EM, 0))
    pen.lineTo((UNITS_PER_EM, UNITS_PER_EM))
    pen.lineTo((0, UNITS_PER_EM))
    pen.closePath()
    return pen.glyph()


def _empty():
    """何も描かない字。マスクの「隠す」側。"""
    return TTGlyphPen(None).glyph()


def _build(name, filled_digits, out_dir):
    """`filled_digits` に入る数字だけが 1em の四角で、ほか（`:`・空白・残りの数字）が空の書体。"""
    order = [".notdef", "space", "colon"] + ["d%d" % digit for digit in range(10)]
    glyphs = {glyph: _empty() for glyph in order}
    for digit in filled_digits:
        glyphs["d%d" % digit] = _filled_square()
    cmap = {ord(":"): "colon", ord(" "): "space"}
    cmap.update({ord(str(digit)): "d%d" % digit for digit in range(10)})

    builder = FontBuilder(UNITS_PER_EM, isTTF=True)
    builder.setupGlyphOrder(order)
    builder.setupCharacterMap(cmap)
    builder.setupGlyf(glyphs)
    builder.setupHorizontalMetrics({glyph: (UNITS_PER_EM, 0) for glyph in order})
    builder.setupHorizontalHeader(ascent=UNITS_PER_EM, descent=0)
    builder.setupNameTable({
        "familyName": name,
        "styleName": "Regular",
        "fullName": name,
        "psName": name,
        "uniqueFontIdentifier": "%s;CharaTime;1.0" % name,
        "version": "Version 1.0",
    })
    builder.setupOS2(sTypoAscender=UNITS_PER_EM, usWinAscent=UNITS_PER_EM, usWinDescent=0)
    builder.setupPost()
    builder.updateHead(created=FIXED_TIMESTAMP, modified=FIXED_TIMESTAMP)
    path = out_dir / ("%s.ttf" % name)
    builder.save(str(path))
    return path


def build(check_only=False):
    """一族を焼き、一覧（mask_fonts.json）を書く。書き出した書体のパスを返す。"""
    entries = [{"name": font_name(digits), "digits": list(digits)} for digits in DIGIT_SETS]
    if check_only:
        return [FONT_DIR / ("%s.ttf" % entry["name"]) for entry in entries]
    FONT_DIR.mkdir(parents=True, exist_ok=True)
    # 一族から外した書体が残らないようにする（CTMask で始まるものだけを消す）。
    for stale in FONT_DIR.glob(FAMILY_PREFIX + "*.ttf"):
        stale.unlink()
    paths = [_build(entry["name"], entry["digits"], FONT_DIR) for entry in entries]
    manifest = {
        "_note": "tools/pipeline が書き出す。手で編集しない。並びは CTCore の MaskFontFamily.digitSets と同じ",
        "fonts": entries,
    }
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
                        encoding="utf-8")
    return paths


def verify(project_yml):
    """一覧の書体がそろっていて、アプリと拡張の両方の UIAppFonts に載っているか。"""
    problems = []
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    listed = project_yml.read_text(encoding="utf-8")
    for entry in manifest["fonts"]:
        file_name = "%s.ttf" % entry["name"]
        if not (FONT_DIR / file_name).exists():
            problems.append("書体 %s がありません（%s）" % (file_name, FONT_DIR))
        # アプリとウィジェット拡張の 2 か所に並べる約束なので、2 回以上出てくるはず。
        if listed.count("- %s" % file_name) < 2:
            problems.append("%s が project.yml の UIAppFonts（アプリと拡張の両方）に載っていません" % file_name)
    return problems
