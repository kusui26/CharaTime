# -*- coding: utf-8 -*-
"""CharaTime アセットパイプライン。

`design/` の SVG から、アプリが読む PNG と同梱データ JSON を作る。
**画像を手で足さない**（.claude/CLAUDE.md §2）。足したいときはここを通す。

    python3 tools/pipeline/pipeline.py            # 全部
    python3 tools/pipeline/pipeline.py --check    # 書き出さず、整合だけ見る

Phase 2 で生成 AI の絵に差し替わるが、**出力の形（imageset の名前・倍率・
接地の位置）は変えない**。差し替えるのは入口（`_character_svgs`）だけでよい。
"""
import argparse
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "design"))
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import chara            # noqa: E402  design/chara.py
import scene            # noqa: E402  design/scene.py
import art              # noqa: E402
import catalog          # noqa: E402
import masks            # noqa: E402
import rasterize        # noqa: E402

RESOURCES = ROOT / "ios/Packages/CTAssets/Sources/CTAssets/Resources"
CHARACTER_CATALOG = RESOURCES / "Characters.xcassets"
ITEM_CATALOG = RESOURCES / "Items.xcassets"

# キャラの絵の大きさ（@1x、ポイント）。
#
# 待受モードではキャラを 150〜180pt で描く。枠（130x180 単位）と 1:1 で焼くと
# @3x でも 1.4 倍に引き伸ばすことになり、輪郭がにじむ。1.5 倍で焼いておくと
# 画面上はほぼ等倍になる。枠と接地線の割合は design/chara.py が持つ。
CHARACTER_SCALE = 1.5
CHARACTER_WIDTH = int(chara.VIEWBOX[2] * CHARACTER_SCALE)     # 195
CHARACTER_HEIGHT = int(chara.VIEWBOX[3] * CHARACTER_SCALE)    # 270

# ウィジェット用の小さい絵（mini。プラン §5.3、D-20）の大きさ（@1x、ポイント）。
#
# ウィジェット拡張のメモリは約 30 MB。待受モードの絵は @3x で 585x810 画素、展開すると
# 1 コマ約 1.9 MB になる。ウィジェットで描くいちばん大きな絵（小の近影、枠の高さ 126pt）に
# 合わせて焼けば、@3x で 273x378 画素・約 0.41 MB で済み、引き伸ばしもしない。
# 0.7 倍にするのは、どの倍率でも画素数が整数になり、枠と接地線の割合が待受モードの絵と
# 1 画素もずれないため（2/3 倍だと @1x・@2x で端数が出る）。
MINI_SCALE = 0.7
MINI_WIDTH = int(round(chara.VIEWBOX[2] * MINI_SCALE))       # 91
MINI_HEIGHT = int(round(chara.VIEWBOX[3] * MINI_SCALE))      # 126
MINI_SUFFIX = "_mini"
# まぶたの差分（mini）の名前の後ろ。`piyo_idle_eyelid_mini` の形。
EYELID_SUFFIX = "_eyelid" + MINI_SUFFIX

# アイテムは接地線を絵の下端にそろえる。上端をそろえるのは吊り下げるものだけ。
ITEM_STROKE_MARGIN = 4
# アイテムも輪郭線が枠の外へ出るので、四方に余白を足して焼く。
ITEM_PAD = 5


def _character_svgs(character, pose_frames, width, height):
    return [chara.svg(character, frame, width, height) for frame in pose_frames]


def _asset_name(character, pose, index):
    """`piyo_walk_03` の形。characters.json が呼ぶ名前と一致させる。"""
    return "%s_%s_%02d" % (character, pose, index + 1)


def _mini_name(name):
    """`piyo_walk_03_mini` の形。characters.json の miniPoses が呼ぶ名前と一致させる。"""
    return name + MINI_SUFFIX


def _eyelid_poses():
    """まばたきの絵を持つ姿勢と、目を開けた絵・まばたきの絵のコマ番号（いまは立ち姿とすわる姿）。

    まばたきのコマは design/chara.py の BLINK_OF が知っている。目を開けた絵は、その姿勢の 1 コマ目。
    """
    return [(pose, 0, index) for pose, frames in chara.FRAMES
            for index, frame in enumerate(frames) if frame in chara.BLINK_OF]


def _eye_region_pixels(scale):
    """目を描く範囲（design/chara.py の EYE_REGION）を、mini の @scale の画素に直す。"""
    left, top = chara.VIEWBOX[0], chara.VIEWBOX[1]
    ratio = MINI_WIDTH * scale / chara.VIEWBOX[2]
    x0, y0, x1, y1 = chara.EYE_REGION
    return (int((x0 - left) * ratio), int((y0 - top) * ratio),
            int(round((x1 - left) * ratio)), int(round((y1 - top) * ratio)))


def _mini_png(catalog_dir, name, suffix):
    return catalog_dir / ("%s.imageset" % name) / ("%s%s.png" % (name, suffix))


