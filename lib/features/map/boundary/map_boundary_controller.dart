import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/campus_boundary_service.dart';

/// Renders the campus boundary as a subtle fill and a crisp outline on Mapbox.
class MapBoundaryController {
  static const String sourceId = 'oau-boundary-source';
  static const String fillLayerId = 'oau-boundary-fill';
  static const String lineLayerId = 'oau-boundary-line';

  // TEMPORARY VISIBILITY PROBE - DELETE BEFORE COMMIT.
  // Blazing values so it is impossible to miss: opaque magenta, 12 px dashed
  // outline. If you do not see this, the layers are not installing.
  // To revert, delete this const and restore the two expressions in
  // _installLayers to the values recorded in git history.
  static const bool loudDebugStyle = true;
  static const int loudColor = 0xFFFF00FF;
  static const double loudFillOpacity = 0.55;
  static const double loudLineOpacity = 1.0;
  static const double loudLineWidth = 12.0;

  MapboxMap? _map;
  GeoJsonSource? _source;
  bool _attached = false;

  /// Attaches (or re-attaches) the boundary layers to [map].
  Future<void> attach(MapboxMap map) async {
    _map = map;
    _attached = false;
    await _installLayers();
  }

  /// Re-attaches if the map reference or style changed.
  Future<void> ensureAttached(MapboxMap map) async {
    if (!identical(_map, map) || !_attached) {
      await attach(map);
    }
  }

  Future<void> _installLayers() async {
    final map = _map;
    if (map == null) return;

    final service = CampusBoundary.instance;
    if (!service.isLoaded) {
      await service.load();
    }

    final data = service.toGeoJson();
    final source = GeoJsonSource(
      id: sourceId,
      data: data,
      generateId: true,
    );
    _source = source;

    // Guarded removal, because the native remove throws PlatformException when
    // the id is absent. An unguarded call aborted the whole install on a fresh
    // style, so the fence silently never drew. The existence probes are the
    // plugin's own documented pattern (see its style integration test).
    if (await map.style.styleLayerExists(lineLayerId)) {
      await map.style.removeStyleLayer(lineLayerId);
    }
    if (await map.style.styleLayerExists(fillLayerId)) {
      await map.style.removeStyleLayer(fillLayerId);
    }
    if (await map.style.styleSourceExists(sourceId)) {
      await map.style.removeStyleSource(sourceId);
    }

    await map.style.addSource(source);

    final fillColor =
        loudDebugStyle ? loudColor : AppColors.primary.toARGB32();

    await map.style.addLayer(FillLayer(
      id: fillLayerId,
      sourceId: sourceId,
      fillColorExpression: [
        'interpolate',
        ['linear'],
        ['zoom'],
        12,
        fillColor,
        16,
        fillColor,
      ],
      fillOpacityExpression: loudDebugStyle
          ? <Object>[loudFillOpacity]
          : <Object>[
              'interpolate',
              ['linear'],
              ['zoom'],
              12,
              0.10,
              16,
              0.16,
            ],
      fillAntialias: true,
    ));

    final lineColor =
        loudDebugStyle ? loudColor : AppColors.primary.toARGB32();

    await map.style.addLayer(LineLayer(
      id: lineLayerId,
      sourceId: sourceId,
      lineColor: lineColor,
      lineOpacity: loudDebugStyle ? loudLineOpacity : null,
      lineOpacityExpression: loudDebugStyle
          ? null
          : <Object>[
              'interpolate',
              ['linear'],
              ['zoom'],
              12,
              0.70,
              16,
              0.90,
            ],
      lineWidth: loudDebugStyle ? loudLineWidth : null,
      lineWidthExpression: loudDebugStyle
          ? null
          : <Object>[
              'interpolate',
              ['linear'],
              ['zoom'],
              12,
              2.0,
              16,
              3.0,
            ],
    ));

    debugPrint('Boundary installed: ${data.length} chars, '
        'fill+line layers live, loudDebugStyle=$loudDebugStyle');
    _attached = true;
  }

  /// Forces a reload if the bundled polygon changes. Currently a no-op after
  /// the first load (bundled), but keeps the API future-proof.
  Future<void> refresh() async {
    final map = _map;
    if (map == null) return;
    if (!_attached) return;

    final data = CampusBoundary.instance.toGeoJson();
    await _source?.updateGeoJSON(data);
  }

  /// Marks the layers as stale after the style reloads.
  void invalidateAttachment() {
    _map = null;
    _source = null;
    _attached = false;
  }

  void dispose() {
    invalidateAttachment();
  }
}
