# -*- coding: utf-8 -*-
"""CharaTime キャラクター SVG ジェネレータ（画風「まるっとフラット」）
   viewBox 0 0 120 170 / 接地線 y=163 / 身長は頭頂 y=20..足元 y=163"""

OUT = "#3B2B2B"   # 輪郭線
SW  = 5           # 線幅

# --- 書き出す枠 -----------------------------------------------------
# 絵そのものは viewBox 0 0 120 170・接地線 y=163 で描く。
# ただし **とさか・アンテナ・頭のとんがりは輪郭線の太さのぶん枠の外へ出る**ので、
# そのまま焼くと上端が切れる。四方に余白を足した枠で書き出す。
PAD = 5
VIEWBOX = (-PAD, -PAD, 120 + PAD * 2, 170 + PAD * 2)
GROUND_Y = 163
# 絵の上端から接地線までの割合。**アプリはこの値で足元を床に合わせる。**
GROUND_RATIO = (GROUND_Y + PAD) / (170 + PAD * 2)
# 枠の縦横比（幅 ÷ 高さ）。
ASPECT = (120 + PAD * 2) / (170 + PAD * 2)

# 5 体のパレット
P = {
  "piyo":  dict(name="ピヨ",   body="#FFE066", sub="#FFCF4D", acc="#FF9F43", cheek="#FFB3C6", shade="#F3CC44"),
  "mochi": dict(name="モチ",   body="#FFF6EE", sub="#FFEADD", acc="#FFC9D9", cheek="#FFB3C6", shade="#F6E6D8"),
  "kumao": dict(name="クマオ", body="#C89464", sub="#B8814F", acc="#F2DCC2", cheek="#E79A86", shade="#B98756"),
  "fuwa":  dict(name="フワ",   body="#C9BCEA", sub="#B7A6E0", acc="#F3EEFB", cheek="#E3B6D8", shade="#BBACE2"),
  "chip":  dict(name="チップ", body="#A8E0D2", sub="#93D3C2", acc="#9AA6B4", cheek="#8FD0BE", shade="#97D6C6"),
}

# --- 共通シルエット -------------------------------------------------
BODY = ("M60 20 C86 20 105 39 105 65 C105 81 99 94 89 102 "
        "C93 109 95 118 95 126 C95 144 80 156 60 156 "
        "C40 156 25 144 25 126 C25 118 27 109 31 102 "
        "C21 94 15 81 15 65 C15 39 34 20 60 20 Z")
BODY_SIT = ("M60 34 C86 34 105 53 105 79 C105 95 99 108 89 116 "
            "C97 122 101 131 101 138 C101 151 83 158 60 158 "
            "C37 158 19 151 19 138 C19 131 23 122 31 116 "
            "C21 108 15 95 15 79 C15 53 34 34 60 34 Z")
# 横向き（左向き）: くちばし側がすぼまる
BODY_SIDE = ("M63 20 C89 20 108 39 108 65 C108 81 102 94 92 102 "
             "C96 109 98 118 98 126 C98 144 83 156 63 156 "
             "C43 156 28 144 28 126 C28 118 30 109 34 102 "
             "C24 94 18 81 18 65 C18 39 37 20 63 20 Z")
# 寝そべり（左が頭・右が胴）
BODY_SLEEP = ("M44 84 C61 84 75 97 75 113 C83 105 96 104 104 114 "
              "C113 125 108 145 91 150 C79 154 64 152 56 145 "
              "C47 150 31 149 21 140 C12 132 8 120 11 107 C15 92 27 84 44 84 Z")
# フワ（裾がひらひら・足なし）。
# 裾の谷は二次ベジエなので、制御点 167 でも実際に下がるのは 161 まで。
# 接地線 y=163 に届く長さにしてある（短いと浮いて見える）。
BODY_FUWA = ("M60 20 C86 20 105 39 105 65 C105 81 99 94 89 102 "
             "C93 109 96 119 96 128 L96 155 "
             "Q87 167 78 155 Q69 143 60 155 Q51 167 42 155 Q33 143 24 155 "
             "L24 128 C24 119 27 109 31 102 C21 94 15 81 15 65 C15 39 34 20 60 20 Z")