def _bake_eyelids(character, poses, catalog_dir, work):
    """まばたきの絵を持つ姿勢ごとに、mini のまぶたの差分を作る。{姿勢: 名前} を返す。"""
    made = {}
    for pose, open_index, blink_index in _eyelid_poses():
        minis = [_mini_name(name) for name in poses[pose]]
        name = "%s_%s%s" % (character, pose, EYELID_SUFFIX)
        written = []
        for scale, suffix in catalog.SCALES:
            out = work / ("%s%s.png" % (name, suffix))
            if not art.eyelid(_mini_png(catalog_dir, minis[open_index], suffix),
                              _mini_png(catalog_dir, minis[blink_index], suffix),
                              out, _eye_region_pixels(scale), scale):
                raise ValueError("%s の %s に、まばたきの違いがありません" % (character, pose))
            written.append((scale, out))
        catalog.write_imageset(catalog_dir, name, written)
        made[pose] = name
    return made


def _sleep_frame_covers_base(poses, catalog_dir):
    """寝息の 2 コマ目が 1 コマ目を覆えるか（いちばん細かい @3x で見る）。"""
    first, second = [_mini_name(name) for name in poses["sleep"][:2]]
    return art.covers(_mini_png(catalog_dir, first, "@3x"), _mini_png(catalog_dir, second, "@3x"))


def _bake_frames(character, frames, names, cell, catalog_dir, work):
    """1 体ぶんのコマを、倍率ごとに 1 枚のシートへ焼き、切り分けて imageset にする。"""
    width, height = cell
    per_scale = {}
    for scale, suffix in catalog.SCALES:
        svgs = _character_svgs(character, frames, width * scale, height * scale)
        # 切り出したコマ（`<名前>@3x.png`）と同じ名前にしない。シートを消すときに一緒に消えるため。
        sheet_path = work / ("sheet-%s%s.png" % (names[0], suffix))
        rasterize.sheet(svgs, width * scale, height * scale, str(sheet_path))
        per_scale[scale] = rasterize.slice_sheet(
            sheet_path, names, width * scale, height * scale, work, suffix)
        sheet_path.unlink()
    for index, name in enumerate(names):
        catalog.write_imageset(
            catalog_dir, name,
            [(scale, per_scale[scale][index]) for scale, _ in catalog.SCALES])


def build_characters(check_only=False):
    frames = [(pose, frame) for pose, fs in chara.FRAMES for frame in fs]
    names_by_character = {}
    poses_by_character = {}
    mini_by_character = {}

    for character in chara.P:
        poses = {}
        for pose, _ in chara.FRAMES:
            count = sum(1 for p, _ in frames if p == pose)
            poses[pose] = [_asset_name(character, pose, i) for i in range(count)]
        poses_by_character[character] = poses
        mini_by_character[character] = {pose: [_mini_name(n) for n in names]
                                        for pose, names in poses.items()}
        names_by_character[character] = [n for names in poses.values() for n in names]

    if check_only:
        return poses_by_character

    catalog_dir = rasterize.reset_directory(CHARACTER_CATALOG)
    catalog.write_catalog_root(catalog_dir)
    work = catalog_dir / "_work"
    work.mkdir()

    ambient_by_character = {}
    for character in chara.P:
        names = names_by_character[character]
        drawn = [f for _, f in frames]
        _bake_frames(character, drawn, names, (CHARACTER_WIDTH, CHARACTER_HEIGHT), catalog_dir, work)
        _bake_frames(character, drawn, [_mini_name(n) for n in names], (MINI_WIDTH, MINI_HEIGHT),
                     catalog_dir, work)
        poses = poses_by_character[character]
        ambient_by_character[character] = {
            "eyelids": _bake_eyelids(character, poses, catalog_dir, work),
            "sleepFrameCoversBase": _sleep_frame_covers_base(poses, catalog_dir),
        }
        print("  %-6s %2d 枚（ほかにウィジェット用 %d 枚・まぶた %d 枚、寝息の 2 コマ目が%s）"
              % (character, len(names), len(names), len(ambient_by_character[character]["eyelids"]),
                 "覆う" if ambient_by_character[character]["sleepFrameCoversBase"] else "覆えない"))

    work.rmdir()
    catalog.update_characters(
        RESOURCES / "characters.json", poses_by_character, mini_by_character, ambient_by_character,
        {"aspectRatio": round(chara.ASPECT, 4), "groundRatio": round(chara.GROUND_RATIO, 4)},
        frame_count=len(frames))
    return poses_by_character


