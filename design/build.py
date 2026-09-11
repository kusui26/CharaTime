# -*- coding: utf-8 -*-
import chara, scene
from chara import P

FONTS = ('<link rel="stylesheet" href="https://fonts.googleapis.com/css2?'
         'family=DotGothic16&family=Zen+Maru+Gothic:wght@400;500;700&display=swap">')
CSS = """
  body { margin: 0; }
  .ct  { font-family: "Zen Maru Gothic","Hiragino Maru Gothic ProN","Hiragino Sans","Yu Gothic",system-ui,sans-serif; }
  .dot { font-family: "DotGothic16","Hiragino Sans",monospace; }
  .sys { font-family: -apple-system,system-ui,"Helvetica Neue","Hiragino Sans",sans-serif; }
  a { color: #E08A4E; } a:hover { color: #C4712F; }
"""
INK, MUT, LINE, BG, ACC, ACC2 = "#3B2B2B", "#8B7B72", "#E6DAC9", "#FBF5EC", "#E08A4E", "#6EA79C"
ARTBOARDS = []

def dc(body, css_extra=""):
    return ('<!doctype html>\n<html>\n<head>\n  <meta charset="utf-8">\n'
            '  <script src="./support.js"></script>\n</head>\n<body>\n<x-dc>\n<helmet>\n  '
            + FONTS + '\n  <style>' + CSS + css_extra + '</style>\n</helmet>\n'
            + body + '\n</x-dc>\n</body>\n</html>\n')

def write(name, body, w, h, css_extra="", label=""):
    open(name, "w").write(dc(body, css_extra))
    ARTBOARDS.append((name, body, w, h, css_extra, label or name))

def phone(inner, w=390, h=844, bg="#000", radius=0):
    return ('<div class="ct" style="position:relative;width:%dpx;height:%dpx;overflow:hidden;'
            'background:%s;border-radius:%dpx;">%s</div>' % (w, h, bg, radius, inner))

def svg_layer(inner, w=390, h=844, z=0, extra="", top="0"):
    return ('<svg viewBox="0 0 %d %d" width="%d" height="%d" style="position:absolute;left:0;top:%s;z-index:%d;%s" '
            'xmlns="http://www.w3.org/2000/svg">%s</svg>' % (w, h, w, h, top, z, extra, inner))

def sprite_at(c, pose, cx, foot_y, w, flip=False, z=3, op=1.0):
    # 枠と接地線の割合は chara.py が持つ（書き出す PNG と同じ値）。
    h = w / chara.ASPECT
    top = foot_y - h * chara.GROUND_RATIO
    tr = "transform:scaleX(-1);" if flip else ""
    return ('<div style="position:absolute;left:%gpx;top:%gpx;width:%gpx;height:%gpx;z-index:%d;%sopacity:%g;">%s</div>'
            % (cx - w / 2, top, w, h, z, tr, op, chara.svg(c, pose, w, h)))

def bubble(x, y, text, z=5, tail="left", fs=15):
    tl = 'left:20px;' if tail == "left" else 'right:20px;'
    return ('<div style="position:absolute;left:%gpx;top:%gpx;z-index:%d;">'
            '<div style="position:relative;background:#fff;border:4px solid #3B2B2B;border-radius:20px;'
            'padding:9px 17px 10px;font-size:%gpx;font-weight:500;color:#3B2B2B;white-space:nowrap;line-height:1.3;">%s'
            '<div style="position:absolute;%stop:calc(100%% - 1px);width:0;height:0;'
            'border-left:13px solid transparent;border-right:13px solid transparent;border-top:19px solid #3B2B2B;"></div>'
            '<div style="position:absolute;%smargin-left:4px;margin-right:4px;top:calc(100%% - 6px);width:0;height:0;'
            'border-left:9px solid transparent;border-right:9px solid transparent;border-top:13px solid #fff;"></div>'
            '</div></div>' % (x, y, z, fs, text, tl, tl))

def battery(pct=76, col="#fff", op=.85):
    return ('<svg width="30" height="15" viewBox="0 0 30 15" style="vertical-align:-2px;">'
            '<rect x="1" y="1.5" width="24" height="12" rx="3.5" fill="none" stroke="%s" stroke-width="2" opacity="%g"/>'
            '<rect x="3.5" y="4" width="%g" height="7" rx="1.6" fill="%s" opacity="%g"/>'
            '<path d="M27.5 5 v5" stroke="%s" stroke-width="2.4" stroke-linecap="round" opacity="%g"/></svg>'
            % (col, op, 19 * pct / 100.0, col, op, col, op * .7))

def gk_clock(t, date, extra="", top=62, size=64, col="#FFF4DC", z=4, sub=.80):
    return ('<div style="position:absolute;left:0;top:%gpx;width:100%%;text-align:center;z-index:%d;">'
            '<div class="dot" style="font-size:%gpx;line-height:1;letter-spacing:6px;color:%s;">%s</div>'
            '<div style="margin-top:14px;font-size:15px;letter-spacing:3px;color:%s;">%s</div>%s</div>'
            % (top, z, size, col, t, "rgba(255,244,220,%g)" % sub, date, extra))

# ---- 汎用アプリアイコン（架空・ブランドなし） ----------------------
GLYPH = {
 "calendar": '<rect x="5" y="6.5" width="14" height="12.5" rx="2.6"/><path d="M5 10.5h14M9 4.5v3M15 4.5v3"/>',
 "notes":    '<path d="M6.5 4.5h11v15h-11z"/><path d="M9.5 9h5M9.5 13h5"/>',
 "camera":   '<rect x="4" y="7" width="16" height="11" rx="3"/><circle cx="12" cy="12.5" r="3.4"/><path d="M9 7l1.4-2h3.2L15 7"/>',
 "clock":    '<circle cx="12" cy="12" r="8"/><path d="M12 7.4V12l3.2 2"/>',
 "weather":  '<circle cx="9.5" cy="10" r="3.4"/><path d="M7 17.5h9.5a3.2 3.2 0 0 0 0-6.4 4.6 4.6 0 0 0-8.7-.6"/>',
 "map":      '<path d="M4.5 6.5l5-2 5 2 5-2v13l-5 2-5-2-5 2z"/><path d="M9.5 4.5v13M14.5 6.5v13"/>',
 "photos":   '<rect x="4.5" y="6" width="15" height="12" rx="2.6"/><circle cx="9" cy="10.5" r="1.6"/><path d="M5.5 16l4.5-4.2 3.6 3.2 2.6-2.2 2.3 2"/>',
 "music":    '<path d="M9 17.5V6.5l8-1.6v11"/><circle cx="7" cy="17.5" r="2.4"/><circle cx="15" cy="15.9" r="2.4"/>',
 "mail":     '<rect x="3.5" y="6.5" width="17" height="11.5" rx="2.6"/><path d="M4 8l8 5.4 8-5.4"/>',
 "calc":     '<rect x="5.5" y="4" width="13" height="16" rx="2.6"/><path d="M8.5 8h7M8.5 12h1.6M13.9 12h1.6M8.5 16h1.6M13.9 16h1.6"/>',
 "health":   '<path d="M12 19s-7-4.3-7-9a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 4.7-7 9-7 9z"/>',
 "gear":     '<circle cx="12" cy="12" r="3.2"/><path d="M12 3.4v2.6M12 18v2.6M3.4 12h2.6M18 12h2.6M6 6l1.9 1.9M16.1 16.1 18 18M18 6l-1.9 1.9M7.9 16.1 6 18"/>',
 "chara":    '',
}
ICON_BG = {"calendar":"#F4F4F6","notes":"#FFF0C4","camera":"#E6E6EA","clock":"#2A2A31","weather":"#BCDCF2",
           "map":"#D9EEDC","photos":"#FFFFFF","music":"#F7C6C6","mail":"#CFE2FA","calc":"#33333A",
           "health":"#FFE0E3","gear":"#D8D8DE"}
