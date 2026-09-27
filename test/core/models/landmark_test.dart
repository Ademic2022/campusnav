import 'package:flutter_test/flutter_test.dart';
import 'package:oau_navigator/core/models/landmark.dart';

void main() {
  const moremi = Landmark(
    id: 12,
    name: 'Moremi Hall',
    category: 'faculty',
    lat: 7.51234,
    lng: 4.52345,
    description: 'Faculty of Environmental Studies',
    icon: 'faculty',
  );

  group('fromJson', () {
    test('parses integer coordinates as doubles', () {
      final l = Landmark.fromJson({
        'id': 3,
        'name': 'Oduduwa Hall',
        'category': 'hostel',
        'lat': 4,
        'lng': 4,
        'description': '',
        'icon': 'hostel',
      });
      expect(l.lat, 4.0);
      expect(l.lng, 4.0);
      expect(l.lat, isA<double>());
    });

    test('falls back to category when icon is absent', () {
      final l = Landmark.fromJson({
        'id': 4,
        'name': 'Bank',
        'category': 'banks',
        'lat': 7.5,
        'lng': 4.5,
        'description': '',
      });
      expect(l.icon, 'banks');
    });
  });

  group('distanceTo', () {
    test('is zero for the same point', () {
      expect(moremi.distanceTo(moremi.lat, moremi.lng), closeTo(0, 0.001));
    });

    test('is symmetric', () {
      final a = moremi.distanceTo(7.5000, 4.5300);
      final b = const Landmark(
        id: 99,
        name: 'Other',
        category: 'other',
        lat: 7.5000,
        lng: 4.5300,
        description: '',
        icon: 'other',
      ).distanceTo(moremi.lat, moremi.lng);
      expect(a, closeTo(b, 0.0001));
    });

    test('gives a plausible campus-scale distance', () {
      // ~0.01 degrees of latitude is a little over 1.1 km.
      final d = moremi.distanceTo(7.52234, 4.52345);
      expect(d, closeTo(1113, 15));
    });
  });

  group('friendlyDistance', () {
    test('uses metres below 1 km', () {
      // 0.001 degrees of latitude is roughly 111 m.
      expect(moremi.friendlyDistance(7.51334, 4.52345), '111m away');
    });

    test('uses one decimal km above 1 km', () {
      expect(moremi.friendlyDistance(7.52234, 4.52345), '1.1km away');
    });
  });

  group('walkingMinutes', () {
    test('never returns less than one minute', () {
      expect(moremi.walkingMinutes(moremi.lat, moremi.lng), 1);
    });

    test('scales with distance at the shared walking pace', () {
      // 1113 m at 80 m/min is ~14 minutes.
      expect(moremi.walkingMinutes(7.52234, 4.52345), 14);
    });
  });

  group('categoryLabel', () {
    test('maps known categories to friendly labels', () {
      expect(moremi.categoryLabel, 'Faculty');
      expect(
        const Landmark(
          id: 1,
          name: 'x',
          category: 'lecture',
          lat: 0,
          lng: 0,
          description: '',
          icon: 'lecture',
        ).categoryLabel,
        'Lecture Hall',
      );
    });

    test('title-cases unknown categories', () {
      expect(
        const Landmark(
          id: 1,
          name: 'x',
          category: 'sports',
          lat: 0,
          lng: 0,
          description: '',
          icon: 'sports',
        ).categoryLabel,
        'Sports',
      );
      expect(
        const Landmark(
          id: 1,
          name: 'x',
          category: 'library',
          lat: 0,
          lng: 0,
          description: '',
          icon: 'library',
        ).categoryLabel,
        'Library',
      );
    });

    test('does not throw on an empty category', () {
      expect(
        const Landmark(
          id: 1,
          name: 'x',
          category: '',
          lat: 0,
          lng: 0,
          description: '',
          icon: '',
        ).categoryLabel,
        'Place',
      );
    });
  });

  group('equality', () {
    test('is by id', () {
      const other = Landmark(
        id: 12,
        name: 'Renamed',
        category: 'hostel',
        lat: 0,
        lng: 0,
        description: '',
        icon: 'hostel',
      );
      expect(moremi, other);
      expect(moremi.hashCode, other.hashCode);
    });
  });

  test('toJson round-trips through fromJson', () {
    final decoded = Landmark.fromJson(moremi.toJson());
    expect(decoded.id, moremi.id);
    expect(decoded.name, moremi.name);
    expect(decoded.category, moremi.category);
    expect(decoded.lat, moremi.lat);
    expect(decoded.lng, moremi.lng);
  });
}
