# -*- coding: utf-8 -*-
"""Asset Catalog と、同梱データ JSON の書き出し。

Asset Catalog（`.xcassets`）は Xcode が実機向けにビルドするとき actool が
`Assets.car` に畳んでくれる。macOS の `swift build` では畳まれず、そのまま
コピーされるだけなので、**macOS のテストで「絵が読めるか」は確かめられない**。
代わりに「JSON が呼ぶ名前に対応する imageset が全部あるか」を
CTAssets のテストが見る（参照切れの検出）。
"""
import json
import pathlib

# 実機は @2x と @3x しか使わないが、@1x も置く。macOS のプレビューや
# Xcode のインスペクタが @1x を求めることがあるため。
SCALES = [(1, "@1x"), (2, "@2x"), (3, "@3x")]

_CATALOG_ROOT = {"info": {"author": "charatime-pipeline", "version": 1}}


def write_catalog_root(catalog_dir):
    _write_json(pathlib.Path(catalog_dir) / "Contents.json", _CATALOG_ROOT)


def write_imageset(catalog_dir, name, image_paths):
    """1 つの絵の imageset を作り、PNG を中へ移す。

    `image_paths` は (倍率, PNG のパス) の並び。
    """
    imageset = pathlib.Path(catalog_dir) / ("%s.imageset" % name)
    imageset.mkdir(parents=True, exist_ok=True)
    images = []
    for scale, source in image_paths:
        filename = source.name
        source.replace(imageset / filename)
        images.append({"filename": filename, "idiom": "universal", "scale": "%dx" % scale})
    _write_json(imageset / "Contents.json", {
        "images": images,
        "info": {"author": "charatime-pipeline", "version": 1},
        # ウィジェットの脱色表示でも元の色を保てるように、テンプレート化させない。
        "properties": {"template-rendering-intent": "original"},
    })
    return imageset


def update_characters(json_path, poses_by_character, geometry):
    """`characters.json` のコマ一覧と、絵の枠の情報を差し替える。

    **性格や表示名は人が調整した値なので触らない。** パイプラインが持つのは
    「どの姿勢に何枚あるか」と「絵のどこが足元か」だけで、
    それ以外は既にある JSON を尊重する。
    """
    return _update_json(json_path, "characters", poses_by_character,
                        lambda entry, value: entry.__setitem__("poses", value),
                        top_level={"spriteGeometry": geometry})


def update_items(json_path, asset_by_item, aspect_by_item):
    """`items.json` のアセット名と縦横比を差し替える。"""
    def apply(entry, value):
        entry["assetName"] = value
        entry["aspectRatio"] = aspect_by_item[entry["id"]]
    return _update_json(json_path, "items", asset_by_item, apply)


def _update_json(json_path, key, values_by_id, apply_value, top_level=None):
    path = pathlib.Path(json_path)
    document = json.loads(path.read_text(encoding="utf-8"))
    known = {entry["id"] for entry in document[key]}
    missing = [i for i in values_by_id if i not in known]
    if missing:
        raise ValueError("%s に無い id があります: %s" % (path.name, missing))
    for entry in document[key]:
        if entry["id"] in values_by_id:
            apply_value(entry, values_by_id[entry["id"]])
    document.update(top_level or {})
    _write_json(path, document)
    return path


def _write_json(path, document):
    # 並びを固定して書く。生成し直しても中身が同じなら git の差分が出ない。
    text = json.dumps(document, ensure_ascii=False, indent=2, sort_keys=True)
    pathlib.Path(path).write_text(text + "\n", encoding="utf-8")
