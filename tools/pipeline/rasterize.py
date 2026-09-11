# -*- coding: utf-8 -*-
"""SVG を PNG に焼く。

**なぜ headless Chrome か。** この機械には rsvg-convert も cairosvg も Inkscape も
入っていない。Chrome は design/ のデザインキャンバスを確認するのに既に使っており、
`--default-background-color=00000000` で背景を透明にしたまま、指定した画素数に
ベクタから直接描いてくれる。倍率ごとに描き直すので、拡大縮小によるぼやけが出ない。
"""
import pathlib
import shutil
import subprocess
import tempfile

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# 1 枚ずつ Chrome を起動すると 1 秒かかる。1 回の起動で 1 行に並べて焼き、
# あとから Pillow で切り分ける。
_PAGE = ('<!doctype html><html><head><meta charset="utf-8"><style>'
         'html,body{margin:0;padding:0;background:transparent;}'
         '#s{display:flex;}#s>svg{display:block;flex:none;}'
         '</style></head><body><div id="s">%s</div></body></html>')


class RasterizeError(RuntimeError):
    pass


def require_chrome():
    """Chrome が無ければ、何を入れればよいかを言って止まる。"""
    if not pathlib.Path(CHROME).exists():
        raise RasterizeError(
            "Google Chrome が %s にありません。SVG を焼くのに使います。" % CHROME)


def sheet(svgs, cell_width, cell_height, out_path):
    """`svgs` を横 1 列に並べて 1 枚の PNG に焼く。

    戻り値は焼いた PNG のパス。切り分けは `slice_sheet` が行う。
    """
    require_chrome()
    width = cell_width * len(svgs)
    with tempfile.TemporaryDirectory() as work:
        page = pathlib.Path(work) / "sheet.html"
        page.write_text(_PAGE % "".join(svgs), encoding="utf-8")
        subprocess.run(
            [CHROME, "--headless", "--disable-gpu", "--hide-scrollbars",
             "--default-background-color=00000000",
             "--force-device-scale-factor=1",
             "--virtual-time-budget=4000",
             "--screenshot=%s" % out_path,
             "--window-size=%d,%d" % (width, cell_height),
             page.as_uri()],
            check=True, capture_output=True)
    if not pathlib.Path(out_path).exists():
        raise RasterizeError("Chrome が PNG を書き出しませんでした: %s" % out_path)
    return out_path


def slice_sheet(sheet_path, names, cell_width, cell_height, out_dir, suffix):
    """1 行のシートを 1 枚ずつに切り分けて保存する。

    **切り取る枠は固定で、余白を詰めない。** 詰めると姿勢ごとに絵の原点がずれ、
    コマを送ったときにキャラが跳ねて見える。
    """
    from PIL import Image

    written = []
    with Image.open(sheet_path) as sheet_image:
        image = sheet_image.convert("RGBA")
        if image.size != (cell_width * len(names), cell_height):
            raise RasterizeError(
                "焼き上がりの大きさが違います: %s（期待 %dx%d）"
                % (image.size, cell_width * len(names), cell_height))
        for index, name in enumerate(names):
            box = (index * cell_width, 0, (index + 1) * cell_width, cell_height)
            path = pathlib.Path(out_dir) / ("%s%s.png" % (name, suffix))
            image.crop(box).save(path, "PNG", optimize=True)
            written.append(path)
    return written


def reset_directory(path):
    """書き出し先を空にする。消えたコマが残らないようにするため。"""
    directory = pathlib.Path(path)
    if directory.exists():
        shutil.rmtree(directory)
    directory.mkdir(parents=True)
    return directory