ICON_FG = {"calendar":"#D0555B","notes":"#C79A2A","camera":"#5A5A63","clock":"#FFFFFF","weather":"#2F6FA8",
           "map":"#3C8A54","photos":"#D06E8A","music":"#B34848","mail":"#2D6FC0","calc":"#FFFFFF",
           "health":"#D65A6A","gear":"#5A5A63"}

def app_icon(kind, label, size=60):
    if kind == "chara":
        art = ('<div style="position:relative;width:%dpx;height:%dpx;border-radius:%gpx;background:#FFE9B8;'
               'overflow:hidden;box-shadow:0 1px 3px rgba(0,0,0,.18);">'
               '<div style="position:absolute;left:50%%;bottom:-4px;transform:translateX(-50%%);">%s</div></div>'
               % (size, size, size * .234, chara.svg("piyo", "idle", size * .60, size * .60 / 120 * 170)))
    else:
        art = ('<div style="width:%dpx;height:%dpx;border-radius:%gpx;background:%s;'
               'display:flex;align-items:center;justify-content:center;box-shadow:0 1px 3px rgba(0,0,0,.18);">'
               '<svg width="%g" height="%g" viewBox="0 0 24 24" fill="none" stroke="%s" stroke-width="1.7" '
               'stroke-linecap="round" stroke-linejoin="round">%s</svg></div>'
               % (size, size, size * .234, ICON_BG[kind], size * .58, size * .58, ICON_FG[kind], GLYPH[kind]))
    return ('<div style="display:flex;flex-direction:column;align-items:center;gap:5px;width:%dpx;">%s'
            '<span class="sys" style="font-size:10.5px;color:rgba(255,255,255,.96);letter-spacing:-.1px;'
            'white-space:nowrap;text-shadow:0 1px 2px rgba(0,0,0,.4);">%s</span></div>' % (size, art, label))

def dock(kinds=(("mail","メール"),("map","マップ"),("music","ミュージック"),("camera","カメラ")), bottom=26):
    cells = "".join(('<div style="width:60px;height:60px;border-radius:14px;background:%s;display:flex;'
                     'align-items:center;justify-content:center;box-shadow:0 1px 3px rgba(0,0,0,.18);">'
                     '<svg width="35" height="35" viewBox="0 0 24 24" fill="none" stroke="%s" stroke-width="1.7" '
                     'stroke-linecap="round" stroke-linejoin="round">%s</svg></div>'
                     % (ICON_BG[k], ICON_FG[k], GLYPH[k])) for k, _ in kinds)
    return ('<div style="position:absolute;left:12px;right:12px;bottom:%gpx;z-index:6;display:flex;'
            'justify-content:space-around;align-items:center;padding:12px 10px;border-radius:32px;'
            'background:rgba(255,255,255,.26);backdrop-filter:blur(14px);">%s</div>' % (bottom, cells))

def page_dots(n=3, active=1, bottom=118, col="#fff"):
    d = "".join('<span style="width:7px;height:7px;border-radius:50%%;background:%s;opacity:%g;"></span>'
                % (col, 1 if i == active else .42) for i in range(n))
    return ('<div style="position:absolute;left:0;right:0;bottom:%gpx;z-index:6;display:flex;'
            'justify-content:center;gap:8px;">%s</div>' % (bottom, d))

# ---- 壁紙 ----------------------------------------------------------
def wallpaper(w, h, kind="day", uid="wp", sun=(0.74, 0.17)):
    if kind == "morning":
        stops = [("0%", "#BCD8EC"), ("34%", "#DCE6E6"), ("66%", "#FCDCBE"), ("100%", "#F7C4AA")]
        hill1, hill2, sunc = "#E3CDA2", "#D6BC8E", "#FFF6D8"
    elif kind == "day":
        stops = [("0%", "#FFD9A6"), ("38%", "#F9BEB6"), ("72%", "#D9BEDF"), ("100%", "#BCB2E2")]
        hill1, hill2, sunc = "#E8C49A", "#DFB78C", "#FFF0C0"
    else:
        stops = [("0%", "#2B2440"), ("45%", "#3A3157"), ("100%", "#4A3F63")]
        hill1, hill2, sunc = "#3B3356", "#332C4B", "#FFE9A8"
    st = "".join('<stop offset="%s" stop-color="%s"/>' % (o, c) for o, c in stops)
    s = ('<linearGradient id="%s" x1="0" y1="0" x2="0" y2="1">%s</linearGradient>'
         '<rect width="%g" height="%g" fill="url(#%s)"/>' % (uid, st, w, h, uid))
    s += '<circle cx="%g" cy="%g" r="%g" fill="%s" opacity="%g"/>' % (w*sun[0], h*sun[1], w*0.15, sunc, .55 if kind=="day" else .9)
    if kind != "day":
        for fx, fy, rr in [(.16,.12,1.9),(.30,.22,1.4),(.52,.09,1.7),(.68,.30,1.3),(.10,.34,1.5),
                           (.86,.14,1.6),(.42,.36,1.2),(.62,.46,1.4),(.24,.48,1.3)]:
            s += '<circle cx="%g" cy="%g" r="%g" fill="#FFF6DC" opacity=".72"/>' % (w*fx, h*fy, rr)
    s += ('<path d="M0 %g C%g %g %g %g %g %g L%g %g L0 %g Z" fill="%s" opacity=".85"/>'
          % (h*0.80, w*0.30, h*0.72, w*0.62, h*0.86, w, h*0.76, w, h, h, hill1))
    s += ('<path d="M0 %g C%g %g %g %g %g %g L%g %g L0 %g Z" fill="%s" opacity=".9"/>'
          % (h*0.90, w*0.26, h*0.85, w*0.66, h*0.96, w, h*0.88, w, h, h, hill2))
    return s

# ====================================================================
# 面 0-a : 待受モード（夜・フワ・ミラーボール）
# ====================================================================
def build_main():
    W, H, HZ = 390, 844, 544
    s  = scene.room(W, H, HZ, night=True, window=False)
    s += ('<rect x="26" y="286" width="112" height="126" rx="10" fill="#2A2440" stroke="#3B2B2B" stroke-width="5"/>'
          '<circle cx="106" cy="322" r="15" fill="#FFE9A8"/>'
          '<circle cx="52" cy="356" r="2" fill="#FFF6DC"/><circle cx="72" cy="388" r="2.4" fill="#FFF6DC"/>'
          '<circle cx="46" cy="310" r="1.8" fill="#FFF6DC"/>'
          '<rect x="26" y="346" width="112" height="5" fill="#3B2B2B"/>')
    s += scene.rug(252, 706, 128, 44, night=True)
    s += scene.mirror_ball(300, 300, 30, ceiling=0, on=True, uid="mb1")
    s += scene.sparkles([(232,258,7),(362,282,6),(246,196,5),(348,206,6),(214,352,6),(364,364,5),
                         (268,150,5),(320,414,6),(198,296,5)])
    s += scene.plant(56, 700)
    s += scene.cushion(142, 700, 76)
    s += scene.shadow(292, 712, 50, .26)
    s += scene.note(148, 468, 1.0)
    s += scene.note(192, 530, .8)
    room = svg_layer(s, W, H, 1)

    extra = ('<div style="margin-top:10px;font-size:12.5px;letter-spacing:1.5px;color:rgba(255,244,220,.60);">'
             + battery(76, "#FFF4DC", .8) + ' <span style="vertical-align:2px;">76% ・ 充電中</span></div>')
    clock = gk_clock("20:42", "9月11日（金）", extra)

    items = [("キャラ", '<circle cx="12" cy="9" r="6.2"/><path d="M3.4 21c1.6-4 5-6 8.6-6s7 2 8.6 6"/>'),
             ("へや",  '<path d="M2.6 10.5 12 3l9.4 7.5"/><path d="M5.4 12.2V21h13.2v-8.8"/>'),
             ("設定",  GLYPH["gear"]),
             ("とじる", '<path d="M6 6l12 12M18 6L6 18"/>')]
    btns = "".join('<div style="display:flex;flex-direction:column;align-items:center;gap:5px;width:60px;">'
                   '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="rgba(255,244,220,.92)" '
                   'stroke-width="2" stroke-linecap="round" stroke-linejoin="round">%s</svg>'
                   '<span style="font-size:11px;color:rgba(255,244,220,.78);letter-spacing:.5px;">%s</span></div>'
                   % (d, l) for l, d in items)
    ctrl = ('<div style="position:absolute;left:22px;right:22px;bottom:46px;z-index:6;display:flex;'
            'justify-content:space-between;align-items:center;padding:13px 12px 11px;border-radius:22px;'
            'background:rgba(26,20,38,.58);border:1px solid rgba(255,244,220,.16);">' + btns + '</div>')

    inner = room + clock + sprite_at("fuwa", "happy", 292, 712, 176, z=3) + \
            bubble(146, 556, "ふふ〜ん♪", tail="right") + ctrl
    write("Main.dc.html", phone(inner, W, H, "#3E3653"), W, H, label="面0 待受モード")

