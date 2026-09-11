# -*- coding: utf-8 -*-
"""CharaTime キャラクター SVG ジェネレータ（画風「まるっとフラット」）
   viewBox 0 0 120 170 / 接地線 y=163 / 身長は頭頂 y=20..足元 y=163"""

OUT = "#3B2B2B"   # 輪郭線
SW  = 5           # 線幅

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
# フワ（裾がひらひら・足なし）
BODY_FUWA = ("M60 20 C86 20 105 39 105 65 C105 81 99 94 89 102 "
             "C93 109 96 119 96 128 L96 147 "
             "Q87 159 78 147 Q69 135 60 147 Q51 159 42 147 Q33 135 24 147 "
             "L24 128 C24 119 27 109 31 102 C21 94 15 81 15 65 C15 39 34 20 60 20 Z")

WING_L  = "M33 110 C15 111 6 125 13 136 C20 145 33 141 37 131 Z"
WING_R  = "M87 110 C105 111 114 125 107 136 C100 145 87 141 83 131 Z"
WING_UP_L = "M34 107 C17 96 5 103 6 115 C9 126 24 126 33 117 Z"
WING_UP_R = "M86 107 C103 96 115 103 114 115 C111 126 96 126 87 117 Z"
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
    body = BODY
    if c == "fuwa": body = BODY_FUWA
    if pose == "sit": body = BODY_SIT
    if pose in ("walk", "walk2", "side"): body = BODY_SIDE
    if pose == "sleep": body = BODY_SLEEP

    side = pose in ("walk", "walk2", "side")

    # ---- 寝そべり ------------------------------------------------
    if pose == "sleep":
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
        return g

    # ---- 立ち・歩き・座り・喜ぶ ----------------------------------
    inner = ""
    inner += _topper(c, side)
    if c != "fuwa":
        if pose == "walk":
            inner += '<ellipse cx="86" cy="157" rx="12" ry="7" fill="%s"/>' % p["shade"]
        elif pose == "walk2":
            inner += '<ellipse cx="72" cy="156" rx="12" ry="7" fill="%s"/>' % p["shade"]
        elif pose == "happy":
            inner += _feet(c, y=154, lx=43, rx=77)
        elif pose != "sit":
            inner += _feet(c)
    # 羽
    if pose == "happy":
        inner += '<path d="%s" fill="%s"/><path d="%s" fill="%s"/>' % (WING_UP_L, p["sub"], WING_UP_R, p["sub"])
    elif pose == "sit":
        inner += ('<path d="M33 124 C17 125 9 138 16 148 C23 156 35 152 39 142 Z" fill="%s"/>'
                  '<path d="M87 124 C103 125 111 138 104 148 C97 156 85 152 81 142 Z" fill="%s"/>' % (p["sub"], p["sub"]))
    else:
        inner += '<path d="%s" fill="%s"/><path d="%s" fill="%s"/>' % (WING_L, p["sub"], WING_R, p["sub"])
    # 本体
    inner += '<path d="%s" fill="%s"/>' % (body, p["body"])
    if side:
        inner += '<path d="%s" fill="%s"/>' % (WING_SIDE, p["sub"])
    # 前に出る足
    if pose == "walk":
        inner += '<ellipse cx="38" cy="157" rx="12" ry="7" fill="%s"/>' % acc
    elif pose == "walk2":
        inner += '<ellipse cx="52" cy="158" rx="12" ry="7" fill="%s"/>' % acc
    elif pose == "sit" and c != "fuwa":
        inner += ('<ellipse cx="38" cy="152" rx="13" ry="7.5" fill="%s"/>'
                  '<ellipse cx="82" cy="152" rx="13" ry="7.5" fill="%s"/>' % (acc, acc))
    inner += _mouth(c, pose, side)
    g = _g(inner)
    g += _topper_deco(c)
    g += _panel(c)
    g += _cheeks(c, side)
    g += _eyes(pose, side)
    g += _mouth_line(c, pose, side)
    return g

def svg(c, pose="idle", w=120, h=170, uid="a", extra=""):
    return ('<svg width="%s" height="%s" viewBox="0 0 120 170" fill="none" '
            'xmlns="http://www.w3.org/2000/svg">%s%s</svg>' % (w, h, sprite(c, pose, uid), extra))
