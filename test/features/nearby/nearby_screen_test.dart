import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:oau_navigator/core/models/landmark.dart';
import 'package:oau_navigator/core/models/saved_location.dart';
import 'package:oau_navigator/core/services/storage_service.dart';
import 'package:oau_navigator/features/map/map_provider.dart';
import 'package:oau_navigator/features/nearby/nearby_provider.dart';
import 'package:oau_navigator/features/nearby/nearby_screen.dart';
import 'package:oau_navigator/features/saved/saved_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = await Directory.systemTemp.createTemp('oau_navigator_test');
    Hive.init(hiveDir.path);
    Hive.registerAdapter(SavedLocationAdapter());
  });

  setUp(() async {
    await Hive.deleteBoxFromDisk('saved_locations');
    await Hive.deleteBoxFromDisk('app_settings');
    await StorageService.instance.init();
  });

  tearDownAll(() async {
    await hiveDir.delete(recursive: true);
  });

  Position position(double lat, double lng) => Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime(2026, 1, 1),
        accuracy: 5,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

  Widget harness({Position? userPosition}) {
    final map = MapProvider()..userPosition = userPosition;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<MapProvider>.value(value: map),
        ChangeNotifierProvider(create: (_) => NearbyProvider()),
        ChangeNotifierProvider(create: (_) => SavedProvider()),
      ],
      child: const MaterialApp(
        home: NearbyScreen(),
      ),
    );
  }

  testWidgets('shows a locating state instead of a false empty state',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.text('Locating you…'), findsOneWidget);
    expect(find.text('No places found'), findsNothing);
  });

  testWidgets('loads results once a position arrives, without a build error',
      (tester) async {
    final map = MapProvider()..userPosition = null;
    final nearby = NearbyProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MapProvider>.value(value: map),
          ChangeNotifierProvider<NearbyProvider>.value(value: nearby),
          ChangeNotifierProvider(create: (_) => SavedProvider()),
        ],
        child: const MaterialApp(home: NearbyScreen()),
      ),
    );
    await tester.pump();

    // Position arrives after the first frame, as it does on a cold GPS start.
    map.userPosition = position(7.4976, 4.5225);
    map.notifyListeners();
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(nearby.hasLoaded, isTrue);
    expect(nearby.nearby, isNotEmpty);
    expect(find.text('Locating you…'), findsNothing);
  });

  testWidgets('does not refetch for sub-50 m GPS jitter', (tester) async {
    final map = MapProvider()..userPosition = position(7.4976, 4.5225);
    final nearby = NearbyProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MapProvider>.value(value: map),
          ChangeNotifierProvider<NearbyProvider>.value(value: nearby),
          ChangeNotifierProvider(create: (_) => SavedProvider()),
        ],
        child: const MaterialApp(home: NearbyScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    final firstIds = nearby.nearby.map((Landmark l) => l.id).toList();
    expect(firstIds, isNotEmpty);

    // ~20 m north: should not trigger a reload.
    expect(nearby.needsReloadFor(7.49778, 4.5225), isFalse);

    // ~200 m north: should trigger a reload.
    expect(nearby.needsReloadFor(7.4994, 4.5225), isTrue);
  });

  testWidgets('shows the off-campus subtitle when GPS is not on campus',
      (tester) async {
    final map = MapProvider()..userPosition = position(7.4976, 4.5225);
    await tester.pumpWidget(harness(userPosition: position(7.4976, 4.5225)));
    await tester.pump();

    // MapProvider.userIsOnCampus delegates to LocationService, which is false
    // in tests, so the honest off-campus copy must be shown.
    expect(find.text('OAU Campus'), findsNothing);
    expect(
      find.text('Outside campus — showing nearest places'),
      findsOneWidget,
    );
    expect(map.userPosition, isNotNull);
  });
}
