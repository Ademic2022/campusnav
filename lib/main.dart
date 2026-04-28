import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'core/models/saved_location.dart';
import 'core/services/storage_service.dart';
import 'app.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// ⚠️  Replace this with your actual Mapbox public token.
/// Get one free at https://account.mapbox.com
final String _mapboxToken = dotenv.env['MAPBOX_TOKEN'] ?? '';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  // Initialise Hive CE
  await Hive.initFlutter();
  Hive.registerAdapter(SavedLocationAdapter());
  await StorageService.instance.init();

  // Set Mapbox access token
  MapboxOptions.setAccessToken(_mapboxToken);

  runApp(OauNavigatorApp(mapboxToken: _mapboxToken));
}
