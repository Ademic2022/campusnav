import 'package:flutter_test/flutter_test.dart';
import 'package:oau_navigator/core/services/campus_boundary_service.dart';
import 'package:oau_navigator/core/services/landmark_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = LandmarkService.instance;

  group('getAll', () {
    test('loads a non-trivial dataset', () async {
      final all = await service.getAll();
      expect(all.length, greaterThan(100));
    });

    test('contains no duplicate ids', () async {
      final all = await service.getAll();
      final ids = all.map((l) => l.id).toSet();
      expect(ids.length, all.length);
    });

    test('every landmark sits inside the campus fence', () async {
      // The OAUTHC teaching hospital complex is the one deliberate exception:
      // it is affiliated with OAU but stands ~4.5 km away on its own site, so
      // the campus fence excludes it. Those landmarks are still published.
      const offSite = {'OAUTHC (Teaching Hospital)', 'OAUTHC Pharmacy'};
      final boundary = CampusBoundary.instance;
      await boundary.load();
      expect(boundary.isLoaded, isTrue,
          reason: 'campus_boundary.json must load for this test to mean '
              'anything');

      final all = await service.getAll();
      for (final l in all) {
        if (offSite.contains(l.name)) continue;
        expect(
          boundary.contains(l.lat, l.lng),
          isTrue,
          reason: '${l.name} is outside the campus fence',
        );
      }
    });

    test('the off-site OAUTHC landmarks are the only ones excluded', () async {
      const offSite = {'OAUTHC (Teaching Hospital)', 'OAUTHC Pharmacy'};
      final boundary = CampusBoundary.instance;
      await boundary.load();

      final all = await service.getAll();
      final outside =
          all.where((l) => !boundary.contains(l.lat, l.lng)).toList();

      expect(
        outside.map((l) => l.name).toSet(),
        offSite,
        reason: 'only the off-site hospital may fall outside the fence',
      );
    });

    test('is sorted by name', () async {
      final all = await service.getAll();
      final names = all.map((l) => l.name).toList();
      final sorted = List<String>.from(names)..sort();
      expect(names, sorted);
    });

    test('returns the cached list on subsequent calls', () async {
      final a = await service.getAll();
      final b = await service.getAll();
      expect(identical(a, b), isTrue);
    });
  });

  group('search', () {
    test('returns nothing for a blank query', () async {
      expect(await service.search(''), isEmpty);
      expect(await service.search('   '), isEmpty);
    });

    test('is case-insensitive', () async {
      final lower = await service.search('moremi');
      final upper = await service.search('MOREMI');
      expect(lower, isNotEmpty);
      expect(lower.map((l) => l.id), upper.map((l) => l.id));
    });

    test('matches on name', () async {
      final results = await service.search('moremi');
      expect(results, isNotEmpty);
      expect(
        results.any((l) => l.name.toLowerCase().contains('moremi')),
        isTrue,
      );
    });

    test('matches on description', () async {
      final results = await service.search('lecture theatre');
      expect(results, isNotEmpty);
    });

    test('matches on category label', () async {
      final results = await service.search('hostel');
      expect(results, isNotEmpty);
      expect(
          results.every((l) =>
              l.category == 'hostel' ||
              l.name.toLowerCase().contains('hostel')),
          isTrue);
    });

    test('returns empty for a query that matches nothing', () async {
      expect(await service.search('zzzzqqqxyw'), isEmpty);
    });
  });

  group('getByCategory', () {
    test('returns everything for "all"', () async {
      final all = await service.getAll();
      expect((await service.getByCategory('all')).length, all.length);
      expect((await service.getByCategory('')).length, all.length);
    });

    test('filters to an exact category', () async {
      final results = await service.getByCategory('hostel');
      expect(results, isNotEmpty);
      expect(results.every((l) => l.category == 'hostel'), isTrue);
    });

    test('returns empty for an unknown category', () async {
      expect(await service.getByCategory('nope'), isEmpty);
    });
  });

  group('getNearby', () {
    test('sorts by ascending distance', () async {
      final results = await service.getNearby(
        userLat: 7.4976,
        userLng: 4.5225,
        limit: 30,
      );
      expect(results.length, 30);

      for (var i = 1; i < results.length; i++) {
        final prev = results[i - 1].distanceTo(7.4976, 4.5225);
        final curr = results[i].distanceTo(7.4976, 4.5225);
        expect(
          curr,
          greaterThanOrEqualTo(prev - 0.0001),
          reason: 'not sorted at index $i',
        );
      }
    });

    test('honours the limit', () async {
      final results = await service.getNearby(
        userLat: 7.4976,
        userLng: 4.5225,
        limit: 5,
      );
      expect(results.length, 5);
    });

    test('puts the nearest landmark first', () async {
      final all = await service.getAll();
      final results = await service.getNearby(
        userLat: 7.4976,
        userLng: 4.5225,
        limit: 1,
      );

      final expected = all
          .map((l) => (l, l.distanceTo(7.4976, 4.5225)))
          .reduce((a, b) => a.$2 <= b.$2 ? a : b)
          .$1;
      expect(results.single.id, expected.id);
    });

    test('applies the category filter before sorting', () async {
      final results = await service.getNearby(
        userLat: 7.4976,
        userLng: 4.5225,
        category: 'hostel',
        limit: 50,
      );
      expect(results, isNotEmpty);
      expect(results.every((l) => l.category == 'hostel'), isTrue);
    });

    test('does not mutate the cached list', () async {
      final before = (await service.getAll()).map((l) => l.id).toList();
      await service.getNearby(userLat: 7.5, userLng: 4.53, limit: 10);
      final after = (await service.getAll()).map((l) => l.id).toList();
      expect(after, before);
    });
  });
}
