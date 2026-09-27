#!/usr/bin/env python3
"""Regenerate assets/data/campus_boundary.json from assets/data/landmarks.json.

    python3 tool/generate_campus_boundary.py

WHY THIS IS A PLACEHOLDER
-------------------------
The real OAU perimeter is not available offline, so the bundled fence is a
convex hull of the campus landmarks, buffered 90 m outward. That is a
stand-in, not the campus boundary: a hull is convex, so it cannot follow a
perimeter that is not convex, and it only knows about places that happen to
have a landmark in landmarks.json.

TO USE THE REAL BOUNDARY
------------------------
Replace assets/data/campus_boundary.json with a GeoJSON FeatureCollection
holding one Polygon whose outer ring is the traced perimeter. No Dart code
changes: CampusBoundary reads the same shape either way, so this generator is
only needed again if you want to re-derive the placeholder.

WHAT IS EXCLUDED
----------------
The OAUTHC teaching hospital complex sits ~4.5 km from the campus centroid.
It is affiliated with OAU but is a separate site, so including it would
stretch the fence into a 4.5 km spur and count the hospital as on campus.
Those landmarks are still published and still render as map pins - only the
fence ignores them.
"""

import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "data" / "landmarks.json"
OUT = ROOT / "assets" / "data" / "campus_boundary.json"

# Metres of padding added outside the hull, so perimeter gates and buildings
# are not left sitting exactly on the fence line.
BUFFER_M = 90.0

# Landmarks belonging to the off-site OAUTHC teaching hospital complex.
EXCLUDE_NAMES = {"OAUTHC (Teaching Hospital)", "OAUTHC Pharmacy"}


def metres_per_degree(lat0):
    return 110574.0, 111320.0 * math.cos(math.radians(lat0))


def convex_hull(points):
    """Monotonic chain. points is a list of (x, y) in metres."""
    pts = sorted(set(points))
    if len(pts) <= 2:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lower = []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)

    upper = []
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)

    return lower[:-1] + upper[:-1]  # CCW, no duplicate endpoints


def offset_convex(poly, dist):
    """Offset a CCW convex polygon outward by dist along each edge normal."""
    n = len(poly)
    lines = []
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        dx, dy = x2 - x1, y2 - y1
        length = math.hypot(dx, dy)
        if length == 0:
            raise ValueError("degenerate edge")
        # Outward normal for a CCW polygon.
        nx, ny = dy / length, -dx / length
        ax, ay = x1 + nx * dist, y1 + ny * dist
        bx, by = x2 + nx * dist, y2 + ny * dist
        lines.append((ax, ay, bx - ax, by - ay))

    out = []
    for i in range(n):
        ax, ay, dx, dy = lines[i - 1]
        bx, by, ex, ey = lines[i]
        denom = dx * ey - dy * ex
        if abs(denom) < 1e-12:
            # Parallel edges: fall back to this edge's own start point.
            out.append((ax, ay))
            continue
        t = ((bx - ax) * ey - (by - ay) * ex) / denom
        out.append((ax + dx * t, ay + dy * t))
    return out


def simplify(points, tol):
    """Ramer-Douglas-Peucker on a closed ring."""
    def rdp(pts, first, last, tol):
        if last <= first + 1:
            return [pts[first]]
        ax, ay = pts[first]
        bx, by = pts[last]
        dx, dy = bx - ax, by - ay
        denom = math.hypot(dx, dy)
        best, best_d = first, -1.0
        for i in range(first + 1, last):
            px, py = pts[i]
            if denom == 0:
                d = math.hypot(px - ax, py - ay)
            else:
                d = abs(dy * px - dx * py + bx * ay - by * ax) / denom
            if d > best_d:
                best, best_d = i, d
        if best_d <= tol:
            return [pts[first]]
        return rdp(pts, first, best, tol) + rdp(pts, best, last, tol)

    n = len(points)
    if n < 4:
        return points
    kept = rdp(points + [points[0]], 0, n, tol)
    # Drop collinear vertices introduced by simplification.
    out = []
    for i in range(len(kept) - 1):
        ax, ay = kept[i - 1]
        bx, by = kept[i]
        cx, cy = kept[i + 1]
        cross = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
        if abs(cross) > 1e-9:
            out.append((bx, by))
    return out


def shoelace(poly):
    total = 0.0
    for i in range(len(poly)):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % len(poly)]
        total += x1 * y2 - x2 * y1
    return abs(total) / 2.0


