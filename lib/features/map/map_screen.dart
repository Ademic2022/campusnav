import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/oau_bounds.dart';
import '../../core/models/landmark.dart';
import '../../core/services/landmark_service.dart';
import '../../core/services/routing_service.dart';
import 'poi/map_poi_controller.dart';

import 'map_provider.dart';
import 'widgets/landmark_sheet.dart';
import 'widgets/locating_indicator.dart';
import 'widgets/map_fab.dart';
import 'widgets/map_style_picker.dart';
import 'widgets/marked_location_sheet.dart';
import 'widgets/navigation_sheet.dart';
import 'widgets/search_sheet.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? _mapboxMap;
  PolylineAnnotationManager? _polylineManager;
  PointAnnotationManager? _pointAnnotationManager;
  final MapPoiController _poi = MapPoiController();
  RouteResult? _activeRoute;
  String? _activeMarkerKey;
  String? _lastNavPositionKey;
  bool _wasNavigating = false;
  Uint8List? _startMarkerImage;
  Uint8List? _destMarkerImage;
  Uint8List? _markedPinImage;
  int? _lastFlownLandmarkId;
  String _currentStyle = MapboxStyles.DARK;
  bool _showStylePicker = false;
  List<Landmark> _landmarks = const [];
  String? _poiDataKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<MapProvider>();
      provider.addListener(_onProviderChange);
      provider.initLocation();
      _loadLandmarks();
    });
  }

  /// Keeps the POI source in step with the provider. Runs on every notification
  /// (including GPS ticks) but each branch is guarded so the platform is only
  /// touched when the POI layer actually needs to change.
  void _onProviderChange() {
    if (!mounted) return;
    _syncPoiData();
    _syncPoiHighlight();
  }

  Future<void> _loadLandmarks() async {
    try {
      final all = await LandmarkService.instance.getAll();
      if (!mounted) return;
      setState(() => _landmarks = all);
      _syncPoiData();
    } on Object {
      // POI layer simply stays empty; the rest of the map still works.
    }
  }

  void _syncPoiData() {
    final map = _mapboxMap;
    if (map == null) return;

    final provider = context.read<MapProvider>();
    final categories = provider.poiCategory == 'all'
        ? const <String>{}
        : <String>{provider.poiCategory};

    final key = [
      _landmarks.length,
      provider.poiCategory,
    ].join('-');
    if (_poiDataKey == key) return;
    _poiDataKey = key;

    _poi.ensureAttached(map).then((_) {
      return _poi.updateData(_landmarks, categories: categories);
    }).catchError((Object error) {
      // Previously swallowed, which hid a stale-attachment bug where the
      // source no longer existed and the layer silently stayed empty.
      debugPrint('POI sync failed: $error');
    });
  }

  void _syncPoiHighlight() {
    final map = _mapboxMap;
    if (map == null) return;
    final selected = context.read<MapProvider>().selectedLandmark;
    _poi.setSelected(selected).catchError((Object _) {});
  }

  @override
  void dispose() {
    try {
      context.read<MapProvider>().removeListener(_onProviderChange);
    } catch (_) {}
    _poi.dispose();
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _poiDataKey = null;
    _polylineManager =
        await mapboxMap.annotations.createPolylineAnnotationManager();
    _pointAnnotationManager =
        await mapboxMap.annotations.createPointAnnotationManager();

    await _pointAnnotationManager!.setIconAllowOverlap(true);
    await _pointAnnotationManager!.setIconIgnorePlacement(true);

    await mapboxMap.gestures.updateSettings(GesturesSettings(
      rotateEnabled: true,
      pinchToZoomEnabled: true,
      simultaneousRotateAndPinchToZoomEnabled: true,
      increaseRotateThresholdWhenPinchingToZoom: false,
      increasePinchToZoomThresholdWhenRotating: false,
      scrollEnabled: true,
      doubleTapToZoomInEnabled: true,
      doubleTouchToZoomOutEnabled: true,
      quickZoomEnabled: true,
      pitchEnabled: true,
    ));
    await mapboxMap.compass.updateSettings(CompassSettings(enabled: false));
    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    await _applyLocationPuck(mapboxMap);

    _syncPoiData();
    _syncPoiHighlight();
  }

  Future<void> _applyLocationPuck(MapboxMap map) async {
    await map.location.updateSettings(LocationComponentSettings(
      enabled: true,
      puckBearingEnabled: true,
      puckBearing: PuckBearing.HEADING,
      pulsingEnabled: true,
      pulsingColor: AppColors.primary.toARGB32(),
    ));
  }

  Future<void> _changeMapStyle(String styleUri) async {
    if (_mapboxMap == null || _currentStyle == styleUri) return;
    _currentStyle = styleUri;
    _activeRoute = null;
    _activeMarkerKey = null;

    await _mapboxMap!.loadStyleURI(styleUri);

    _polylineManager =
        await _mapboxMap!.annotations.createPolylineAnnotationManager();
    _pointAnnotationManager =
        await _mapboxMap!.annotations.createPointAnnotationManager();
    await _pointAnnotationManager!.setIconAllowOverlap(true);
    await _pointAnnotationManager!.setIconIgnorePlacement(true);
    await _applyLocationPuck(_mapboxMap!);

    // Loading a new style discards custom sources and layers, so the
    // controller's attachment is stale even though the MapboxMap is the same
    // instance. Drop it so the next sync reinstalls against the new style.
    _poi.invalidateAttachment();
    _poiDataKey = null;
    _syncPoiData();
    _syncPoiHighlight();
  }

  Future<void> _flyToUserLocation() async {
    final provider = context.read<MapProvider>();
    final pos = provider.userPosition;
    if (pos == null || _mapboxMap == null) return;
    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(pos.longitude, pos.latitude)),
        zoom: OauBounds.defaultZoom,
      ),
      MapAnimationOptions(duration: 1000),
    );
  }

  Future<void> _followForNavigation(MapProvider mapProvider) async {
    if (!mapProvider.isNavigating || _mapboxMap == null) return;
    final pos = mapProvider.userPosition;
    if (pos == null) return;

    final key =
        '${pos.latitude.toStringAsFixed(5)}-${pos.longitude.toStringAsFixed(5)}';
    if (_lastNavPositionKey == key) return;
    _lastNavPositionKey = key;

    await _mapboxMap!.easeTo(
      CameraOptions(
        center: Point(coordinates: Position(pos.longitude, pos.latitude)),
        zoom: 17.5,
        bearing: pos.heading,
        pitch: 45,
      ),
      MapAnimationOptions(duration: 500),
    );
  }

  Future<void> _resetNavigationCamera() async {
    if (_mapboxMap == null) return;
    _lastNavPositionKey = null;
    await _mapboxMap!.easeTo(
      CameraOptions(pitch: 0, bearing: 0, zoom: OauBounds.defaultZoom),
      MapAnimationOptions(duration: 600),
    );
  }

  Future<void> _flyToLandmark(Landmark landmark) async {
    if (_mapboxMap == null) return;
    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(landmark.lng, landmark.lat)),
        zoom: OauBounds.searchZoom,
      ),
      MapAnimationOptions(duration: 800),
    );
  }

  void _onMapLongTap(MapContentGestureContext ctx) {
    HapticFeedback.mediumImpact();
    final provider = context.read<MapProvider>();
    if (provider.isNavigating) return;
    final coord = ctx.point.coordinates;
    provider.setMarkedLocation(coord.lat.toDouble(), coord.lng.toDouble());
    _mapboxMap?.flyTo(
      CameraOptions(center: ctx.point, zoom: 17.5),
      MapAnimationOptions(duration: 600),
    );
  }

  /// Handles a tap on the POI layer: a cluster zooms in to split apart, a
  /// landmark opens its detail sheet.
  Future<void> _onMapTap(MapContentGestureContext ctx) async {
    if (!mounted) return;
    final provider = context.read<MapProvider>();
    if (provider.isNavigating) return;

    final hit = await _poi.resolveTap(ctx.touchPosition);
    if (hit == null || !mounted) return;

    if (hit.isCluster) {
      final zoom = await _poi.clusterExpansionZoom(hit.properties);
      if (zoom == null || !mounted) return;
      await _mapboxMap?.easeTo(
        CameraOptions(center: ctx.point, zoom: zoom.clamp(0, 20)),
        MapAnimationOptions(duration: 400),
      );
      return;
    }

    final id = hit.landmarkId;
    if (id == null) return;

    final landmark = _landmarks.firstWhere(
      (l) => l.id == id,
      orElse: () => Landmark(
        id: id,
        name: 'Selected place',
        category: 'other',
        lat: ctx.point.coordinates.lat.toDouble(),
        lng: ctx.point.coordinates.lng.toDouble(),
        description: '',
        icon: 'other',
      ),
    );

    HapticFeedback.selectionClick();
    provider.selectLandmark(landmark);
  }

  Future<Uint8List> _createMarkedPinImage() async {
    const iconSize = 96.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    const icon = Icons.location_on;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Shadow
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        color: Colors.black.withValues(alpha: 0.4),
        fontSize: iconSize,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(0, 4));

    // Pin
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        color: const Color(0xFF8B5CF6),
        fontSize: iconSize,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset.zero);

    final picture = recorder.endRecording();
    final image = await picture.toImage(iconSize.toInt(), iconSize.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<void> _drawRoute(RouteResult route, {bool skipCamera = false}) async {
    if (_mapboxMap == null || _polylineManager == null) return;

    // Identity check: a reroute that returns the same point count and distance
    // is still a different route, so the old polyline must be replaced.
    if (identical(_activeRoute, route)) return;
    _activeRoute = route;

    await _polylineManager!.deleteAll();

    final line = LineString(
      coordinates: route.coordinates.map((c) => Position(c[0], c[1])).toList(),
    );

    if (!mounted) return;
    await _polylineManager!.create(
      PolylineAnnotationOptions(
        geometry: line,
        // ignore: deprecated_member_use
        lineColor:
            context.read<MapProvider>().routeProfile == RouteProfile.driving
                // ignore: deprecated_member_use
                ? AppColors.routeDriving.value
                // ignore: deprecated_member_use
                : AppColors.routeWalking.value,
        lineWidth: 4.0,
        lineOpacity: 0.9,
      ),
    );

    if (skipCamera) return;

    final lats = route.coordinates.map((c) => c[1]);
    final lngs = route.coordinates.map((c) => c[0]);
    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);

    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(
            (minLng + maxLng) / 2,
            (minLat + maxLat) / 2,
          ),
        ),
        zoom: OauBounds.overviewZoom,
      ),
      MapAnimationOptions(duration: 800),
    );
  }

  Future<Uint8List> _createStartLocationMarker() async {
    const size = 64.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(size / 2, size / 2);

    canvas.drawCircle(
      center,
      14,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(center, 14, Paint()..color = Colors.white);
    canvas.drawCircle(center, 10, Paint()..color = AppColors.primary);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<Uint8List> _createDestLocationMarker() async {
    const iconSize = 72.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    const icon = Icons.location_on;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        color: Colors.black.withValues(alpha: 0.4),
        fontSize: iconSize,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, const Offset(0, 4));

    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        color: AppColors.error,
        fontSize: iconSize,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset.zero);

    final picture = recorder.endRecording();
    final image = await picture.toImage(iconSize.toInt(), iconSize.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<void> _ensureMarkerImages() async {
    _startMarkerImage ??= await _createStartLocationMarker();
    _destMarkerImage ??= await _createDestLocationMarker();
    _markedPinImage ??= await _createMarkedPinImage();
  }

  Future<void> _updateMarkers(MapProvider mapProvider) async {
    if (_pointAnnotationManager == null) return;
    await _ensureMarkerImages();

    final isRouting = mapProvider.activeRoute != null;

    final showGateMarker = mapProvider.isStartingFromGate &&
        (isRouting || mapProvider.canRouteFromCurrentStart);

    final targetDest = isRouting
        ? mapProvider.routeDestination ?? mapProvider.selectedLandmark
        : mapProvider.selectedLandmark;
    final hasDestination = targetDest != null;

    final markerKey = [
      showGateMarker ? mapProvider.routeStartLat : 'gate-off',
      showGateMarker ? mapProvider.routeStartLng : 'gate-off',
      hasDestination ? targetDest.id : 'none',
      mapProvider.hasMarkedLocation
          ? '${mapProvider.markedLat}-${mapProvider.markedLng}'
          : 'pin-off',
    ].join('-');

    if (_activeMarkerKey == markerKey) return;
    _activeMarkerKey = markerKey;

    await _pointAnnotationManager!.deleteAll();

    if (showGateMarker) {
      await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              mapProvider.routeStartLng,
              mapProvider.routeStartLat,
            ),
          ),
          image: _startMarkerImage,
          iconSize: 1.0,
          iconAnchor: IconAnchor.CENTER,
        ),
      );
    }

    if (hasDestination) {
      await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(targetDest.lng, targetDest.lat),
          ),
          image: _destMarkerImage,
          iconSize: 1.0,
          iconAnchor: IconAnchor.BOTTOM,
          iconOffset: [0.0, 0.0],
        ),
      );
    }

    if (mapProvider.hasMarkedLocation) {
      await _pointAnnotationManager!.create(
        PointAnnotationOptions(
          geometry: Point(
            coordinates:
                Position(mapProvider.markedLng!, mapProvider.markedLat!),
          ),
          image: _markedPinImage,
          iconSize: 1.0,
          iconAnchor: IconAnchor.BOTTOM,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MapProvider>(
      builder: (context, mapProvider, _) {
        final selected = mapProvider.selectedLandmark;
        if (selected == null) {
          _lastFlownLandmarkId = null;
        } else if (_lastFlownLandmarkId != selected.id) {
          _lastFlownLandmarkId = selected.id;
          // Capture the landmark now: it may be cleared before the frame ends.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _flyToLandmark(selected);
          });
        }

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: Stack(
              children: [
                MapWidget(
                  key: const ValueKey('mapbox_map'),
                  cameraOptions: CameraOptions(
                    center: Point(
                      coordinates: Position(
                        OauBounds.centerLng,
                        OauBounds.centerLat,
                      ),
                    ),
                    zoom: OauBounds.defaultZoom,
                  ),
                  styleUri: mapProvider.mapStyle,
                  onMapCreated: _onMapCreated,
                  onLongTapListener: _onMapLongTap,
                  onTapListener: _onMapTap,
                ),
                Builder(builder: (_) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _changeMapStyle(mapProvider.mapStyle);
                  });
                  return const SizedBox.shrink();
                }),
                if (mapProvider.isNavigating)
                  Positioned.fill(
                    child: NavigationSheet(mapProvider: mapProvider),
                  ),
                if (!mapProvider.isNavigating &&
                    mapProvider.selectedLandmark == null &&
                    !mapProvider.hasMarkedLocation)
                  Positioned.fill(
                    child: SearchSheet(
                      onSearchTap: () => context.push('/search'),
                    ),
                  ),
                if (!mapProvider.isNavigating &&
                    mapProvider.selectedLandmark != null)
                  Positioned.fill(
                    child: LandmarkSheet(
                      mapProvider: mapProvider,
                    ),
                  ),
                if (!mapProvider.isNavigating && mapProvider.hasMarkedLocation)
                  Positioned.fill(
                    child: MarkedLocationSheet(mapProvider: mapProvider),
                  ),
                Builder(
                  builder: (_) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _updateMarkers(mapProvider);
                    });
                    return const SizedBox.shrink();
                  },
                ),
                if (mapProvider.activeRoute != null)
                  Builder(
                    builder: (_) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _drawRoute(
                          mapProvider.activeRoute!,
                          skipCamera: mapProvider.isNavigating,
                        );
                      });
                      return const SizedBox.shrink();
                    },
                  )
                else
                  Builder(
                    builder: (_) {
                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        // Only clear when a polyline was actually drawn, so
                        // idle GPS ticks do not hit the platform channel.
                        if (_activeRoute == null) return;
                        _activeRoute = null;
                        await _polylineManager?.deleteAll();
                      });
                      return const SizedBox.shrink();
                    },
                  ),
                Builder(builder: (_) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mapProvider.isNavigating) {
                      _wasNavigating = true;
                      _followForNavigation(mapProvider);
                    } else if (_wasNavigating) {
                      _wasNavigating = false;
                      _resetNavigationCamera();
                    }
                  });
                  return const SizedBox.shrink();
                }),
                if (_showStylePicker)
                  Positioned(
                    right: 72,
                    top: 0,
                    child: SafeArea(
                      child: MapStylePicker(
                        currentStyle: _currentStyle,
                        onStyleSelected: (style) {
                          mapProvider.setMapStyle(style);
                          setState(() => _showStylePicker = false);
                        },
                      ),
                    ),
                  ),
                Positioned(
                  right: 16,
                  top: 50,
                  child: SafeArea(
                    child: Column(
                      children: [
                        MapFab(
                          icon: _showStylePicker
                              ? Icons.close_rounded
                              : Icons.layers_rounded,
                          onTap: () => setState(
                              () => _showStylePicker = !_showStylePicker),
                        ),
                        const SizedBox(height: 12),
                        MapFab(
                          icon: Icons.my_location_rounded,
                          onTap: _flyToUserLocation,
                        ),
                      ],
                    ),
                  ),
                ),
                if (mapProvider.isLocating)
                  const Positioned(
                    top: 0,
                    right: 16,
                    child: SafeArea(child: LocatingIndicator()),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
