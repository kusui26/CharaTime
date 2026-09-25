# -*- coding: utf-8 -*-
"""画面収録から、ウィジェットの中の点滅を数える（プラン §9 Phase 3 の 3-0b・3-0d）。

`scripts/home-screen.sh record` が呼ぶ。**実機の画面収録にも使える**（写真アプリから Mac へ
送った .mov をそのまま渡す。402×874pt の iPhone なら、ウィジェットの位置はシミュレータと同じ）。

    python3 scripts/lib/count-frames.py 動画.mp4 --widgets .shots/home/widgets.json
    python3 scripts/lib/count-frames.py 動画.mov --slots small6          # 実機: 小 6 枠をまとめて
    python3 scripts/lib/count-frames.py 動画.mov --region 26.3,90,164.3,164.3 --name 左上の小

**何を数えるか。** 点灯の色（既定はスパイクの橙 #E08A4E）に近い画素のかたまりを「点」とし、
コマごとに点いているか消えているかを読む。点の位置は、収録の中で一度でも点いた所から自動で見つける。
点の並び方を知らなくてよいので、ウィジェットを作り替えても、このスクリプトは直さずに済む。
スパイクのウィジェットは 3-2c で消したので、既定の橙の点はもう出ない。数えるときは `--color` で色を渡す。

**戻った直後の測り方。** 収録の大半はホーム画面なので、コマの縮小画像の中央値を「ホーム画面の姿」とし、
それと大きく違うコマ（他のアプリが出ている・切り替えの途中）を「離れている」とみなす。離れていた後、
最初にホーム画面に戻ったコマから、最初に点が切り替わるまでの時間を「動き出しの遅れ」とする。

動画は 1 回だけ読み流す（メモリ 8 GB の機械で、コマを溜め込まないため）。ffmpeg と numpy が要る。
"""
import argparse
import json
import pathlib
import subprocess
import sys
from dataclasses import dataclass, field

import numpy as np

# 402×874pt の iPhone（iPhone 17 / 17 Pro）の画面。ウィジェットの枠は pt で受け取る。
SCREEN_POINTS = (402.0, 874.0)
# 同じ iPhone で測った、小ウィジェットの置き場所（pt。iOS 26.5。プラン §9 Phase 3 の 3-C ①）。
# 実機の画面収録を数えるときは、widgets.json の代わりにこれを使う（--slots small6）。
SMALL_SLOTS = {
    "labels": {"x": (26.33, 211.67), "y": (90.0, 290.67, 491.33), "size": 164.33},
    # 設定の「大きいアプリアイコン」でラベルを消したとき。
    "nolabels": {"x": (21.33, 211.33), "y": (90.0, 279.33, 468.67), "size": 169.67},
}
SLOT_NAMES = ("左上", "右上", "左中", "右中", "左下", "右下")
# スパイクの点灯の色 #E08A4E。動画に圧縮されると少しずれる（実機の収録では (218,125,67)）ので、許容幅で受ける。
DEFAULT_LIT_COLOR = (224, 138, 78)
DEFAULT_TOLERANCE = 40
# 点とみなす最小の大きさ（pt²）。スパイクの点は 22〜26pt 角なので、文字のかけらや縁のにじみを落とせる。
MIN_DOT_AREA = 60
# 点の画素のうち、この割合より多く点灯の色なら「点いている」。
LIT_FRACTION = 0.5
# ホーム画面の姿との違い（0〜255 の平均）がこれ未満なら、ホーム画面が出ているとみなす。
# シミュレータの収録では、他のアプリの画面は 20〜80、戻るアニメーションの途中は 3〜14、
# 落ち着いたホーム画面は 1〜3 だった（2026-09-23、スパイク E）。
HOME_DIFF_THRESHOLD = 14.0
# これ未満なら、戻るアニメーションも終わって落ち着いている。点を読むのは、落ち着いたコマだけ。
SETTLED_DIFF_THRESHOLD = 3.0
# 戻ってから、何秒のあいだの空白を「動き出しの遅れ」として見るか。
RESUME_WINDOW_SECONDS = 2.0
# ふだんの空白を代表させる値。たまのコマ落ち（シミュレータの収録は画面が変わったときだけコマを書く）を外す。
NATURAL_GAP_PERCENTILE = 95
# ホーム画面の姿を比べる縮小画像の間引き（pt ごと）。細部より全体の様子で見分ける。
THUMB_STEP = 8
# 「離れていた」とみなす最短の時間。切り替えの途中の 1〜2 コマの揺れを、行って戻ったと取り違えない。
MIN_AWAY_SECONDS = 0.3


