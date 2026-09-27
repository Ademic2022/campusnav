import 'package:flutter_test/flutter_test.dart';
import 'package:oau_navigator/core/utils/geo.dart';

/// Regression coverage for the off-route false positive.
///
/// A real cross-campus Directions route was measured and 32 of its segments
/// were longer than 80 m. For every one of those segments, the midpoint was
/// more than 40 m from *both* endpoints, so the old vertex-based check
/// reported the user as off-route while they walked straight down the road.
void main() {
  // A simplified straight 435 m segment, matching the worst case measured on
  // the live route (max segment length 435.6 m).
  final start = [4.5225, 7.4976];
  final end = [4.5225, 7.4976 + (435.6 / 111132.92)];

  test('midpoint of a 435 m segment is within the 40 m off-route threshold',
      () {
    final midLat = (start[1] + end[1]) / 2;
    const midLng = 4.5225;

    final toSegment =
        distanceToSegmentMetres(lat: midLat, lng: midLng, a: start, b: end);
    final toNearestVertex = [
      haversineMetres(
          lat1: midLat, lng1: midLng, lat2: start[1], lng2: start[0]),
      haversineMetres(lat1: midLat, lng1: midLng, lat2: end[1], lng2: end[0]),
    ].reduce((a, b) => a < b ? a : b);

    // The old check would have rerouted here.
    expect(toNearestVertex, greaterThan(40));
    // The new check correctly reports on-route.
    expect(toSegment, lessThan(1));
  });

  test('a genuine detour well away from the line is still detected', () {
    // ~120 m east of the road: must exceed the 40 m threshold.
    final d = distanceToSegmentMetres(
      lat: (start[1] + end[1]) / 2,
      lng: 4.5225 + (120 / 111319.49),
      a: start,
      b: end,
    );
    expect(d, closeTo(120, 3));
    expect(d, greaterThan(40));
  });

  test('threshold behaviour holds at several points along a long segment', () {
    const threshold = 40.0;
    for (var i = 0; i <= 20; i++) {
      final t = i / 20;
      final lat = start[1] + (end[1] - start[1]) * t;
      final d = distanceToSegmentMetres(
        lat: lat,
        lng: 4.5225,
        a: start,
        b: end,
      );
      expect(d, lessThan(threshold), reason: 'rerouted at t=$t');
    }
  });
}
