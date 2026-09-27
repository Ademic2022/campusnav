import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'core/models/saved_location.dart';
import 'core/services/campus_boundary_service.dart';
import 'core/services/storage_service.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // A missing .env is a setup problem, not a crash: report it clearly below.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // handled by the empty-token check
  }

  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set dark status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF111827),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final mapboxToken =
      dotenv.env['MAPBOX_PUBLIC_TOKEN'] ?? dotenv.env['MAPBOX_TOKEN'] ?? '';

  if (mapboxToken.isEmpty) {
    runApp(const _SetupRequiredApp());
    return;
  }

  // Initialise Hive CE
  await Hive.initFlutter();
  Hive.registerAdapter(SavedLocationAdapter());
  await StorageService.instance.init();

  // Set Mapbox access token
  MapboxOptions.setAccessToken(mapboxToken);

  // Load the campus fence before the first frame so the map can draw it and
  // the geofence can classify the opening GPS fix. Failing to load is
  // non-fatal: the app falls back to "cannot tell" and keeps working.
  await CampusBoundary.instance.load();

  final showOnboarding = !StorageService.instance.hasSeenOnboarding;

  runApp(OauNavigatorApp(
    mapboxToken: mapboxToken,
    showOnboarding: showOnboarding,
  ));
}

/// Shown when no Mapbox token is configured, instead of crashing on startup.
class _SetupRequiredApp extends StatelessWidget {
  const _SetupRequiredApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFF0B1120),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_outlined,
                    size: 56, color: Color(0xFF38BDF8)),
                SizedBox(height: 20),
                Text(
                  'Setup required',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  'No Mapbox token found.\n\n'
                  '1. Copy .env.example to .env\n'
                  '2. Set MAPBOX_PUBLIC_TOKEN=pk.…\n'
                  '3. Restart the app',
                  style: TextStyle(
                      color: Color(0xFF94A3B8), fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
