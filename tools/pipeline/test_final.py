# -*- coding: utf-8 -*-
"""chara-bake の final/ を Asset Catalog に入れる処理（final.py）のテスト。

    python3 -m unittest discover -s tools/pipeline -p 'test_*.py'

見本の final/ は、いまのピヨの絵（Asset Catalog の @3x）から組む。SVG は焼かないので数秒で終わる。
"""
import pathlib
import shutil
import sys
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / "design"))
sys.path.insert(0, str(HERE))

import numpy        # noqa: E402
from PIL import Image  # noqa: E402

import art          # noqa: E402
import chara        # noqa: E402  design/chara.py
import final        # noqa: E402

CATALOG = ROOT / "ios/Packages/CTAssets/Sources/CTAssets/Resources/Characters.xcassets"
CELLS = {"hero": (195, 270), "mini": (91, 126)}
# 見本のまばたき: 目を開けた mini（@3x）の目のあたりを塗る範囲（左, 上, 右, 下）と、差分を比べる範囲。
BLINK_PAINT = (90, 135, 185, 155)
BLINK_REGION = (80, 125, 195, 165)


def bundled(name):
    return CATALOG / ("%s.imageset" % name) / ("%s@3x.png" % name)


def names(character):
    """pipeline.py の `_final_names` と同じ形。"""
    poses = {pose: ["%s_%s_%02d" % (character, pose, i + 1) for i in range(len(frames))]
             for pose, frames in chara.FRAMES}
    return {"hero": poses,
            "mini": {pose: [n + "_mini" for n in ns] for pose, ns in poses.items()},
            "eyelid": {pose: "%s_%s_eyelid_mini" % (character, pose) for pose in set(chara.BLINK_OF.values())}}


def make_final(folder, character="piyo"):
    """いまの絵の @3x を、chara-bake が書く形（hero/・mini/・まぶた）に並べる。

    まばたきの mini は、目を開けた mini の目のあたりだけを塗って作る。いまの絵のまばたきは Chrome が別の位置に
    描いたもので、目のまわりの外の縁もわずかに違う（README の「Chrome の描き方」）。chara-bake の絵は、目を開けた
    絵とまばたきの絵が同じ手順で作られ、目のまわりの外は同じなので、それに合わせる。
    """
    table = names(character)
    for pose, frames in chara.FRAMES:
        for index in range(len(frames)):
            for kind, source in (("hero", table["hero"][pose][index]), ("mini", table["mini"][pose][index])):
                target = final.frame_path(folder, kind, pose, index)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(bundled(source), target)
    for pose, name in table["eyelid"].items():
        opened, blinked = final.frame_path(folder, "mini", pose, 0), final.frame_path(folder, "mini", pose, 1)
        with Image.open(opened) as image:
            blink = image.convert("RGBA")
        blink.paste((59, 43, 43, 255), BLINK_PAINT)
        blink.save(blinked)
        art.eyelid(opened, blinked, final.eyelid_path(folder, pose), BLINK_REGION, final.FINAL_SCALE)


def rgba(path):
    with Image.open(path) as image:
        return numpy.array(image.convert("RGBA")).astype(float)


def over(top, bottom):
    """乗算を戻した RGBA どうしを重ねる（上が `top`）。"""
    top_alpha, bottom_alpha = top[:, :, 3:4] / 255, bottom[:, :, 3:4] / 255
    alpha = top_alpha + bottom_alpha * (1 - top_alpha)
    color = (top[:, :, :3] * top_alpha + bottom[:, :, :3] * bottom_alpha * (1 - top_alpha)) / numpy.maximum(alpha, 1e-6)
    return numpy.concatenate([color * (alpha > 0), alpha * 255], axis=2)