# ====================================================================
# 面 0-b : 待受モード（ホーム画面のスクショの上を歩く）
# ====================================================================
def build_standbyhome():
    W, H = 390, 844
    bg = svg_layer(wallpaper(W, H, "day", "wp2"), W, H, 0)
    rows = [[("calendar","カレンダー"),("notes","メモ"),("photos","写真"),("clock","時計")],
            [("weather","天気"),("health","ヘルスケア"),("calc","計算機"),("gear","設定")],
            [("chara","CharaTime"),("map","マップ"),("music","ミュージック"),("mail","メール")],
            [("camera","カメラ"),("notes","リマインダー"),("photos","ファイル"),("clock","ブック")]]
    grid = ""
    for r in rows:
        grid += ('<div style="display:flex;justify-content:space-between;">'
                 + "".join(app_icon(k, l) for k, l in r) + '</div>')
    icons = ('<div style="position:absolute;left:27px;right:27px;top:86px;z-index:2;display:flex;'
             'flex-direction:column;gap:22px;">' + grid + '</div>')

    band = ('<div style="position:absolute;left:0;right:0;top:576px;height:108px;z-index:3;'
            'background:linear-gradient(180deg,rgba(255,250,240,0) 0%,rgba(255,250,240,.14) 55%,rgba(255,250,240,.24) 100%);'
            'border-bottom:2px dashed rgba(59,43,43,.15);"></div>')
    shad = svg_layer(scene.shadow(206, 682, 44, .20) + scene.note(314, 590, .72, "#FFF0C4"), W, H, 4)
    clock = ('<div style="position:absolute;left:0;top:24px;width:100%;text-align:center;z-index:5;">'
             '<div class="dot" style="font-size:36px;letter-spacing:4px;color:#FFF6E8;'
             'text-shadow:0 2px 10px rgba(80,40,60,.45);">13:08</div></div>')
    inner = (bg + icons + band + shad
             + sprite_at("piyo", "walk", 206, 682, 128, z=5)
             + bubble(48, 546, "おさんぽ中", tail="left", fs=14) + clock + dock() + page_dots(3, 0))
    write("StandbyHome.dc.html", phone(inner, W, H, "#C9BCEA"), W, H, label="面0 ホーム画面の上")

# ====================================================================
# 面 1-a : ホーム画面ウィジェット（透過）
# ====================================================================
def widget_large_inner(w=338, h=354):
    g = h * 0.80
    s  = scene.shadow(w*0.50, g+4, 46, .20)
    s += scene.plant(w*0.15, g+6, .78)
    s += scene.cushion(w*0.86, g-2, 62)
    s += scene.note(w*0.28, g-124, .70, "#FFF0C4")
    return svg_layer(s, w, h, 2)

def build_homewidget(spec=False):
    W, H = 390, 844
    bg = svg_layer(wallpaper(W, H, "day", "wp3"), W, H, 0)
    LX, LY, LW, LH = 26, 78, 338, 354
    MX, MY, MW, MH = 26, 458, 338, 158

    large = ('<div style="position:absolute;left:%gpx;top:%gpx;width:%gpx;height:%gpx;z-index:2;%s">%s%s</div>'
             % (LX, LY, LW, LH,
                "border:2px dashed rgba(255,255,255,.85);border-radius:26px;" if spec else "",
                widget_large_inner(LW, LH),
                sprite_at("piyo", "walk", LW*0.50, LH*0.80+4, 126, z=3)))
    mid = ('<div style="position:absolute;left:%gpx;top:%gpx;width:%gpx;height:%gpx;z-index:2;%s'
           'display:flex;align-items:center;justify-content:space-between;padding:0 26px;box-sizing:border-box;">'
           '<div><div class="dot" style="font-size:44px;letter-spacing:3px;color:#fff;'
           'text-shadow:0 1px 5px rgba(0,0,0,.24);line-height:1;">13:25</div>'
           '<div style="margin-top:9px;font-size:12.5px;letter-spacing:1.6px;color:rgba(255,255,255,.94);'
           'text-shadow:0 1px 4px rgba(0,0,0,.28);">9月11日（金）・ おさんぽ中</div></div>'
           '<div style="position:relative;width:96px;height:96px;">%s%s</div></div>'
           % (MX, MY, MW, MH,
              "border:2px dashed rgba(255,255,255,.85);border-radius:26px;" if spec else "",
              svg_layer(scene.shadow(48, 84, 26, .18), 96, 96, 1),
              sprite_at("piyo", "idle", 48, 86, 62, z=2)))

    tags = ""
    if spec:
        tags = ('<div style="position:absolute;left:%gpx;top:%gpx;z-index:4;font-size:11px;font-weight:700;'
                'letter-spacing:1px;color:#3B2B2B;background:rgba(255,255,255,.92);padding:4px 9px;'
                'border-radius:8px;">ラージ 4×4 ・ 部屋の全景</div>'
                '<div style="position:absolute;left:%gpx;top:%gpx;z-index:4;font-size:11px;font-weight:700;'
                'letter-spacing:1px;color:#3B2B2B;background:rgba(255,255,255,.92);padding:4px 9px;'
                'border-radius:8px;">ミディアム 4×2 ・ 時計＋近影</div>'
                '<div style="position:absolute;left:26px;top:%gpx;right:26px;z-index:4;font-size:11.5px;'
                'line-height:1.7;color:#3B2B2B;background:rgba(255,255,255,.90);padding:11px 14px;'
                'border-radius:14px;">背景は<b>ユーザーの壁紙のスクショを切り抜いて敷いている</b>ので、'
                'ウィジェットの枠が見えない。キャラと家具だけが壁紙の上に立って見える。</div>'
                % (LX + 10, LY + 12, MX + 10, MY + 12, MY + MH + 22))
    inner = bg + large + mid + tags + dock() + page_dots(3, 1)
    name = "HomeWidgetSpec.dc.html" if spec else "HomeWidget.dc.html"
    write(name, phone(inner, W, H, "#C9BCEA"), W, H,
          label="面1 ウィジェットの構成" if spec else "面1 ホーム画面")

