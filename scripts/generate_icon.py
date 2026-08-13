#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""安装《塑身工坊》启动器图标 —— 古典人体雕塑（维纳斯 / 大卫），不是战斗魔物。

源图：
- assets/branding/sculpt/venus/{0-clay … 7-rebound}.png
- assets/branding/sculpt/david/{0-clay … 7-rebound}.png
  0/1 两线共用粘土与石块。

桌面默认 ic_launcher = 人体粘土（stage 0），不用 app_icon_full 魔物图。
"""
from __future__ import annotations

import glob
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
)
BRANDING = os.path.join(ROOT, "assets", "branding")
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
IMAGES = os.path.join(ROOT, "images")
SCULPT_DIR = os.path.join(BRANDING, "sculpt")

STAGE_STEMS = (
    "0-clay",
    "1-block",
    "2-rough",
    "3-emerge",
    "4-master",
    "5-polish",
    "6-dust",
    "7-rebound",
)

# 与工坊炭黑底接近，避免白角透出 squircle 蒙版
CHARCOAL = (28, 25, 22, 255)

LEGACY_SIZES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}

ADAPTIVE_FG = {
    "mdpi": 108,
    "hdpi": 162,
    "xhdpi": 216,
    "xxhdpi": 324,
    "xxxhdpi": 432,
}


def _ensure_rgba(img: Image.Image) -> Image.Image:
    return img.convert("RGBA") if img.mode != "RGBA" else img


def fill_corners_charcoal(img: Image.Image) -> Image.Image:
    """把圆形图标四周近白/近透明像素填成炭黑，避免启动器白角。"""
    img = _ensure_rgba(img)
    w, h = img.size
    px = img.load()
    cx, cy = w / 2.0, h / 2.0
    r = min(w, h) * 0.49
    for y in range(h):
        for x in range(w):
            r0, g0, b0, a0 = px[x, y]
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            outside = d > r
            near_white = r0 > 232 and g0 > 232 and b0 > 232
            if outside or (near_white and a0 > 200):
                px[x, y] = CHARCOAL
            elif a0 < 16:
                px[x, y] = CHARCOAL
    return img


def square_on_charcoal(img: Image.Image, size: int) -> Image.Image:
    src = fill_corners_charcoal(img)
    src = src.resize((size, size), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (size, size), CHARCOAL)
    out.alpha_composite(src)
    return out


def circle_mask(size: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    return mask.filter(ImageFilter.GaussianBlur(radius=max(0.4, size * 0.004)))


def make_round(img: Image.Image, size: int) -> Image.Image:
    square = square_on_charcoal(img, size)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(square, (0, 0), circle_mask(size))
    return out


def _is_backdrop(rgb: tuple[int, int, int]) -> bool:
    r0, g0, b0 = rgb
    if r0 > 228 and g0 > 228 and b0 > 228:
        return True
    luma = 0.2126 * r0 + 0.7152 * g0 + 0.0722 * b0
    chroma = max(r0, g0, b0) - min(r0, g0, b0)
    return luma < 22 and chroma < 18


def knock_out_bg(img: Image.Image) -> Image.Image:
    """从四角洪水填充抠掉黑/白底板。"""
    img = _ensure_rgba(img)
    w, h = img.size
    px = img.load()
    seen = bytearray(w * h)
    stack = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]
    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= w or y >= h:
            continue
        i = y * w + x
        if seen[i]:
            continue
        seen[i] = 1
        r0, g0, b0, a0 = px[x, y]
        if a0 < 8 or _is_backdrop((r0, g0, b0)):
            px[x, y] = (r0, g0, b0, 0)
            stack.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return img


def pad_foreground(img: Image.Image, size: int, margin: float = 0.20) -> Image.Image:
    src = knock_out_bg(img)
    inner = max(8, int(size * (1.0 - margin * 2)))
    fitted = src.copy()
    fitted.thumbnail((inner, inner), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ox = (size - fitted.width) // 2
    oy = (size - fitted.height) // 2
    canvas.alpha_composite(fitted, (ox, oy))
    return canvas


def write_text(path: str, text: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def write_adaptive_xml(name: str, fg: str) -> None:
    xml = f"""<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/{fg}"/>
