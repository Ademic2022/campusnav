import 'package:flutter_test/flutter_test.dart';
import 'package:oau_navigator/core/utils/polygon.dart';

void main() {
  // A square roughly 2 km on a side, centred on OAU, in [lng, lat] order.
  // 0.018 degrees of latitude is about 2 km.
  final square = <List<double>>[
    [4.5138, 7.5087],
    [4.5138, 7.5267],
    [4.5318, 7.5267],
    [4.5318, 7.5087],
  ];

  group('pointInPolygon', () {
    test('accepts a point in the middle', () {
      expect(
        pointInPolygon(lat: 7.5177, lng: 4.5228, ring: square),
        isTrue,
      );
    });

    test('rejects a point beyond an edge', () {
      expect(
        pointInPolygon(lat: 7.5300, lng: 4.5228, ring: square),
        isFalse,
      );
    });

    test('rejects a point in the concave notch of a C shape', () {
      // A "C" opening east, so the notch must read as outside.
      final c = <List<double>>[
        [4.5100, 7.5100],
        [4.5100, 7.5250],
        [4.5300, 7.5250],
        [4.5300, 7.5210],
        [4.5140, 7.5210],
        [4.5140, 7.5140],
        [4.5300, 7.5140],
        [4.5300, 7.5100],
      ];
      // The notch is the gap between the two arms, x in (4.5140, 4.5300),
      // y in (7.5140, 7.5210).
      expect(pointInPolygon(lat: 7.5175, lng: 4.5220, ring: c), isFalse,
          reason: 'notch is outside the C');
      expect(pointInPolygon(lat: 7.5175, lng: 4.5120, ring: c), isTrue,
          reason: 'spine of the C is inside');
      // The top arm is solid, so the same longitude reads as inside up there.
      expect(pointInPolygon(lat: 7.5230, lng: 4.5220, ring: c), isTrue,
          reason: 'top arm of the C is inside');
    });

    test('a closed ring matches the same ring left open', () {
      // GeoJSON repeats the first point last; that must not change the answer
      // nor double-count the closing edge.
      final closed = [...square, square.first];
      for (final probe in [
        [7.5177, 4.5228], // inside
        [7.5300, 4.5228], // outside north
        [4.5000, 7.5177], // outside west
        [7.5087, 4.5318], // on the south-east corner
      ]) {
        expect(
          pointInPolygon(lat: probe[0], lng: probe[1], ring: closed),
          pointInPolygon(lat: probe[0], lng: probe[1], ring: square),
          reason: 'closed vs open disagree at $probe',
        );
      }
    });

    test('rejects a degenerate ring', () {
      expect(pointInPolygon(lat: 7.5177, lng: 4.5228, ring: const []), isFalse);
      expect(
        pointInPolygon(lat: 7.5177, lng: 4.5228, ring: [
          [4.51, 7.51],
          [4.52, 7.52],
        ]),
        isFalse,
      );
    });
  });

  group('distanceToPolygonEdgeMetres', () {
    test('measures ~1 km from the centre to an edge', () {
      // Centre is ~0.009 deg from each edge, about 1000 m.
      final d = distanceToPolygonEdgeMetres(
        lat: 7.5177,
        lng: 4.5228,
        ring: square,
      );
      expect(d, closeTo(1000, 60));
    });

    test('is zero on a vertex', () {
      final d = distanceToPolygonEdgeMetres(
        lat: 7.5087,
        lng: 4.5138,
        ring: square,
      );
      expect(d, closeTo(0, 1));
    });

    test('is infinite for a degenerate ring', () {
      expect(
        distanceToPolygonEdgeMetres(lat: 7.5, lng: 4.5, ring: const []),
        double.infinity,
      );
    });
  });

  group('signedDistanceToPolygonMetres', () {
    test('is negative inside', () {
      final d = signedDistanceToPolygonMetres(
        lat: 7.5177,
        lng: 4.5228,
        ring: square,
      );
      expect(d, lessThan(0));
      expect(d.abs(), closeTo(1000, 60));
    });

    test('is positive outside and grows with distance', () {
      final near = signedDistanceToPolygonMetres(
        lat: 7.5280,
        lng: 4.5228,
        ring: square,
      );
      final far = signedDistanceToPolygonMetres(
        lat: 7.5400,
        lng: 4.5228,
        ring: square,
      );
      expect(near, greaterThan(0));
      expect(far, greaterThan(near));
      // Just past the north edge, so a few hundred metres at most.
      expect(near, lessThan(500));
    });

    test('is zero on the edge', () {
      final d = signedDistanceToPolygonMetres(
        lat: 7.5267,
        lng: 4.5228,
        ring: square,
      );
      expect(d.abs(), lessThan(1));
    });

    test('magnitude matches the unsigned edge distance either way', () {
      final inside = signedDistanceToPolygonMetres(
          lat: 7.5177, lng: 4.5228, ring: square);
      final outside = signedDistanceToPolygonMetres(
          lat: 7.5300, lng: 4.5228, ring: square);
      expect(inside.abs(), closeTo(1000, 60));
      expect(outside.abs(), lessThan(1000));
    });
  });

  group('polygonAreaSquareMetres', () {
    test('matches the square wall length for a square', () {
      final a = polygonAreaSquareMetres(square);
      // ~2000 m sides.
      expect(a, closeTo(4.0e6, 2.0e5));
    });

    test('is zero for a degenerate ring', () {
      expect(polygonAreaSquareMetres(const []), 0);
      expect(
        polygonAreaSquareMetres([
          [4.51, 7.51],
          [4.52, 7.52],
        ]),
        0,
      );
    });
  });

  group('polygonBounds', () {
    test('returns the extremes', () {
      final b = polygonBounds(square)!;
      expect(b.$1, closeTo(4.5138, 1e-9));
      expect(b.$2, closeTo(7.5087, 1e-9));
      expect(b.$3, closeTo(4.5318, 1e-9));
      expect(b.$4, closeTo(7.5267, 1e-9));
    });

    test('is null for an empty ring', () {
      expect(polygonBounds(const []), isNull);
    });
  });
}