# ====================================================================
# 面 1-c : ウィジェットは時間で変わる
# ====================================================================
def mini_widget(t, date_status, c, pose, w=338, h=158, bub=None, night=False, cx=0.80, size=64):
    inner = svg_layer(wallpaper(w, h*4.6, "night" if night else "day", "mw%s" % t.replace(":", "")),
                      w, h*4.6, 0, top="-%gpx" % (h*1.9))
    sh = svg_layer(scene.shadow(w*cx, h*0.80, 25, .18), w, h, 1)
    col = "#FFF4DC" if night else "#fff"
    txt = ('<div style="position:absolute;left:26px;top:34px;z-index:3;">'
           '<div class="dot" style="font-size:42px;letter-spacing:3px;color:%s;line-height:1;'
           'text-shadow:0 1px 5px rgba(0,0,0,.26);">%s</div>'
           '<div style="margin-top:9px;font-size:12px;letter-spacing:1.4px;color:%s;'
           'text-shadow:0 1px 4px rgba(0,0,0,.3);">%s</div></div>' % (col, t, col, date_status))
    b = bubble(w*cx - 116, h*0.13, bub, z=5, tail="right", fs=12.5) if bub else ""
    return ('<div style="position:relative;width:%gpx;height:%gpx;border-radius:26px;overflow:hidden;">%s%s%s%s%s</div>'
            % (w, h, inner, sh, txt, sprite_at(c, pose, w*cx, h*0.80, size, z=4), b))

def build_widgethours():
    W = 462
    rows = [("07:10", "9月11日（金）・ おきた", "piyo", "happy", "おはよう！", False, 62),
            ("12:00", "9月11日（金）・ 時報",   "piyo", "idle",  "12時だよ",   False, 62),
            ("15:35", "9月11日（金）・ すわり", "piyo", "sit",   None,        False, 66),
            ("23:20", "9月11日（金）・ ねてる", "piyo", "sleep", None,        True,  74)]
    cells = ""
    for t, st, c, pose, bub, night, sz in rows:
        cells += ('<div style="display:flex;flex-direction:column;gap:9px;">'
                  '<div style="display:flex;align-items:baseline;gap:9px;padding-left:3px;">'
                  '<span style="font-size:13px;font-weight:700;color:%s;letter-spacing:1px;">%s</span>'
                  '<span style="font-size:12px;color:%s;">%s</span></div>%s</div>'
                  % (ACC, t, MUT, st.split("・ ")[1], mini_widget(t, st, c, pose, 338, 152, bub, night, .80, sz)))
    body = ('<div class="ct" style="width:%dpx;box-sizing:border-box;padding:30px 41px 34px;background:%s;'
            'display:flex;flex-direction:column;gap:22px;">'
            '<div><div style="font-size:18px;font-weight:700;color:%s;letter-spacing:.3px;">'
            '同じウィジェットが、時間でこう変わる</div>'
            '<div style="margin-top:8px;font-size:12.5px;line-height:1.75;color:%s;">'
            '日課エンジンが 5 分刻みの姿を先に計算しておくので、ホーム画面を見るたびに違う。'
            'アプリを開いていなくても、朝は起きて夜は寝ている。</div></div>%s</div>'
            % (W, BG, INK, MUT, cells))
    write("WidgetHours.dc.html", body, W, 1000, label="面1 時間で変わる")

# ====================================================================
# 面 2 : StandBy（横向き・充電中）
# ====================================================================
def build_standby():
    W, H = 844, 390
    s  = scene.room(390, 260, 168, night=True, window=False)
    s += scene.rug(196, 214, 118, 34, night=True)
    s += scene.cushion(300, 206, 66)
    s += scene.plant(58, 210, .8)
    s += scene.shadow(176, 216, 40, .26)
    s += scene.zzz(210, 120, 1.15, "#FFF4DC")
    left_art = ('<div style="position:relative;width:390px;height:260px;border-radius:24px;overflow:hidden;">'
                + svg_layer(s, 390, 260, 1)
                + sprite_at("mochi", "sleep", 176, 218, 142, z=3) + '</div>')
    left = ('<div style="display:flex;flex-direction:column;align-items:center;gap:14px;">%s'
            '<div style="font-size:13px;letter-spacing:2px;color:rgba(255,244,220,.66);">'
            'モチ ・ おやすみ中</div></div>' % left_art)
    right = ('<div style="display:flex;flex-direction:column;align-items:center;justify-content:center;gap:6px;">'
             '<div style="font-size:15px;letter-spacing:3px;color:rgba(255,244,220,.72);">9月11日（金）</div>'
             '<div class="dot" style="font-size:104px;line-height:1.04;letter-spacing:6px;color:#FFF4DC;">23:20</div>'
             '<div style="margin-top:4px;font-size:13px;letter-spacing:2px;color:rgba(255,244,220,.6);">%s'
             '<span style="vertical-align:2px;"> 92%% ・ 充電中</span></div></div>' % battery(92, "#FFF4DC", .75))
    inner = ('<div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:space-around;'
             'padding:0 40px;box-sizing:border-box;">%s%s</div>' % (left, right))
    write("StandBy.dc.html", phone(inner, W, H, "#0B0A10"), W, H, label="面2 StandBy")

# ---- アプリ共通 UI --------------------------------------------------
def app_header(title, sub=""):
    return ('<div style="position:absolute;left:0;right:0;top:54px;z-index:6;padding:0 20px;'
            'display:flex;align-items:center;gap:12px;">'
            '<svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="%s" stroke-width="2.2" '
            'stroke-linecap="round" stroke-linejoin="round"><path d="M15 5l-7 7 7 7"/></svg>'
            '<div><div style="font-size:19px;font-weight:700;color:%s;letter-spacing:.4px;">%s</div>%s</div>'
            '</div>' % (INK, INK, title,
                        '<div style="font-size:11.5px;color:%s;margin-top:2px;">%s</div>' % (MUT, sub) if sub else ""))

def cta(label, bottom=44, sub=None):
    s = ('<div style="position:absolute;left:20px;right:20px;bottom:%gpx;z-index:7;">'
         '<div style="background:%s;color:#fff;border-radius:18px;padding:16px;text-align:center;'
         'font-size:16px;font-weight:700;letter-spacing:1px;box-shadow:0 4px 12px rgba(224,138,78,.30);">%s</div>'
         % (bottom, ACC, label))
    if sub:
        s += ('<div style="margin-top:11px;text-align:center;font-size:11.5px;color:%s;">%s</div>' % (MUT, sub))
    return s + '</div>'

# ====================================================================
# 面 3-a : ロック画面 ＋ いっしょモード
# ====================================================================
def island_pill(w=206, h=37, c="piyo", right="1:12"):
    return ('<div style="position:absolute;left:50%%;top:13px;transform:translateX(-50%%);z-index:9;'
            'width:%gpx;height:%gpx;border-radius:%gpx;background:#000;display:flex;align-items:center;'
            'justify-content:space-between;padding:0 11px 0 9px;box-sizing:border-box;">'
            '<div style="width:26px;height:26px;border-radius:50%%;background:#FFE066;overflow:hidden;'
            'position:relative;flex:none;">'
            '<div style="position:absolute;left:50%%;top:2px;transform:translateX(-50%%);">%s</div></div>'
            '<span class="dot" style="font-size:15px;color:#FFE066;letter-spacing:1px;">%s</span></div>'
            % (w, h, h/2, chara.svg(c, "idle", 24, 34), right))

