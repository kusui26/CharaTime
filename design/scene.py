# -*- coding: utf-8 -*-
"""CharaTime 背景・アイテムの SVG パーツ"""
OUT="#3B2B2B"

DAY  = dict(wall="#F7E7D0", wall2="#F2DDC0", floor="#E5C79E", floor2="#D9B587",
            line="#3B2B2B", sky="#BFE3F2", glow="#FFF3D6")
NITE = dict(wall="#4A4160", wall2="#3E3653", floor="#574A6B", floor2="#4A3E5D",
            line="#3B2B2B", sky="#2A2440", glow="#FFE9A8")

def room(w, h, horizon, night=False, window=True, uid="r"):
    """壁＋床＋窓。0,0 - w,h"""
    c = NITE if night else DAY
    s = '<rect x="0" y="0" width="%g" height="%g" fill="%s"/>' % (w, horizon, c["wall"])
    s += '<rect x="0" y="%g" width="%g" height="%g" fill="%s"/>' % (horizon, w, h-horizon, c["floor"])
    # 床の手前を少し明るく
    s += '<rect x="0" y="%g" width="%g" height="%g" fill="%s" opacity="0.55"/>' % (horizon+(h-horizon)*0.55, w, (h-horizon)*0.45, c["floor2"])
    s += '<rect x="0" y="%g" width="%g" height="7" fill="%s"/>' % (horizon-7, w, c["wall2"])
    s += '<rect x="0" y="%g" width="%g" height="4" fill="%s"/>' % (horizon-1, w, OUT)
    if window:
        wx, wy, ww, wh = w*0.60, horizon*0.22, w*0.30, horizon*0.40
        s += '<rect x="%g" y="%g" width="%g" height="%g" rx="10" fill="%s" stroke="%s" stroke-width="5"/>' % (wx, wy, ww, wh, c["sky"], OUT)
        if night:
            s += '<circle cx="%g" cy="%g" r="%g" fill="%s"/>' % (wx+ww*0.66, wy+wh*0.30, ww*0.13, c["glow"])
            for i,(fx,fy) in enumerate([(0.2,0.62),(0.38,0.30),(0.30,0.80),(0.55,0.70)]):
                s += '<circle cx="%g" cy="%g" r="1.8" fill="#FFF6DC"/>' % (wx+ww*fx, wy+wh*fy)
        else:
            s += '<ellipse cx="%g" cy="%g" rx="%g" ry="%g" fill="#FFFFFF" opacity="0.85"/>' % (wx+ww*0.32, wy+wh*0.34, ww*0.22, wh*0.14)
        s += '<rect x="%g" y="%g" width="%g" height="5" fill="%s"/>' % (wx, wy+wh/2-2.5, ww, OUT)
    return s

def rug(cx, cy, rx, ry, night=False):
    f = "#6E6088" if night else "#EFC9A8"
    f2 = "#7E6F9A" if night else "#F6DCC4"
    return ('<ellipse cx="%g" cy="%g" rx="%g" ry="%g" fill="%s" stroke="%s" stroke-width="5"/>'
            '<ellipse cx="%g" cy="%g" rx="%g" ry="%g" fill="%s"/>' % (cx,cy,rx,ry,f,OUT,cx,cy,rx*0.62,ry*0.58,f2))

def shadow(cx, cy, rx, op=0.16):
    return '<ellipse cx="%g" cy="%g" rx="%g" ry="%g" fill="#3B2B2B" opacity="%g"/>' % (cx, cy, rx, rx*0.30, op)

def mirror_ball(cx, cy, r, ceiling=0, on=True, uid="mb"):
    s = '<path d="M%g %g L%g %g" stroke="%s" stroke-width="4" stroke-linecap="round"/>' % (cx, ceiling, cx, cy-r+2, OUT)
    s += '<circle cx="%g" cy="%g" r="%g" fill="#CBD3E2" stroke="%s" stroke-width="5"/>' % (cx, cy, r, OUT)
    # ファセット
    for i in range(-2, 3):
        yy = cy + i*r*0.38
        half = (max(r*r - (yy-cy)**2, 0))**0.5 * 0.92
        s += '<path d="M%g %g L%g %g" stroke="#9AA6BE" stroke-width="2.5" opacity="0.9"/>' % (cx-half, yy, cx+half, yy)
    for i in range(-2, 3):
        xx = cx + i*r*0.38
        half = (max(r*r - (xx-cx)**2, 0))**0.5 * 0.92
        s += '<path d="M%g %g L%g %g" stroke="#9AA6BE" stroke-width="2.5" opacity="0.9"/>' % (xx, cy-half, xx, cy+half)
    s += '<path d="M%g %g a%g %g 0 0 1 %g %g" stroke="#FFFFFF" stroke-width="5" fill="none" opacity="0.75" stroke-linecap="round"/>' % (
        cx-r*0.62, cy-r*0.30, r*0.72, r*0.72, r*0.30, -r*0.52)
    if on:
        s = ('<radialGradient id="%s"><stop offset="0%%" stop-color="#FFF0B8" stop-opacity=".30"/>'
             '<stop offset="55%%" stop-color="#FFF0B8" stop-opacity=".10"/>'
             '<stop offset="100%%" stop-color="#FFF0B8" stop-opacity="0"/></radialGradient>'
             '<circle cx="%g" cy="%g" r="%g" fill="url(#%s)"/>' % (uid, cx, cy, r*3.4, uid)) + s
    return s

