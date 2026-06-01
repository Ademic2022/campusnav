import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/routing_service.dart';
import '../map_provider.dart';

class LandmarkSheet extends StatefulWidget {
  final MapProvider mapProvider;
  const LandmarkSheet({super.key, required this.mapProvider});

  @override
  State<LandmarkSheet> createState() => _LandmarkSheetState();
}

class _LandmarkSheetState extends State<LandmarkSheet> {
  final _ctrl = DraggableScrollableController();

  static const double _peek   = 0.165;
  static const double _detail = 0.46;
  static const double _full   = 0.88;

  @override
  void initState() {
    super.initState();
    widget.mapProvider.addListener(_onProviderChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _ctrl.isAttached && _ctrl.size < _detail - 0.02) {
        _ctrl.animateTo(_detail,
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic);
      }
    });
  }

  void _onProviderChange() {
    if (!mounted || !_ctrl.isAttached) return;
    if (widget.mapProvider.selectedLandmark != null && _ctrl.size < _detail - 0.02) {
      _ctrl.animateTo(_detail,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    widget.mapProvider.removeListener(_onProviderChange);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mp = widget.mapProvider;
    final landmark = mp.selectedLandmark;
    if (landmark == null) return const SizedBox.shrink();

    final catColor = AppColors.categoryColor(landmark.category);
    final startLat = mp.routeStartLat;
    final startLng = mp.routeStartLng;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      controller: _ctrl,
      initialChildSize: _peek,
      minChildSize: _peek,
      maxChildSize: _full,
      snap: true,
      snapSizes: const [_detail, _full],
      expand: true,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, -2))],
        ),
        child: ListView(
          controller: scrollController,
          padding: EdgeInsets.only(bottom: bottomPad + 16),
          children: [
            Center(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            )),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(child: Text(
                      AppColors.categoryEmoji(landmark.category),
                      style: const TextStyle(fontSize: 26),
                    )),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(landmark.name, style: AppTextStyles.headlineMedium),
                      const SizedBox(height: 2),
                      Text(landmark.description,
                          style: AppTextStyles.bodySmall,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  )),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      mp.clearSelectedLandmark();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: AppColors.textSecondary, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            if (mp.canRouteFromCurrentStart) ...[
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  InfoChip(icon: Icons.directions_walk, label: landmark.friendlyDistance(startLat, startLng)),
                  const SizedBox(width: 8),
                  InfoChip(icon: Icons.access_time_rounded, label: '~${landmark.walkingMinutes(startLat, startLng)} min walk'),
                ]),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  Icon(mp.isStartingFromGate ? Icons.door_front_door_rounded : Icons.my_location_rounded,
                      size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 5),
                  Text(
                    mp.isStartingFromGate ? 'Starting from Main Gate' : 'Starting from your location',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                  ),
                ]),
              ),
            ],

            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Expanded(child: RouteProfileBtn(
                  label: 'Walk', icon: Icons.directions_walk_rounded,
                  isActive: mp.routeProfile == RouteProfile.walking,
                  onTap: () { HapticFeedback.lightImpact(); mp.setRouteProfile(RouteProfile.walking); },
                )),
                const SizedBox(width: 10),
                Expanded(child: RouteProfileBtn(
                  label: 'Drive', icon: Icons.directions_car_rounded,
                  isActive: mp.routeProfile == RouteProfile.driving,
                  onTap: () { HapticFeedback.lightImpact(); mp.setRouteProfile(RouteProfile.driving); },
                )),
              ]),
            ),
            const SizedBox(height: 12),

            if (mp.routeError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: RouteErrorCard(
                  message: mp.routeError!,
                  isNetworkError: mp.routeIsNetworkError,
                  onRetry: () { HapticFeedback.lightImpact(); mp.fetchRoute(); },
                ),
              ),

            if (mp.activeRoute != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.route_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text('${mp.activeRoute!.distanceLabel}  •  ${mp.activeRoute!.durationLabel}',
                        style: AppTextStyles.titleMedium.copyWith(color: AppColors.primary)),
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(width: double.infinity, height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0),
                    onPressed: () { HapticFeedback.mediumImpact(); mp.startNavigation(); },
                    icon: const Icon(Icons.navigation_rounded),
                    label: Text('Start Navigation', style: AppTextStyles.labelLarge),
                  ),
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(width: double.infinity, height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0),
                    onPressed: mp.isLoadingRoute ? null : () { HapticFeedback.mediumImpact(); mp.fetchRoute(); },
                    icon: mp.isLoadingRoute
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.directions_rounded),
                    label: Text(mp.isLoadingRoute ? 'Getting route...' : 'Get Directions',
                        style: AppTextStyles.labelLarge),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const InfoChip({super.key, required this.icon, required this.label});

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

class RouteProfileBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const RouteProfileBtn({
    super.key,
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

class RouteErrorCard extends StatelessWidget {
  final String message;
  final bool isNetworkError;
  final VoidCallback onRetry;

  const RouteErrorCard({
    super.key,
    required this.message,
    required this.isNetworkError,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isNetworkError
                ? Icons.wifi_off_rounded
                : Icons.error_outline_rounded,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Retry',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
