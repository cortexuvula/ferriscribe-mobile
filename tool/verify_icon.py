#!/usr/bin/env python3
"""Verify the regenerated icon assets against the icon-review findings."""
from PIL import Image
import numpy as np

im = Image.open("assets/icon/app_icon.png").convert("RGB")
a = np.asarray(im)
white = (a[:, :, 0] > 235) & (a[:, :, 1] > 235) & (a[:, :, 2] > 235)
edge = 61
border_zone = np.zeros(a.shape[:2], dtype=bool)
border_zone[:edge, :] = True
border_zone[-edge:, :] = True
border_zone[:, :edge] = True
border_zone[:, -edge:] = True
print("white in border zone:", int((white & border_zone).sum()))
print("corners:", im.getpixel((2, 2)), im.getpixel((1021, 1021)))

fg = Image.open("assets/icon/adaptive_foreground.png")
fa = np.asarray(fg)
alpha = fa[:, :, 3]
ys, xs = np.where(alpha > 10)
print(
    "fg emblem bbox:",
    xs.min(),
    ys.min(),
    xs.max(),
    ys.max(),
    "height dp:",
    round((ys.max() - ys.min()) / 1024 * 108, 2),
)
