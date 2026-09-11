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
import catalog          # noqa: E402
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

# アイテムは接地線を絵の下端にそろえる。上端をそろえるのは吊り下げるものだけ。
ITEM_STROKE_MARGIN = 4
# アイテムも輪郭線が枠の外へ出るので、四方に余白を足して焼く。
ITEM_PAD = 5


def _character_svgs(character, pose_frames, width, height):
    return [chara.svg(character, frame, width, height) for frame in pose_frames]


def _asset_name(character, pose, index):
    """`piyo_walk_03` の形。characters.json が呼ぶ名前と一致させる。"""
    return "%s_%s_%02d" % (character, pose, index + 1)


def build_characters(check_only=False):
    frames = [(pose, frame) for pose, fs in chara.FRAMES for frame in fs]
    names_by_character = {}
    poses_by_character = {}

    for character in chara.P:
        poses = {}
        for pose, _ in chara.FRAMES:
            count = sum(1 for p, _ in frames if p == pose)
            poses[pose] = [_asset_name(character, pose, i) for i in range(count)]
        poses_by_character[character] = poses
        names_by_character[character] = [n for names in poses.values() for n in names]

    if check_only:
        return poses_by_character

    catalog_dir = rasterize.reset_directory(CHARACTER_CATALOG)
    catalog.write_catalog_root(catalog_dir)
    work = catalog_dir / "_work"
    work.mkdir()

    for character in chara.P:
        names = names_by_character[character]
        per_scale = {}
        for scale, suffix in catalog.SCALES:
            width, height = CHARACTER_WIDTH * scale, CHARACTER_HEIGHT * scale
            svgs = _character_svgs(character, [f for _, f in frames], width, height)
            sheet_path = work / ("%s%s.png" % (character, suffix))
            rasterize.sheet(svgs, width, height, str(sheet_path))
            per_scale[scale] = rasterize.slice_sheet(
                sheet_path, names, width, height, work, suffix)
            sheet_path.unlink()
        for index, name in enumerate(names):
            catalog.write_imageset(
                catalog_dir, name,
                [(scale, per_scale[scale][index]) for scale, _ in catalog.SCALES])
        print("  %-6s %2d 枚" % (character, len(names)))

    work.rmdir()
    catalog.update_characters(
        RESOURCES / "characters.json", poses_by_character,
        {"aspectRatio": round(chara.ASPECT, 4), "groundRatio": round(chara.GROUND_RATIO, 4)})
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
               lambda e: [n for names in e["poses"].values() for n in names]),
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

    problems = verify()
    if problems:
        for problem in problems:
            print("✗ %s" % problem, file=sys.stderr)
        return 1
    print("✓ JSON と Asset Catalog の整合を確認")
    return 0


if __name__ == "__main__":
    sys.exit(main())