# --- コマ割り -------------------------------------------------------
# 待受モードで使う 11 枚。**枚数と順番の唯一の出どころ**で、
# tools/pipeline と design/build.py の両方がここを読む。
# 姿勢名は CTCore の Pose と一致させること。
FRAMES = [
    ("idle",  ["idle", "blink"]),                          # 立つ（まばたき）
    ("walk",  ["walk", "walkpass", "walk2", "walkpass2"]),  # 歩く（接地→中間→接地→中間）
    ("sit",   ["sit"]),
    ("sleep", ["sleep", "sleep2"]),                        # ねる（ゆっくり呼吸）
    ("happy", ["happy", "happy2"]),                        # よろこぶ（跳ねる）
]

# 歩きの 4 コマの足の位置 (奥の足 x, y, 手前の足 x, y)。
# **左を向いて歩くので x が小さいほど前。** 接地 → 中間 → 接地（逆足）→ 中間 の順に
# 足が入れ替わる。中間コマは足をそろえる（上下の揺れはアプリが sin で足す）。
WALK_FEET = {
    "walk":      (86, 157, 38, 157),
    "walkpass":  (70, 156, 56, 158),
    "walk2":     (44, 157, 82, 157),
    "walkpass2": (56, 158, 70, 156),
}
SIDE_POSES = set(WALK_FEET) | {"side"}

# 顔の作りが同じコマをまとめる。walkpass は walk と、happy2 は happy と同じ顔。
FACE_OF = {"walkpass": "walk", "walkpass2": "walk", "happy2": "happy", "sleep2": "sleep"}

WING_L  = "M33 110 C15 111 6 125 13 136 C20 145 33 141 37 131 Z"
WING_R  = "M87 110 C105 111 114 125 107 136 C100 145 87 141 83 131 Z"
WING_UP_L = "M34 107 C17 96 5 103 6 115 C9 126 24 126 33 117 Z"
WING_UP_R = "M86 107 C103 96 115 103 114 115 C111 126 96 126 87 117 Z"
# フワの横向き。裾のひらひらを残したまま、くちばし側をすぼめる。
#
# **フワには足が無いので、歩きの 4 コマを足の位置では描き分けられない。**
# 代わりに裾の波を phase でずらして波打たせる（`_body_side_fuwa`）。
# フワの裾の高さの基準。接地線 y=163 に谷が届く値。
HEM_BASE = 155
# 寝そべりを接地線まで落とす量。
SLEEP_DROP = 3


def _body_side_fuwa(phase=0.0):
    """フワの横向きの体。`phase` は裾の波の位相（0〜2 で 1 周）。

    山と谷の間隔をわざと半波長からずらしてある（0.75π）。ちょうど半波長だと
    位相を 4 分の 1 動かしたときに裾が一直線になり、4 コマのうち 2 コマが
    同じ形（ひらひらの無い裾）になってしまう。
    """
    import math
    hem = ""
    for i, x in enumerate([90, 72, 54, 36]):
        y = HEM_BASE + 12 * math.cos(0.75 * math.pi * i + math.pi * phase)
        hem += "Q%g %g %g %g " % (x, y, x - 9, HEM_BASE)
    return ("M63 20 C89 20 108 39 108 65 C108 81 102 94 92 102 "
            "C96 109 99 119 99 128 L99 %g " % HEM_BASE + hem +
            "L27 128 C27 119 30 109 34 102 C24 94 18 81 18 65 C18 39 37 20 63 20 Z")

# 歩きの 4 コマでの、フワの裾の位相と、横向きの羽の振り（度）。
# 羽は肩（68,115）を中心に回す。前に出した足と逆の羽が前に出ると自然に見える。
WALK_FUWA_PHASE = {"walk": 0.0, "walkpass": 0.5, "walk2": 1.0, "walkpass2": 1.5}
WALK_WING_ANGLE = {"walk": 10, "walkpass": 0, "walk2": -10, "walkpass2": 0}

WING_SIDE = "M70 112 C86 114 93 129 86 139 C78 145 68 138 66 128 Z"

def _g(inner, fill=None):
    return ('<g stroke="%s" stroke-width="%d" stroke-linejoin="round" stroke-linecap="round">%s</g>'
            % (OUT, SW, inner))

