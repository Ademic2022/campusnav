import 'dart:math';

import 'geo.dart';

/// Whether a point lies inside a closed ring, by ray casting.
///
/// [ring] is a list of `[lng, lat]` pairs in GeoJSON order. An unclosed ring is
/// accepted — the closing edge is implied — and a ring that repeats its first
/// point last (the GeoJSON convention) is not double-counted.
bool pointInPolygon({
  required double lat,
  required double lng,
  required List<List<double>> ring,
  LocalPlane? plane,
}) {
  if (ring.length < 3) return false;

  final p = plane ?? LocalPlane(lat);
  final px = p.xOf(lng);
  final py = p.yOf(lat);

  // Drop the repeated closing vertex so the implicit wrap edge below is the
  // real one rather than a duplicate.
  var pts = ring;
  if (pts.first[0] == pts.last[0] && pts.first[1] == pts.last[1]) {
    pts = pts.sublist(0, pts.length - 1);
  }
  if (pts.length < 3) return false;

  var inside = false;
  for (var i = 0; i < pts.length; i++) {
    final a = pts[i];
    final b = pts[(i + 1) % pts.length];
    final yi = p.yOf(a[1]);
    final yj = p.yOf(b[1]);

    // Half-open rule: a ray through a vertex must not be counted twice.
    if ((yi > py) != (yj > py)) {
      final xi = p.xOf(a[0]);
      final xj = p.xOf(b[0]);
      if (px < (xj - xi) * (py - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
    }
  }
  return inside;
}

/// Smallest distance in metres from a point to a polygon's edge.
///
/// [ring] is a list of `[lng, lat]` pairs. Returns `double.infinity` for a
/// ring with fewer than two vertices.
double distanceToPolygonEdgeMetres({
  required double lat,
  required double lng,
  required List<List<double>> ring,
  LocalPlane? plane,
}) {
  if (ring.length < 2) return double.infinity;

  final p = plane ?? LocalPlane(lat);
  var best = double.infinity;
  for (var i = 0; i < ring.length; i++) {
    final a = ring[i];
    final b = ring[(i + 1) % ring.length];
    final d = distanceToSegmentMetres(
      lat: lat,
      lng: lng,
      a: a,
      b: b,
      plane: p,
    );
    if (d < best) best = d;
  }
  return best;
}

/// Signed distance in metres to a polygon's edge: negative inside, positive
/// outside, zero on the edge.
///
/// The magnitude is the distance to the nearest edge, so this doubles as the
/// geofence hysteresis band — a point just outside the fence reports a small
/// positive value rather than flipping to "far away".
double signedDistanceToPolygonMetres({
  required double lat,
  required double lng,
  required List<List<double>> ring,
  LocalPlane? plane,
}) {
  final d = distanceToPolygonEdgeMetres(
    lat: lat,
    lng: lng,
    ring: ring,
    plane: plane,
  );
  if (d == double.infinity) return double.infinity;
  return pointInPolygon(lat: lat, lng: lng, ring: ring, plane: plane)
      ? -d
      : d;
}

/// Area of a ring in square metres, via the shoelace formula on a local plane.
///
/// Used only for reporting the fence size.
double polygonAreaSquareMetres(List<List<double>> ring) {
  if (ring.length < 3) return 0;
  final p = LocalPlane(ring.first[1]);

  var total = 0.0;
  for (var i = 0; i < ring.length; i++) {
    final a = ring[i];
    final b = ring[(i + 1) % ring.length];
    total += p.xOf(a[0]) * p.yOf(b[1]) - p.xOf(b[0]) * p.yOf(a[1]);
  }
  return total.abs() / 2.0;
}

/// Bounding box of a ring as `(minLng, minLat, maxLng, maxLat)`.
///
/// Lets a caller reject obviously out-of-range points with one comparison
/// before paying for the full containment test.
(double, double, double, double)? polygonBounds(
  List<List<double>> ring,
) {
  if (ring.isEmpty) return null;

  var minLng = double.infinity;
  var minLat = double.infinity;
  var maxLng = double.negativeInfinity;
  var maxLat = double.negativeInfinity;

  for (final c in ring) {
    minLng = min(minLng, c[0]);
    minLat = min(minLat, c[1]);
    maxLng = max(maxLng, c[0]);
    maxLat = max(maxLat, c[1]);
  }
  return (minLng, minLat, maxLng, maxLat);
}
