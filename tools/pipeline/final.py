# -*- coding: utf-8 -*-
"""chara-bake が整えた絵（`assets-src/characters/<id>/final/`）を、Asset Catalog に入れる（プラン §6.4 の ②、2-3）。

final/ は @3x の絵だけを持つ（hero 585×810・mini 273×378・まぶたの差分。名前は取り込んだキャラのフォルダと同じ
`hero/idle_01.png` の形）。@3x はそのまま写し、@2x と @1x は @3x から縮めて作る（Pillow の Lanczos。RGBA は乗算済みで
縮めるので、透明な縁に色がにじまない）。まぶたの差分は、縮めた mini どうしを比べて倍率ごとに作り直す（SVG のキャラと
同じ `art.eyelid`。縮めた絵と差分が食い違わない）。比べる範囲は、@3x の差分の外接矩形を縮め、縮めるときの補間が
まわりへ届く幅だけ広げたもの。

**形は SVG のキャラと同じ**（`design/chara.py` の FRAMES の姿勢と枚数、BLINK_OF の姿勢のまぶた）。違えば、どの
ファイルかを添えて止める（chara-bake はそろわない絵を final/ に書かないが、手で消した・足したときのため）。
"""
import math
import pathlib
import shutil

from PIL import Image

import art
import catalog

# final/ の絵の大きさ（@3x の画素）。CTStore の `CharacterImageKind.pixelSize` と同じ（D-34）。
HERO_SIZE = (585, 810)
MINI_SIZE = (273, 378)
# final/ は @3x だけを持つ。
FINAL_SCALE = 3
FINAL_SUFFIX = "@3x"
# まぶたの差分を比べる範囲を、縮めた外接矩形から広げる幅（画素）。Lanczos は縮めた先で 3 画素ほどまで届く。
EYELID_RESAMPLING_MARGIN = 3
# 予備のコマ（見上げる・驚く）のフォルダ。Asset Catalog には入れない（Phase 4 の Tier 2 で使う）。
SPARE_FOLDER = "spare"


class FinalArt:
    """final/ の 1 体ぶん。`heroes`・`minis` は {姿勢: [PNG のパス]}、`eyelids` は {姿勢: PNG のパス}。"""

    def __init__(self, folder, heroes, minis, eyelids):
        self.folder = folder
        self.heroes = heroes
        self.minis = minis
        self.eyelids = eyelids


def frame_path(folder, kind, pose, index):
    """`hero/idle_01.png` の形（CTStore の `CharacterImageName.frame` と同じ）。"""
    return pathlib.Path(folder) / kind / ("%s_%02d.png" % (pose, index + 1))


def eyelid_path(folder, pose):
    """`mini/idle_eyelid.png` の形（CTStore の `CharacterImageName.eyelid` と同じ）。"""
    return pathlib.Path(folder) / "mini" / ("%s_eyelid.png" % pose)


def load(folder, frames, blink_of):
    """final/ を読む。無ければ None。形か大きさが違えば ValueError（どのファイルかを添える）。

    `frames` は design/chara.py の FRAMES（[(姿勢, [コマ])]）、`blink_of` は BLINK_OF（{まばたきのコマ: 姿勢}）。
    """
    folder = pathlib.Path(folder)
    if not folder.is_dir():
        return None
    heroes = {pose: [frame_path(folder, "hero", pose, i) for i in range(len(names))] for pose, names in frames}
    minis = {pose: [frame_path(folder, "mini", pose, i) for i in range(len(names))] for pose, names in frames}
    eyelids = {pose: eyelid_path(folder, pose) for pose in sorted(set(blink_of.values()))}
    expected = ([(p, HERO_SIZE) for paths in heroes.values() for p in paths]
                + [(p, MINI_SIZE) for paths in minis.values() for p in paths]
                + [(p, MINI_SIZE) for p in eyelids.values()])
    _check_files(folder, expected)
    return FinalArt(folder, heroes, minis, eyelids)


def _check_files(folder, expected):
    """あるべき絵がそろい、大きさが合い、余りの絵が無いか。"""
    for path, size in expected:
        if not path.exists():
            raise ValueError("%s がありません（chara-bake で整え直してください）" % path)
        with Image.open(path) as image:
            if image.size != size:
                raise ValueError("%s の大きさが %dx%d です（%dx%d のはず）" % ((path,) + image.size + size))
    known = {path for path, _ in expected}
    extra = sorted(str(path) for path in folder.rglob("*.png")
                   if path not in known and SPARE_FOLDER not in path.relative_to(folder).parts)
    if extra:
        raise ValueError("final/ に使わない絵があります: %s" % ", ".join(extra))


