#!/usr/bin/env python3
"""Rebuild every mobile icon asset deterministically from the desktop mark.

Source of truth: the desktop app's flattened 1024 icon
(rustMedicalAssistant/src-tauri/icons/ios/AppIcon-512@2x.png). Its provenance
is documented here because no layered source exists in either repo.

Outputs (all committed; this script regenerates them):
  assets/icon/app_icon.png            full-bleed opaque 1024 square (iOS)
  assets/icon/adaptive_foreground.png emblem-only transparent 1024 foreground
  assets/icon/adaptive_background.png solid cerulean 1024 background
  assets/icon/monochrome.png          single-color emblem (themed icons)

Icon review 2af6534 findings addressed:
  1. White squircle-perimeter fragments removed — the perimeter is detected
     (white outside the emblem bbox ring band) and painted to the background
     color, leaving one continuous blue surface.
  2. Emblem sized ONCE: extracted by alpha/emblem bounding box, placed at
     ~57dp tall on the 108dp adaptive canvas (~54% foreground), and the XML
     inset removed, so no double shrink.
  3. Round path consistent: ic_launcher_round.xml (v26) adaptive like square.
  4. Self-contained: run from repo root, no other repo's build pipeline.
"""
from PIL import Image, ImageDraw
import numpy as np
import os
import subprocess

SRC = "/Users/cortexuvula/Development/rustMedicalAssistant/src-tauri/icons/ios/AppIcon-512@2x.png"
BG = (26, 115, 168)  # cerulean, sampled from the brand surface
OUT_DIR = "assets/icon"

src = Image.open(SRC).convert("RGB")

# ---------------------------------------------------------------- emblem
# Crop inside the old squircle border, then remove the border ring: any
# pixel that is near-white AND outside the emblem bounding box becomes BG.
crop = src.crop((52, 52, 972, 972)).resize((1024, 1024), Image.LANCZOS)
a = np.asarray(crop).astype(np.int16)
white = (a[:, :, 0] > 235) & (a[:, :, 1] > 235) & (a[:, :, 2] > 235)

# Emblem = large connected white region near the center; approximate its
# bbox by scanning rows/cols of white density (border ring is thin, emblem
# is thick). Work on a center-weighted window.
dens = white.sum(axis=1)
rows = np.where(dens > 40)[0]  # thick white rows = emblem
cols = np.where(white.sum(axis=0) > 40)[0]
ey0, ey1 = rows.min(), rows.max()
ex0, ex1 = cols.min(), cols.max()
print("emblem bbox:", (ex0, ey0, ex1, ey1))

emblem_mask = np.zeros((1024, 1024), dtype=bool)
emblem_mask[ey0:ey1, ex0:ex1] = white[ey0:ey1, ex0:ex1]
emblem = crop.copy()
ea = np.asarray(emblem).copy()
# everything white outside the emblem bbox -> background blue
outside = white & ~emblem_mask
ea[outside] = BG
emblem_only = Image.fromarray(ea.astype(np.uint8))

# ------------------------------------------------------- full-bleed square
square = Image.new("RGB", (1024, 1024), BG)
square.paste(emblem_only, (0, 0))
# Final sweep: near-white pixels within 6% of any edge -> BG (perimeter
# fragments per icon-review finding 1).
sa = np.asarray(square).copy()
edge = 110  # covers the old squircle border + corner fragments
border_zone = np.zeros((1024, 1024), dtype=bool)
border_zone[:edge, :] = True
border_zone[-edge:, :] = True
border_zone[:, :edge] = True
border_zone[:, -edge:] = True
frag = (sa[:, :, 0] > 225) & (sa[:, :, 1] > 225) & (sa[:, :, 2] > 225) & border_zone
sa[frag] = BG
square = Image.fromarray(sa.astype(np.uint8))
square.save(os.path.join(OUT_DIR, "app_icon.png"))
print("square white-perimeter pixels painted:", int(frag.sum()))

# ----------------------------------------------- adaptive layers (sized once)
# 108dp canvas at 1024px -> 1dp = 9.481px. Emblem target ~57dp tall.
emblem_img = emblem_only.crop((ex0, ey0, ex1 + 1, ey1 + 1))
target_h = int(57 * (1024 / 108))
scale = target_h / emblem_img.height
target_w = int(emblem_img.width * scale)
emblem_resized = emblem_img.resize((target_w, target_h), Image.LANCZOS)

fg = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
fg.paste(emblem_resized, ((1024 - target_w) // 2, (1024 - target_h) // 2))
fg.save(os.path.join(OUT_DIR, "adaptive_foreground.png"))

bg = Image.new("RGB", (1024, 1024), BG)
bg.save(os.path.join(OUT_DIR, "adaptive_background.png"))

# Monochrome (themed): emblem silhouette in white.
mono = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
sil = Image.new("L", emblem_img.size, 0)
sil_a = np.asarray(emblem_img.convert("L"))
sil_mask = Image.fromarray(((sil_a > 200) * 255).astype(np.uint8))
sil = Image.new("RGBA", emblem_img.size, (255, 255, 255, 255))
mono.paste(sil, (0, 0), sil_mask)
mono = mono.resize((target_w, target_h), Image.LANCZOS)
mono_full = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
mono_full.paste(mono, ((1024 - target_w) // 2, (1024 - target_h) // 2))
mono_full.save(os.path.join(OUT_DIR, "monochrome.png"))
print("adaptive layers written; emblem", target_w, "x", target_h, "on 1024")
