import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'core/models/saved_location.dart';
import 'core/services/storage_service.dart';
import 'app.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await dotenv.load(fileName: '.env');

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

  final mapboxToken =
      dotenv.env['MAPBOX_PUBLIC_TOKEN'] ?? dotenv.env['MAPBOX_TOKEN'] ?? '';

  // Set Mapbox access token
  MapboxOptions.setAccessToken(mapboxToken);

  await Future.delayed(const Duration(milliseconds: 2500));
  FlutterNativeSplash.remove();

  runApp(OauNavigatorApp(mapboxToken: mapboxToken));
}