def bake(art_files, names, cells, catalog_dir, work):
    """1 体ぶんを Asset Catalog に入れる。まぶたの差分の名前と、寝息の 2 コマ目が覆えるかを返す。

    `names` は {"hero": {姿勢: [名前]}, "mini": {姿勢: [名前]}, "eyelid": {姿勢: 名前}}、
    `cells` は {"hero": (@1x の幅, 高さ), "mini": (…)}。
    """
    for kind, sources in (("hero", art_files.heroes), ("mini", art_files.minis)):
        for pose, paths in sources.items():
            for source, name in zip(paths, names[kind][pose]):
                _bake_image(source, name, cells[kind], catalog_dir, work)
    eyelids = {pose: _bake_eyelid(art_files, pose, names, cells["mini"], catalog_dir, work)
               for pose in art_files.eyelids}
    sleep = art_files.minis["sleep"]
    return {"eyelids": eyelids, "sleepFrameCoversBase": art.covers(sleep[0], sleep[1])}


def _bake_image(source, name, cell, catalog_dir, work):
    """@3x を写し、@2x・@1x を縮めて、imageset にする。"""
    written = []
    for scale, suffix in catalog.SCALES:
        out = work / ("%s%s.png" % (name, suffix))
        written.append((scale, _scaled(source, (cell[0] * scale, cell[1] * scale), out)))
    catalog.write_imageset(catalog_dir, name, written)


def _scaled(source, size, out):
    """絵を `size` に縮めて書く（同じ大きさなら、そのまま写す）。"""
    with Image.open(source) as image:
        if image.size == size:
            shutil.copyfile(source, out)
        else:
            image.convert("RGBA").resize(size, Image.LANCZOS).save(out, "PNG", optimize=True)
    return out


def _bake_eyelid(art_files, pose, names, mini_cell, catalog_dir, work):
    """まぶたの差分: @3x は final/ のまま、@2x・@1x は縮めた mini どうしを比べて作り直す。"""
    name = names["eyelid"][pose]
    opened, blinked = [_mini_file(catalog_dir, names["mini"][pose][i]) for i in (0, 1)]
    written = []
    for scale, suffix in catalog.SCALES:
        out = work / ("%s%s.png" % (name, suffix))
        if scale == FINAL_SCALE:
            shutil.copyfile(art_files.eyelids[pose], out)
        elif not art.eyelid(opened(suffix), blinked(suffix), out,
                            eyelid_region(art_files.eyelids[pose], scale), scale):
            raise ValueError("%s の %s に、まばたきの違いがありません" % (art_files.folder, pose))
        written.append((scale, out))
    catalog.write_imageset(catalog_dir, name, written)
    return name


def _mini_file(catalog_dir, name):
    """Asset Catalog に入れた mini の、倍率ごとの PNG。"""
    return lambda suffix: pathlib.Path(catalog_dir) / ("%s.imageset" % name) / ("%s%s.png" % (name, suffix))


def eyelid_region(eyelid, scale):
    """@3x のまぶたの差分の外接矩形を @scale に縮め、補間の届く幅だけ広げる（左, 上, 右, 下）。"""
    with Image.open(eyelid) as image:
        box = image.convert("RGBA").getchannel("A").getbbox()
        width, height = image.size
    if box is None:
        raise ValueError("%s に違う画素がありません" % eyelid)
    ratio = scale / FINAL_SCALE
    left, top, right, bottom = box
    margin = EYELID_RESAMPLING_MARGIN
    return (max(0, math.floor(left * ratio) - margin), max(0, math.floor(top * ratio) - margin),
            min(round(width * ratio), math.ceil(right * ratio) + margin),
            min(round(height * ratio), math.ceil(bottom * ratio) + margin))


def stale_files(art_files, names, catalog_dir):
    """Asset Catalog の @3x が final/ と違う絵（final/ を整え直したのに pipeline.py を回していない）。"""
    pairs = ([(p, n) for kind, sources in (("hero", art_files.heroes), ("mini", art_files.minis))
              for pose, paths in sources.items() for p, n in zip(paths, names[kind][pose])]
             + [(art_files.eyelids[pose], names["eyelid"][pose]) for pose in art_files.eyelids])
    stale = []
    for source, name in pairs:
        target = pathlib.Path(catalog_dir) / ("%s.imageset" % name) / ("%s%s.png" % (name, FINAL_SUFFIX))
        if not target.exists() or target.read_bytes() != source.read_bytes():
            stale.append(name)
    return stale