def point_in_ring(pt, ring):
    """Ray casting. ring is a closed [lng, lat] list."""
    x, y = pt
    inside = False
    for i in range(len(ring) - 1):
        x1, y1 = ring[i]
        x2, y2 = ring[i + 1]
        if (y1 > y) != (y2 > y):
            xin = (x2 - x1) * (y - y1) / (y2 - y1) + x1
            if x < xin:
                inside = not inside
    return inside


def main():
    with open(SRC) as fh:
        landmarks = json.load(fh)

    used = [x for x in landmarks if x["name"] not in EXCLUDE_NAMES]
    skipped = len(landmarks) - len(used)
    if not used:
        sys.exit("no landmarks left after exclusions")

    lat0 = sum(x["lat"] for x in used) / len(used)
    mlat, mlng = metres_per_degree(lat0)

    # Work in a local metre frame centred on the campus.
    lat_ref = used[0]["lat"]
    lng_ref = used[0]["lng"]
    _, mlng_ref = metres_per_degree(lat_ref)
    pts = [((x["lng"] - lng_ref) * mlng_ref, (x["lat"] - lat_ref) * mlat)
           for x in used]

    hull = convex_hull(pts)
    hull_area = shoelace(hull)
    buffered = offset_convex(hull, BUFFER_M)
    buffered_area = shoelace(buffered)
    if buffered_area <= hull_area:
        sys.exit("offset shrank the polygon - buffer too large")

    # Simplification is only worth it for verbose fences, and a cut corner can
    # push a landmark that sits ON a hull vertex outside the fence. So try to
    # simplify, then prove every landmark is still enclosed; otherwise keep the
    # full ring.
    candidates = [(simplify(buffered, tol=tol), "tol=%.0fm" % tol)
                  for tol in (12.0, 4.0)]
    candidates.append((buffered, "unsimplified"))

    ring = None
    how = ""
    for candidate, label in candidates:
        if len(candidate) < 3:
            continue
        ring_lnglat = [[x / mlng_ref + lng_ref, y / mlat + lat_ref]
                       for x, y in candidate]
        closed = ring_lnglat + [list(ring_lnglat[0])]
        stray = [x["name"] for x in used
                 if not point_in_ring((x["lng"], x["lat"]), closed)]
        if not stray:
            ring, how = closed, label
            break
        print("  rejected %-14s (%d vertex) - excludes %d landmark(s): %s"
              % (label, len(candidate), len(stray), ", ".join(stray[:3])))

    if ring is None:
        sys.exit("no candidate ring encloses every landmark")

    coords = [[round(c[0], 6), round(c[1], 6)] for c in ring]

    feature = {
        "type": "Feature",
        "properties": {
            "name": "OAU campus",
            "source": "convex hull of assets/data/landmarks.json",
            "note": ("PLACEHOLDER - hull of %d landmarks, buffered %d m outward. "
                     "OAUTHC teaching hospital excluded (off-site). Replace with a "
                     "hand-traced perimeter." % (len(used), int(BUFFER_M))),
            "excludedOffSite": sorted(EXCLUDE_NAMES),
            "landmarkCount": len(used),
            "bufferMetres": int(BUFFER_M),
            "simplify": how,
        },
        "geometry": {"type": "Polygon", "coordinates": [coords]},
    }

    doc = {"type": "FeatureCollection", "features": [feature]}
    with open(OUT, "w") as fh:
        json.dump(doc, fh, indent=2)
        fh.write("\n")

    lats = [c[1] for c in coords]
    lngs = [c[0] for c in coords]

    # Final gate: the published asset must enclose every campus landmark and
    # must not enclose the off-site hospital.
    stray = [x["name"] for x in used
             if not point_in_ring((x["lng"], x["lat"]), coords)]
    if stray:
        sys.exit("published fence excludes landmarks: %s" % stray)
    for name in EXCLUDE_NAMES:
        lm = next(x for x in landmarks if x["name"] == name)
        if point_in_ring((lm["lng"], lm["lat"]), coords):
            sys.exit("published fence wrongly encloses off-site %s" % name)

    print("excluded off-site landmarks : %d" % skipped)
    print("simplification kept          : %s" % how)
    print("vertices                     : %d" % (len(coords) - 1))
    print("hull area                    : %.2f km2" % (hull_area / 1e6))
    print("buffered area                : %.2f km2" % (buffered_area / 1e6))
    print("lat span                     : %.4f deg (%.2f km)"
          % (max(lats) - min(lats), (max(lats) - min(lats)) * mlat / 1000))
    print("lng span                     : %.4f deg (%.2f km)"
          % (max(lngs) - min(lngs), (max(lngs) - min(lngs)) * mlng / 1000))
    print("verified                     : all %d campus landmarks inside, "
          "%d off-site outside" % (len(used), len(EXCLUDE_NAMES)))


if __name__ == "__main__":
    main()