</adaptive-icon>
"""
    anydpi = os.path.join(RES, "mipmap-anydpi-v26")
    write_text(os.path.join(anydpi, f"{name}.xml"), xml)
    write_text(os.path.join(anydpi, f"{name}_round.xml"), xml)


def write_background_color() -> None:
    write_text(
        os.path.join(RES, "values", "ic_launcher_background.xml"),
        """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#1C1916</color>
</resources>
""",
    )


def install_one(src_path: str, stem: str) -> None:
    if not os.path.isfile(src_path):
        raise SystemExit(f"missing {src_path}")
    full = _ensure_rgba(Image.open(src_path))
    fg_name = f"{stem}_foreground"
    for dpi, px in LEGACY_SIZES.items():
        out_dir = os.path.join(RES, f"mipmap-{dpi}")
        os.makedirs(out_dir, exist_ok=True)
        square_on_charcoal(full, px).save(os.path.join(out_dir, f"{stem}.png"))
        make_round(full, px).save(os.path.join(out_dir, f"{stem}_round.png"))
        pad_foreground(full, ADAPTIVE_FG[dpi]).save(
            os.path.join(out_dir, f"{fg_name}.png")
        )
    write_adaptive_xml(name=stem, fg=fg_name)
    print(f"[ok] {stem} <- {os.path.relpath(src_path, ROOT)}")


def remove_legacy_monster_stages() -> None:
    """去掉旧的 5 阶段魔物 launcher 残留（sculpt_2/3/4）。"""
    patterns = [
        os.path.join(RES, "mipmap-*", "ic_launcher_sculpt_2*"),
        os.path.join(RES, "mipmap-*", "ic_launcher_sculpt_3*"),
        os.path.join(RES, "mipmap-*", "ic_launcher_sculpt_4*"),
        os.path.join(RES, "mipmap-anydpi-v26", "ic_launcher_sculpt_2*"),
        os.path.join(RES, "mipmap-anydpi-v26", "ic_launcher_sculpt_3*"),
        os.path.join(RES, "mipmap-anydpi-v26", "ic_launcher_sculpt_4*"),
    ]
    for pat in patterns:
        for path in glob.glob(pat):
            # 保留 venus_2 / david_2 等新名
            base = os.path.basename(path)
            if base.startswith("ic_launcher_sculpt_venus_") or base.startswith(
                "ic_launcher_sculpt_david_"
            ):
                continue
            if base.startswith("ic_launcher_sculpt_2") or base.startswith(
                "ic_launcher_sculpt_3"
            ) or base.startswith("ic_launcher_sculpt_4"):
                os.remove(path)
                print(f"[rm] {path}")


def install_sculpt_stages() -> None:
    write_background_color()
    # 0/1 共用人体粘土/石块
    for i in (0, 1):
        src = os.path.join(SCULPT_DIR, "venus", f"{STAGE_STEMS[i]}.png")
        install_one(src, f"ic_launcher_sculpt_{i}")

    for line in ("venus", "david"):
        for i in range(2, 8):
            src = os.path.join(SCULPT_DIR, line, f"{STAGE_STEMS[i]}.png")
            install_one(src, f"ic_launcher_sculpt_{line}_{i}")

    # 默认启动器 = 人体粘土，不用魔物全图
    clay = os.path.join(SCULPT_DIR, "venus", f"{STAGE_STEMS[0]}.png")
    full = _ensure_rgba(Image.open(clay))
    for dpi, px in LEGACY_SIZES.items():
        out_dir = os.path.join(RES, f"mipmap-{dpi}")
        square_on_charcoal(full, px).save(os.path.join(out_dir, "ic_launcher.png"))
        make_round(full, px).save(os.path.join(out_dir, "ic_launcher_round.png"))
        pad_foreground(full, ADAPTIVE_FG[dpi]).save(
            os.path.join(out_dir, "ic_launcher_foreground.png")
        )
    write_adaptive_xml(name="ic_launcher", fg="ic_launcher_foreground")
    preview = square_on_charcoal(full, 512)
    preview.save(os.path.join(BRANDING, "app_icon_512.png"))
    os.makedirs(IMAGES, exist_ok=True)
    square_on_charcoal(full, 1024).save(os.path.join(IMAGES, "icon_preview.png"))
    remove_legacy_monster_stages()


def main() -> None:
    install_sculpt_stages()
    print("preview:", os.path.join(IMAGES, "icon_preview.png"))


if __name__ == "__main__":
    main()
