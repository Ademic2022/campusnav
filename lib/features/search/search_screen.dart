import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/landmark_card.dart';
import '../map/map_provider.dart';
import '../saved/saved_provider.dart';
import 'search_provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      // Load all landmarks on open
      context.read<SearchProvider>().onQueryChanged('');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mapProvider = context.read<MapProvider>();
    final savedProvider = context.read<SavedProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header: Back + Search field ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Consumer<SearchProvider>(
                      builder: (context, provider, _) {
                        return Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            style: AppTextStyles.bodyLarge,
                            decoration: InputDecoration(
                              hintText: 'Search locations, halls, banks...',
                              hintStyle: AppTextStyles.bodyMedium,
                              prefixIcon: const Icon(Icons.search_rounded,
                                  color: AppColors.textSecondary, size: 20),
                              suffixIcon: _controller.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded,
                                          color: AppColors.textSecondary,
                                          size: 18),
                                      onPressed: () {
                                        _controller.clear();
                                        provider.onQueryChanged('');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onChanged: (v) => provider.onQueryChanged(v),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // ── Category filter chips ──
            Consumer<SearchProvider>(
              builder: (context, provider, _) {
                return SizedBox(
                  height: 52,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                    scrollDirection: Axis.horizontal,
                    children: [
                      ...CategoryChip.buildRow(
                        categories: SearchProvider.categories,
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

            // ── Divider ──
            const Divider(height: 1, color: AppColors.divider),

            // ── Results list ──
            Expanded(
              child: Consumer<SearchProvider>(
                builder: (context, provider, _) {
                  if (provider.isSearching) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2),
                    );
                  }

                  if (provider.results.isEmpty) {
                    return _EmptyState(query: provider.query);
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: provider.results.length,
                    itemBuilder: (context, i) {
                      final landmark = provider.results[i];
                      final userPos = mapProvider.userPosition;
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

class _EmptyState extends StatelessWidget {
  final String query;
  const _EmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              query.isEmpty
                  ? 'Start typing to search OAU campus'
                  : 'No results for "$query"',
              style: AppTextStyles.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              query.isEmpty
                  ? 'Search hostels, faculties, banks, cafeterias and more'
                  : 'Try a different keyword or category',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
