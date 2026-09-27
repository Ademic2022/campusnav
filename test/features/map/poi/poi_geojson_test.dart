import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:oau_navigator/core/constants/app_colors.dart';
import 'package:oau_navigator/core/models/landmark.dart';
import 'package:oau_navigator/features/map/poi/poi_geojson.dart';

void main() {
  const moremi = Landmark(
    id: 12,
    name: 'Moremi Hall',
    category: 'faculty',
    lat: 7.51234,
    lng: 4.52345,
    description: '',
    icon: 'faculty',
  );
  const canteen = Landmark(
    id: 34,
    name: 'Amina Canteen',
    category: 'food',
    lat: 7.51100,
    lng: 4.52400,
    description: '',
    icon: 'food',
  );
  const hall = Landmark(
    id: 56,
    name: 'Oduduwa Hall',
    category: 'hostel',
    lat: 7.51000,
    lng: 4.52300,
    description: '',
    icon: 'hostel',
  );

  Map<String, dynamic> decode(String json) =>
      jsonDecode(json) as Map<String, dynamic>;

  group('buildPoiGeoJson', () {
    test('produces a valid FeatureCollection', () {
      final json = decode(buildPoiGeoJson([moremi, canteen, hall]));
      expect(json['type'], 'FeatureCollection');

      final features = json['features'] as List<dynamic>;
      expect(features.length, 3);
    });

    test('emits GeoJSON Point geometry in [lng, lat] order', () {
      final features =
          decode(buildPoiGeoJson([moremi]))['features'] as List<dynamic>;
      final geometry = (features.first as Map<String, dynamic>)['geometry']
          as Map<String, dynamic>;

      expect(geometry['type'], 'Point');
      // Longitude first, latitude second — the reverse silently misplaces pins.
      expect(geometry['coordinates'], [4.52345, 7.51234]);
    });

    test('carries the landmarkId needed to resolve a tap', () {
      final features =
          decode(buildPoiGeoJson([moremi]))['features'] as List<dynamic>;
      final properties = (features.first as Map<String, dynamic>)['properties']
          as Map<String, dynamic>;

      expect(properties['landmarkId'], 12);
      expect(properties['name'], 'Moremi Hall');
      expect(properties['category'], 'faculty');
    });

    test('filters by a single category', () {
      final json = decode(buildPoiGeoJson(
        [moremi, canteen, hall],
        categories: {'food'},
      ));
      final features = json['features'] as List<dynamic>;
      expect(features.length, 1);
      final properties = (features.first as Map<String, dynamic>)['properties']
          as Map<String, dynamic>;
      expect(properties['category'], 'food');
    });

    test('filters by several categories', () {
      final json = decode(buildPoiGeoJson(
        [moremi, canteen, hall],
        categories: {'food', 'hostel'},
      ));
      expect((json['features'] as List<dynamic>).length, 2);
    });

    test('an empty filter means everything', () {
      final json = decode(buildPoiGeoJson([moremi, canteen, hall]));
      expect((json['features'] as List<dynamic>).length, 3);
    });

    test('a non-matching filter yields an empty collection', () {
      final json = decode(buildPoiGeoJson(
        [moremi, canteen],
        categories: {'__none__'},
      ));
      expect(json['features'], isEmpty);
    });

    test('handles an empty landmark list', () {
      final json = decode(buildPoiGeoJson([]));
      expect(json['type'], 'FeatureCollection');
      expect(json['features'], isEmpty);
    });

    test('handles negative ids used by marked locations', () {
      const marked = Landmark(
        id: -1,
        name: 'Marked Location',
        category: 'other',
        lat: 7.5,
        lng: 4.5,
        description: '',
        icon: 'other',
      );
      final features =
          decode(buildPoiGeoJson([marked]))['features'] as List<dynamic>;
      final properties = (features.first as Map<String, dynamic>)['properties']
          as Map<String, dynamic>;
      expect(properties['landmarkId'], -1);
    });
  });

  group('buildCategoryColorExpression', () {
    test('is a match expression keyed on category', () {
      final expression = buildCategoryColorExpression();
      expect(expression.first, 'match');
      expect(expression[1], ['get', 'category']);
    });

    test('covers every known category and ends with a default', () {
      final expression = buildCategoryColorExpression();
      const categories = [
        'hostel',
        'faculty',
        'admin',
        'food',
        'banks',
        'health',
        'gate',
        'sports',
        'lecture',
        'department',
      ];

      // ["match", ["get","category"], cat, colour, ... , default]
      //   = 2 head + 2 per category + 1 trailing default
      expect(expression.length, 2 + categories.length * 2 + 1);

      for (final category in categories) {
        final index = expression.indexOf(category);
        expect(index, greaterThan(0), reason: '$category missing');
        expect(
          expression[index + 1],
          AppColors.categoryColor(category).toARGB32(),
          reason: '$category colour mismatch',
        );
      }
    });

    test('default colour is the last element', () {
      final expression = buildCategoryColorExpression();
      expect(expression.last, AppColors.textSecondary.toARGB32());
    });

    test('colours are encoded as ints the style spec accepts', () {
      for (final value in buildCategoryColorExpression()) {
        if (value is String || value is List) continue;
        expect(value, isA<int>().having((v) => v, 'argb', greaterThan(0)));
      }
    });
  });

  group('parsePoiTapResult', () {
    test('resolves a landmark feature', () {
      final result = parsePoiTapResult({
        'type': 'Feature',
        'properties': {'landmarkId': 12, 'name': 'Moremi Hall'},
      });

      expect(result, isNotNull);
      expect(result!.isLandmark, isTrue);
      expect(result.isCluster, isFalse);
      expect(result.landmarkId, 12);
    });

    test('resolves a cluster feature', () {
      final result = parsePoiTapResult({
        'type': 'Feature',
        'properties': {
          'cluster': true,
          'cluster_id': 42,
          'point_count': 17,
          'point_count_abbreviated': '17',
        },
      });

      expect(result, isNotNull);
      expect(result!.isCluster, isTrue);
      expect(result.isLandmark, isFalse);
      expect(result.clusterId, 42);
      expect(result.pointCount, 17);
    });

    test('retains raw properties for the cluster expansion query', () {
      final result = parsePoiTapResult({
        'properties': {'cluster': true, 'cluster_id': 7, 'point_count': 3},
      });
      expect(result!.properties['cluster_id'], 7);
    });

    test('accepts numeric ids delivered as doubles', () {
      final result = parsePoiTapResult({
        'properties': {'landmarkId': 12.0},
      });
      expect(result!.landmarkId, 12);
    });

    test('ignores a null feature', () {
      expect(parsePoiTapResult(null), isNull);
    });

    test('ignores a feature with no properties', () {
      expect(parsePoiTapResult({'type': 'Feature'}), isNull);
    });

    test('ignores non-POI properties', () {
      expect(
          parsePoiTapResult({
            'properties': {'name': 'Some Road', 'class': 'street'},
          }),
          isNull);
    });

    test('ignores a malformed cluster missing its id', () {
      expect(
          parsePoiTapResult({
            'properties': {'cluster': true, 'point_count': 5},
          }),
          isNull);
    });

    test('ignores a malformed cluster missing its count', () {
      expect(
          parsePoiTapResult({
            'properties': {'cluster': true, 'cluster_id': 5},
          }),
          isNull);
    });

    test('handles properties delivered as a nested dynamic map', () {
      final result = parsePoiTapResult({
        'properties': <String, dynamic>{'landmarkId': 99, 'name': 'X'},
      });
      expect(result!.landmarkId, 99);
    });
  });

  group('kPoiCategories', () {
    test('starts with all and uses categories present in the data', () {
      expect(kPoiCategories.first, 'all');
      expect(kPoiCategories, isNotEmpty);
    });
  });
}