# アイテムの絵。(SVG の中身を作る関数, viewBox の幅, 高さ)。
# 接地するものは下端に、吊り下げるものは上端に合わせて描く。
def _item_drawings():
    margin = ITEM_STROKE_MARGIN
    return {
        # 吊り下げるので上端が基準。紐はアプリ側が天井まで描くため、ここでは描かない。
        "mirror-ball": (lambda w, h: scene.mirror_ball(w / 2, h / 2, h / 2 - margin,
                                                       ceiling=h / 2 - h / 2 + margin,
                                                       on=False, uid="mb"), 120, 120),
        "cushion":     (lambda w, h: scene.cushion(w / 2, h - margin - h * 0.23, w - margin * 2), 140, 72),
        "bed":         (lambda w, h: scene.bed(w / 2, h - margin, w - margin * 2), 180, 120),
        "plant":       (lambda w, h: scene.plant(w / 2, h - margin), 130, 150),
        "desk-clock":  (lambda w, h: scene.deskclock(w / 2, h - margin), 110, 110),
        "ball":        (lambda w, h: scene.ball(w / 2, h - margin, w / 2 - margin), 90, 90),
        "snack":       (lambda w, h: scene.snack(w / 2, h - margin, w - margin * 4), 110, 66),
    }


def _item_box(item_id):
    """アイテムを焼く枠。(描く関数, 中身の幅, 高さ, 余白を含む枠の幅, 高さ)"""
    draw, box_width, box_height = _item_drawings()[item_id]
    return draw, box_width, box_height, box_width + ITEM_PAD * 2, box_height + ITEM_PAD * 2


def _item_svg(item_id, scale):
    draw, box_width, box_height, framed_width, framed_height = _item_box(item_id)
    return ('<svg width="%g" height="%g" viewBox="%g %g %g %g" fill="none" '
            'xmlns="http://www.w3.org/2000/svg">'
            '<g stroke="%s" stroke-width="5" stroke-linejoin="round" stroke-linecap="round">'
            '%s</g></svg>'
            % (framed_width * scale, framed_height * scale,
               -ITEM_PAD, -ITEM_PAD, framed_width, framed_height,
               scene.OUT, draw(box_width, box_height)))


def _item_asset_name(item_id):
    return "item_" + item_id.replace("-", "_")


def build_items(check_only=False):
    drawings = _item_drawings()
    assets = {item_id: _item_asset_name(item_id) for item_id in drawings}
    # アプリは幅だけを指定して置くので、高さを出すために縦横比を渡す。
    aspects = {item_id: round(_item_box(item_id)[3] / _item_box(item_id)[4], 4)
               for item_id in drawings}
    if check_only:
        return assets, aspects

    catalog_dir = rasterize.reset_directory(ITEM_CATALOG)
    catalog.write_catalog_root(catalog_dir)
    work = catalog_dir / "_work"
    work.mkdir()

    item_ids = list(drawings)
    per_scale = {}
    for scale, suffix in catalog.SCALES:
        written = []
        for item_id in item_ids:
            _, _, _, framed_width, framed_height = _item_box(item_id)
            width, height = int(framed_width * scale), int(framed_height * scale)
            sheet_path = work / ("%s%s.png" % (item_id, suffix))
            rasterize.sheet([_item_svg(item_id, scale)], width, height, str(sheet_path))
            written += rasterize.slice_sheet(
                sheet_path, [assets[item_id]], width, height, work, suffix)
            sheet_path.unlink()
        per_scale[scale] = written
    for index, item_id in enumerate(item_ids):
        catalog.write_imageset(catalog_dir, assets[item_id],
                               [(s, per_scale[s][index]) for s, _ in catalog.SCALES])
    print("  アイテム %d 種" % len(item_ids))

    work.rmdir()
    catalog.update_items(RESOURCES / "items.json", assets, aspects)
    return assets, aspects


def verify():
    """JSON が呼ぶ名前に、対応する imageset が全部あるか。"""
    import json
    problems = []
    checks = [(RESOURCES / "characters.json", "characters", CHARACTER_CATALOG,
               lambda e: [n for key in ("poses", "miniPoses")
                          for names in e[key].values() for n in names]
               + list(e.get("eyelids", {}).values())),
              (RESOURCES / "items.json", "items", ITEM_CATALOG,
               lambda e: [e["assetName"]])]
    for json_path, key, catalog_dir, names_of in checks:
        document = json.loads(json_path.read_text(encoding="utf-8"))
        for entry in document[key]:
            for name in names_of(entry):
                imageset = catalog_dir / ("%s.imageset" % name)
                if not (imageset / "Contents.json").exists():
                    problems.append("%s が呼ぶ %s に imageset がありません" % (json_path.name, name))
                    continue
                for scale, suffix in catalog.SCALES:
                    if not (imageset / ("%s%s.png" % (name, suffix))).exists():
                        problems.append("%s の %s が足りません" % (name, suffix))
    return problems


def main():
    parser = argparse.ArgumentParser(description="CharaTime アセットパイプライン")
    parser.add_argument("--check", action="store_true", help="書き出さず整合だけ見る")
    args = parser.parse_args()

    if not args.check:
        print("キャラクター")
        build_characters()
        print("アイテム")
        build_items()
        print("マスク書体")
        for path in masks.build():
            print("  %s" % path.name)

    problems = verify() + masks.verify(ROOT / "ios/project.yml")
    if problems:
        for problem in problems:
            print("✗ %s" % problem, file=sys.stderr)
        return 1
    print("✓ JSON と Asset Catalog の整合を確認")
    return 0


if __name__ == "__main__":
    sys.exit(main())
