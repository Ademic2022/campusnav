import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:oau_navigator/core/models/saved_location.dart';
import 'package:oau_navigator/core/services/landmark_service.dart';
import 'package:oau_navigator/core/services/storage_service.dart';
import 'package:oau_navigator/features/map/map_provider.dart';
import 'package:oau_navigator/features/map/widgets/search_sheet.dart';
import 'package:oau_navigator/features/saved/saved_provider.dart';
import 'package:oau_navigator/features/search/search_provider.dart';
import 'package:oau_navigator/widgets/category_chip.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;
  late SearchProvider searchProvider;
  late MapProvider mapProvider;
  late GoRouter router;
  bool searchFieldTapped = false;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('oau_nav_search_test');
    Hive.init(hiveDir.path);
    Hive.registerAdapter(SavedLocationAdapter());
  });

  setUp(() async {
    await Hive.deleteBoxFromDisk('saved_locations');
    await Hive.deleteBoxFromDisk('app_settings');
    await StorageService.instance.init();
    searchProvider = SearchProvider();
    mapProvider = MapProvider();
    searchFieldTapped = false;

    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: Stack(
              children: [
                // Mirrors map_screen.dart: the sheet is a positioned overlay.
                Positioned.fill(
                  child: SearchSheet(
                    onSearchTap: () => searchFieldTapped = true,
                  ),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/search',
          builder: (_, __) => const Scaffold(body: Text('search screen')),
        ),
      ],
    );
  });

  tearDown(() {
    mapProvider.dispose();
    router.dispose();
  });

  tearDownAll(() async {
    await hiveDir.delete(recursive: true);
  });

  Future<void> pumpSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: mapProvider),
          ChangeNotifierProvider.value(value: searchProvider),
          ChangeNotifierProvider(create: (_) => SavedProvider()..load()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The category row lives below the sheet's ~90px peek, and the sheet is
  /// bottom-anchored, so the drag has to start inside the visible strip.
  Future<void> openCategoryRow(WidgetTester tester) async {
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    await tester.dragFrom(
      Offset(size.width / 2, size.height - 40),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
  }

  /// Taps the first chip, which is always in view without horizontal scroll.
  Future<void> tapCategory(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(CategoryChip, label));
    await tester.pumpAndSettle();
  }

  Future<void> goBack(WidgetTester tester) async {
    router.pop();
    await tester.pumpAndSettle();
  }

  /// Popping rebuilds the sheet at its peek size, so the category row has to be
  /// re-opened before it can be inspected again.
  Future<void> goBackAndReopen(WidgetTester tester) async {
    await goBack(tester);
    await openCategoryRow(tester);
  }

  testWidgets('tapping a category sets the map POI filter', (tester) async {
    await pumpSheet(tester);
    await openCategoryRow(tester);

    expect(mapProvider.poiCategory, 'all');

    await tapCategory(tester, 'Hostels');

    expect(mapProvider.poiCategory, 'hostel');
  });

  testWidgets('tapping a category applies it to the search provider',
      (tester) async {
    await pumpSheet(tester);
    await openCategoryRow(tester);

    await tapCategory(tester, 'Hostels');

    expect(searchProvider.selectedCategory, 'hostel');
  });

  testWidgets('tapping a category shows the matching places', (tester) async {
    await pumpSheet(tester);
    await openCategoryRow(tester);

    // The sheet renders no result list of its own, so a tap that stays here
    // changes state that nothing renders -- the reported "nothing happens".
    await tapCategory(tester, 'Hostels');

    expect(find.text('search screen'), findsOneWidget);
  });

  testWidgets('the summary label reflects the active filter', (tester) async {
    await pumpSheet(tester);
    await openCategoryRow(tester);

    expect(find.text('All pins'), findsOneWidget);

    await tapCategory(tester, 'Hostels');
    await goBackAndReopen(tester);

    expect(find.text('Hostels pins'), findsOneWidget);
  });

  testWidgets('the chosen chip is rendered as selected', (tester) async {
    await pumpSheet(tester);
    await openCategoryRow(tester);

    await tapCategory(tester, 'Hostels');
    await goBackAndReopen(tester);

    final chip = tester.widget<CategoryChip>(
      find.widgetWithText(CategoryChip, 'Hostels'),
    );
    expect(chip.isSelected, isTrue);
  });

  testWidgets('a filtered category yields real landmarks to show',
      (tester) async {
    await pumpSheet(tester);
    await openCategoryRow(tester);

    await tapCategory(tester, 'Hostels');

    final expected = await LandmarkService.instance.getByCategory('hostel');
    expect(expected, isNotEmpty);
    expect(searchProvider.results.map((l) => l.id),
        containsAll(expected.map((l) => l.id)));
  });

  testWidgets('tapping the search field navigates without filtering',
      (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.text('Search OAU campus...'));
    await tester.pumpAndSettle();

    expect(searchFieldTapped, isTrue);
    expect(mapProvider.poiCategory, 'all',
        reason: 'the search field is navigation, not a filter');
  });

  testWidgets('tapping a category leaves pin visibility alone', (tester) async {
    await pumpSheet(tester);
    await openCategoryRow(tester);

    await tapCategory(tester, 'Hostels');

    expect(mapProvider.poiVisible, isTrue);
  });

  testWidgets('the hidden-pins state is reported in the summary',
      (tester) async {
    await pumpSheet(tester);
    await openCategoryRow(tester);

    mapProvider.togglePoiVisibility();
    await tester.pumpAndSettle();

    expect(find.text('Map pins hidden'), findsOneWidget);
  });
}
