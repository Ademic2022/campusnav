import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/models/landmark.dart';
import '../../core/services/location_service.dart';
import '../../core/services/routing_service.dart';

class MapProvider extends ChangeNotifier {
  // Mapbox token — set before using routing
  String mapboxToken = '';

  // User's current GPS position
  Position? userPosition;

  // Selected landmark (tapped from search / map)
  Landmark? selectedLandmark;

  // Active route
  RouteResult? activeRoute;
  RouteProfile routeProfile = RouteProfile.walking;
  bool isLoadingRoute = false;
  String? routeError;

  // Bottom nav index
  int navIndex = 0;

  bool _isLocating = false;
  bool get isLocating => _isLocating;

  Future<void> initLocation() async {
    _isLocating = true;
    notifyListeners();
    userPosition = await LocationService.instance.getCurrentPosition();
    _isLocating = false;
    notifyListeners();

    // Listen to continuous updates
    LocationService.instance.getPositionStream().listen((pos) {
      userPosition = pos;
      notifyListeners();
    });
  }

  void selectLandmark(Landmark landmark) {
    selectedLandmark = landmark;
    activeRoute = null;
    routeError = null;
    notifyListeners();
  }

  void clearSelectedLandmark() {
    selectedLandmark = null;
    activeRoute = null;
    routeError = null;
    notifyListeners();
  }

  Future<void> fetchRoute() async {
    if (selectedLandmark == null || userPosition == null) return;
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
        fromLat: userPosition!.latitude,
        fromLng: userPosition!.longitude,
        toLat: selectedLandmark!.lat,
        toLng: selectedLandmark!.lng,
        accessToken: mapboxToken,
        profile: routeProfile,
      );

      activeRoute = result;
    } on RoutingException catch (e) {
      routeError = e.message;
    }

    isLoadingRoute = false;
    notifyListeners();
  }

  void setRouteProfile(RouteProfile profile) {
    routeProfile = profile;
    notifyListeners();
    fetchRoute();
  }

  void clearRoute() {
    activeRoute = null;
    routeError = null;
    notifyListeners();
  }

  void setNavIndex(int index) {
    navIndex = index;
    notifyListeners();
  }
}
