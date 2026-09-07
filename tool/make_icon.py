#!/usr/bin/env python3
"""Rebuild the FerriScribe mobile icon as a full-bleed opaque square.

The only source asset in the repo is the desktop's flattened icon: a
pre-rounded squircle on a white field with a navy ring. iOS requires a
fully opaque square (the OS applies its own mask), and Android adaptive
icons need a full-bleed canvas too. No layered source exists, so this
script:
  1. crops to the mark bounds and scales to 1024,
  2. paints everything outside the superellipse with the navy ring color
     (solid full-bleed, no alpha, no pre-rounding),
  3. saves the iOS/adaptive-canvas source.

Run from the repo root: python3 tool/make_icon.py
"""
from PIL import Image
import numpy as np

SRC = "/Users/cortexuvula/Development/rustMedicalAssistant/src-tauri/icons/ios/AppIcon-512@2x.png"
OUT = "assets/icon/app_icon.png"

src = Image.open(SRC).convert("RGB")
mark = src.crop((40, 40, 984, 984)).resize((1024, 1024), Image.LANCZOS)
a = np.asarray(mark).astype(np.int16)

h, w = a.shape[:2]
yy, xx = np.mgrid[0:h, 0:w]
cx, cy = (w - 1) / 2, (h - 1) / 2
nx = (xx - cx) / (w / 2)
ny = (yy - cy) / (h / 2)
n = 4.0
margin = 0.985
inside = (np.abs(nx / margin) ** n + np.abs(ny / margin) ** n) <= 1.0

navy = np.array([26, 115, 168], dtype=np.int16)
out = a.copy()
out[~inside] = navy
img = Image.fromarray(out.astype(np.uint8))
img.save(OUT)

white_outside = int(
    ((a[:, :, 0] > 235) + (a[:, :, 1] > 235) + (a[:, :, 2] > 235)).all(axis=2).sum()
    if False
    else ((a[:, :, 0] > 235) & (a[:, :, 1] > 235) & (a[:, :, 2] > 235) & ~inside).sum()
)
print("corners:", img.getpixel((2, 2)), img.getpixel((1021, 1021)))
print("edge mid:", img.getpixel((0, 512)), img.getpixel((512, 0)))
print("white pixels outside superellipse:", white_outside)
print("mode:", img.mode, "saved", OUT)