def _feet(c, y=156, lx=47, rx=73, far=False):
    p = P[c]
    s = ''
    if far:
        s += '<ellipse cx="%g" cy="%g" rx="12" ry="7" fill="%s"/>' % (rx, y-2, p["shade"])
    else:
        s += '<ellipse cx="%g" cy="%g" rx="12" ry="7" fill="%s"/>' % (rx, y, p["acc"] if c=="piyo" else p["sub"])
    s += '<ellipse cx="%g" cy="%g" rx="12" ry="7" fill="%s"/>' % (lx, y, p["acc"] if c=="piyo" else p["sub"])
    return s

def _topper(c, side=False):
    """頭の突起（キャラ固有の識別要素）"""
    p = P[c]
    dx = 4 if side else 0
    if c == "piyo":     # とさか
        return '<path d="M%g 22 C%g 12 %g 4 %g 6 C%g 11 %g 18 %g 23 Z" fill="%s"/>' % (
            63+dx, 58+dx, 63+dx, 71+dx, 76+dx, 73+dx, 63+dx, p["sub"])
    if c == "mochi":    # 三角耳
        return ('<path d="M30 37 L26 15 L48 27 Z" fill="%s"/><path d="M90 37 L94 15 L72 27 Z" fill="%s"/>'
                % (p["body"], p["body"]))
    if c == "kumao":    # まる耳
        return ('<circle cx="27" cy="31" r="14" fill="%s"/><circle cx="93" cy="31" r="14" fill="%s"/>'
                % (p["body"], p["body"]))
    if c == "fuwa":     # 頭のとんがり
        return '<path d="M60 22 C54 10 58 0 66 1 C73 6 70 16 60 23 Z" fill="%s"/>' % p["sub"]
    if c == "chip":     # アンテナ
        return ('<path d="M60 22 L60 12" fill="none"/><circle cx="60" cy="7" r="6.5" fill="%s"/>' % p["acc"])
    return ''

def _topper_deco(c):
    p = P[c]
    if c == "mochi":
        return '<path d="M36 35 L33 21 L45 28 Z" fill="%s"/><path d="M84 35 L87 21 L75 28 Z" fill="%s"/>' % (p["acc"], p["acc"])
    if c == "kumao":
        return '<circle cx="27" cy="31" r="7" fill="%s"/><circle cx="93" cy="31" r="7" fill="%s"/>' % (p["acc"], p["acc"])
    return ''

def _mouth(c, kind="idle", side=False):
    p = P[c]
    if c == "piyo":
        if side:
            return '<path d="M18 68 L2 75 L18 82 Z" fill="%s"/>' % p["acc"]
        y = 72 if kind != "happy" else 74
        w = 7 if kind != "happy" else 9
        return '<path d="M%g %g L%g %g L60 %g Z" fill="%s"/>' % (60-w, y, 60+w, y, y+10, p["acc"])
    if c == "kumao":   # マズル
        cx = 32 if side else 60
        return ('<ellipse cx="%g" cy="78" rx="18" ry="13" fill="%s" stroke="%s" stroke-width="%d"/>'
                % (cx, p["acc"], OUT, SW))
    return ''

def _mouth_line(c, kind="idle", side=False):
    if c == "piyo": return ''
    dx = -28 if side else 0
    if c == "kumao":
        return ('<path d="M%g 78 Q%g 84 %g 78" stroke="%s" stroke-width="4" fill="none" stroke-linecap="round"/>'
                % (54+dx, 60+dx, 66+dx, OUT))
    if kind == "happy":
        return ('<path d="M%g 76 Q%g 87 %g 76" stroke="%s" stroke-width="4" fill="none" stroke-linecap="round"/>'
                % (52+dx, 60+dx, 68+dx, OUT))
    return ('<path d="M%g 75 Q%g 82 %g 75" stroke="%s" stroke-width="4" fill="none" stroke-linecap="round"/>'
            % (53+dx, 60+dx, 67+dx, OUT))

