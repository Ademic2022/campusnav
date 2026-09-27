import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/landmark.dart';
import 'poi_geojson.dart';

/// Owns the map's landmark POI layer.
///
/// Landmarks are rendered through a clustered GeoJSON source rather than
/// individual annotations, so 158 points stay cheap and collapse into a
/// handful of circles when zoomed out.
class MapPoiController {
  static const String sourceId = 'oau-poi-source';
  static const String clusterHaloLayerId = 'oau-poi-cluster-halo';
  static const String clusterLayerId = 'oau-poi-cluster';
  static const String clusterCountLayerId = 'oau-poi-cluster-count';
  static const String pointLayerId = 'oau-poi-point';
  static const String pointRingLayerId = 'oau-poi-point-ring';
  static const String selectedLayerId = 'oau-poi-selected';

  /// Above this zoom, clustering is disabled so individual buildings separate.
  static const double clusterMaxZoom = 16.0;

  static const double clusterRadius = 55.0;

  static const double clusterMinPoints = 2;

  MapboxMap? _map;
  GeoJsonSource? _poiSource;
  List<Landmark> _landmarks = const [];
  Set<String> _categories = const {};
  int? _selectedId;
  bool _attached = false;

  /// Categories currently visible. Empty means "all".
  Set<String> get categories => _categories;

  /// Attaches the source and layers. Safe to call again after a style change,
  /// which wipes any previously added sources and layers.
  Future<void> attach(MapboxMap map) async {
    _map = map;
    _attached = false;
    await _installLayers();
  }

  /// Re-attaches if the style was swapped out, discarding the cached reference.
  Future<void> ensureAttached(MapboxMap map) async {
    if (!identical(_map, map) || !_attached) {
      await attach(map);
    }
  }

  Future<void> _installLayers() async {
    final map = _map;
    if (map == null) return;

    final source = GeoJsonSource(
      id: sourceId,
      data: buildPoiGeoJson(_landmarks, categories: _categories),
      cluster: true,
      clusterRadius: clusterRadius,
      clusterMaxZoom: clusterMaxZoom,
      clusterMinPoints: clusterMinPoints,
    );
    _poiSource = source;
    await map.style.addSource(source);

    // Soft halo behind each cluster so circles read clearly on dark tiles.
    await map.style.addLayer(CircleLayer(
      id: clusterHaloLayerId,
      sourceId: sourceId,
      filter: ['has', 'point_count'],
      circleRadiusExpression: [
        'step',
        ['get', 'point_count'],
        20.0,
        25,
        27.0,
        75,
        34.0,
      ],
      circleColorExpression: [
        'step',
        ['get', 'point_count'],
        AppColors.primary.toARGB32(),
        25,
        AppColors.accent.toARGB32(),
        75,
        AppColors.routeWalking.toARGB32(),
      ],
      circleOpacityExpression: ['*', 0.25, 1],
      circleBlur: 0.6,
    ));

    await map.style.addLayer(CircleLayer(
      id: clusterLayerId,
      sourceId: sourceId,
      filter: ['has', 'point_count'],
      circleRadiusExpression: [
        'step',
        ['get', 'point_count'],
        13.0,
        25,
        17.0,
        75,
        21.0,
      ],
      circleColorExpression: [
        'step',
        ['get', 'point_count'],
        AppColors.primary.toARGB32(),
        25,
        AppColors.accent.toARGB32(),
        75,
        AppColors.routeWalking.toARGB32(),
      ],
      circleStrokeColor: AppColors.background.toARGB32(),
      circleStrokeWidth: 2.0,
    ));

    // Cluster count label. Uses the style's default glyph stack; the circles
    // still convey the grouping if glyphs are unavailable.
    await map.style.addLayer(SymbolLayer(
      id: clusterCountLayerId,
      sourceId: sourceId,
      filter: ['has', 'point_count'],
      textFieldExpression: ['get', 'point_count_abbreviated'],
      textSizeExpression: [
        'step',
        ['get', 'point_count'],
        12.0,
        75,
        14.0,
      ],
      textColor: AppColors.background.toARGB32(),
      textIgnorePlacement: true,
      textAllowOverlap: true,
    ));

    // Individual landmarks: a translucent ring with a solid core.
    await map.style.addLayer(CircleLayer(
      id: pointRingLayerId,
      sourceId: sourceId,
      filter: [
        '!',
        ['has', 'point_count']
      ],
      circleRadius: 11.0,
      circleColorExpression: [
        '*',
        ['get', 'landmarkId'],
        0
      ],
      circleOpacity: 0.25,
    ));

    await map.style.addLayer(CircleLayer(
      id: pointLayerId,
      sourceId: sourceId,
      filter: [
        '!',
        ['has', 'point_count']
      ],
      circleRadiusExpression: [
        'interpolate',
        ['linear'],
        ['zoom'],
        13,
        4.0,
        16,
        6.5,
        19,
        9.0,
      ],
      circleColorExpression: buildCategoryColorExpression(),
      circleStrokeColor: AppColors.background.toARGB32(),
      circleStrokeWidth: 1.5,
    ));

    // Highlight ring for the currently selected landmark.
    await map.style.addLayer(CircleLayer(
      id: selectedLayerId,
      sourceId: sourceId,
      filter: [
        '==',
        ['get', 'landmarkId'],
        -1
      ],
      circleRadiusExpression: [
        'interpolate',
        ['linear'],
        ['zoom'],
        13,
        9.0,
        16,
        14.0,
        19,
        18.0,
      ],
      circleColor: AppColors.accent.toARGB32(),
      circleOpacity: 0.0,
      circleStrokeColor: AppColors.accent.toARGB32(),
      circleStrokeWidth: 3.0,
    ));

    _attached = true;
  }

