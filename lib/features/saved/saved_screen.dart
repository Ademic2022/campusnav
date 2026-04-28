import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/landmark.dart';
import '../../core/models/saved_location.dart';
import '../../core/services/routing_service.dart';
import '../map/map_provider.dart';
import 'saved_provider.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SavedProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = context.read<MapProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: AppColors.textPrimary, size: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Saved Places', style: AppTextStyles.headlineLarge),
                      Consumer<SavedProvider>(
                        builder: (_, p, __) => Text(
                          '${p.saved.length} bookmarked',
                          style: AppTextStyles.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: AppColors.divider),

            // ── List ──
            Expanded(
              child: Consumer<SavedProvider>(
                builder: (context, provider, _) {
                  if (provider.isEmpty) {
                    return _EmptyState();
                  }

                  final userPos = mapProvider.userPosition;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: provider.saved.length,
                    itemBuilder: (context, i) {
                      final saved = provider.saved[i];
                      return _SavedCard(
                        saved: saved,
                        userLat: userPos?.latitude,
                        userLng: userPos?.longitude,
                        onNavigate: () {
                          final landmark = Landmark(
                            id: saved.landmarkId,
                            name: saved.name,
                            category: saved.category,
                            lat: saved.lat,
                            lng: saved.lng,
                            description: saved.description,
                            icon: saved.category,
                          );
                          mapProvider.selectLandmark(landmark);
                          context.pop();
                        },
                        onRemove: () => provider.remove(saved.landmarkId),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Saved card with swipe-to-dismiss
// ─────────────────────────────────────────────
class _SavedCard extends StatelessWidget {
  final SavedLocation saved;
  final double? userLat;
  final double? userLng;
  final VoidCallback onNavigate;
  final VoidCallback onRemove;

  const _SavedCard({
    required this.saved,
    this.userLat,
    this.userLng,
    required this.onNavigate,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = AppColors.categoryColor(saved.category);
    final landmark = Landmark(
      id: saved.landmarkId,
      name: saved.name,
      category: saved.category,
      lat: saved.lat,
      lng: saved.lng,
      description: saved.description,
      icon: saved.category,
    );
    final hasDist = userLat != null && userLng != null;

    return Dismissible(
      key: Key('saved_${saved.landmarkId}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: AppColors.error),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: catColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(_emoji(saved.category),
                      style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(saved.name, style: AppTextStyles.titleMedium),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: catColor.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            landmark.categoryLabel,
                            style: AppTextStyles.labelSmall
                                .copyWith(color: catColor),
                          ),
                        ),
                        if (hasDist) ...[
                          const SizedBox(width: 8),
                          Text(
                            landmark.friendlyDistance(userLat!, userLng!),
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onNavigate,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.directions_rounded,
                      color: AppColors.primary, size: 20),
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

// ─────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔖', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 20),
            Text('No saved places yet', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 10),
            Text(
              'Tap the bookmark icon on any location\nto save it for quick access',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => context.push('/search'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_rounded,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Text('Browse Campus',
                        style: AppTextStyles.labelLarge
                            .copyWith(color: AppColors.primary)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