class FinalFolderTests(unittest.TestCase):

    def setUp(self):
        self.work = pathlib.Path(tempfile.mkdtemp())
        self.folder = self.work / "final"
        make_final(self.folder)

    def tearDown(self):
        shutil.rmtree(self.work)

    def load(self):
        return final.load(self.folder, chara.FRAMES, chara.BLINK_OF)

    def test_loads_every_frame(self):
        art = self.load()
        self.assertEqual({pose: len(paths) for pose, paths in art.heroes.items()},
                         {pose: len(frames) for pose, frames in chara.FRAMES})
        self.assertEqual(sorted(art.eyelids), ["idle", "sit"])

    def test_missing_folder_is_none(self):
        self.assertIsNone(final.load(self.work / "無い", chara.FRAMES, chara.BLINK_OF))

    def test_missing_wrong_size_and_extra_files_are_named(self):
        (self.folder / "hero" / "sit_02.png").unlink()
        with self.assertRaisesRegex(ValueError, "sit_02.png"):
            self.load()
        make_final(self.folder)
        Image.new("RGBA", (100, 100)).save(self.folder / "mini" / "walk_03.png")
        with self.assertRaisesRegex(ValueError, "walk_03.png の大きさ"):
            self.load()
        make_final(self.folder)
        shutil.copyfile(bundled("piyo_idle_01"), self.folder / "hero" / "idle_03.png")
        with self.assertRaisesRegex(ValueError, "idle_03.png"):
            self.load()

    def test_spare_frames_are_kept_out(self):
        spare = self.folder / final.SPARE_FOLDER / "hero"
        spare.mkdir(parents=True)
        shutil.copyfile(bundled("piyo_idle_01"), spare / "lookUp_01.png")
        self.assertIsNotNone(self.load())

    def bake(self):
        catalog_dir = self.work / "Characters.xcassets"
        work = self.work / "_work"
        catalog_dir.mkdir()
        work.mkdir()
        ambient = final.bake(self.load(), names("piyo"), CELLS, catalog_dir, work)
        return catalog_dir, ambient

    def test_bakes_three_scales_and_keeps_the_3x_bytes(self):
        catalog_dir, ambient = self.bake()
        self.assertEqual(ambient["eyelids"], {"idle": "piyo_idle_eyelid_mini", "sit": "piyo_sit_eyelid_mini"})
        self.assertFalse(ambient["sleepFrameCoversBase"])
        for name, cell in (("piyo_walk_03", CELLS["hero"]), ("piyo_walk_03_mini", CELLS["mini"])):
            for scale in (1, 2, 3):
                with Image.open(catalog_dir / ("%s.imageset" % name) / ("%s@%dx.png" % (name, scale))) as image:
                    self.assertEqual(image.size, (cell[0] * scale, cell[1] * scale))
        self.assertEqual(final.stale_files(self.load(), names("piyo"), catalog_dir), [])

    def test_eyelids_at_every_scale_turn_the_open_mini_into_the_blink(self):
        catalog_dir, _ = self.bake()
        for pose in ("idle", "sit"):
            for scale in (1, 2, 3):
                def png(name):
                    return catalog_dir / ("%s.imageset" % name) / ("%s@%dx.png" % (name, scale))
                opened = rgba(png("piyo_%s_01_mini" % pose))
                blinked = rgba(png("piyo_%s_02_mini" % pose))
                lid = rgba(png("piyo_%s_eyelid_mini" % pose))
                self.assertGreater((lid[:, :, 3] > 0).sum(), 0)
                visible = blinked[:, :, 3] > 0
                difference = numpy.abs(over(lid, opened) - blinked)[visible]
                self.assertLessEqual(difference.max(), 1, "%s @%dx" % (pose, scale))

    def test_stale_catalog_is_found(self):
        catalog_dir, _ = self.bake()
        shutil.copyfile(bundled("piyo_sit_01"), self.folder / "hero" / "idle_01.png")
        self.assertEqual(final.stale_files(self.load(), names("piyo"), catalog_dir), ["piyo_idle_01"])


if __name__ == "__main__":
    unittest.main()
