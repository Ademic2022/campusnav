import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../map_provider.dart';

class NavigationSheet extends StatefulWidget {
  final MapProvider mapProvider;
  const NavigationSheet({super.key, required this.mapProvider});

  @override
  State<NavigationSheet> createState() => _NavigationSheetState();
}

class _NavigationSheetState extends State<NavigationSheet> {
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
    if (widget.mapProvider.isNavigating && _ctrl.size < _detail - 0.02) {
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
    final step = mp.currentStep;
    final stepIndex = mp.currentStepIndex;
    final total = mp.totalSteps;
    final hasNext = mp.hasNextStep;
    final hasPrev = mp.hasPrevStep;
    final dest = mp.routeDestination?.name ?? 'destination';
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final route = mp.activeRoute;

    final nextStep = hasNext && route != null
        ? route.steps[stepIndex + 1]
        : null;

    final remainingMetres = route != null
        ? route.steps.skip(stepIndex).fold(0.0, (s, st) => s + st.distanceMetres)
        : 0.0;
    final remainingLabel = remainingMetres < 1000
        ? '${remainingMetres.round()} m remaining'
        : '${(remainingMetres / 1000).toStringAsFixed(1)} km remaining';
    final remainingMins = (remainingMetres / 83.3).ceil();

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
              padding: const EdgeInsets.fromLTRB(20, 0, 16, 10),
              child: Row(children: [
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('To $dest',
                      style: AppTextStyles.labelMedium.copyWith(color: AppColors.primary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${stepIndex + 1}/$total',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
                ),
                GestureDetector(
                  onTap: () { HapticFeedback.lightImpact(); mp.endNavigation(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Text('End', style: AppTextStyles.labelSmall.copyWith(color: AppColors.error)),
                  ),
                ),
              ]),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total > 0 ? (stepIndex + 1) / total : 0,
                  minHeight: 4,
                  backgroundColor: AppColors.surfaceHigh,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),

            const Divider(height: 1, color: AppColors.divider),

            if (step != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(step.icon, color: AppColors.primary, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(step.instruction, style: AppTextStyles.headlineMedium,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.straighten_rounded,
                              size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(step.distanceLabel,
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                        ]),
                      ],
                    )),
                  ],
                ),
              ),

            if (nextStep != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Icon(nextStep.icon, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      'Then: ${nextStep.instruction}',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    )),
                    Text(nextStep.distanceLabel,
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textMuted)),
                  ]),
                ),
              ),
            ],

            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.route_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(remainingLabel,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
                  const Spacer(),
                  const Icon(Icons.access_time_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text('~$remainingMins min',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
                ]),
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(children: [
                Expanded(child: NavStepBtn(
                  label: 'Previous',
                  icon: Icons.arrow_back_rounded,
                  enabled: hasPrev,
                  onTap: () { HapticFeedback.lightImpact(); mp.prevStep(); },
                )),
                const SizedBox(width: 12),
                Expanded(child: NavStepBtn(
                  label: hasNext ? 'Next Step' : 'Arrived 🎉',
                  icon: hasNext ? Icons.arrow_forward_rounded : Icons.flag_rounded,
                  enabled: true,
                  isPrimary: true,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (hasNext) { mp.nextStep(); }
                    else { mp.endNavigation(); }
                  },
                )),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class NavStepBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final bool isPrimary;
  final VoidCallback onTap;

  const NavStepBtn({
    super.key,
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isPrimary ? Colors.white : AppColors.textSecondary;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 48,
        decoration: BoxDecoration(
          color: isPrimary
              ? AppColors.primary.withValues(alpha: enabled ? 1.0 : 0.4)
              : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary ? Colors.transparent : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: activeColor.withValues(alpha: enabled ? 1.0 : 0.4)),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: activeColor.withValues(alpha: enabled ? 1.0 : 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
