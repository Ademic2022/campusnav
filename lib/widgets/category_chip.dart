import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class CategoryChip extends StatelessWidget {
  final String category;
  final String label;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.category,
    required this.label,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.categoryColor(category);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<CategoryChip> buildRow({
    required List<String> categories,
    required String selected,
    required void Function(String) onChanged,
  }) {
    const meta = {
      'all': ('All', '🗺️'),
      'hostel': ('Hostels', '🏠'),
      'faculty': ('Faculties', '🏛️'),
      'department': ('Depts', '📚'),
      'lecture': ('Halls', '🎓'),
      'admin': ('Admin', '🏢'),
      'food': ('Food', '🍽️'),
      'banks': ('Banks', '🏦'),
      'health': ('Health', '🏥'),
      'gate': ('Gates', '🚪'),
      'sports': ('Sports', '⚽'),
    };

    return categories.map((cat) {
      final info = meta[cat] ?? (cat, '📍');
      return CategoryChip(
        category: cat,
        label: info.$1,
        emoji: info.$2,
        isSelected: selected == cat,
        onTap: () => onChanged(cat),
      );
    }).toList();
  }
}
