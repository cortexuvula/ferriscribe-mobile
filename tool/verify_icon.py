#!/usr/bin/env python3
"""Round-2 acceptance: foreground has no cerulean badge; EKG survives in
both the color foreground and the monochrome layer."""
from PIL import Image
import numpy as np

fg = Image.open("assets/icon/adaptive_foreground.png")
a = np.asarray(fg)
alpha = a[:, :, 3] > 0
cer = (
    (a[:, :, 0] > 20) & (a[:, :, 0] < 35)
    & (a[:, :, 1] > 105) & (a[:, :, 1] < 125)
    & (a[:, :, 2] > 158) & (a[:, :, 2] < 178)
) & alpha
print("cerulean-in-foreground px:", int(cer.sum()), "(expect ~edge-aa only)")
print("foreground opaque px:", int(alpha.sum()))
teal_fg = (
    (a[:, :, 0] > 40) & (a[:, :, 0] < 130)
    & (a[:, :, 1] > 150) & (a[:, :, 2] > 180)
) & alpha
print("teal (EKG) px in fg:", int(teal_fg.sum()))

mono = Image.open("assets/icon/monochrome.png")
ma = np.asarray(mono)
ink = ma[:, :, 3] > 0
ys, xs = np.where(ink)
print("mono ink bbox:", xs.min(), ys.min(), xs.max(), ys.max(), "count:", int(ink.sum()))
