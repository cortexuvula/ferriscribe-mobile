#!/usr/bin/env python3
"""Post-process the generated Android adaptive icon XMLs (icon-review
findings 2 & 3):
  - remove the 16% inset (the foreground is already sized ONCE at the
    correct dp height by make_icon.py — the XML inset double-shrinks it)
  - add the monochrome layer for themed icons
  - write ic_launcher_round.xml (v26) so the round path resolves to the
    same layered adaptive resource as the square, with legacy fallback.
"""
import os

RES = "android/app/src/main/res"

ADAPTIVE = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@drawable/ic_launcher_background"/>
  <foreground android:drawable="@drawable/ic_launcher_foreground"/>
  <monochrome android:drawable="@drawable/ic_launcher_monochrome"/>
</adaptive-icon>
"""

v26 = os.path.join(RES, "mipmap-anydpi-v26")
os.makedirs(v26, exist_ok=True)
for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
    with open(os.path.join(v26, name), "w") as f:
        f.write(ADAPTIVE)
print("wrote", v26, "ic_launcher.xml + ic_launcher_round.xml (no inset, monochrome)")
