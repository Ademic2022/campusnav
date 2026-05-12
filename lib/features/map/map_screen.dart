import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/oau_bounds.dart';
import '../../core/models/landmark.dart';
import '../../core/services/routing_service.dart';
import 'map_provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? _mapboxMap;
  PolylineAnnotationManager? _polylineManager;
  PointAnnotationManager? _pointAnnotationManager;
  String? _activeRouteKey;
  String? _activeMarkerKey;
  Uint8List? _startMarkerImage;
  Uint8List? _destMarkerImage;
  int? _lastFlownLandmarkId;
  String _currentStyle = MapboxStyles.DARK;
  bool _showStylePicker = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MapProvider>().initLocation();
    });
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
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
    // Disable compass and attribution for cleaner look
    await mapboxMap.compass.updateSettings(CompassSettings(enabled: false));
    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
  }

  Future<void> _changeMapStyle(String styleUri) async {
    if (_mapboxMap == null || _currentStyle == styleUri) return;
    _currentStyle = styleUri;
    _activeRouteKey = null;
    _activeMarkerKey = null;

    await _mapboxMap!.loadStyleURI(styleUri);

    // Annotation managers are invalidated after a style change — re-create them.
    _polylineManager =
        await _mapboxMap!.annotations.createPolylineAnnotationManager();
    _pointAnnotationManager =
        await _mapboxMap!.annotations.createPointAnnotationManager();
    await _pointAnnotationManager!.setIconAllowOverlap(true);
    await _pointAnnotationManager!.setIconIgnorePlacement(true);
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

  Future<void> _drawRoute(RouteResult route) async {
    if (_mapboxMap == null || _polylineManager == null) return;

    final routeKey = '${route.coordinates.length}-${route.distanceMetres}';
    if (_activeRouteKey == routeKey) return;
    _activeRouteKey = routeKey;

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

    // Draw shadow
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

    // Draw icon
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
  }

  Future<void> _updateMarkers(MapProvider mapProvider) async {
    if (_pointAnnotationManager == null) return;
    await _ensureMarkerImages();

    final isRouting = mapProvider.activeRoute != null;

    final hasStart = isRouting ||
        mapProvider.useCampusAsStart ||
        mapProvider.userPosition != null;

    final targetDest = isRouting
        ? mapProvider.routeDestination ?? mapProvider.selectedLandmark
        : mapProvider.selectedLandmark;
    final hasDestination = targetDest != null;

    final markerKey = [
      hasStart ? mapProvider.routeStartLat : 'none',
      hasStart ? mapProvider.routeStartLng : 'none',
      hasDestination ? targetDest.id : 'none',
    ].join('-');

    if (_activeMarkerKey == markerKey) return;
    _activeMarkerKey = markerKey;

    await _pointAnnotationManager!.deleteAll();

    if (hasStart) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MapProvider>(
      builder: (context, mapProvider, _) {
        // Fly only when the selected landmark changes.
        if (mapProvider.selectedLandmark == null) {
          _lastFlownLandmarkId = null;
        } else if (_lastFlownLandmarkId != mapProvider.selectedLandmark!.id) {
          _lastFlownLandmarkId = mapProvider.selectedLandmark!.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _flyToLandmark(mapProvider.selectedLandmark!);
          });
        }

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: Stack(
              children: [
                // ── Mapbox Map ──
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
                ),

                // ── Style change side-effect ──
                Builder(builder: (_) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _changeMapStyle(mapProvider.mapStyle);
                  });
                  return const SizedBox.shrink();
                }),

                // ── Top search bar ──
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _SearchBar(
                      onTap: () => context.push('/search'),
                    ),
                  ),
                ),

                // ── Style picker popup ──
                if (_showStylePicker)
                  Positioned(
                    right: 72,
                    bottom: 168,
                    child: _StylePickerCard(
                      currentStyle: _currentStyle,
                      onStyleSelected: (style) {
                        mapProvider.setMapStyle(style);
                        setState(() => _showStylePicker = false);
                      },
                    ),
                  ),

                // ── Layers button ──
                Positioned(
                  right: 16,
                  bottom: 168,
                  child: _MapFab(
                    icon: _showStylePicker
                        ? Icons.close_rounded
                        : Icons.layers_rounded,
                    onTap: () => setState(
                        () => _showStylePicker = !_showStylePicker),
                  ),
                ),

                // ── My location FAB ──
                Positioned(
                  right: 16,
                  bottom: 110,
                  child: _MapFab(
                    icon: Icons.my_location_rounded,
                    onTap: _flyToUserLocation,
                  ),
                ),

                // ── Selected landmark bottom sheet ──
                if (mapProvider.selectedLandmark != null &&
                    mapProvider.isLandmarkSheetVisible)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _LandmarkBottomSheet(
                      landmark: mapProvider.selectedLandmark!,
                      mapProvider: mapProvider,
                    ),
                  ),

                if (mapProvider.selectedLandmark != null &&
                    !mapProvider.isLandmarkSheetVisible)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 10,
                    child: SafeArea(
                      top: false,
                      child: Center(
                        child: _ReopenSheetButton(
                          onTap: mapProvider.showLandmarkSheet,
                        ),
                      ),
                    ),
                  ),

                // ── Route markers (start + destination) ──
                Builder(
                  builder: (_) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _updateMarkers(mapProvider);
                    });
                    return const SizedBox.shrink();
                  },
                ),

                // ── Render active route ──
                if (mapProvider.activeRoute != null)
                  Builder(
                    builder: (_) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _drawRoute(mapProvider.activeRoute!);
                      });
                      return const SizedBox.shrink();
                    },
                  )
                else
                  Builder(
                    builder: (_) {
                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        _activeRouteKey = null;
                        await _polylineManager?.deleteAll();
                      });
                      return const SizedBox.shrink();
                    },
                  ),

                // ── Loading overlay ──
                if (mapProvider.isLocating)
                  const Positioned(
                    top: 0,
                    right: 16,
                    child: SafeArea(child: _LocatingIndicator()),
                  ),

              ],
            ),
            // ── Bottom navigation bar ──
            bottomNavigationBar: _BottomNav(
              currentIndex: mapProvider.navIndex,
              onTap: (i) {
                mapProvider.setNavIndex(i);
                if (i == 1) context.push('/nearby');
                if (i == 2) context.push('/saved');
              },
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Search Bar
// ─────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(Icons.search_rounded,
                color: AppColors.textSecondary, size: 22),
            const SizedBox(width: 10),
            Text(
              'Search OAU campus...',
              style: AppTextStyles.bodyMedium,
            ),
            const Spacer(),
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      color: AppColors.primary, size: 14),
                  const SizedBox(width: 4),
                  Text('OAU',
                      style: AppTextStyles.labelSmall
                          .copyWith(color: AppColors.primary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// FAB button
// ─────────────────────────────────────────────
class _MapFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapFab({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
    );
  }
}

class _ReopenSheetButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ReopenSheetButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.keyboard_arrow_up_rounded,
                color: AppColors.textPrimary, size: 18),
            const SizedBox(width: 6),
            Text('Show details', style: AppTextStyles.labelMedium),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Landmark bottom sheet