@dataclass
class Region:
    """数える範囲（ウィジェット 1 つ）。枠は pt。"""
    name: str
    x: float
    y: float
    w: float
    h: float
    masks: list = field(default_factory=list)   # コマごとの「点灯の色か」（ビット詰め）

    def slice(self, frame):
        x0, y0 = int(round(self.x)), int(round(self.y))
        return frame[y0:y0 + int(round(self.h)), x0:x0 + int(round(self.w))]

    @property
    def shape(self):
        return int(round(self.h)), int(round(self.w))


# ---------------------------------------------------------------------------
# 入力
# ---------------------------------------------------------------------------

def parse_args(argv):
    parser = argparse.ArgumentParser(description="画面収録から、ウィジェットの中の点滅を数える")
    parser.add_argument("video", help="画面収録（.mp4 / .mov）")
    parser.add_argument("--widgets", help="scripts/home-screen.sh が書いた widgets.json")
    parser.add_argument("--widget", help="この文字を含むウィジェットだけ数える（表題など）")
    parser.add_argument("--region", help="数える範囲を pt で直接（x,y,幅,高さ）")
    parser.add_argument("--name", default="範囲", help="--region に付ける名前")
    parser.add_argument("--slots", choices=["small6"],
                        help="小ウィジェット 6 枠（2 列 × 3 段）を数える。実機の画面収録に使う")
    parser.add_argument("--no-labels", action="store_true",
                        help="--slots の位置を「大きいアプリアイコン」（ラベルなし）のものにする")
    parser.add_argument("--color", default=",".join(map(str, DEFAULT_LIT_COLOR)), help="点灯の色 R,G,B")
    parser.add_argument("--tolerance", type=int, default=DEFAULT_TOLERANCE, help="色の許容幅（各色 0〜255）")
    parser.add_argument("--json", help="結果を JSON で書き出す先")
    return parser.parse_args(argv)


def load_regions(args):
    """数える範囲を決める。--region > --slots > widgets.json（--widget で絞る）> 画面全体。"""
    if args.region:
        x, y, w, h = (float(v) for v in args.region.split(","))
        return [Region(args.name, x, y, w, h)]
    if args.slots:
        slots = SMALL_SLOTS["nolabels" if args.no_labels else "labels"]
        places = [(x, y) for y in slots["y"] for x in slots["x"]]
        return [Region(name, x, y, slots["size"], slots["size"]) for name, (x, y) in zip(SLOT_NAMES, places)]
    if args.widgets and pathlib.Path(args.widgets).exists():
        data = json.loads(pathlib.Path(args.widgets).read_text(encoding="utf-8"))
        regions = [Region(" / ".join(w["texts"][:1]) or w["family"], *w["frame"]) for w in data["widgets"]
                   if not args.widget or any(args.widget in text for text in w["texts"])]
        if regions:
            return regions
        sys.exit(f"widgets.json に「{args.widget}」を含むウィジェットがありません")
    return [Region("画面全体", 0, 0, *SCREEN_POINTS)]


# ---------------------------------------------------------------------------
# 動画
# ---------------------------------------------------------------------------

def probe(video):
    """画素の大きさ（回転を戻したあと）と、コマごとの時刻（秒）。"""
    info = json.loads(subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
         "stream=width,height:stream_side_data=rotation", "-of", "json", video],
        capture_output=True, text=True, check=True).stdout)["streams"][0]
    width, height = info["width"], info["height"]
    rotation = next((abs(int(d.get("rotation", 0))) for d in info.get("side_data_list", [])), 0)
    if rotation in (90, 270):
        width, height = height, width
    times = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "frame=pts_time",
         "-of", "csv=p=0", video], capture_output=True, text=True, check=True).stdout.split()
    return width, height, [float(t.strip(",")) for t in times if t.strip(",") not in ("", "N/A")]


