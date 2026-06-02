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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pos = context.read<MapProvider>().userPosition;
      if (pos != null) {
        context.read<NearbyProvider>().load(pos.latitude, pos.longitude);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = context.read<MapProvider>();
    final savedProvider = context.read<SavedProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
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
                      Text('OAU Campus', style: AppTextStyles.bodySmall),
                    ],
                  ),
                ],
              ),
            ),

            // ── Category filter chips ──
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
                      ).map((chip) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: chip,
                          )),
                    ],
                  ),
                );
              },
            ),

            const Divider(height: 1, color: AppColors.divider),

            // ── Results ──
            Expanded(
              child: Consumer<NearbyProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2),
                    );
                  }

                  if (provider.nearby.isEmpty) {
                    return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('📍', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 16),
                          Text('No places found', style: AppTextStyles.headlineMedium),
                          const SizedBox(height: 8),
                          Text(
                            'GPS location needed for nearby results',
                            style: AppTextStyles.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                  }

                  final userPos = mapProvider.userPosition;
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: provider.nearby.length,
                    itemBuilder: (context, i) {
                      final landmark = provider.nearby[i];
                      return LandmarkCard(
                        landmark: landmark,
                        userLat: userPos?.latitude,
                        userLng: userPos?.longitude,
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