  /// Replaces the landmark dataset or the active category filter.
  Future<void> updateData(
    List<Landmark> landmarks, {
    Set<String> categories = const {},
  }) async {
    _landmarks = landmarks;
    _categories = categories;
    if (!_attached || _poiSource == null) return;

    await _poiSource!.updateGeoJSON(
      buildPoiGeoJson(landmarks, categories: categories),
    );

    await _syncHighlight();
  }

  /// Rings the landmark with [landmark]'s id, or clears the ring when null.
  Future<void> setSelected(Landmark? landmark) async {
    _selectedId = landmark?.id;
    await _syncHighlight();
  }

  Future<void> _syncHighlight() async {
    final map = _map;
    if (map == null || !_attached) return;

    await map.style.updateLayer(CircleLayer(
      id: selectedLayerId,
      sourceId: sourceId,
      filter: [
        '==',
        ['get', 'landmarkId'],
        _selectedId ?? -1
      ],
      circleRadiusExpression: const [
        'interpolate',
        'linear',
        ['zoom'],
        13,
        9.0,
        16,
        14.0,
        19,
        18.0,
      ],
      circleColor: AppColors.accent.toARGB32(),
      circleOpacity: 0.0,
      circleStrokeColor: AppColors.accent.toARGB32(),
      circleStrokeWidth: 3.0,
    ));
  }

  /// Resolves a map tap to a landmark or a cluster.
  ///
  /// [touchPosition] is the screen-space location of the tap.
  Future<PoiTapResult?> resolveTap(ScreenCoordinate touchPosition) async {
    final map = _map;
    if (map == null) return null;

    try {
      final features = await map.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(touchPosition),
        RenderedQueryOptions(
          layerIds: const [
            clusterLayerId,
            pointLayerId,
            selectedLayerId,
          ],
        ),
      );

      for (final feature in features) {
        final parsed = parsePoiTapResult(feature?.queriedFeature.feature);
        if (parsed != null) return parsed;
      }
    } on Object {
      return null;
    }

    return null;
  }

  /// Expands a cluster to the zoom level at which it splits apart.
  ///
  /// The native side returns the zoom as a string, so an integer-valued
  /// response like `"17"` is handled as well as a fractional one.
  Future<double?> clusterExpansionZoom(Map<String?, Object?> properties) async {
    final map = _map;
    if (map == null) return null;

    try {
      final result = await map.getGeoJsonClusterExpansionZoom(
        sourceId,
        properties,
      );
      final value = result.value;
      if (value == null) return null;
      return double.tryParse(value.trim());
    } on Object {
      return null;
    }
  }

  void dispose() {
    _map = null;
    _poiSource = null;
    _attached = false;
  }
}