def decode(video, points):
    """コマを 1 枚ずつ返す。画面全体を 1pt = 1 画素に縮める（点の大きさには十分で、軽い）。

    `-fps_mode passthrough` で、コマを足しも間引きもしない（ffprobe の時刻と 1 対 1 に並ぶ）。
    """
    width, height = int(points[0]), int(points[1])
    # シミュレータの収録は、画面が変わったときだけコマを書く（コマの間隔がまちまち）。生の画素で
    # 書き出すと ffmpeg が時刻の並びについて大量に警告するが、コマは欠けない（数は下で突き合わせる）。
    process = subprocess.Popen(
        ["ffmpeg", "-v", "fatal", "-i", video, "-fps_mode", "passthrough",
         "-vf", f"scale={width}:{height}:flags=area", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
        stdout=subprocess.PIPE)
    size = width * height * 3
    try:
        while True:
            chunk = process.stdout.read(size)
            if len(chunk) < size:
                break
            yield np.frombuffer(chunk, np.uint8).reshape(height, width, 3)
    finally:
        process.stdout.close()
        if process.wait() != 0:
            sys.exit(f"ffmpeg が動画を読めませんでした: {video}")


def lit_mask(pixels, color, tolerance):
    """点灯の色に近い画素。各色の差の最大で比べる（明るさだけ似た別の色を拾わない）。"""
    return (np.abs(pixels.astype(np.int16) - color).max(axis=2) <= tolerance)


# ---------------------------------------------------------------------------
# 点と、その切り替わり
# ---------------------------------------------------------------------------

def find_dots(region, steady):
    """ホーム画面が落ち着いているコマで一度でも点灯した画素のかたまりを、点として見つける（左上から順）。

    他のアプリ（設定のアイコンにも橙がある）や、切り替えの途中で縮んだり動いたりしている絵の画素を
    混ぜると、本物の点どうしがつながって 1 つのかたまりになり、点いているのに消えていると読んでしまう。
    """
    height, width = region.shape
    union = np.zeros((height, width), bool)
    for packed, is_steady in zip(region.masks, steady):
        if is_steady:
            union |= np.unpackbits(packed)[:height * width].reshape(height, width).astype(bool)
    dots = [component for component in components(union) if len(component[0]) >= MIN_DOT_AREA]
    return sorted(dots, key=lambda c: (round(c[0].mean() / 10), c[1].mean()))


def components(mask):
    """4 近傍でつながった画素のかたまり。各かたまりは (行の配列, 列の配列)。"""
    seen = np.zeros_like(mask)
    found = []
    for start in zip(*np.nonzero(mask)):
        if seen[start]:
            continue
        stack, rows, cols = [start], [], []
        seen[start] = True
        while stack:
            row, col = stack.pop()
            rows.append(row)
            cols.append(col)
            for d_row, d_col in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nxt = (row + d_row, col + d_col)
                if 0 <= nxt[0] < mask.shape[0] and 0 <= nxt[1] < mask.shape[1] and mask[nxt] and not seen[nxt]:
                    seen[nxt] = True
                    stack.append(nxt)
        found.append((np.array(rows), np.array(cols)))
    return found


def dot_states(region, dots):
    """コマ × 点 の「点いているか」。"""
    height, width = region.shape
    states = np.zeros((len(region.masks), len(dots)), bool)
    for index, packed in enumerate(region.masks):
        mask = np.unpackbits(packed)[:height * width].reshape(height, width)
        for dot_index, (rows, cols) in enumerate(dots):
            states[index, dot_index] = mask[rows, cols].mean() > LIT_FRACTION
    return states


def transitions(times, states, steady):
    """点ごとの切り替わり（時刻, 点いたか, ひと続きの番号）。落ち着いたホーム画面のコマだけで数える。

    「ひと続き」は、落ち着いたホーム画面が途切れずに出ていたあいだ。間隔や点灯の長さは、同じひと続きの
    中でだけ測る（他のアプリに行っていたあいだを、長い間隔と取り違えない）。
    """
    segment_of = np.cumsum(np.concatenate([[1], np.diff(steady.astype(int)) == 1]))
    result = []
    for dot in range(states.shape[1]):
        events, last = [], None
        for time, state, is_steady, segment in zip(times, states[:, dot], steady, segment_of):
            if not is_steady:
                last = None
                continue
            if last is not None and state != last:
                events.append((round(time, 4), bool(state), int(segment)))
            last = state
        result.append(events)
    return result


def spread(values):
    if not values:
        return None
    array = np.array(values)
    return {"n": len(values), "mean": round(float(array.mean()), 3),
            "min": round(float(array.min()), 3), "max": round(float(array.max()), 3)}


def describe_dot(events):
    """1 つの点の切り替わりの間隔、点いている長さ、1 秒の中のどこで切り替わるか（位相）。"""
    times = [time for time, _, _ in events]
    pairs = [(a, b) for a, b in zip(events, events[1:]) if a[2] == b[2]]   # 同じひと続きの中だけ
    intervals = [b[0] - a[0] for a, b in pairs]
    on_lengths = [b[0] - a[0] for a, b in pairs if a[1] and not b[1]]
    phase = None
    if times:
        # 1 秒の中の位置を、円の上の平均で取る（0.99 秒と 0.01 秒を平均して 0.5 秒にしない）。
        angles = np.array(times) % 1.0 * 2 * np.pi
        phase = round(float(np.angle(np.exp(1j * angles).mean()) / (2 * np.pi) % 1.0), 3)
    return {"changes": len(events), "interval": spread(intervals), "on": spread(on_lengths), "phase": phase}


# ---------------------------------------------------------------------------
# 行って戻る
# ---------------------------------------------------------------------------

def home_flags(thumbs):
    """コマごとに「ホーム画面が出ているか」。収録の大半はホーム画面なので、中央値を姿とする。"""
    stack = np.stack(thumbs).astype(np.int16)
    reference = np.median(stack, axis=0)
    differences = np.abs(stack - reference).mean(axis=(1, 2, 3))
    return differences < HOME_DIFF_THRESHOLD, differences


def returns_home(times, home, steady):
    """離れていたあと、ホーム画面に戻って落ち着いた最初のコマの時刻。"""
    moments, away_since, returning = [], None, False
    for time, at_home, is_steady in zip(times, home, steady):
        if not at_home:
            away_since = time if away_since is None else away_since
            returning = False
        elif away_since is not None:
            returning = time - away_since >= MIN_AWAY_SECONDS
            away_since = None
        if returning and is_steady:
            moments.append(time)
            returning = False
    return moments


def natural_gap(all_events, moments):
    """ふだんの「切り替わりどうしの最長の空白」。戻った直後を除いた、落ち着いたあいだで測る。

    4 本を 0.25 秒ずつずらしたウィジェットなら 0.25 秒前後になる。戻った直後の空白が
    これより長ければ、そのぶんだけ動き出しが遅れている。空白は同じひと続きの中でだけ測る
    （他のアプリに行っていたあいだを、ふだんの空白に数えない）。たまのコマ落ちに引きずられないよう、
    いちばん長いものではなく 95 パーセンタイルを取る。
    """
    changes = sorted({(segment, time) for events in all_events for time, _, segment in events
                      if not any(0 <= time - moment < RESUME_WINDOW_SECONDS for moment in moments)})
    gaps = [b[1] - a[1] for a, b in zip(changes, changes[1:]) if a[0] == b[0]]
    return round(float(np.percentile(gaps, NATURAL_GAP_PERCENTILE)), 3) if gaps else None


def resume_delays(moments, all_events):
    """戻って落ち着いた瞬間から、最初にどれかの点が切り替わるまで。と、その後 2 秒の中の最長の空白。"""
    delays = []
    for moment in moments:
        changes = sorted({time for events in all_events for time, _, _ in events
                          if moment <= time < moment + RESUME_WINDOW_SECONDS})
        marks = [moment] + changes
        delays.append({"home_at": round(moment, 3),
                       "first_change": round(changes[0] - moment, 3) if changes else None,
                       "longest_gap": round(max(b - a for a, b in zip(marks, marks[1:])), 3)
                       if changes else None})
    return delays


# ---------------------------------------------------------------------------
# まとめ
# ---------------------------------------------------------------------------

def measure(args):
    regions = load_regions(args)
    color = np.array([int(v) for v in args.color.split(",")], np.int16)
    width, height, times = probe(args.video)
    thumbs = []
    for frame in decode(args.video, SCREEN_POINTS):
        thumbs.append(frame[::THUMB_STEP, ::THUMB_STEP].copy())
        for region in regions:
            region.masks.append(np.packbits(lit_mask(region.slice(frame), color, args.tolerance)))
    count = min(len(times), len(thumbs))
    if len(times) != len(thumbs):
        print(f"   ! コマの数が合いません（時刻 {len(times)}・画素 {len(thumbs)}）。少ないほうに合わせます", file=sys.stderr)
    times = [t - times[0] for t in times[:count]]
    home, differences = home_flags(thumbs[:count])
    steady = differences < SETTLED_DIFF_THRESHOLD
    moments = returns_home(times, home, steady)
    result = {"video": args.video, "pixels": [width, height], "frames": count,
              "seconds": round(times[-1], 3) if times else 0, "home_frames": int(home.sum()),
              "steady_frames": int(steady.sum()), "returns_home": [round(m, 3) for m in moments], "widgets": []}
    for region in regions:
        region.masks = region.masks[:count]
        dots = find_dots(region, steady)
        events = transitions(times, dot_states(region, dots), steady)
        result["widgets"].append({
            "name": region.name, "frame_pt": [region.x, region.y, region.w, region.h],
            "dots": [dict(center_pt=[round(float(c.mean()) + region.x, 1), round(float(r.mean()) + region.y, 1)],
                          area_pt=len(r), **describe_dot(e)) for (r, c), e in zip(dots, events)],
            "natural_gap": natural_gap(events, moments),
            "resumes": resume_delays(moments, events),
            "events": [[list(e) for e in dot_events] for dot_events in events],
        })
    return result


def print_summary(result):
    fps = result["frames"] / result["seconds"] if result["seconds"] else 0
    print(f"   {result['frames']} コマ・{result['seconds']:.1f} 秒（平均 {fps:.0f}fps）・"
          f"落ち着いたホーム画面のコマ {result['steady_frames']}・戻った回数 {len(result['returns_home'])}")
    for widget in result["widgets"]:
        print(f"   ■ {widget['name']}  点 {len(widget['dots'])} 個")
        for index, dot in enumerate(widget["dots"], 1):
            interval, on = dot["interval"] or {}, dot["on"] or {}
            print(f"     {index:>2}. 切替 {dot['changes']:>3} 回  間隔 {interval.get('mean', '-')} 秒"
                  f"（{interval.get('min', '-')}〜{interval.get('max', '-')}）  点灯 {on.get('mean', '-')} 秒"
                  f"  位相 {dot['phase']}")
        if widget["resumes"]:
            print(f"     ふだんの最長の空白 {widget['natural_gap']} 秒（戻った直後を除く、95 パーセンタイル）")
        for resume in widget["resumes"]:
            first, longest = resume["first_change"], resume["longest_gap"]
            print(f"     戻った {resume['home_at']:6.2f} 秒 → 最初の切替まで "
                  f"{'-' if first is None else f'{first:.3f}'} 秒・2 秒の中の最長の空白 "
                  f"{'-' if longest is None else f'{longest:.3f}'} 秒")


def main(argv):
    args = parse_args(argv)
    result = measure(args)
    print_summary(result)
    if args.json:
        pathlib.Path(args.json).write_text(json.dumps(result, ensure_ascii=False, indent=1), encoding="utf-8")
        print(f"   結果: {args.json}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
