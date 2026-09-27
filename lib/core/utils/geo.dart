import 'dart:math';

/// Canonical great-circle distance in metres.
///
/// Single source of truth for campus-scale distance maths so that
/// calculations cannot drift apart between models, services and providers.
double haversineMetres({
  required double lat1,
  required double lng1,
  required double lat2,
  required double lng2,
}) {
  const earthRadiusMetres = 6371000.0;
  final dLat = _radians(lat2 - lat1);
  final dLng = _radians(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_radians(lat1)) * cos(_radians(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  return earthRadiusMetres * 2 * atan2(sqrt(a), sqrt(1 - a));
}

/// Equirectangular projection to local metres.
///
/// Accurate to well under a metre across campus-scale distances, and far
/// cheaper than repeated haversine calls when walking a whole polyline.
class LocalPlane {
  static const double _metresPerDegreeLat = 111132.92;

  final double _metresPerDegreeLng;

  LocalPlane(double referenceLatDeg)
      : _metresPerDegreeLng = 111412.84 * cos(referenceLatDeg * pi / 180.0);

  double xOf(double lngDeg) => lngDeg * _metresPerDegreeLng;

  double yOf(double latDeg) => latDeg * _metresPerDegreeLat;
}

double _radians(double degrees) => degrees * pi / 180.0;

/// Perpendicular distance in metres from a point to the segment `a`→`b`.
///
/// [a] and [b] are `[lng, lat]` pairs in GeoJSON order. Measuring against the
/// segment rather than its endpoints is what keeps a user walking a long
/// straight road from being reported as off-route.
double distanceToSegmentMetres({
  required double lat,
  required double lng,
  required List<double> a,
  required List<double> b,
  LocalPlane? plane,
}) {
  final p = plane ?? LocalPlane(lat);

  final px = p.xOf(lng);
  final py = p.yOf(lat);
  final ax = p.xOf(a[0]);
  final ay = p.yOf(a[1]);
  final bx = p.xOf(b[0]);
  final by = p.yOf(b[1]);

  final dx = bx - ax;
  final dy = by - ay;
  final lengthSquared = dx * dx + dy * dy;

  var t = 0.0;
  if (lengthSquared > 0) {
    t = ((px - ax) * dx + (py - ay) * dy) / lengthSquared;
    t = t.clamp(0.0, 1.0);
  }

  final closestX = ax + t * dx;
  final closestY = ay + t * dy;
  final offsetX = px - closestX;
  final offsetY = py - closestY;

  return sqrt(offsetX * offsetX + offsetY * offsetY);
}

/// Smallest distance in metres from a point to a polyline.
///
/// [coordinates] is a list of `[lng, lat]` pairs. Returns `double.infinity`
/// when there is nothing to measure against.
double minDistanceToPolylineMetres({
  required double lat,
  required double lng,
  required List<List<double>> coordinates,
  LocalPlane? plane,
}) {
  if (coordinates.isEmpty) return double.infinity;
  if (coordinates.length == 1) {
    return haversineMetres(
      lat1: lat,
      lng1: lng,
      lat2: coordinates.first[1],
      lng2: coordinates.first[0],
    );
  }

  final p = plane ?? LocalPlane(lat);
  var best = double.infinity;
  for (var i = 0; i < coordinates.length - 1; i++) {
    final d = distanceToSegmentMetres(
      lat: lat,
      lng: lng,
      a: coordinates[i],
      b: coordinates[i + 1],
      plane: p,
    );
    if (d < best) best = d;
  }
  return best;
}
