import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../widgets/category_chip.dart';
import '../../search/search_provider.dart';

class SearchSheet extends StatelessWidget {
  final VoidCallback onSearchTap;
  const SearchSheet({super.key, required this.onSearchTap});

  static const double _peekPx = 90.0;
  static const double _mid    = 0.50;
  static const double _full   = 0.88;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPad    = MediaQuery.of(context).padding.bottom;
    final peek = (_peekPx / screenHeight).clamp(0.08, 0.14);

    return DraggableScrollableSheet(
      initialChildSize: peek,
      minChildSize: peek,
      maxChildSize: _full,
      snap: true,
      snapSizes: const [_mid, _full],
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
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onSearchTap();
                },
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(children: [
                    const SizedBox(width: 16),
                    const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Search OAU campus...', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary))),
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Row(children: [
                        const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 14),
                        const SizedBox(width: 4),
                        Text('OAU', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 10),
              child: Text('Browse by Category',
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary)),
            ),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: CategoryChip.buildRow(
                  categories: SearchProvider.categories.where((c) => c != 'all').toList(),
                  selected: '',
                  onChanged: (cat) {
                    HapticFeedback.lightImpact();
                    context.read<SearchProvider>().onCategoryChanged(cat);
                    context.push('/search');
                  },
                ).map((chip) => Padding(padding: const EdgeInsets.only(right: 8), child: chip)).toList(),
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 10),
              child: Text('Quick Access',
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: QuickAccessCard(
                  icon: Icons.near_me_rounded,
                  label: 'Nearby Places',
                  subtitle: 'Locations around you',
                  color: AppColors.accent,
                  onTap: () { HapticFeedback.lightImpact(); context.push('/nearby'); },
                )),
                const SizedBox(width: 12),
                Expanded(child: QuickAccessCard(
                  icon: Icons.bookmark_rounded,
                  label: 'Saved Places',
                  subtitle: 'Your bookmarks',
                  color: AppColors.primary,
                  onTap: () { HapticFeedback.lightImpact(); context.push('/saved'); },
                )),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class QuickAccessCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const QuickAccessCard({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: AppTextStyles.titleMedium.copyWith(color: color),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(subtitle,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
