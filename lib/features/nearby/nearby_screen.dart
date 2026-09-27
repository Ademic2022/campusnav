import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/landmark_card.dart';
import '../../widgets/nav_back_button.dart';
import '../map/map_provider.dart';
import '../saved/saved_provider.dart';
import 'nearby_provider.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  @override
  Widget build(BuildContext context) {
    final mapProvider = context.watch<MapProvider>();
    final savedProvider = context.read<SavedProvider>();
    final userPos = mapProvider.userPosition;

    // Re-evaluated on every GPS update. The load is deferred to a post-frame
    // callback because it notifies listeners, which is illegal during build.
    if (userPos != null) {
      final nearby = context.read<NearbyProvider>();
      if (nearby.needsReloadFor(userPos.latitude, userPos.longitude)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          context
              .read<NearbyProvider>()
              .ensureLoaded(userPos.latitude, userPos.longitude);
        });
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  const NavBackButton(),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nearby Places', style: AppTextStyles.headlineLarge),
                      Text(
                        mapProvider.userIsOnCampus
                            ? 'OAU Campus'
                            : 'Outside campus — showing nearest places',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Consumer<NearbyProvider>(
              builder: (context, provider, _) {
                return SizedBox(
                  height: 52,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    scrollDirection: Axis.horizontal,
                    children: [
                      ...CategoryChip.buildRow(
                        categories: NearbyProvider.categories,
                        selected: provider.selectedCategory,
                        onChanged: provider.onCategoryChanged,
                      ).map(
                        (chip) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: chip,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: Consumer<NearbyProvider>(
                builder: (context, provider, _) {
                  if (userPos == null) {
                    return const _NearbyMessage(
                      icon: '🛰️',
                      title: 'Locating you…',
                      message: 'Waiting for a GPS fix to find nearby places.',
                    );
                  }

                  if (provider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    );
                  }

                  if (provider.nearby.isEmpty) {
                    return const _NearbyMessage(
                      icon: '📍',
                      title: 'No places found',
                      message: 'Try a different category to see more places.',
                    );
                  }

                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () =>
                        provider.load(userPos.latitude, userPos.longitude),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: provider.nearby.length,
                      itemBuilder: (context, i) {
                        final landmark = provider.nearby[i];
                        return LandmarkCard(
                          key: ValueKey('nearby-${landmark.id}'),
                          landmark: landmark,
                          userLat: userPos.latitude,
                          userLng: userPos.longitude,
                          onSaveToggled: () => savedProvider.load(),
                          onNavigate: () {
                            mapProvider.selectLandmark(landmark);
                            context.pop();
                          },
                          onTap: () {
                            mapProvider.selectLandmark(landmark);
                            context.pop();
                          },
                        );
                      },
                    ),
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

class _NearbyMessage extends StatelessWidget {
  const _NearbyMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final String icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(title, style: AppTextStyles.headlineMedium),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
