import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

class MapStylePicker extends StatelessWidget {
  final String currentStyle;
  final void Function(String) onStyleSelected;

  const MapStylePicker({
    super.key,
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
            onTap: () {
              HapticFeedback.lightImpact();
              onStyleSelected(s.uri);
            },
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
