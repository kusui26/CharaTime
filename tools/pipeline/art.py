# -*- coding: utf-8 -*-
"""ウィジェットの疑似アニメのための、絵から決まること（プラン §9 Phase 3 の 3-C ⑫、3-2b）。

- **まぶたの差分**: まばたきの絵のうち、目を開けた絵と違う画素だけを残した絵。目を開けた絵の上に
  重ねるとまばたきの絵になる（土台＋差分。D-17）。比べるのは目を描く範囲の中だけ
  （design/chara.py の EYE_REGION）。範囲の外にも描き直しの揺れがあり、拾うと羽の縁がちらつく
- **寝息の 2 コマ目が 1 コマ目を覆えるか**: 覆えるなら 1 コマ目を土台にして 2 コマ目だけを重ねる
  （タイマー 1 本）。覆えないなら 2 枚を出し分ける（2 本）
"""
from PIL import Image, ImageChops, ImageFilter

# まぶたの差分を、違う画素から外へ何画素ぶん広げるか（@1x の画素。倍率ぶん大きくする）。
# 重ねた絵と土台は同じ枠で描くが、縮めて描くときの補間で、差分の縁に土台の画素が透けて
# 細い輪が出る。縁を、土台と同じ色の画素の上まで少し広げておけば、輪は見えない。
EYELID_DILATION_POINTS = 1
# 覆えるかの判定で、見える画素とみなす不透明さ（0〜255）。縁のぼかしの薄い画素は数えない。
OPAQUE_THRESHOLD = 128


def eyelid(open_path, blink_path, out_path, region, scale):
    """まぶたの差分を書き出す。`region` は画素の (左, 上, 右, 下)、`scale` は @Nx の N。

    違う画素が無ければ何も書かずに False を返す。
    """
    with Image.open(open_path) as opened, Image.open(blink_path) as blinked:
        base = opened.convert("RGBA")
        blink = blinked.convert("RGBA")
    changed = _difference_mask(base, blink)
    inside = Image.new("L", base.size, 0)
    inside.paste(255, region)
    changed = ImageChops.multiply(changed, inside)
    if changed.getbbox() is None:
        return False
    grow = 2 * EYELID_DILATION_POINTS * scale + 1
    area = ImageChops.multiply(changed.filter(ImageFilter.MaxFilter(grow)), inside)
    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    overlay.paste(blink, (0, 0), area)
    overlay.save(out_path, "PNG", optimize=True)
    return True


def covers(bottom_path, top_path):
    """`top` を重ねたとき、`bottom` の見える画素がすべて隠れるか（はみ出す画素が無いか）。"""
    with Image.open(bottom_path) as bottom_image, Image.open(top_path) as top_image:
        bottom = bottom_image.convert("RGBA").getchannel("A")
        top = top_image.convert("RGBA").getchannel("A")
    visible = bottom.point(lambda alpha: 255 if alpha >= OPAQUE_THRESHOLD else 0)
    hidden = top.point(lambda alpha: 255 if alpha >= OPAQUE_THRESHOLD else 0)
    sticking_out = ImageChops.subtract(visible, hidden)
    return sticking_out.getbbox() is None


def _difference_mask(first, second):
    """色か不透明さが 1 でも違う画素を 255 にした白黒の絵。"""
    difference = ImageChops.difference(first, second)
    channels = difference.split()
    merged = channels[0]
    for channel in channels[1:]:
        merged = ImageChops.lighter(merged, channel)
    return merged.point(lambda value: 255 if value > 0 else 0)