// ─────────────────────────────────────────────
class _LandmarkBottomSheet extends StatelessWidget {
  final Landmark landmark;
  final MapProvider mapProvider;
  const _LandmarkBottomSheet(
      {required this.landmark, required this.mapProvider});

  @override
  Widget build(BuildContext context) {
    final userPos = mapProvider.userPosition;
    final startLat = mapProvider.routeStartLat;
    final startLng = mapProvider.routeStartLng;
    final catColor = AppColors.categoryColor(landmark.category);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 24)],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        AppColors.categoryEmoji(landmark.category),
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(landmark.name,
                            style: AppTextStyles.headlineMedium),
                        const SizedBox(height: 2),
                        Text(landmark.description,
                            style: AppTextStyles.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => mapProvider.hideLandmarkSheet(),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
              if (userPos != null || mapProvider.useCampusAsStart) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    _InfoChip(
                      icon: Icons.directions_walk,
                      label: landmark.friendlyDistance(startLat, startLng),
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: Icons.access_time_rounded,
                      label:
                          '~${landmark.walkingMinutes(startLat, startLng)} min walk',
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // Route profile selector + Get Directions
              Row(
                children: [
                  Expanded(
                    child: _RouteProfileBtn(
                      label: 'Walk',
                      icon: Icons.directions_walk_rounded,
                      isActive:
                          mapProvider.routeProfile == RouteProfile.walking,
                      onTap: () =>
                          mapProvider.setRouteProfile(RouteProfile.walking),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _RouteProfileBtn(
                      label: 'Drive',
                      icon: Icons.directions_car_rounded,
                      isActive:
                          mapProvider.routeProfile == RouteProfile.driving,
                      onTap: () =>
                          mapProvider.setRouteProfile(RouteProfile.driving),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Error message
              if (mapProvider.routeError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    mapProvider.routeError!,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.error),
                  ),
                ),

              // Route info
              if (mapProvider.activeRoute != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.route_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${mapProvider.activeRoute!.distanceLabel}  •  ${mapProvider.activeRoute!.durationLabel}',
                        style: AppTextStyles.titleMedium
                            .copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),

              // Get Directions button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: mapProvider.isLoadingRoute
                      ? null
                      : () => mapProvider.fetchRoute(),
                  icon: mapProvider.isLoadingRoute
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.directions_rounded),
                  label: Text(
                    mapProvider.isLoadingRoute
                        ? 'Getting route...'
                        : 'Get Directions',
                    style: AppTextStyles.labelLarge,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _RouteProfileBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _RouteProfileBtn({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 44,
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.accent.withValues(alpha: 0.15)
              : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isActive ? AppColors.accent : AppColors.textSecondary,
                size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: isActive ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Locating indicator
// ─────────────────────────────────────────────
class _LocatingIndicator extends StatelessWidget {
  const _LocatingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 80),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text('Locating...', style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Bottom navigation bar
// ─────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.map_rounded,
                label: 'Map',
                isActive: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.near_me_rounded,
                label: 'Nearby',
                isActive: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.bookmark_rounded,
                label: 'Saved',
                isActive: currentIndex == 2,
                onTap: () => onTap(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _NavItem(
      {required this.icon,
      required this.label,
      required this.isActive,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : AppColors.textSecondary;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Map style picker card
// ─────────────────────────────────────────────
class _StylePickerCard extends StatelessWidget {
  final String currentStyle;
  final void Function(String) onStyleSelected;

  const _StylePickerCard({
    required this.currentStyle,
    required this.onStyleSelected,
  });

  static final _styles = [
    (label: 'Dark',      uri: MapboxStyles.DARK,              icon: Icons.dark_mode_rounded,     color: const Color(0xFF334155)),
    (label: 'Satellite', uri: MapboxStyles.SATELLITE_STREETS, icon: Icons.satellite_alt_rounded, color: const Color(0xFF166534)),
    (label: 'Standard',  uri: MapboxStyles.STANDARD,          icon: Icons.map_outlined,          color: const Color(0xFF1D4ED8)),
    (label: 'Outdoors',  uri: MapboxStyles.OUTDOORS,          icon: Icons.terrain_rounded,       color: const Color(0xFF92400E)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _styles.map((s) {
          final isActive = currentStyle == s.uri;
          return GestureDetector(
            onTap: () => onStyleSelected(s.uri),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(vertical: 3),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: s.color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(s.icon, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    s.label,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: isActive ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isActive)
                    const Icon(Icons.check_rounded,
                        size: 14, color: AppColors.primary),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