def _eyes(kind="idle", side=False):
    if side:
        if kind in ("sleep","happy"):
            return '<path d="M34 63 Q40 70 46 63" stroke="%s" stroke-width="4.5" fill="none" stroke-linecap="round"/>' % OUT
        return '<circle cx="40" cy="64" r="6.5" fill="%s"/><circle cx="42.3" cy="61.7" r="2" fill="#fff"/>' % OUT
    if kind == "blink":
        return ('<path d="M38 65 Q44 71 50 65" stroke="%s" stroke-width="4.5" fill="none" stroke-linecap="round"/>'
                '<path d="M70 65 Q76 71 82 65" stroke="%s" stroke-width="4.5" fill="none" stroke-linecap="round"/>' % (OUT, OUT))
    if kind in ("happy","sleep"):
        d = 'M38 67 Q44 59 50 67' if kind=="happy" else 'M38 63 Q44 70 50 63'
        d2 = 'M70 67 Q76 59 82 67' if kind=="happy" else 'M70 63 Q76 70 82 63'
        return ('<path d="%s" stroke="%s" stroke-width="4.5" fill="none" stroke-linecap="round"/>'
                '<path d="%s" stroke="%s" stroke-width="4.5" fill="none" stroke-linecap="round"/>' % (d, OUT, d2, OUT))
    return ('<circle cx="44" cy="64" r="6.5" fill="%s"/><circle cx="76" cy="64" r="6.5" fill="%s"/>'
            '<circle cx="46.3" cy="61.7" r="2" fill="#fff"/><circle cx="78.3" cy="61.7" r="2" fill="#fff"/>' % (OUT, OUT))

def _cheeks(c, side=False):
    p = P[c]
    if side:
        return '<ellipse cx="34" cy="80" rx="8" ry="5" fill="%s"/>' % p["cheek"]
    return ('<ellipse cx="30" cy="80" rx="8.5" ry="5.5" fill="%s"/>'
            '<ellipse cx="90" cy="80" rx="8.5" ry="5.5" fill="%s"/>' % (p["cheek"], p["cheek"]))

def _panel(c):
    """チップの胸パネル"""
    if c != "chip": return ''
    p = P["chip"]
    return ('<rect x="46" y="116" width="28" height="20" rx="6" fill="%s" stroke="%s" stroke-width="4"/>'
            '<circle cx="54" cy="126" r="2.6" fill="%s"/><circle cx="66" cy="126" r="2.6" fill="%s"/>'
            % (p["sub"], OUT, OUT, p["acc"]))