def sparkles(pts, color="#FFF0B8"):
    s = ""
    for (x, y, r) in pts:
        s += ('<path d="M%g %g L%g %g L%g %g L%g %g Z" fill="%s" opacity="0.9"/>'
              % (x, y-r, x+r*0.34, y-r*0.34, x+r, y, x+r*0.34, y+r*0.34, color))
        s += ('<path d="M%g %g L%g %g L%g %g L%g %g Z" fill="%s" opacity="0.9"/>'
              % (x, y+r, x-r*0.34, y+r*0.34, x-r, y, x-r*0.34, y-r*0.34, color))
    return s

def cushion(cx, cy, w=70, col="#F0A8BC", col2="#E48CA4"):
    h = w*0.46
    return ('<rect x="%g" y="%g" width="%g" height="%g" rx="%g" fill="%s" stroke="%s" stroke-width="5"/>'
            '<ellipse cx="%g" cy="%g" rx="%g" ry="%g" fill="%s"/>'
            % (cx-w/2, cy-h/2, w, h, h*0.42, col, OUT, cx, cy, w*0.15, h*0.17, col2))

def plant(cx, base, s=1.0):
    p = '<path d="M%g %g L%g %g L%g %g L%g %g Z" fill="#D98F5E" stroke="%s" stroke-width="5" stroke-linejoin="round"/>' % (
        cx-22*s, base-30*s, cx+22*s, base-30*s, cx+16*s, base, cx-16*s, base, OUT)
    p += '<rect x="%g" y="%g" width="%g" height="%g" rx="4" fill="#C87D4E" stroke="%s" stroke-width="5"/>' % (
        cx-25*s, base-40*s, 50*s, 13*s, OUT)
    leaves = [(-1, 40, 26), (1, 52, 22), (-1, 66, 16), (1, 30, 18)]
    for d, hgt, ln in leaves:
        p += ('<path d="M%g %g C%g %g %g %g %g %g C%g %g %g %g %g %g Z" fill="#8FC08A" stroke="%s" stroke-width="5" stroke-linejoin="round"/>'
              % (cx, base-38*s,
                 cx+d*ln*0.4*s, base-(38+hgt*0.5)*s, cx+d*ln*1.0*s, base-(38+hgt*0.8)*s, cx+d*ln*0.5*s, base-(38+hgt)*s,
                 cx+d*ln*0.1*s, base-(38+hgt*0.8)*s, cx, base-(38+hgt*0.5)*s, cx, base-38*s, OUT))
    return p

def deskclock(cx, base, hh=20, mm=42, s=1.0):
    r = 26*s
    cy = base - r - 8*s
    import math
    ha = math.radians((hh % 12) * 30 + mm * 0.5 - 90)
    ma = math.radians(mm * 6 - 90)
    p = '<path d="M%g %g L%g %g L%g %g L%g %g Z" fill="#C87D4E" stroke="%s" stroke-width="5" stroke-linejoin="round"/>' % (
        cx-16*s, base-10*s, cx+16*s, base-10*s, cx+22*s, base, cx-22*s, base, OUT)
    p += '<circle cx="%g" cy="%g" r="%g" fill="#FBF1DC" stroke="%s" stroke-width="5"/>' % (cx, cy, r, OUT)
    p += '<path d="M%g %g L%g %g" stroke="%s" stroke-width="4.5" stroke-linecap="round"/>' % (
        cx, cy, cx+math.cos(ha)*r*0.48, cy+math.sin(ha)*r*0.48, OUT)
    p += '<path d="M%g %g L%g %g" stroke="%s" stroke-width="3.5" stroke-linecap="round"/>' % (
        cx, cy, cx+math.cos(ma)*r*0.72, cy+math.sin(ma)*r*0.72, OUT)
    p += '<circle cx="%g" cy="%g" r="2.6" fill="%s"/>' % (cx, cy, OUT)
    return p

def bed(cx, base, w=120, night=False):
    h = 34
    p = '<rect x="%g" y="%g" width="%g" height="%g" rx="12" fill="#B9D7E8" stroke="%s" stroke-width="5"/>' % (
        cx-w/2, base-h, w, h, OUT)
    p += '<rect x="%g" y="%g" width="%g" height="%g" rx="10" fill="#FBF1DC" stroke="%s" stroke-width="5"/>' % (
        cx-w/2+6, base-h-16, w*0.34, 24, OUT)
    return p

def note(x, y, s=1.0, col="#FFE8A8"):
    return ('<g transform="translate(%g %g) scale(%g)">'
            '<path d="M14 4 L14 22" stroke="%s" stroke-width="4.5" stroke-linecap="round" fill="none"/>'
            '<path d="M14 4 C20 6 26 9 26 15 C22 12 18 11 14 11 Z" fill="%s" stroke="%s" stroke-width="4" stroke-linejoin="round"/>'
            '<ellipse cx="8.5" cy="23" rx="8.5" ry="6.5" transform="rotate(-16 8.5 23)" fill="%s" stroke="%s" stroke-width="4"/>'
            '</g>' % (x, y, s, OUT, col, OUT, col, OUT))

def zzz(x, y, s=1.0, col="#FFFFFF"):
    o = ""
    for i,(dx,dy,sc) in enumerate([(0,0,1.0),(20,-18,0.76),(35,-33,0.56)]):
        o += ('<text x="%g" y="%g" font-family="DotGothic16, monospace" font-size="%g" fill="%s" opacity="%g">z</text>'
              % (x+dx*s, y+dy*s, 26*sc*s, col, 0.95-i*0.18))
    return o
