import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/models/landmark.dart';
import '../../core/services/landmark_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/routing_service.dart';
import '../../core/constants/oau_bounds.dart';

class MapProvider extends ChangeNotifier {
  // Mapbox token — set before using routing
  String mapboxToken = '';

  // User's current GPS position
  Position? userPosition;

  // Selected landmark (tapped from search / map)
  Landmark? selectedLandmark;
  bool isLandmarkSheetVisible = false;

  // Active route
  RouteResult? activeRoute;
  Landmark? routeDestination;
  RouteProfile routeProfile = RouteProfile.walking;
  bool isLoadingRoute = false;
  String? routeError;

  // Bottom nav index
  int navIndex = 0;

  // Use campus main gate as start point
  bool useCampusAsStart = false;

  bool _isLocating = false;
  bool get isLocating => _isLocating;
  double? _mainGateLatFromData;
  double? _mainGateLngFromData;

  bool get canRouteFromCurrentStart => useCampusAsStart || userPosition != null;

  double get routeStartLat => useCampusAsStart
      ? (_mainGateLatFromData ?? OauBounds.fallbackLat)
      : (userPosition?.latitude ?? OauBounds.fallbackLat);
  double get routeStartLng => useCampusAsStart
      ? (_mainGateLngFromData ?? OauBounds.fallbackLng)
      : (userPosition?.longitude ?? OauBounds.fallbackLng);

  Future<void> initLocation() async {
    _isLocating = true;
    notifyListeners();
    await _loadMainGateFromLandmarks();
    userPosition = await LocationService.instance.getCurrentPosition();
    _isLocating = false;
    notifyListeners();

    // Listen to continuous updates
    LocationService.instance.getPositionStream().listen((pos) {
      userPosition = pos;
      notifyListeners();
    });
  }

  Future<void> _loadMainGateFromLandmarks() async {
    if (_mainGateLatFromData != null && _mainGateLngFromData != null) return;
    try {
      final all = await LandmarkService.instance.getAll();
      final gate = all.firstWhere(
        (l) => l.id == 1,
        orElse: () => all.firstWhere(
          (l) => l.name.toLowerCase() == 'main gate',
          orElse: () => all.first,
        ),
      );
      _mainGateLatFromData = gate.lat;
      _mainGateLngFromData = gate.lng;
    } catch (_) {
      // Keep fallback center if landmarks fail to load.
    }
  }

  void selectLandmark(Landmark landmark) {
    selectedLandmark = landmark;
    isLandmarkSheetVisible = true;
    activeRoute = null;
    routeDestination = null;
    routeError = null;
    notifyListeners();
  }

  void hideLandmarkSheet() {
    if (selectedLandmark == null) return;
    if (!isLandmarkSheetVisible) return;
    isLandmarkSheetVisible = false;
    notifyListeners();
  }

  void showLandmarkSheet() {
    if (selectedLandmark == null) return;
    if (isLandmarkSheetVisible) return;
    isLandmarkSheetVisible = true;
    notifyListeners();
  }

  void clearSelectedLandmark() {
    selectedLandmark = null;
    isLandmarkSheetVisible = false;
    routeError = null;
    notifyListeners();
  }

  Future<void> fetchRoute() async {
    if (selectedLandmark == null) return;
    if (useCampusAsStart) {
      await _loadMainGateFromLandmarks();
    }
    if (!canRouteFromCurrentStart) {
      routeError = 'Enable location or use campus as start';
      notifyListeners();
      return;
    }
    if (mapboxToken.isEmpty) {
      routeError = 'Mapbox token not set';
      notifyListeners();
      return;
    }

    isLoadingRoute = true;
    routeError = null;
    notifyListeners();

    try {
      final result = await RoutingService.instance.getRoute(
        fromLat: routeStartLat,
        fromLng: routeStartLng,
        toLat: selectedLandmark!.lat,
        toLng: selectedLandmark!.lng,
        accessToken: mapboxToken,
        profile: routeProfile,
      );

      activeRoute = result;
      routeDestination = selectedLandmark;
    } on RoutingException catch (e) {
      routeError = e.message;
    }

    isLoadingRoute = false;
    notifyListeners();
  }

  void setRouteProfile(RouteProfile profile) {
    if (routeProfile == profile) return;
    routeProfile = profile;
    notifyListeners();
    if (selectedLandmark != null && canRouteFromCurrentStart) {
      fetchRoute();
    }
  }

  void clearRoute() {
    activeRoute = null;
    routeDestination = null;
    routeError = null;
    notifyListeners();
  }

  void setNavIndex(int index) {
    navIndex = index;
    notifyListeners();
  }

  void setUseCampusAsStart(bool value) {
    if (useCampusAsStart == value) return;
    useCampusAsStart = value;
    notifyListeners();
    if (!useCampusAsStart) {
      if (selectedLandmark != null && canRouteFromCurrentStart) {
        fetchRoute();
      }
      return;
    }
    _loadMainGateFromLandmarks().then((_) {
      notifyListeners();
      if (selectedLandmark != null && canRouteFromCurrentStart) {
        fetchRoute();
      }
    });
  }
}