def live_card(w=350, c="piyo", pose="walk", title="いっしょモード", status="おさんぽ中", left="あと 1:12", pct=.70):
    strip = ('<div style="position:relative;width:96px;height:74px;border-radius:16px;overflow:hidden;'
             'background:#4A4160;flex:none;">%s%s</div>'
             % (svg_layer(scene.room(96, 74, 50, night=True, window=False) + scene.shadow(48, 66, 20, .3), 96, 74, 1),
                sprite_at(c, pose, 48, 68, 50, z=2)))
    return ('<div style="position:absolute;left:20px;right:20px;bottom:214px;z-index:6;border-radius:26px;'
            'background:rgba(20,16,28,.52);border:1px solid rgba(255,244,220,.14);padding:15px 17px;'
            'box-sizing:border-box;">'
            '<div style="display:flex;align-items:center;gap:8px;margin-bottom:11px;">'
            '<div style="width:17px;height:17px;border-radius:5px;background:#FFE9B8;"></div>'
            '<span style="font-size:11.5px;letter-spacing:1.4px;color:rgba(255,244,220,.62);">CHARATIME</span></div>'
            '<div style="display:flex;align-items:center;gap:14px;">%s'
            '<div style="flex:1;min-width:0;">'
            '<div style="font-size:16px;font-weight:700;color:#FFF4DC;letter-spacing:.6px;">%s</div>'
            '<div style="margin-top:4px;font-size:12.5px;color:rgba(255,244,220,.72);">%s</div>'
            '<div style="margin-top:11px;height:6px;border-radius:3px;background:rgba(255,244,220,.20);">'
            '<div style="width:%g%%;height:100%%;border-radius:3px;background:#FFE066;"></div></div></div>'
            '<div style="text-align:right;flex:none;">'
            '<div class="dot" style="font-size:22px;color:#FFE066;letter-spacing:1px;">%s</div>'
            '<div style="margin-top:3px;font-size:10.5px;color:rgba(255,244,220,.55);">のこり</div></div>'
            '</div></div>' % (strip, title, status, pct*100, left.replace("あと ", "")))

def build_locklive():
    W, H = 390, 844
    bg = svg_layer(wallpaper(W, H, "night", "wp4", sun=(0.22, 0.43)), W, H, 0)
    clock = ('<div class="sys" style="position:absolute;left:0;top:104px;width:100%;text-align:center;z-index:4;">'
             '<div style="font-size:17px;font-weight:500;letter-spacing:.4px;color:rgba(255,255,255,.86);">'
             '9月11日 金曜日</div>'
             '<div style="font-size:82px;line-height:1.05;font-weight:600;letter-spacing:-1px;color:#fff;">22:08</div>'
             '</div>')
    inner = bg + island_pill() + clock + live_card()
    write("LockLive.dc.html", phone(inner, W, H, "#2B2440"), W, H, label="面3 ロック画面")

# ====================================================================
# 面 3-b : Dynamic Island の 2 状態
# ====================================================================
def build_island():
    W, H = 640, 452
    compact = ('<div style="position:relative;width:206px;height:37px;border-radius:18.5px;background:#000;'
               'display:flex;align-items:center;justify-content:space-between;padding:0 11px 0 9px;box-sizing:border-box;">'
               '<div style="width:26px;height:26px;border-radius:50%;background:#FFE066;overflow:hidden;position:relative;">'
               '<div style="position:absolute;left:50%;top:2px;transform:translateX(-50%);">' +
               chara.svg("piyo", "idle", 24, 34) + '</div></div>'
               '<span class="dot" style="font-size:15px;color:#FFE066;letter-spacing:1px;">1:12</span></div>')
    strip = ('<div style="position:relative;width:112px;height:86px;border-radius:18px;overflow:hidden;'
             'background:#4A4160;flex:none;">%s%s</div>'
             % (svg_layer(scene.room(112, 86, 58, night=True, window=False) + scene.shadow(56, 78, 22, .3), 112, 86, 1),
                sprite_at("piyo", "walk", 56, 80, 58, z=2)))
    expanded = ('<div style="width:372px;border-radius:40px;background:#000;padding:20px 22px 22px;'
                'box-sizing:border-box;">'
                '<div style="display:flex;align-items:center;gap:16px;">%s'
                '<div style="flex:1;min-width:0;">'
                '<div style="font-size:16px;font-weight:700;color:#FFF4DC;">いっしょモード</div>'
                '<div style="margin-top:5px;font-size:12.5px;color:rgba(255,244,220,.7);">ピヨ ・ おさんぽ中</div>'
                '<div style="margin-top:12px;height:6px;border-radius:3px;background:rgba(255,244,220,.2);">'
                '<div style="width:70%%;height:100%%;border-radius:3px;background:#FFE066;"></div></div></div>'
                '<div style="text-align:right;"><div class="dot" style="font-size:24px;color:#FFE066;">1:12</div>'
                '<div style="margin-top:2px;font-size:10px;color:rgba(255,244,220,.5);">のこり</div></div></div>'
                '</div>' % strip)
    def lab(t, d):
        return ('<div style="display:flex;flex-direction:column;align-items:center;gap:13px;">'
                '<div style="font-size:12px;letter-spacing:2px;color:rgba(255,255,255,.46);">%s</div>%s</div>' % (t, d))
    body = ('<div class="ct" style="width:%dpx;height:%dpx;box-sizing:border-box;background:#15151A;'
            'display:flex;flex-direction:column;align-items:center;justify-content:center;gap:40px;">'
            '%s%s</div>' % (W, H, lab("コンパクト", compact), lab("展開（長押し）", expanded)))
    write("DynamicIsland.dc.html", body, W, H, label="面3 Dynamic Island")

# ====================================================================
# 面 4 : 壁紙（ロック画面）
# ====================================================================
def build_wallpaper():
    W, H = 390, 844
    bg = svg_layer(wallpaper(W, H, "morning", "wp5", sun=(0.80, 0.42)) + scene.shadow(196, 676, 46, .18), W, H, 0)
    clock = ('<div class="sys" style="position:absolute;left:0;top:104px;width:100%;text-align:center;z-index:4;">'
             '<div style="font-size:17px;font-weight:500;letter-spacing:.4px;color:rgba(56,58,72,.76);">'
             '9月11日 金曜日</div>'
             '<div style="font-size:82px;line-height:1.05;font-weight:600;letter-spacing:-1px;color:#3E4354;">7:24</div>'
             '</div>')
    inner = (bg + clock + sprite_at("piyo", "happy", 196, 676, 150, z=3)
             + bubble(56, 512, "おはよう！", tail="right", fs=14))
    write("Wallpaper.dc.html", phone(inner, W, H, "#DCE6E6"), W, H, label="面4 壁紙")

# ====================================================================
# 面 5 : PiP おさんぽモード
# ====================================================================
def build_pip():
    W, H = 390, 844
    lines = ["9月11日（金）", "", "・ 牛乳とヨーグルト", "・ 図書館に本を返す", "・ 日曜の展示のチケット",
             "", "来週のごはん、月曜はカレーにする。", "土曜の午前は部屋の片づけ。"]
    txt = "".join('<div style="height:13px;"></div>' if not l else
                  '<div style="font-size:14.5px;line-height:1.95;color:%s;">%s</div>' % (INK, l) for l in lines)
    note_app = ('<div style="position:absolute;inset:0;background:#fff;z-index:1;">'
                '<div style="padding:70px 24px 0;">'
                '<div style="font-size:24px;font-weight:700;color:%s;letter-spacing:.4px;">きょうのメモ</div>'
                '<div style="margin-top:18px;">%s</div></div></div>' % (INK, txt))
    pip_inner = ('<div style="position:relative;width:100%;height:100%;">'
                 + svg_layer(wallpaper(200, 150, "day", "wp6") + scene.shadow(100, 128, 30, .2), 200, 150, 1)
                 + sprite_at("chip", "walk", 100, 130, 76, z=2) + '</div>')
    pip = ('<div style="position:absolute;right:16px;bottom:110px;width:200px;height:150px;z-index:8;'
           'border-radius:20px;overflow:hidden;box-shadow:0 10px 28px rgba(0,0,0,.28),0 2px 6px rgba(0,0,0,.16);'
           'background:#D9BEDF;">%s</div>' % pip_inner)
    write("PiP.dc.html", phone(note_app + pip, W, H, "#fff"), W, H, label="面5 PiP おさんぽ")

