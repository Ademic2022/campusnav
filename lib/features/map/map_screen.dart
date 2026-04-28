import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/oau_bounds.dart';
import '../../core/models/landmark.dart';
import '../../core/services/routing_service.dart';
import '../../widgets/category_chip.dart';
import '../nearby/nearby_provider.dart';
import '../saved/saved_provider.dart';
import 'map_provider.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _annotationManager;
  PolylineAnnotationManager? _polylineManager;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MapProvider>().initLocation();
    });
  }

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _annotationManager =
        await mapboxMap.annotations.createPointAnnotationManager();
    _polylineManager =
        await mapboxMap.annotations.createPolylineAnnotationManager();

    // Disable compass and attribution for cleaner look
    await mapboxMap.compass.updateSettings(CompassSettings(enabled: false));
    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
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
        center: Point(
            coordinates: Position(landmark.lng, landmark.lat)),
        zoom: OauBounds.searchZoom,
      ),
      MapAnimationOptions(duration: 800),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MapProvider>(
      builder: (context, mapProvider, _) {
        // Fly to landmark when selected
        if (mapProvider.selectedLandmark != null) {
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
                  styleUri: MapboxStyles.DARK,
                  onMapCreated: _onMapCreated,
                ),

                // ── Top search bar ──
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _SearchBar(
                      onTap: () => context.push('/search'),
                    ),
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
                if (mapProvider.selectedLandmark != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _LandmarkBottomSheet(
                      landmark: mapProvider.selectedLandmark!,
                      mapProvider: mapProvider,
                    ),
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
              color: Colors.black.withOpacity(0.4),
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
                color: AppColors.primary.withOpacity(0.15),
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
              color: Colors.black.withOpacity(0.4),
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
                    color: AppColors.border,
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
                      color: catColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        _emoji(landmark.category),
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
                    onPressed: () => mapProvider.clearSelectedLandmark(),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
              if (userPos != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    _InfoChip(
                      icon: Icons.directions_walk,
                      label: landmark.friendlyDistance(
                          userPos.latitude, userPos.longitude),
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: Icons.access_time_rounded,
                      label:
                          '~${landmark.walkingMinutes(userPos.latitude, userPos.longitude)} min walk',
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
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.3)),
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

  String _emoji(String category) {
    switch (category) {
      case 'hostel': return '🏠';
      case 'faculty': return '🏛️';
      case 'department': return '📚';
      case 'admin': return '🏢';
      case 'food': return '🍽️';
      case 'atm': return '💳';
      case 'health': return '🏥';
      case 'gate': return '🚪';
      case 'sports': return '⚽';
      case 'lecture': return '🎓';
      default: return '📍';
    }
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
          color: isActive ? AppColors.accent.withOpacity(0.15) : AppColors.surfaceHigh,
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
            Icon(icon, color: color, size: 24),
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
