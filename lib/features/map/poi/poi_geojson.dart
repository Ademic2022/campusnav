import 'dart:convert';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/landmark.dart';

/// Serialises landmarks into the GeoJSON `FeatureCollection` consumed by the
/// map's clustered POI source.
///
/// [categories] filters by exact category; pass an empty set for "show all".
String buildPoiGeoJson(
  List<Landmark> landmarks, {
  Set<String> categories = const {},
}) {
  final features = <Map<String, dynamic>>[];

  for (final landmark in landmarks) {
    if (categories.isNotEmpty && !categories.contains(landmark.category)) {
      continue;
    }
    features.add({
      'type': 'Feature',
      'id': landmark.id,
      'properties': {
        'landmarkId': landmark.id,
        'name': landmark.name,
        'category': landmark.category,
      },
      'geometry': {
        'type': 'Point',
        'coordinates': [landmark.lng, landmark.lat],
      },
    });
  }

  return jsonEncode({'type': 'FeatureCollection', 'features': features});
}

/// Style expression mapping each category to its app colour, so POI dots match
/// the rest of the UI without a round trip to Flutter per feature.
List<Object> buildCategoryColorExpression() {
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

  final expression = <Object>[
    'match',
    ['get', 'category']
  ];
  for (final category in categories) {
    expression
      ..add(category)
      ..add(AppColors.categoryColor(category).toARGB32());
  }
  expression.add(AppColors.textSecondary.toARGB32());
  return expression;
}

/// Categories offered in the map's POI filter row.
const List<String> kPoiCategories = [
  'all',
  'food',
  'banks',
  'hostel',
  'health',
  'lecture',
  'faculty',
  'sports',
];

/// The outcome of a tap on the POI layer.
class PoiTapResult {
  /// Set when a single landmark was tapped.
  final int? landmarkId;

  final bool isCluster;

  /// Mapbox cluster id, needed to request a cluster's expansion zoom.
  final int? clusterId;

  final int pointCount;

  /// Raw feature properties, needed verbatim for cluster queries.
  final Map<String?, Object?> properties;

  const PoiTapResult.landmark(this.landmarkId,
      {Map<String?, Object?>? properties})
      : isCluster = false,
        clusterId = null,
        pointCount = 1,
        properties = properties ?? const {};

  const PoiTapResult.cluster({
    required int this.clusterId,
    required this.pointCount,
    Map<String?, Object?>? properties,
  })  : landmarkId = null,
        isCluster = true,
        properties = properties ?? const {};

  bool get isLandmark => landmarkId != null;
}

/// Interprets a feature returned by `queryRenderedFeatures`.
///
/// Returns `null` for anything that is not a POI feature, so unrelated map
/// layers are ignored rather than misread as landmarks.
PoiTapResult? parsePoiTapResult(Map<Object?, Object?>? feature) {
  if (feature == null) return null;

  final rawProperties = feature['properties'];
  if (rawProperties is! Map) return null;

  final properties = rawProperties.cast<String?, Object?>();

  if (properties['cluster'] == true) {
    final clusterId = properties['cluster_id'];
    final pointCount = properties['point_count'];
    if (clusterId is num && pointCount is num) {
      return PoiTapResult.cluster(
        clusterId: clusterId.toInt(),
        pointCount: pointCount.toInt(),
        properties: properties,
      );
    }
    return null;
  }

  final landmarkId = properties['landmarkId'];
  if (landmarkId is num) {
    return PoiTapResult.landmark(landmarkId.toInt(), properties: properties);
  }

  return null;
}