# ---- アイテムのアイコン --------------------------------------------
def item_art(kind, w=64, h=64):
    if kind == "ball":  s = scene.mirror_ball(32, 36, 17, ceiling=11, on=False, uid="i1")
    elif kind == "cushion": s = scene.cushion(32, 40, 46)
    elif kind == "bed": s = scene.bed(32, 54, 46)
    elif kind == "plant": s = scene.plant(32, 60, .48)
    else: s = scene.deskclock(32, 56, 10, 10, .72)
    return ('<svg viewBox="0 0 64 64" width="' + str(w) + '" height="' + str(h) + '" fill="none" '
            'xmlns="http://www.w3.org/2000/svg">' + s + '</svg>')

# ====================================================================
# アプリ内 : キャラクターをえらぶ
# ====================================================================
def build_charaselect():
    W, H = 390, 844
    tags = ["よく歩く", "朝型", "ボールが好き"]
    chips = "".join('<span style="background:#FFF2DC;color:#B97233;font-size:12px;font-weight:700;'
                    'padding:6px 12px;border-radius:11px;">' + t + '</span>' for t in tags)
    preview = ('<div style="position:absolute;left:20px;right:20px;top:120px;height:334px;background:#fff;'
               'border-radius:30px;border:2px solid ' + LINE + ';overflow:hidden;z-index:3;">'
               + svg_layer(scene.rug(175, 232, 106, 34) + scene.shadow(175, 236, 40, .16), 346, 330, 1)
               + sprite_at("piyo", "idle", 175, 236, 152, z=2)
               + '<div style="position:absolute;left:0;right:0;bottom:0;padding:14px 0 18px;text-align:center;'
                 'z-index:4;background:linear-gradient(180deg,rgba(255,255,255,0),#fff 26%);">'
                 '<div style="font-size:22px;font-weight:700;color:' + INK + ';letter-spacing:1.5px;">ピヨ</div>'
                 '<div style="margin-top:9px;display:flex;gap:7px;justify-content:center;">' + chips + '</div>'
                 '</div></div>')
    picks = ""
    for c in ["piyo", "mochi", "kumao", "fuwa", "chip"]:
        on = c == "piyo"
        picks += ('<div style="display:flex;flex-direction:column;align-items:center;gap:7px;">'
                  '<div style="position:relative;width:62px;height:62px;border-radius:50%;background:'
                  + ("#FFF2DC" if on else "#fff") + ';border:' + ("3px solid " + ACC if on else "2px solid " + LINE)
                  + ';overflow:hidden;">'
                  '<div style="position:absolute;left:50%;bottom:-7px;transform:translateX(-50%);">'
                  + chara.svg(c, "idle", 46, 65) + '</div></div>'
                  '<span style="font-size:11.5px;font-weight:' + ("700" if on else "400") + ';color:'
                  + (INK if on else MUT) + ';">' + P[c]["name"] + '</span></div>')
    row = ('<div style="position:absolute;left:20px;right:20px;top:480px;z-index:3;display:flex;'
           'justify-content:space-between;">' + picks + '</div>')
    bars = ""
    for label, v in [("よく歩く", .9), ("夜ふかし", .12), ("ひるね", .3)]:
        bars += ('<div style="display:flex;align-items:center;gap:12px;">'
                 '<span style="width:64px;font-size:12.5px;color:' + MUT + ';">' + label + '</span>'
                 '<div style="flex:1;height:8px;border-radius:4px;background:#F0E4D2;">'
                 '<div style="width:' + str(int(v*100)) + '%;height:100%;border-radius:4px;background:'
                 + ACC2 + ';"></div></div></div>')
    stat = ('<div style="position:absolute;left:20px;right:20px;top:602px;z-index:3;background:#fff;'
            'border-radius:22px;border:2px solid ' + LINE + ';padding:17px 18px;display:flex;'
            'flex-direction:column;gap:12px;">' + bars + '</div>')
    body = ('<div class="ct" style="position:relative;width:' + str(W) + 'px;height:' + str(H) + 'px;'
            'background:' + BG + ';overflow:hidden;">'
            + app_header("キャラクターをえらぶ", "あとから何度でも変えられる")
            + preview + row + stat + cta("ピヨにする") + '</div>')
    write("CharaSelect.dc.html", body, W, H, label="アプリ キャラ選択")

# ====================================================================
# アプリ内 : へやをかざる
# ====================================================================
def build_roomeditor():
    W, H = 390, 844
    room = (svg_layer(scene.room(346, 300, 196, night=True, window=False)
                      + scene.rug(173, 252, 104, 32, night=True)
                      + scene.mirror_ball(104, 78, 21, ceiling=0, on=True, uid="mb2")
                      + scene.sparkles([(62,58,5),(150,70,4),(70,126,4),(146,120,5),(40,96,4)])
                      + scene.plant(46, 250, .66)
                      + scene.cushion(252, 250, 56)
                      + scene.shadow(104, 258, 32, .26), 346, 300, 1)
            + sprite_at("fuwa", "happy", 104, 258, 104, z=2))
    preview = ('<div style="position:absolute;left:20px;right:20px;top:118px;height:300px;border-radius:28px;'
               'overflow:hidden;border:2px solid ' + LINE + ';z-index:3;background:#3E3653;">' + room
               + '<div style="position:absolute;left:14px;top:14px;z-index:5;background:rgba(255,255,255,.90);'
                 'border-radius:11px;padding:5px 11px;font-size:11px;font-weight:700;color:' + INK + ';">'
                 'ドラッグして置く</div></div>')
    segs = ""
    for i, t in enumerate(["おへや", "しゃしん", "ホーム画面"]):
        on = i == 0
        segs += ('<div style="flex:1;text-align:center;padding:10px 0;border-radius:13px;font-size:13px;'
                 'font-weight:' + ("700" if on else "400") + ';color:' + (INK if on else MUT)
                 + ';background:' + ("#fff" if on else "transparent") + ';'
                 + ("box-shadow:0 1px 3px rgba(59,43,43,.12);" if on else "") + '">' + t + '</div>')
    seg = ('<div style="position:absolute;left:20px;right:20px;top:436px;z-index:3;display:flex;gap:4px;'
           'background:#F0E4D2;border-radius:16px;padding:4px;">' + segs + '</div>')
    items = [("ball", "ミラーボール", True), ("cushion", "クッション", True), ("plant", "観葉植物", True),
             ("clock", "置き時計", True), ("bed", "ベッド", True)]
    cards = ""
    for k, n, owned in items:
        cards += ('<div style="flex:none;width:76px;display:flex;flex-direction:column;align-items:center;gap:8px;">'
                  '<div style="position:relative;width:76px;height:76px;border-radius:19px;background:'
                  + ("#fff" if owned else "#F3EADC") + ';border:2px solid ' + (ACC if k == "ball" else LINE)
                  + ';display:flex;align-items:center;justify-content:center;">' + item_art(k, 60, 60)
                  + ('' if owned else '<div style="position:absolute;inset:0;border-radius:18px;'
                     'background:rgba(251,245,236,.72);display:flex;align-items:center;justify-content:center;">'
                     '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="' + MUT + '" '
                     'stroke-width="2" stroke-linecap="round"><rect x="5" y="11" width="14" height="9" rx="2.4"/>'
                     '<path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg></div>')
                  + '</div><span style="font-size:11px;color:' + (INK if owned else MUT) + ';white-space:nowrap;">'
                  + n + '</span></div>')
    tray = ('<div style="position:absolute;left:0;right:0;top:512px;z-index:3;">'
            '<div style="padding:0 20px 11px;font-size:12.5px;font-weight:700;color:' + INK + ';">もちもの</div>'
            '<div style="display:flex;gap:11px;padding:0 20px;overflow:hidden;">' + cards + '</div></div>')
    note = ('<div style="position:absolute;left:20px;right:20px;top:672px;z-index:3;background:#FFF2DC;'
            'border-radius:18px;padding:14px 16px;font-size:12px;line-height:1.75;color:#8A6034;">'
            '<b>ミラーボール</b>を置くと、夜のあいだ、この子はその下で踊るようになる。</div>')
    body = ('<div class="ct" style="position:relative;width:' + str(W) + 'px;height:' + str(H) + 'px;'
            'background:' + BG + ';overflow:hidden;">'
            + app_header("へやをかざる", "アイテムが行動をふやす") + preview + seg + tray + note
            + cta("できあがり") + '</div>')
    write("RoomEditor.dc.html", body, W, H, label="アプリ 部屋の編集")