def sprite(c, pose="idle", uid="a"):
    """1 体分の <g> を返す"""
    p = P[c]
    acc = p["acc"] if c == "piyo" else p["sub"]
    face = FACE_OF.get(pose, pose)          # 顔の作りは同系のコマで共通
    side = pose in SIDE_POSES

    body = BODY
    if c == "fuwa": body = BODY_FUWA
    if pose == "sit": body = BODY_SIT
    if side:
        body = _body_side_fuwa(WALK_FUWA_PHASE.get(pose, 0.0)) if c == "fuwa" else BODY_SIDE
    if face == "sleep": body = BODY_SLEEP

    # ---- 寝そべり ------------------------------------------------
    if face == "sleep":
        inner = ""
        if c == "piyo":
            inner += '<path d="M40 86 C34 77 37 69 45 70 C51 75 49 82 40 87 Z" fill="%s"/>' % p["sub"]
        elif c == "mochi":
            inner += ('<path d="M18 100 L8 82 L31 88 Z" fill="%s"/><path d="M52 88 L58 70 L36 79 Z" fill="%s"/>'
                      % (p["body"], p["body"]))
        elif c == "kumao":
            inner += ('<circle cx="16" cy="97" r="13" fill="%s"/><circle cx="50" cy="85" r="13" fill="%s"/>'
                      % (p["body"], p["body"]))
        elif c == "fuwa":
            inner += '<path d="M40 86 C32 76 35 66 43 67 C50 72 48 81 40 87 Z" fill="%s"/>' % p["sub"]
        elif c == "chip":
            inner += '<path d="M40 86 L36 77" fill="none"/><circle cx="34" cy="72" r="6" fill="%s"/>' % p["acc"]
        inner += '<ellipse cx="96" cy="151" rx="11" ry="6.5" fill="%s"/>' % acc
        inner += '<path d="%s" fill="%s"/>' % (body, p["body"])
        inner += '<path d="M72 118 C86 118 94 130 89 140 C82 147 70 141 68 131 Z" fill="%s"/>' % p["sub"]
        if c == "piyo":
            inner += '<path d="M13 108 L1 114 L13 121 Z" fill="%s"/>' % p["acc"]
        g = _g(inner)
        if c == "kumao":
            g += '<circle cx="16" cy="97" r="6.5" fill="%s"/><circle cx="50" cy="85" r="6.5" fill="%s"/>' % (p["acc"], p["acc"])
        if c == "mochi":
            g += '<path d="M22 97 L15 85 L29 89 Z" fill="%s"/><path d="M50 89 L54 78 L40 83 Z" fill="%s"/>' % (p["acc"], p["acc"])
        g += '<ellipse cx="30" cy="129" rx="8" ry="5" fill="%s"/>' % p["cheek"]
        g += '<path d="M28 112 Q34 119 40 112" stroke="%s" stroke-width="4.5" fill="none" stroke-linecap="round"/>' % OUT
        # 寝そべりの silhouette は下端が y=156 あたりで、接地線 y=163 に 3 単位届かない。
        # 落としておかないと、影の上に浮いて見える。
        drop = SLEEP_DROP + (2.25 if pose == "sleep2" else 0)
        squash = " scale(1 0.985)" if pose == "sleep2" else ""
        return '<g transform="translate(0 %g)%s">%s</g>' % (drop, squash, g)

    # ---- 立ち・歩き・座り・喜ぶ ----------------------------------
    inner = ""
    inner += _topper(c, side)
    if c != "fuwa":
        if pose in WALK_FEET:
            fx, fy, _, _ = WALK_FEET[pose]
            inner += '<ellipse cx="%g" cy="%g" rx="12" ry="7" fill="%s"/>' % (fx, fy, p["shade"])
        elif pose == "happy":
            inner += _feet(c, y=154, lx=43, rx=77)
        elif pose == "happy2":
            # 着地したところ。跳ねているコマより足を少し外へ開いて低くする。
            inner += _feet(c, y=157, lx=41, rx=79)
        elif pose != "sit":
            inner += _feet(c)
    # 羽
    if pose == "happy":
        inner += '<path d="%s" fill="%s"/><path d="%s" fill="%s"/>' % (WING_UP_L, p["sub"], WING_UP_R, p["sub"])
    elif pose == "happy2":
        # 羽を下ろしたコマ。上げたコマと交互に出すと、羽ばたいて見える。
        inner += '<path d="%s" fill="%s"/><path d="%s" fill="%s"/>' % (WING_L, p["sub"], WING_R, p["sub"])
    elif pose == "sit":
        inner += ('<path d="M33 124 C17 125 9 138 16 148 C23 156 35 152 39 142 Z" fill="%s"/>'
                  '<path d="M87 124 C103 125 111 138 104 148 C97 156 85 152 81 142 Z" fill="%s"/>' % (p["sub"], p["sub"]))
    else:
        inner += '<path d="%s" fill="%s"/><path d="%s" fill="%s"/>' % (WING_L, p["sub"], WING_R, p["sub"])
    # 本体
    inner += '<path d="%s" fill="%s"/>' % (body, p["body"])
    if side:
        # 歩くコマでは羽を前後に振る。肩を軸にするので付け根がずれない。
        angle = WALK_WING_ANGLE.get(pose, 0)
        wing = '<path d="%s" fill="%s"/>' % (WING_SIDE, p["sub"])
        inner += '<g transform="rotate(%g 68 115)">%s</g>' % (angle, wing) if angle else wing
    # 手前の足（奥の足より明るい色で、前後関係を出す）
    if pose in WALK_FEET and c != "fuwa":
        _, _, nx, ny = WALK_FEET[pose]
        inner += '<ellipse cx="%g" cy="%g" rx="12" ry="7" fill="%s"/>' % (nx, ny, acc)
    elif pose == "sit" and c != "fuwa":
        inner += ('<ellipse cx="38" cy="152" rx="13" ry="7.5" fill="%s"/>'
                  '<ellipse cx="82" cy="152" rx="13" ry="7.5" fill="%s"/>' % (acc, acc))
    inner += _mouth(c, face, side)
    g = _g(inner)
    g += _topper_deco(c)
    g += _panel(c)
    g += _cheeks(c, side)
    g += _eyes(face if pose != "blink" else "blink", side)
    g += _mouth_line(c, face, side)
    return g

def svg(c, pose="idle", w=None, h=None, uid="a", extra=""):
    """1 体分の SVG。既定の大きさは書き出す枠と同じ。"""
    vx, vy, vw, vh = VIEWBOX
    if w is None: w = vw
    if h is None: h = vh
    return ('<svg width="%s" height="%s" viewBox="%g %g %g %g" fill="none" '
            'xmlns="http://www.w3.org/2000/svg">%s%s</svg>'
            % (w, h, vx, vy, vw, vh, sprite(c, pose, uid), extra))
