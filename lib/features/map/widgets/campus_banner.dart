import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/location_service.dart';

/// Transient banner shown when the device crosses the campus fence.
///
/// Reads the same [CampusTransitionEvent] the geofence emits, so the wording
/// always matches the state the rest of the app switched to.
class CampusBanner extends StatelessWidget {
  const CampusBanner({super.key, required this.event});

  final CampusTransitionEvent event;

  bool get _entered => event.transition == CampusTransition.entered;

  @override
  Widget build(BuildContext context) {
    final color = _entered ? AppColors.primary : AppColors.accent;
    final icon = _entered ? Icons.login_rounded : Icons.logout_rounded;
    final metres = event.distanceToFenceMetres.abs().round();

    return TweenAnimationBuilder<double>(
      // Slide down from the top on entry, settle in place afterwards.
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, -12 * (1 - t)), child: child),
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _entered
                      ? 'You have entered OAU campus'
                      : 'You have left OAU campus',
                  style: AppTextStyles.bodySmall,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${metres}m',
                style: AppTextStyles.labelSmall
                    .copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