# ====================================================================
# アプリ内 : キャラ工房
# ====================================================================
def build_charastudio():
    W, H = 390, 844
    checker = ('background-image:linear-gradient(45deg,#E8DFD0 25%,transparent 25%),'
               'linear-gradient(-45deg,#E8DFD0 25%,transparent 25%),'
               'linear-gradient(45deg,transparent 75%,#E8DFD0 75%),'
               'linear-gradient(-45deg,transparent 75%,#E8DFD0 75%);'
               'background-size:16px 16px;background-position:0 0,0 8px,8px -8px,-8px 0;background-color:#FBF7F0;')
    preview = ('<div style="position:absolute;left:20px;right:20px;top:120px;height:258px;border-radius:28px;'
               'overflow:hidden;border:2px solid ' + LINE + ';z-index:3;' + checker + '">'
               '<div style="position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);">'
               + chara.svg("kumao", "idle", 150, 213) + '</div>'
               '<div style="position:absolute;left:14px;top:14px;background:rgba(255,255,255,.92);'
               'border-radius:11px;padding:5px 11px;font-size:11px;font-weight:700;color:' + INK + ';">'
               '切り抜きました</div>'
               '<div style="position:absolute;right:14px;bottom:14px;background:' + ACC2 + ';color:#fff;'
               'border-radius:11px;padding:5px 11px;font-size:11px;font-weight:700;">端末の中だけで処理</div>'
               '</div>')
    steps = [("1", "プロンプトをコピー", "画風とポーズの指示を、そのまま貼れる形で渡す"),
             ("2", "ChatGPT / Gemini で作る", "8 コマのグリッドで一度に描かせる"),
             ("3", "画像を読みこむ", "背景は端末の中で切り抜く。外には送らない"),
             ("4", "ポーズを割りあてる", "1 枚だけでも動く。歩くのに要るのは 4 枚")]
    rows = ""
    for n, t, d in steps:
        rows += ('<div style="display:flex;gap:13px;align-items:flex-start;">'
                 '<div style="flex:none;width:26px;height:26px;border-radius:50%;background:' + ACC + ';color:#fff;'
                 'font-size:13px;font-weight:700;display:flex;align-items:center;justify-content:center;">' + n + '</div>'
                 '<div><div style="font-size:14px;font-weight:700;color:' + INK + ';">' + t + '</div>'
                 '<div style="margin-top:3px;font-size:12px;line-height:1.6;color:' + MUT + ';">' + d + '</div></div></div>')
    steplist = ('<div style="position:absolute;left:20px;right:20px;top:404px;z-index:3;background:#fff;'
                'border-radius:24px;border:2px solid ' + LINE + ';padding:20px 20px;display:flex;'
                'flex-direction:column;gap:17px;">' + rows + '</div>')
    body = ('<div class="ct" style="position:relative;width:' + str(W) + 'px;height:' + str(H) + 'px;'
            'background:' + BG + ';overflow:hidden;">'
            + app_header("キャラ工房", "じぶんで作った子を連れてくる")
            + preview + steplist + cta("この子を登録する", sub="登録した子も、同じ日課で動きます") + '</div>')
    write("CharaStudio.dc.html", body, W, H, label="アプリ キャラ工房")

# ====================================================================
# キャラクター仕様シート
# ====================================================================
def build_sheet():
    W, H = 1400, 812
    chips = ["2 頭身", "輪郭線 #3B2B2B・本体は太さ一定", "ベタ塗り＋影は 1 段", "1 体 4 色まで",
             "突起は 1 つだけ", "40pt でも見分けられる"]
    chiprow = "".join('<span style="background:#fff;border:2px solid ' + LINE + ';border-radius:13px;'
                      'padding:7px 14px;font-size:12.5px;color:' + INK + ';">' + c + '</span>' for c in chips)
    roster = ""
    for c in ["piyo", "mochi", "kumao", "fuwa", "chip"]:
        p = P[c]
        sw = "".join('<span style="width:19px;height:19px;border-radius:50%;background:' + col
                     + ';border:2px solid #3B2B2B;"></span>' for col in [p["body"], p["sub"], p["acc"], p["cheek"]])
        roster += ('<div style="display:flex;flex-direction:column;align-items:center;gap:11px;">'
                   + chara.svg(c, "idle", 132, 187)
                   + '<div style="font-size:16px;font-weight:700;color:' + INK + ';letter-spacing:1px;">'
                   + p["name"] + '</div>'
                   + '<div style="display:flex;gap:6px;">' + sw + '</div></div>')
    # コマの並びは chara.FRAMES が持つ（tools/pipeline が焼く 11 枚と同じもの）。
    LABEL = {"idle": "立つ", "walk": "歩く", "sit": "すわる", "sleep": "ねる", "happy": "よろこぶ"}
    poserow = ""
    for pose, frames in chara.FRAMES:
        for i, frame in enumerate(frames):
            lab = "%s %d/%d" % (LABEL[pose], i + 1, len(frames))
            poserow += ('<div style="display:flex;flex-direction:column;align-items:center;gap:9px;">'
                        + chara.svg("piyo", frame, 78, 108)
                        + '<span style="font-size:11px;color:' + MUT + ';">' + lab + '</span></div>')
    smalls = ""
    for lab, sz in [("40pt", 40), ("28pt", 28), ("20pt", 20)]:
        cells = "".join('<div style="width:' + str(sz + 14) + 'px;height:' + str(sz + 14) + 'px;background:#fff;'
                        'border:1px solid ' + LINE + ';border-radius:9px;display:flex;align-items:flex-end;'
                        'justify-content:center;overflow:hidden;">'
                        + chara.svg(c, "idle", sz, sz / 120.0 * 170) + '</div>'
                        for c in ["piyo", "mochi", "kumao", "fuwa", "chip"])
        smalls += ('<div style="display:flex;align-items:center;gap:13px;">'
                   '<span style="width:38px;font-size:12px;color:' + MUT + ';">' + lab + '</span>'
                   '<div style="display:flex;gap:9px;align-items:flex-end;">' + cells + '</div></div>')
    def sec(t):
        return ('<div style="font-size:13px;font-weight:700;letter-spacing:2px;color:' + ACC + ';">' + t + '</div>')
    body = ('<div class="ct" style="width:' + str(W) + 'px;height:' + str(H) + 'px;box-sizing:border-box;'
            'background:' + BG + ';padding:44px 52px;display:flex;flex-direction:column;gap:26px;">'
            '<div><div style="font-size:26px;font-weight:700;color:' + INK + ';letter-spacing:1px;">'
            'キャラクター ― 画風「まるっとフラット」</div>'
            '<div style="margin-top:9px;font-size:13px;color:' + MUT + ';">'
            'サンリオ等の識別要素は使わないオリジナル。生成 AI で作り、人が手を入れて確定させる。</div></div>'
            '<div style="display:flex;gap:9px;flex-wrap:wrap;">' + chiprow + '</div>'
            '<div style="display:flex;gap:30px;">'
            '<div style="flex:1;display:flex;flex-direction:column;gap:15px;">' + sec("5 体のロスター")
            + '<div style="display:flex;gap:22px;justify-content:space-between;">' + roster + '</div></div>'
            '<div style="width:2px;background:' + LINE + ';"></div>'
            '<div style="flex:none;width:330px;display:flex;flex-direction:column;gap:15px;">'
            + sec("小さいときの見え方") + '<div style="display:flex;flex-direction:column;gap:15px;">' + smalls + '</div>'
            '<div style="margin-top:2px;font-size:11.5px;line-height:1.7;color:' + MUT + ';">'
            'ウィジェットやロック画面では 40pt 前後で表示される。突起と主色だけで誰か分かることを採用条件にした。</div>'
            '</div></div>'
            '<div style="display:flex;flex-direction:column;gap:15px;">' + sec("1 体ぶんのポーズ（Tier 1 ＝ 11 枚）")
            + '<div style="display:flex;gap:20px;align-items:flex-end;">' + poserow
            + '<div style="margin-left:10px;max-width:300px;font-size:11.5px;line-height:1.8;color:' + MUT + ';">'
            '立つ 2 ＋ 歩く 4 ＋ すわる 1 ＋ ねる 2 ＋ よろこぶ 2 ＝ <b>11 枚</b>。<br>'
            '右向きは左向きの反転で作るので、描くのは左向きだけ。<br>'
            '足りない表情は、はねる・かたむく・呼吸などコード側の動きで足す。</div>'
            '</div></div></div>')
    write("CharacterSheet.dc.html", body, W, H, label="キャラクター仕様")

