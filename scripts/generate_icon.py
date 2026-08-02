#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成《塑身工坊》App 图标 —— 好的身材，精雕细琢

设计语言（锻造工坊主题）：
- 暖炭黑圆底 + 顶部炉火辉光（径向渐变）
- 中央铜金 S 曲线剪影：女性身体曲线 = 待雕琢的作品
- 炉火赤红"雕琢火花"沿曲线飞溅：精雕细琢的过程感
- 铜金描边 + 底部微光投影

输出：Android 全部 mipmap 尺寸 ic_launcher.png / ic_launcher_round.png
"""
import math
import os
from PIL import Image, ImageDraw

# ============ 主题色（与 AppColors 一致） ============
BG = (20, 17, 14)          # #14110E 炭黑
BG_TOP = (42, 30, 22)      # 炉火暖棕
EMBER = (232, 93, 76)      # #E85D4C 炉火赤红
COPPER = (196, 165, 116)   # #C4A574 铜金
GOLD = (222, 194, 145)     # 铜金高光
GLOW = (255, 138, 91)      # #FF8A5B 锻造辉光
CREAM = (255, 248, 245)    # 近白

SIZES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}
OUT_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "android", "app", "src", "main", "res",
)


def lerp_color(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def radial_bg(size, cx, cy, r_outer, r_inner, c_center, c_edge):
    """径向渐变圆形背景"""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    cx_s, cy_s = cx * size, cy * size
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - cx_s, y - cy_s) / size
            t = max(0.0, min(1.0, (d - r_inner) / max(1e-6, r_outer - r_inner)))
            px[x, y] = lerp_color(c_center, c_edge, t ** 1.35)
    return img


def draw_s_curve(draw, size, t_start, t_end, width, color_fn, samples=220):
    """参数化 S 曲线剪影：x = A*sin(pi*t) 偏移，y 从顶到底"""
    A = 0.115 * size          # 水平振幅
    y0, y1 = 0.24 * size, 0.76 * size
    pts = []
    for i in range(samples + 1):
        t = t_start + (t_end - t_start) * i / samples
        y = y0 + (y1 - y0) * t
        x = size / 2 + A * math.sin(math.pi * t)
        pts.append((x, y, t))
    # 逐段画线（渐变描边）
    seg = 6
    for i in range(0, len(pts) - seg, seg):
        p1, p2 = pts[i], pts[i + seg]
        draw.line(
            [p1[:2], p2[:2]],
            fill=color_fn((p1[2] + p2[2]) / 2),
            width=width,
            joint="curve",
        )
    return pts


def make_icon(size, rounded=True):
    """生成一个尺寸的图标"""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    # 1) 圆形底：炭黑 + 顶部炉火辉光
    base = radial_bg(size, 0.5, 0.42, 0.5, 0.0, BG_TOP, BG)
    mask = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(mask)
    if rounded:
        r = size * 0.225
        md.rounded_rectangle([0, 0, size - 1, size - 1], radius=r, fill=255)
    else:
        md.ellipse([0, 0, size - 1, size - 1], fill=255)
    img.paste(base, (0, 0), mask)

    draw = ImageDraw.Draw(img)

    # 2) 曲线高光描边（先画宽的暗描边，再叠亮色，产生雕刻感）
    def dark_color(t):
        return lerp_color((60, 42, 30), (38, 26, 20), t)

    def bright_color(t):
        # 从铜金渐变到高亮金，中间泛赤红（炉火映照）
        if t < 0.45:
            return lerp_color(COPPER, GOLD, t / 0.45)
        return lerp_color(GOLD, EMBER, (t - 0.45) / 0.55)

    w = max(3, int(size * 0.075))
    # 暗底边 → 立体感
    draw_s_curve(draw, size, 0.0, 1.0, w + max(2, int(size * 0.02)), lambda t: dark_color(t))
    # 主曲线（铜金→金→赤红渐变，自上而下）
    draw_s_curve(draw, size, 0.0, 1.0, w, bright_color)

    # 3) 雕琢火花（炉火赤红圆点，沿曲线中段飞溅）
    rng_seed = 7
    spark_pts = [(0.52, 0.34), (0.62, 0.40), (0.40, 0.52), (0.58, 0.60), (0.47, 0.66), (0.64, 0.28)]
    for i, (sx, sy) in enumerate(spark_pts):
        x, y = sx * size, sy * size
        r = size * (0.016 + 0.004 * ((i + rng_seed) % 3))
        color = GLOW if i % 2 == 0 else EMBER
        draw.ellipse([x - r, y - r, x + r, y + r], fill=color)

    # 4) 曲线两端的小锤点（锻造触点）：顶部一点铜金
    r = max(2, size * 0.028)
    draw.ellipse([size / 2 - r, 0.235 * size - r, size / 2 + r, 0.235 * size + r], fill=GOLD)

    # 5) 底部微光投影（曲线下端泛赤红）
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gx, gy = 0.5 * size, 0.8 * size
    gr = 0.22 * size
    for yy in range(int(gy - gr), int(gy + gr)):
        for xx in range(int(gx - gr), int(gx + gr)):
            d = math.hypot(xx - gx, yy - gy) / gr
            if d < 1.0:
                a = int(70 * (1 - d) ** 2)
                if a > 0:
                    gd.point((xx, yy), fill=(255, 138, 91, a))
    img = Image.alpha_composite(img, glow)
    img = Image.alpha_composite(img, glow)

    return img


def main():
    root = os.path.normpath(OUT_DIR)
    for dpi, px in SIZES.items():
        out = os.path.join(root, f"mipmap-{dpi}")
        os.makedirs(out, exist_ok=True)
        icon = make_icon(px, rounded=True)
        icon.save(os.path.join(out, "ic_launcher.png"))
        round_icon = make_icon(px, rounded=False)
        round_icon.save(os.path.join(out, "ic_launcher_round.png"))
        print(f"[ok] {dpi} {px}px")
    # 预览大图（供人工检查）
    preview = make_icon(1024, rounded=True)
    preview_path = os.path.normpath(os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "images", "icon_preview.png",
    ))
    preview.save(preview_path)
    print("preview:", preview_path)


if __name__ == "__main__":
    main()
