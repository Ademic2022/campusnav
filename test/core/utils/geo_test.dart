import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oau_navigator/core/utils/geo.dart';

void main() {
  group('haversineMetres', () {
    test('is zero for identical points', () {
      expect(
        haversineMetres(lat1: 7.4976, lng1: 4.5225, lat2: 7.4976, lng2: 4.5225),
        closeTo(0, 0.001),
      );
    });

    test('matches a known OAU distance', () {
      // Main Gate to the campus centre is a little over 2 km.
      final d = haversineMetres(
        lat1: 7.497644,
        lng1: 4.522536,
        lat2: 7.5174,
        lng2: 4.5228,
      );
      expect(d, closeTo(2200, 60));
    });

    test('is symmetric', () {
      final a = haversineMetres(
          lat1: 7.4905, lng1: 4.5092, lat2: 7.5280, lng2: 4.5523);
      final b = haversineMetres(
          lat1: 7.5280, lng1: 4.5523, lat2: 7.4905, lng2: 4.5092);
      expect(a, closeTo(b, 0.0001));
    });
  });

  group('distanceToSegmentMetres', () {
    test('measures perpendicular distance at the midpoint', () {
      // North-south segment on the prime meridian, point offset east of it.
      final d = distanceToSegmentMetres(
        lat: 0.005,
        lng: 0.0009,
        a: [0.0, 0.0],
        b: [0.0, 0.01],
      );
      expect(d, closeTo(100, 1.5));
    });

    test('clamps to the segment start when projected before it', () {
      final d = distanceToSegmentMetres(
        lat: 0.0,
        lng: -0.001,
        a: [0.0, 0.0],
        b: [0.0, 0.01],
      );
      // Distance to vertex a, not to the infinite line.
      expect(d, closeTo(111.32, 2));
    });

    test('clamps to the segment end when projected beyond it', () {
      final d = distanceToSegmentMetres(
        lat: 0.0109,
        lng: 0.0,
        a: [0.0, 0.0],
        b: [0.0, 0.01],
      );
      expect(d, closeTo(100, 1.5));
    });

    test('handles a degenerate zero-length segment', () {
      final d = distanceToSegmentMetres(
        lat: 7.4977,
        lng: 4.5225,
        a: [4.5225, 7.4976],
        b: [4.5225, 7.4976],
      );
      expect(d, closeTo(11, 2));
    });

    test('regression: midpoint of a long segment is not reported as far away',
        () {
      // The bug this guards: a 400 m straight segment had a midpoint more
      // than 200 m from either endpoint, so vertex-based off-route checks
      // fired while the user walked straight down the road.
      final a = [4.5225, 7.4976];
      final b = [4.5225, 7.5012];
      final midLat = (a[1] + b[1]) / 2;
      final midLng = (a[0] + b[0]) / 2;

      final toNearestVertex = <double>[
        haversineMetres(lat1: midLat, lng1: midLng, lat2: a[1], lng2: a[0]),
        haversineMetres(lat1: midLat, lng1: midLng, lat2: b[1], lng2: b[0]),
      ].reduce(min);

      final toSegment =
          distanceToSegmentMetres(lat: midLat, lng: midLng, a: a, b: b);

      expect(toNearestVertex, greaterThan(150));
      expect(toSegment, lessThan(1));
    });
  });

  group('minDistanceToPolylineMetres', () {
    test('returns infinity for an empty polyline', () {
      expect(
        minDistanceToPolylineMetres(lat: 7.5, lng: 4.5, coordinates: []),
        double.infinity,
      );
    });

    test('falls back to point distance for a single coordinate', () {
      final d = minDistanceToPolylineMetres(
        lat: 7.498644,
        lng: 4.522536,
        coordinates: [
          [4.522536, 7.497644],
        ],
      );
      expect(d, closeTo(111, 2));
    });

    test('snaps to the nearest segment, not the nearest vertex', () {
      final coordinates = [
        [4.5225, 7.4976],
        [4.5225, 7.5016],
      ];
      const midLat = 7.4996;
      const midLng = 4.5225;

      final nearestVertex = <double>[
        haversineMetres(lat1: midLat, lng1: midLng, lat2: 7.4976, lng2: 4.5225),
        haversineMetres(lat1: midLat, lng1: midLng, lat2: 7.5016, lng2: 4.5225),
      ].reduce(min);

      final onLine = minDistanceToPolylineMetres(
          lat: midLat, lng: midLng, coordinates: coordinates);

      expect(nearestVertex, closeTo(222, 5));
      expect(onLine, lessThan(1));
    });

    test('picks the correct segment out of several', () {
      final coordinates = [
        [4.5225, 7.4976],
        [4.5225, 7.5016],
        [4.5300, 7.5016],
        [4.5300, 7.4976],
      ];
      // Just south of the second (eastern) segment.
      final d = minDistanceToPolylineMetres(
        lat: 7.5027,
        lng: 4.5260,
        coordinates: coordinates,
      );
      expect(d, closeTo(122, 3));
    });
  });
}