# ====================================================================
# すべて生成 ＋ canvas.json
# ====================================================================
TITLES = {
 "Main.dc.html": "面0 待受モード（夜）", "StandbyHome.dc.html": "面0 ホーム画面の上を歩く",
 "HomeWidget.dc.html": "面1 ホーム画面（完成形）", "HomeWidgetSpec.dc.html": "面1 ウィジェットの構成",
 "WidgetHours.dc.html": "面1 時間で変わる", "Wallpaper.dc.html": "面4 壁紙（ロック画面）",
 "LockLive.dc.html": "面3 ロック画面＋いっしょモード", "DynamicIsland.dc.html": "面3 Dynamic Island",
 "PiP.dc.html": "面5 PiP おさんぽモード", "StandBy.dc.html": "面2 StandBy（充電中・横置き）",
 "CharaSelect.dc.html": "キャラクターをえらぶ", "RoomEditor.dc.html": "へやをかざる",
 "CharaStudio.dc.html": "キャラ工房", "CharacterSheet.dc.html": "キャラクター仕様",
}
LAYOUT = [
 # file, x, y, w, h, page
 ("Main.dc.html",            0,    0, 390, 844, "page-1"),
 ("StandbyHome.dc.html",   470,    0, 390, 844, "page-1"),
 ("HomeWidget.dc.html",    940,    0, 390, 844, "page-1"),
 ("HomeWidgetSpec.dc.html",1410,   0, 390, 844, "page-1"),
 ("WidgetHours.dc.html",   1880,   0, 462,1000, "page-1"),
 ("Wallpaper.dc.html",        0,1320, 390, 844, "page-1"),
 ("LockLive.dc.html",       470,1320, 390, 844, "page-1"),
 ("DynamicIsland.dc.html",  940,1320, 640, 452, "page-1"),
 ("PiP.dc.html",           1660,1320, 390, 844, "page-1"),
 ("StandBy.dc.html",       2130,1320, 844, 390, "page-1"),
 ("CharaSelect.dc.html",      0,   0, 390, 844, "page-2"),
 ("RoomEditor.dc.html",     470,   0, 390, 844, "page-2"),
 ("CharaStudio.dc.html",    940,   0, 390, 844, "page-2"),
 ("CharacterSheet.dc.html",   0,   0,1400, 812, "page-3"),
]
NOTES = [
 ("n-standby-mode", 0, 1080, 390, "page-1",
  "面0 待受モード\nアプリを開いているあいだだけ。60fps で自由に歩き回れる唯一の面なので、ここに「勝手に生きている」を作り込む。机の充電スタンド前提。"),
 ("n-homeshot", 470, 1080, 390, "page-1",
  "同じ待受モードで、背景をユーザーのホーム画面のスクショにした状態。メモにあった「アプリが並んでいる画面を歩く」に最も近い見え方。"),
 ("n-widget", 940, 1080, 860, "page-1",
  "面1 ホーム画面ウィジェット\n壁紙のスクショを機種ごとの座標で切り抜き、ウィジェットの背景に敷くことで枠を消している（透過ウィジェット）。ライト/ダーク外観でのみ成立し、着色・クリア外観ではシステムが背景を置き換えてしまう。右は同じ画面で枠を見せたもの。"),
 ("n-hours", 1880, 1080, 462, "page-1",
  "ウィジェットは 1 日 40〜70 回しか更新できないので、5 分刻みの姿を先に計算して並べておく。秒単位で動かす疑似アニメは Phase 0 のスパイクで実機判定してから。"),
 ("n-wallpaper", 0, 2200, 390, "page-1",
  "面4 壁紙\nアプリから壁紙は設定できない。時間帯ごとの画像を書き出し、写真シャッフルかショートカットで差し替えてもらう。粒度は 1 時間〜数時間。"),
 ("n-live", 470, 2200, 1110, "page-1",
  "面3 いっしょモード\nLive Activity は最長 8 時間で自動終了するので、常駐ペットにはしない。1・2・4 時間のセッションとして始め、終わりに「またあとでね」で閉じる。Dynamic Island はコンパクトと展開の 2 状態。"),
 ("n-pip", 1660, 2200, 390, "page-1",
  "面5 PiP\nほかのアプリの上に出せる唯一の公開 API。窓は不透明な角丸なので、中には壁紙の一部を敷いて「部屋の続き」に見せる。ホーム画面の上なら透けているように見え、この図のように白いアプリの上では小さな窓として出る。Phase 4 の実験枠。"),
 ("n-standby", 2130, 2200, 844, "page-1",
  "面2 StandBy\n充電中・横置き・ロック時に出る。背景は必ず除去されるので、部屋そのものをウィジェットの中身として描く。夜間は赤いティントがかかる。"),
 ("n-select", 0, 920, 390, "page-2", "選んだあとも何度でも変えられる。性格（よく歩く・夜ふかし・ひるね）が日課の偏りになる。"),
 ("n-room", 470, 920, 390, "page-2", "アイテムは飾りではなく行動の語彙。ミラーボールを置くと夜の踊りが増える、クッションを置くと座る。"),
 ("n-studio", 940, 920, 390, "page-2", "自分で生成したキャラを取り込む。切り抜きは端末の中だけで行い、画像を外に送らない。1 枚でも動く。"),
 ("n-sheet", 0, 870, 1400, "page-3",
  "画風「まるっとフラット」。2 頭身・太さ一定の輪郭線・ベタ塗り・1 体 4 色まで。突起を 1 つだけ持たせて、40pt でも誰か分かるようにしている。右向きは左向きの反転で作る。"),
]

def build_all():
    ARTBOARDS.clear()
    build_main(); build_standbyhome(); build_homewidget(False); build_homewidget(True)
    build_widgethours(); build_standby(); build_locklive(); build_island()
    build_wallpaper(); build_pip(); build_charaselect(); build_roomeditor()
    build_charastudio(); build_sheet()
    import json
    cv = {"artboards": [{"file": f, "x": x, "y": y, "w": w, "h": h, "page": pg, "title": TITLES[f]}
                        for f, x, y, w, h, pg in LAYOUT],
          "annotations": [{"id": i, "x": x, "y": y, "w": w, "page": pg, "text": t}
                          for i, x, y, w, pg, t in NOTES],
          "pages": [{"id": "page-1", "name": "面（iPhone の各画面）"},
                    {"id": "page-2", "name": "アプリ内の画面"},
                    {"id": "page-3", "name": "キャラクター"}],
          "launch": {"view": "canvas", "page": "page-1"}}
    open("canvas.json", "w").write(json.dumps(cv, ensure_ascii=False, indent=2))
    return [a[0] for a in ARTBOARDS]

if __name__ == "__main__":
    print("\n".join(build_all()))
