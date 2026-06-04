import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../map_provider.dart';

class MarkedLocationSheet extends StatefulWidget {
  final MapProvider mapProvider;
  const MarkedLocationSheet({super.key, required this.mapProvider});

  @override
  State<MarkedLocationSheet> createState() => _MarkedLocationSheetState();
}

class _MarkedLocationSheetState extends State<MarkedLocationSheet> {
  final _ctrl = DraggableScrollableController();

  static const double _peek = 0.165;
  static const double _detail = 0.46;
  static const double _full = 0.88;

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
    if (widget.mapProvider.hasMarkedLocation && _ctrl.size < _detail - 0.02) {
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
    if (!mp.hasMarkedLocation) return const SizedBox.shrink();

    final distLabel = mp.markedLocationDistanceLabel(mp.userPosition);
    final coordLabel = mp.markedCoordinateLabel;
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
          boxShadow: [
            BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, -2))
          ],
        ),
        child: ListView(
          controller: scrollController,
          padding: EdgeInsets.only(bottom: bottomPad + 16),
          children: [
            // Drag handle
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Title row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFF8B5CF6),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Marked Location', style: AppTextStyles.headlineMedium),
                        const SizedBox(height: 2),
                        if (distLabel.isNotEmpty)
                          Text(distLabel,
                              style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      mp.clearMarkedLocation();
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

            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.divider),

            // Coordinates
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Details',
                      style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.my_location_rounded,
                          size: 15, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Text('Coordinates',
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary)),
                      const Spacer(),
                      Text(coordLabel,
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textPrimary)),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 16),

            // Get Directions button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
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
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    mp.navigateToMarkedLocation();
                  },
                  icon: const Icon(Icons.directions_rounded),
                  label: Text('Get Directions', style: AppTextStyles.labelLarge),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Remove button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    mp.clearMarkedLocation();
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text('Remove', style: AppTextStyles.labelMedium),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
