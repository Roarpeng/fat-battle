#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 0-clay 圆龛外的近白/灰边铺成纯黑 #000000，不重画圆内粘土。

大卫 / 维纳斯 stage 0 共用同一文件。从四边洪水填充亮像素，
并用半径保险：圆内（黑环以内）一律不改。
"""
from __future__ import annotations

import hashlib
import os
import shutil
from collections import deque

from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
SRC = os.path.join(ROOT, "assets", "branding", "sculpt", "david", "0-clay.png")
DST = os.path.join(ROOT, "assets", "branding", "sculpt", "venus", "0-clay.png")

BLACK = (0, 0, 0)
# 黑环实测半径约 473–477（1024² 图，中心 511.5）
R_PROTECT = 468.0  # 以内：粘土 / 工具 / 工坊，禁止改
R_FORCE = 478.0  # 以外：圆龛外画布，一律纯黑


def _luma(p: tuple[int, ...]) -> float:
    return 0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2]


def _is_outer_fillable(p: tuple[int, ...]) -> bool:
    """近白、浅灰边、抗锯齿晕；停在黑环（luma ~10）。"""
    r, g, b = p[0], p[1], p[2]
    if r <= 2 and g <= 2 and b <= 2:
        return False
    luma = _luma(p)
    chroma = max(r, g, b) - min(r, g, b)
    if min(r, g, b) >= 180:
        return True
    if luma >= 160 and chroma < 40:
        return True
    if luma >= 20:
        return True
    return False


def fill_outer_black(img: Image.Image) -> Image.Image:
    img = img.convert("RGB")
    w, h = img.size
    px = img.load()
    cx, cy = (w - 1) / 2.0, (h - 1) / 2.0

    def dist(x: int, y: int) -> float:
        return ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5

    # 1) 半径外：整圈画布强制 #000000
    for y in range(h):
        for x in range(w):
            if dist(x, y) >= R_FORCE:
                px[x, y] = BLACK

    # 2) 从边缘洪水填充剩余亮/灰像素（吃掉黑环外沿抗锯齿）
    seen = bytearray(w * h)
    q: deque[tuple[int, int]] = deque()

    def seed(x: int, y: int) -> None:
        i = y * w + x
        if seen[i]:
            return
        if dist(x, y) < R_PROTECT:
            return
        if not _is_outer_fillable(px[x, y]):
            return
        seen[i] = 1
        q.append((x, y))

    for x in range(w):
        seed(x, 0)
        seed(x, h - 1)
    for y in range(h):
        seed(0, y)
        seed(w - 1, y)

    while q:
        x, y = q.popleft()
        px[x, y] = BLACK
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if nx < 0 or ny < 0 or nx >= w or ny >= h:
                continue
            i = ny * w + nx
            if seen[i]:
                continue
            if dist(nx, ny) < R_PROTECT:
                continue
            if not _is_outer_fillable(px[nx, ny]):
                continue
            seen[i] = 1
            q.append((nx, ny))

    return img


def _md5(path: str) -> str:
    h = hashlib.md5()
    with open(path, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def main() -> None:
    before = Image.open(SRC)
    locks = [(512, 512), (480, 420), (560, 500), (600, 540), (400, 480)]
    lock_rgb = [before.convert("RGB").getpixel(p) for p in locks]

    out = fill_outer_black(before)
    w, h = out.size
    corners = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1), (w // 2, 0), (0, h // 2)]
    for c in corners:
        if out.getpixel(c) != BLACK:
            raise SystemExit(f"corner {c} is {out.getpixel(c)}, want {BLACK}")
    after_locks = [out.getpixel(p) for p in locks]
    if after_locks != lock_rgb:
        raise SystemExit(f"interior clay changed: {lock_rgb} -> {after_locks}")

    os.makedirs(os.path.dirname(SRC), exist_ok=True)
    out.save(SRC, format="PNG", optimize=True)
    shutil.copy2(SRC, DST)
    if _md5(SRC) != _md5(DST):
        raise SystemExit("david/venus 0-clay digest mismatch")
    print(f"[ok] wrote identical 0-clay -> david & venus  md5={_md5(SRC)}")


if __name__ == "__main__":
    main()
