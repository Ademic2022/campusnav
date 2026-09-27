import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/polygon.dart';

/// The OAU campus fence, loaded once from a bundled GeoJSON asset.
///
/// Single source of truth for "is this position on campus". The map draws this
/// same ring, so the visible boundary and the geofence can never disagree.
///
/// The bundled polygon is a **placeholder** derived from the convex hull of the
/// landmarks in `assets/data/landmarks.json` (see its `properties`). Replacing
/// it with a hand-traced perimeter needs no code change.
class CampusBoundary {
  CampusBoundary._();
  static final CampusBoundary instance = CampusBoundary._();

  static const String assetPath = 'assets/data/campus_boundary.json';

  /// The outer ring as `[lng, lat]` pairs, closed. Empty until [load] succeeds.
  List<List<double>> _ring = const [];

  String? _source;
  bool _loaded = false;
  bool _loading = false;

  /// True once a usable ring is available.
  bool get isLoaded => _loaded;

  /// How the bundled ring was derived, for display and debugging.
  String? get provenance => _source;

  /// The fence ring as `[lng, lat]` pairs, closed. Empty when not loaded.
  List<List<double>> get ring => _ring;

  /// Fence area in square metres, or 0 when not loaded.
  double get areaSquareMetres =>
      _loaded ? polygonAreaSquareMetres(_ring) : 0;

  /// Loads the polygon asset. Safe to call repeatedly; concurrent and later
  /// calls reuse the first result.
  ///
  /// [CampusBoundary.instance] must be used from widget tests, where the
  /// default asset bundle is not populated; see [debugSetRing].
  Future<void> load() async {
    if (_loaded || _loading) return;
    _loading = true;
    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final features = decoded['features'] as List<dynamic>?;
      if (features == null || features.isEmpty) {
        throw const FormatException('campus boundary has no features');
      }

      final geometry = features.first['geometry'] as Map<String, dynamic>?;
      final coordinates = geometry?['coordinates'] as List<dynamic>?;
      if (coordinates == null || coordinates.isEmpty) {
        throw const FormatException('campus boundary has no coordinates');
      }

      // GeoJSON Polygon: coordinates[0] is the outer ring.
      final outer = coordinates.first as List<dynamic>;
      final ring = outer
          .map((c) => (c as List<dynamic>)
              .map((v) => (v as num).toDouble())
              .toList())
          .toList();

      if (ring.length < 4) {
        throw const FormatException(
            'campus boundary ring needs at least 3 distinct vertices');
      }

      final closed = _closeRing(ring);

      // Sanity-check the ring encloses area and is not wound inside out. A
      // centroid that falls outside means a mangled or self-intersecting ring.
      final centroid = _centroid(closed);
      if (polygonAreaSquareMetres(closed) <= 0) {
        throw const FormatException('campus boundary encloses no area');
      }
      if (!pointInPolygon(lat: centroid[1], lng: centroid[0], ring: closed)) {
        throw const FormatException(
            'campus boundary centroid falls outside its own ring');
      }

      final properties = features.first['properties'] as Map<String, dynamic>?;
      _source = properties?['source'] as String?;
      _ring = closed;
      _loaded = true;
    } on Object catch (error) {
      // A missing or malformed fence must not take the app down: callers treat
      // an unloaded boundary as "cannot tell" rather than "off campus".
      debugPrint('CampusBoundary: could not load $assetPath ($error)');
      _loaded = false;
      _ring = const [];
    } finally {
      _loading = false;
    }
  }

  /// Whether [lat]/[lng] is inside the fence.
  ///
  /// Returns false when the boundary has not loaded, so an unavailable fence is
  /// never mistaken for a confirmed "on campus".
  bool contains(double lat, double lng) {
    if (!_loaded) return false;
    return pointInPolygon(lat: lat, lng: lng, ring: _ring);
  }

  /// Signed metres to the fence edge: negative inside, positive outside.
  ///
  /// Returns [double.infinity] when the boundary has not loaded.
  double signedDistanceMetres(double lat, double lng) {
    if (!_loaded) return double.infinity;
    return signedDistanceToPolygonMetres(lat: lat, lng: lng, ring: _ring);
  }

  /// The fence as a GeoJSON geometry string, for the map's polygon source.
  String toGeoJson() => jsonEncode({
        'type': 'Feature',
        'properties': const <String, dynamic>{},
        'geometry': {'type': 'Polygon', 'coordinates': [_ring]},
      });

  /// Test seam: inject a ring without touching the asset bundle.
  @visibleForTesting
  void debugSetRing(List<List<double>> ring, {String? source}) {
    _ring = _closeRing(ring);
    _source = source;
    _loaded = _ring.length >= 4;
  }

  @visibleForTesting
  void debugReset() {
    _ring = const [];
    _source = null;
    _loaded = false;
    _loading = false;
  }

  static List<List<double>> _closeRing(List<List<double>> ring) {
    if (ring.isEmpty) return ring;
    final first = ring.first;
    final last = ring.last;
    if (first[0] == last[0] && first[1] == last[1]) return ring;
    return [...ring, [first[0], first[1]]];
  }

  /// Mean of the distinct vertices, used only to validate the ring.
  static List<double> _centroid(List<List<double>> ring) {
    var sumLng = 0.0;
    var sumLat = 0.0;
    var count = 0;
    for (final c in ring) {
      sumLng += c[0];
      sumLat += c[1];
      count++;
    }
    return count == 0 ? [0, 0] : [sumLng / count, sumLat / count];
  }
}
