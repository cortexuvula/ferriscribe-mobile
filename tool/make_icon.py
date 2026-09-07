#!/usr/bin/env python3
"""Rebuild every mobile icon asset deterministically from the desktop mark.

Source of truth: the desktop app's flattened 1024 icon
(rustMedicalAssistant/src-tauri/icons/ios/AppIcon-512@2x.png) — a cerulean
squircle field with a white medical cross + stethoscope outline and a teal
EKG trace inside the cross. No layered source exists in either repo; the
provenance is this file.

Pipeline (icon-review round 2 — emblem isolated BY COLOR, not bbox):
  1. Crop inside the old border, scale to 1024.
  2. Paint everything outside the emblem's true bbox (white/teal artwork,
     found by color + component size) with the cerulean field color —
     including the old ring and edge resampling artifacts.
  3. Square: full-bleed opaque cerulean + emblem (iOS; OS masks it).
  4. Adaptive foreground: emblem ONLY (colors preserved, background made
     transparent), sized once at ~57dp on the 108dp canvas.
  5. Adaptive background: solid cerulean.
  6. Monochrome: single-color silhouette of the artwork (white cross/
     stethoscope AND the teal EKG both included — threshold on
     "clearly not background").

Run from repo root: python3 tool/make_icon.py
"""
from PIL import Image
import numpy as np
from scipy import ndimage
import os

SRC = "/Users/cortexuvula/Development/rustMedicalAssistant/src-tauri/icons/ios/AppIcon-512@2x.png"
BG = (26, 115, 168)  # cerulean, sampled from the brand field
OUT_DIR = "assets/icon"

src = Image.open(SRC).convert("RGB")
crop = src.crop((52, 52, 972, 972)).resize((1024, 1024), Image.LANCZOS)
a = np.asarray(crop).astype(int)

# ---- true emblem: white + teal artwork components (size-filtered) -----
white = (a[:, :, 0] > 180) & (a[:, :, 1] > 180) & (a[:, :, 2] > 180)
teal = (a[:, :, 0] > 40) & (a[:, :, 0] < 130) & (a[:, :, 1] > 150) & (a[:, :, 2] > 180)
art = white | teal
# Restrict to the old squircle interior and drop small specks: the pale
# anti-aliased border FRAME and corner triangles otherwise connect through
# and stretch the bbox to the whole tile (icon-review round 2's finding).
central = np.zeros_like(art)
central[140:900, 140:900] = art[140:900, 140:900]
lbl, n = ndimage.label(central)
sizes = ndimage.sum(central, lbl, range(1, n + 1))
keep = (sizes >= 1000).nonzero()[0] + 1  # real strokes; drops specks
mask = np.isin(lbl, keep)
ys, xs = np.where(mask)
ex0, ey0, ex1, ey1 = xs.min(), ys.min(), xs.max(), ys.max()
print("true emblem bbox:", (ex0, ey0, ex1, ey1))

# ------------------------------------------------------- full-bleed square
sa = a.copy()
# paint EVERYTHING outside the emblem bbox (ring, fragments, field noise)
box = np.zeros((1024, 1024), dtype=bool)
box[ey0 : ey1 + 1, ex0 : ex1 + 1] = True
sa[~box] = BG
# inside the bbox, anything that is neither artwork-ish nor field -> field
inside_off = box & ~art
sa[inside_off] = BG
square = Image.fromarray(sa.astype(np.uint8))
square.save(os.path.join(OUT_DIR, "app_icon.png"))
print("square written; emblem-only field inside bbox:", (ex0, ey0, ex1, ey1))

# ------------------------------------------------ emblem-only RGBA (fg) ---
emblem = crop.crop((ex0, ey0, ex1 + 1, ey1 + 1))
ea = np.asarray(emblem).astype(int)
# alpha: artwork opaque, field transparent (soft edge by distance)
op = np.zeros(ea.shape[:2], dtype=np.uint8)
edist = np.sqrt(((ea - np.array(BG)) ** 2).sum(axis=2))
op[edist > 25] = 255
op[edist <= 25] = 0
rgba = np.dstack([ea.astype(np.uint8), op])
emblem_rgba = Image.fromarray(rgba, "RGBA")

# ------------------------------------------------ adaptive layers (once) ---
target_h = int(57 * (1024 / 108))
scale = target_h / emblem_rgba.height
target_w = int(emblem_rgba.width * scale)
em = emblem_rgba.resize((target_w, target_h), Image.LANCZOS)

fg = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
fg.paste(em, ((1024 - target_w) // 2, (1024 - target_h) // 2))
fg.save(os.path.join(OUT_DIR, "adaptive_foreground.png"))

bg = Image.new("RGB", (1024, 1024), BG)
bg.save(os.path.join(OUT_DIR, "adaptive_background.png"))

# --------------------------------------------------------- monochrome -----
mono_em = np.asarray(em).copy()
mdist = np.sqrt(
    ((mono_em[:, :, :3].astype(int) - np.array(BG)) ** 2).sum(axis=2)
)
alpha = mono_em[:, :, 3] > 0
ink = alpha & (mdist > 25)  # white strokes AND teal EKG both count
mono = np.zeros((target_h, target_w, 4), dtype=np.uint8)
mono[ink] = (255, 255, 255, 255)
Image.fromarray(mono, "RGBA").save(os.path.join(OUT_DIR, "monochrome.png"))

print(
    "adaptive layers written; emblem",
    target_w,
    "x",
    target_h,
    "on 1024 (",
    round(target_h / 1024 * 108, 2),
    "dp )",
)
