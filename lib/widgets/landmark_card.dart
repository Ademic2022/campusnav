import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_text_styles.dart';
import '../core/models/landmark.dart';
import '../core/services/storage_service.dart';

class LandmarkCard extends StatefulWidget {
  final Landmark landmark;
  final double? userLat;
  final double? userLng;
  final VoidCallback? onTap;
  final VoidCallback? onNavigate;
  final bool showSaveButton;
  final VoidCallback? onSaveToggled;

  const LandmarkCard({
    super.key,
    required this.landmark,
    this.userLat,
    this.userLng,
    this.onTap,
    this.onNavigate,
    this.showSaveButton = true,
    this.onSaveToggled,
  });

  @override
  State<LandmarkCard> createState() => _LandmarkCardState();
}

class _LandmarkCardState extends State<LandmarkCard> {
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _isSaved = StorageService.instance.isSaved(widget.landmark.id);
  }

  Future<void> _toggleSave() async {
    await StorageService.instance.toggle(widget.landmark);
    setState(() {
      _isSaved = StorageService.instance.isSaved(widget.landmark.id);
    });
    widget.onSaveToggled?.call();
  }

  @override
  Widget build(BuildContext context) {
    final catColor = AppColors.categoryColor(widget.landmark.category);
    final hasDist = widget.userLat != null && widget.userLng != null;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Category icon bubble
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: catColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    AppColors.categoryEmoji(widget.landmark.category),
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name + category + distance
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.landmark.name,
                      style: AppTextStyles.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.landmark.categoryLabel,
                            style: AppTextStyles.labelSmall
                                .copyWith(color: catColor),
                          ),
                        ),
                        if (hasDist) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.directions_walk,
                              size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 2),
                          Text(
                            widget.landmark.friendlyDistance(
                                widget.userLat!, widget.userLng!),
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Action buttons
              Row(
                children: [
                  if (widget.onNavigate != null)
                    _IconBtn(
                      icon: Icons.directions_rounded,
                      color: AppColors.primary,
                      bgColor: AppColors.primary.withValues(alpha: 0.15),
                      onTap: widget.onNavigate!,
                    ),
                  if (widget.showSaveButton) ...[
                    const SizedBox(width: 6),
                    _IconBtn(
                      icon: _isSaved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_outline_rounded,
                      color:
                          _isSaved ? AppColors.accent : AppColors.textSecondary,
                      bgColor: _isSaved
                          ? AppColors.accent.withValues(alpha: 0.15)
                          : AppColors.surfaceHigh,
                      onTap: _toggleSave,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _IconBtn({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
