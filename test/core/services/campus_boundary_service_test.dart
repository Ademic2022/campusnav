import 'package:flutter_test/flutter_test.dart';
import 'package:oau_navigator/core/services/campus_boundary_service.dart';
import 'package:oau_navigator/core/services/landmark_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final boundary = CampusBoundary.instance;

  group('bundled campus_boundary.json', () {
    setUp(() async {
      boundary.debugReset();
      await boundary.load();
    });

    test('loads a closed ring', () {
      expect(boundary.isLoaded, isTrue);
      final ring = boundary.ring;
      expect(ring.length, greaterThanOrEqualTo(4));
      expect(ring.first, ring.last, reason: 'ring must be closed');
    });

    test('records how the placeholder was derived', () {
      expect(boundary.provenance, isNotNull);
    });

    test('covers a plausible campus area', () {
      final km2 = boundary.areaSquareMetres / 1e6;
      expect(km2, greaterThan(3.0));
      expect(km2, lessThan(12.0));
    });

    test('contains the campus centre', () {
      expect(boundary.contains(7.5177, 4.5228), isTrue);
    });

    test('excludes Ile-Ife town, well outside the fence', () {
      expect(boundary.contains(7.4800, 4.5000), isFalse);
    });

    test('excludes the off-site OAUTHC teaching hospital', () {
      // ~4.5 km south-east of the centroid. Affiliated with OAU but a separate
      // site, so it must not read as "on campus".
      expect(boundary.contains(7.4905, 4.5521), isFalse);
    });

    test('signed distance is negative inside and positive outside', () {
      expect(boundary.signedDistanceMetres(7.5177, 4.5228), lessThan(0));
      expect(boundary.signedDistanceMetres(7.4800, 4.5000), greaterThan(0));
    });

    test('encloses every landmark that is not off-site', () async {
      const offSite = {'OAUTHC (Teaching Hospital)', 'OAUTHC Pharmacy'};
      final all = await LandmarkService.instance.getAll();
      final stray = all
          .where((l) => !offSite.contains(l.name))
          .where((l) => !boundary.contains(l.lat, l.lng))
          .map((l) => l.name)
          .toList();

      expect(stray, isEmpty, reason: 'fence excludes campus landmarks');
    });

    test('is far tighter than the old bounding box', () {
      // The retired bbox overshot the northernmost landmark by ~1.3 km. The
      // fence must not reach anywhere near the off-site hospital.
      expect(boundary.contains(7.5350, 4.5521), isFalse);
      expect(boundary.contains(7.5399, 4.4901), isFalse);
    });

    test('exports a GeoJSON polygon for the map layer', () {
      final json = boundary.toGeoJson();
      expect(json, contains('Polygon'));
      expect(json, contains('Feature'));
    });

    test('load is idempotent', () async {
      final first = boundary.ring;
      await boundary.load();
      expect(identical(boundary.ring, first), isTrue);
    });
  });

  group('before load', () {
    setUp(boundary.debugReset);

    test('reports not loaded and never claims on-campus', () {
      expect(boundary.isLoaded, isFalse);
      expect(boundary.contains(7.5177, 4.5228), isFalse);
      expect(
        boundary.signedDistanceMetres(7.5177, 4.5228),
        double.infinity,
      );
      expect(boundary.areaSquareMetres, 0);
    });
  });

  group('debug injection', () {
    setUp(boundary.debugReset);

    test('accepts a ring directly and closes it', () {
      boundary.debugSetRing([
        [4.51, 7.51],
        [4.51, 7.53],
        [4.53, 7.53],
        [4.53, 7.51],
      ]);
      expect(boundary.isLoaded, isTrue);
      expect(boundary.contains(7.52, 4.52), isTrue);
      expect(boundary.contains(7.50, 4.52), isFalse);
      expect(boundary.ring.first, boundary.ring.last);
    });
  });
}
