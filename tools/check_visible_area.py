#!/usr/bin/env python3
"""Check the visible-area mask in handoff/claude-dashboard/shared-contracts.json against the truck photos.

The photos show Factory > Screen grid (2026-10-30): one from the driver eye height, one from a lower camera through the wheel.
EDGES lists screen points where the photos show the edge of the hidden area. Each point was read on a zoomed photo from the
grid lines and the colored edge frames. The check fails when the mask leaves an observed hidden point visible (tolerance 3 px).
With the private photos present, the tool also projects the mask onto each photo (registration on the 100-px grid lines)
and writes overlays and a JSON report to analysis/capture-04/vehicle-runs/screen-grid-2026-10-30/mask-check/.

Usage: python tools/check_visible_area.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "handoff/claude-dashboard/shared-contracts.json"
PHOTOS = ROOT / "analysis/capture-04/vehicle-runs/screen-grid-2026-10-30"
OUT = PHOTOS / "mask-check"
TOLERANCE = 3
W, H = 1920, 932

# Observed edges, screen px. "top": rows above y are hidden at x. "bottom": rows below y are hidden at x.
EDGES = {
    "driver-eye": {
        # Top frames (y 10 to 70) end where the bezel arch starts; the white frame (y 0) is hidden even at the center, where
        # the center line (x 960) starts at y 3. The x 0, 70, 1849, 1909 frames end at the wheel rim.
        "top": [(960, 3), (667, 10), (536, 20), (436, 30), (356, 40), (286, 50), (219, 60), (162, 70),
                (1238, 10), (1380, 20), (1486, 30), (1569, 40), (1639, 50), (1705, 60), (1741, 70),
                (0, 156), (70, 113), (1849, 129), (1909, 170)],
        # Bottom frames (y 930, 862) end at the shroud; the center line (x 960) ends at the shroud top.
        "bottom": [(183, 930), (274, 862), (960, 776), (1623, 862), (1704, 930)],
    },
    "through-wheel": {
        "top": [(960, 3), (155, 70), (211, 60), (275, 50), (344, 40), (427, 30), (70, 87)],
        "bottom": [(197, 930), (284, 862), (302, 845), (383, 816), (481, 793), (960, 777),
                   (1400, 799), (1500, 814), (1600, 850), (1617, 862), (1702, 930)],
    },
}
# Driver-eye registration: grid line positions read on the zoomed photo (original photo px).
DRIVER_LINES = {"x": {200: 805.6, 400: 861.25, 600: 916.25, 800: 971.5, 1000: 1026.25, 1200: 1081.9, 1400: 1136.9, 1600: 1192.25},
                "y": {100: 749.45, 200: 777.1, 300: 804.75, 400: 832.5, 500: 860.0, 700: 915.5, 800: 943.75}}
# Lower-camera registration: rough label points (screen -> photo), refined on the bright grid lines.
LOWER_ROUGH = [((237, 86), (568.8, 522.5)), ((1637, 86), (1446, 509)), ((237, 786), (577.5, 956)), ((1637, 786), (1447.5, 947.5))]


def inside(poly, x, y):
    c = False
    for i in range(len(poly)):
        (xi, yi), (xj, yj) = poly[i], poly[i - 1]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            c = not c
    return c


def hidden(polys, x, y):
    return any(inside(p, x, y) for p in polys)


def top_edge(polys, x):
    """First visible row at x, walking down from the top."""
    y = 0.0
    while y < H and hidden(polys, x, y):
        y += 0.5
    return y


def bottom_edge(polys, x):
    """First hidden row at x, walking down from the middle."""
    y = H / 2
    while y < H and not hidden(polys, x, y):
        y += 0.5
    return y


def check(polys):
    rows, failed = [], 0
    for photo, edges in EDGES.items():
        for x, y in edges["top"]:
            edge = top_edge(polys, min(max(x, 0.5), W - 0.5))
            ok = edge >= y - TOLERANCE
            failed += not ok
            rows.append({"photo": photo, "side": "top", "x": x, "observed_y": y, "mask_y": edge, "slack": round(edge - y, 1), "ok": ok})
        for x, y in edges["bottom"]:
            edge = bottom_edge(polys, min(max(x, 0.5), W - 0.5))
            ok = edge <= y + TOLERANCE
            failed += not ok
            rows.append({"photo": photo, "side": "bottom", "x": x, "observed_y": y, "mask_y": edge, "slack": round(y - edge, 1), "ok": ok})
    return rows, failed


def overlays(polys, rows):
    """Project the mask onto each photo. Needs numpy and Pillow, and the private photos."""
    import numpy as np
    from PIL import Image, ImageDraw

    def fit(pairs):
        a = []
        for (x, y), (u, v) in pairs:
            a += [[x, y, 1, 0, 0, 0, -u * x, -u * y, -u], [0, 0, 0, x, y, 1, -v * x, -v * y, -v]]
        return (lambda h: h / h[2, 2])(np.linalg.svd(np.asarray(a, float))[2][-1].reshape(3, 3))

    def proj(h, x, y):
        p = h @ np.array([x, y, 1.0])
        return float(p[0] / p[2]), float(p[1] / p[2])

    def sample(img, u, v):
        i, j = int(v), int(u)
        if not (0 <= j < img.shape[1] - 1 and 0 <= i < img.shape[0] - 1):
            return 0.0
        a, b = v - i, u - j
        return img[i, j] * (1 - a) * (1 - b) + img[i, j + 1] * (1 - a) * b + img[i + 1, j] * a * (1 - b) + img[i + 1, j + 1] * a * b

    def refine(img, h):
        """Move each 100-px grid point to the brightest line nearby, then refit. The label sits above right of each point."""
        grid = [(x, y) for x in range(200, 1800, 100) for y in range(100, 900, 100)
                if not hidden(polys, x, y - 30) and not hidden(polys, x, y + 25) and not (620 < x < 1300 and 380 < y < 560)]
        scale = np.hypot(*np.subtract(proj(h, 1000, 466), proj(h, 900, 466))) / 100
        pairs = []
        for window in (40 * scale, 12 * scale, 5 * scale, 3 * scale):
            pairs = []
            for x, y in grid:
                shift = []
                for seg, normal in ((((x, y + 3), (x, y + 18)), (1, 0)), (((x - 18, y), (x - 3, y)), (0, 1))):
                    pts = [proj(h, seg[0][0] + (seg[1][0] - seg[0][0]) * t, seg[0][1] + (seg[1][1] - seg[0][1]) * t) for t in np.linspace(0, 1, 12)]
                    mid = ((seg[0][0] + seg[1][0]) / 2, (seg[0][1] + seg[1][1]) / 2)
                    n = np.subtract(proj(h, mid[0] + normal[0], mid[1] + normal[1]), proj(h, *mid))
                    n /= np.linalg.norm(n)
                    offs = np.arange(-window, window + 0.25, 0.25)
                    prof = [np.mean([sample(img, u + d * n[0], v + d * n[1]) for u, v in pts]) for d in offs]
                    k = int(np.argmax(prof))
                    shift.append((offs[k] * n, prof[k] - np.median(prof)))
                if min(c for _, c in shift) < 6:
                    continue
                u, v = proj(h, x, y)
                pairs.append(((x, y), (u + shift[0][0][0] + shift[1][0][0], v + shift[0][0][1] + shift[1][0][1])))
            h = fit(pairs)
        rms = float(np.sqrt(np.mean([np.sum(np.square(np.subtract(proj(h, *s), p))) for s, p in pairs]))) / scale
        return h, len(pairs), rms

    report = {}
    for photo in EDGES:
        path = PHOTOS / f"{photo}.jpg"
        if not path.exists():
            return None
        im = Image.open(path).convert("RGB")
        if photo == "driver-eye":
            pairs = [((x, y), (u, v)) for x, u in DRIVER_LINES["x"].items() for y, v in DRIVER_LINES["y"].items()]
            h = fit(pairs)
            scale = np.hypot(*np.subtract(proj(h, 1000, 466), proj(h, 900, 466))) / 100
            rms = float(np.sqrt(np.mean([np.sum(np.square(np.subtract(proj(h, *s), p))) for s, p in pairs]))) / scale
            count = len(pairs)
        else:
            h, count, rms = refine(np.asarray(im, float).max(axis=2), fit(LOWER_ROUGH))
        report[photo] = {"grid_points": count, "registration_rms_screen_px": round(rms, 2)}
        d = ImageDraw.Draw(im)
        for poly in polys:
            ring = [proj(h, *p) for p in poly + [poly[0]]]
            d.line(ring, fill=(255, 40, 40), width=2)
        for r in rows:
            if r["photo"] == photo:
                u, v = proj(h, r["x"], r["observed_y"])
                d.ellipse([u - 4, v - 4, u + 4, v + 4], outline=(0, 255, 0) if r["ok"] else (255, 0, 255), width=2)
        a, b = proj(h, -80, -80), proj(h, W + 80, H + 80)
        crop = im.crop((int(a[0]), int(a[1]), int(b[0]), int(b[1])))
        crop = crop.resize((crop.width * 1600 // crop.width, crop.height * 1600 // crop.width))
        OUT.mkdir(parents=True, exist_ok=True)
        crop.save(OUT / f"{photo}-mask.jpg", quality=92)
    return report


def main():
    polys = [p for p in json.loads(CONTRACT.read_text(encoding="utf-8"))["measurement"]["visible_area"]["hidden_polygons"].values()]
    rows, failed = check(polys)
    for r in rows:
        print(f"{'ok  ' if r['ok'] else 'FAIL'} {r['photo']:13} {r['side']:6} x {r['x']:5} observed y {r['observed_y']:4} mask y {r['mask_y']:6} slack {r['slack']}")
    registration = overlays(polys, rows)
    result = {"contract": str(CONTRACT.relative_to(ROOT)), "tolerance_px": TOLERANCE, "points": len(rows), "failed": failed,
              "registration": registration, "rows": rows}
    if registration is not None:
        (OUT / "mask-check.json").write_text(json.dumps(result, indent=1) + "\n", encoding="utf-8")
        print("registration", json.dumps(registration), "overlays", OUT.relative_to(ROOT))
    print(json.dumps({"points": len(rows), "failed": failed}))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
