import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
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
  bool routeIsNetworkError = false;

  // Step-by-step navigation
  bool isNavigating = false;
  int _currentStepIndex = 0;

  // Rerouting
  bool isRerouting = false;
  DateTime? _lastRerouteTime;
  static const _offRouteThresholdMetres = 40.0;
  static const _rerouteCooldown = Duration(seconds: 15);

  int get currentStepIndex => _currentStepIndex;
  int get totalSteps => activeRoute?.steps.length ?? 0;

  RouteStep? get currentStep {
    final steps = activeRoute?.steps;
    if (steps == null || steps.isEmpty) return null;
    if (_currentStepIndex >= steps.length) return null;
    return steps[_currentStepIndex];
  }

  bool get hasNextStep => _currentStepIndex < totalSteps - 1;
  bool get hasPrevStep => _currentStepIndex > 0;

  void startNavigation() {
    if (activeRoute == null || activeRoute!.steps.isEmpty) return;
    _currentStepIndex = 0;
    isNavigating = true;
    // Grace period: don't reroute immediately after starting
    _lastRerouteTime = DateTime.now();
    notifyListeners();
  }

  void endNavigation() {
    isNavigating = false;
    isRerouting = false;
    _currentStepIndex = 0;
    _lastRerouteTime = null;
    notifyListeners();
  }

  void nextStep() {
    if (!hasNextStep) return;
    _currentStepIndex++;
    notifyListeners();
  }

  void prevStep() {
    if (!hasPrevStep) return;
    _currentStepIndex--;
    notifyListeners();
  }

  void _checkStepAdvance(Position pos) {
    if (!isNavigating || isRerouting) return;
    final step = currentStep;
    if (step == null || step.maneuverLocation[0] == 0.0) return;
    final dist = const Distance().as(
      LengthUnit.Meter,
      LatLng(pos.latitude, pos.longitude),
      LatLng(step.maneuverLocation[1], step.maneuverLocation[0]),
    );
    if (dist < 20) {
      if (hasNextStep) {
        _currentStepIndex++;
      } else {
        isNavigating = false;
        _currentStepIndex = 0;
      }
      notifyListeners();
    }
  }

  void _checkOffRoute(Position pos) {
    if (!isNavigating || isRerouting || isLoadingRoute) return;
    final route = activeRoute;
    if (route == null || route.coordinates.isEmpty) return;

    if (_lastRerouteTime != null &&
        DateTime.now().difference(_lastRerouteTime!) < _rerouteCooldown) {
      return;
    }

    final userLatLng = LatLng(pos.latitude, pos.longitude);
    const distCalc = Distance();
    for (final coord in route.coordinates) {
      final d = distCalc.as(LengthUnit.Meter, userLatLng, LatLng(coord[1], coord[0]));
      if (d < _offRouteThresholdMetres) return; // still on route
    }
    _triggerReroute();
  }

  Future<void> _triggerReroute() async {
    final pos = userPosition;
    final dest = routeDestination;
    if (isRerouting || dest == null || pos == null || mapboxToken.isEmpty) return;

    isRerouting = true;
    _lastRerouteTime = DateTime.now();
    notifyListeners();

    try {
      final result = await RoutingService.instance.getRoute(
        fromLat: pos.latitude,
        fromLng: pos.longitude,
        toLat: dest.lat,
        toLng: dest.lng,
        accessToken: mapboxToken,
        profile: routeProfile,
      );
      if (result != null && isNavigating) {
        activeRoute = result;
        _currentStepIndex = 0;
      }
    } on RoutingException {
      // Silently fail; user continues with the existing route
    }

    isRerouting = false;
    notifyListeners();
  }

  // Map style URI
  String mapStyle = 'mapbox://styles/mapbox/dark-v11';

  void setMapStyle(String styleUri) {
    if (mapStyle == styleUri) return;
    mapStyle = styleUri;
    notifyListeners();
  }

  // Bottom nav index
  int navIndex = 0;

  bool _isLocating = false;
  bool get isLocating => _isLocating;
  double? _mainGateLatFromData;
  double? _mainGateLngFromData;

  /// True when device GPS is confirmed within OAU bounds.
  bool get userIsOnCampus => LocationService.instance.userOnCampus;

  /// True when routing can proceed — either live GPS on-campus or gate loaded.
  bool get canRouteFromCurrentStart =>
      userIsOnCampus || _mainGateLatFromData != null;

  /// True when we're falling back to the campus main gate as the start point.
  bool get isStartingFromGate => !userIsOnCampus;

  double get routeStartLat => userIsOnCampus
      ? (userPosition?.latitude ?? _mainGateLatFromData ?? OauBounds.fallbackLat)
      : (_mainGateLatFromData ?? OauBounds.fallbackLat);
  double get routeStartLng => userIsOnCampus
      ? (userPosition?.longitude ?? _mainGateLngFromData ?? OauBounds.fallbackLng)
      : (_mainGateLngFromData ?? OauBounds.fallbackLng);

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
      _checkStepAdvance(pos);
      _checkOffRoute(pos);
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
    routeIsNetworkError = false;
    if (isNavigating) endNavigation();
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
    routeIsNetworkError = false;
    if (isNavigating) endNavigation();
    notifyListeners();
  }

  Future<void> fetchRoute() async {
    if (selectedLandmark == null) return;
    // Always ensure gate coords are loaded — needed when user is off-campus.
    await _loadMainGateFromLandmarks();
    if (!canRouteFromCurrentStart) {
      routeError = 'Location unavailable. Please enable location services.';
      routeIsNetworkError = false;
      notifyListeners();
      return;
    }
    if (mapboxToken.isEmpty) {
      routeError = 'Mapbox token not set';
      routeIsNetworkError = false;
      notifyListeners();
      return;
    }

    isLoadingRoute = true;
    routeError = null;
    routeIsNetworkError = false;
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
      routeIsNetworkError = e.isNetworkError;
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
    routeIsNetworkError = false;
    isRerouting = false;
    _lastRerouteTime = null;
    if (isNavigating) endNavigation();
    notifyListeners();
  }

  // ── Marked location (long-press pin) ──────────────────────────────────────

  double? _markedLat;
  double? _markedLng;

  double? get markedLat => _markedLat;
  double? get markedLng => _markedLng;
  bool get hasMarkedLocation => _markedLat != null && _markedLng != null;

  String get markedCoordinateLabel {
    if (_markedLat == null || _markedLng == null) return '';
    final latStr = '${_markedLat!.abs().toStringAsFixed(5)}° ${_markedLat! >= 0 ? 'N' : 'S'}';
    final lngStr = '${_markedLng!.abs().toStringAsFixed(5)}° ${_markedLng! >= 0 ? 'E' : 'W'}';
    return '$latStr, $lngStr';
  }

  String markedLocationDistanceLabel(Position? userPos) {
    if (userPos == null || _markedLat == null || _markedLng == null) return '';
    final d = const Distance().as(
      LengthUnit.Meter,
      LatLng(userPos.latitude, userPos.longitude),
      LatLng(_markedLat!, _markedLng!),
    );
    if (d < 1000) return '${d.round()} m away';
    return '${(d / 1000).toStringAsFixed(1)} km away';
  }

  void setMarkedLocation(double lat, double lng) {
    if (isNavigating) return;
    _markedLat = lat;
    _markedLng = lng;
    selectedLandmark = null;
    isLandmarkSheetVisible = false;
    activeRoute = null;
    routeDestination = null;
    routeError = null;
    routeIsNetworkError = false;
    notifyListeners();
  }

  void clearMarkedLocation() {
    _markedLat = null;
    _markedLng = null;
    notifyListeners();
  }

  /// Convert the marked location into a temporary landmark and open directions.
  void navigateToMarkedLocation() {
    if (_markedLat == null || _markedLng == null) return;
    final temp = Landmark(
      id: -1,
      name: 'Marked Location',
      category: 'other',
      lat: _markedLat!,
      lng: _markedLng!,
      description: markedCoordinateLabel,
      icon: 'other',
    );
    clearMarkedLocation();
    selectLandmark(temp);
  }

  void setNavIndex(int index) {
    navIndex = index;
    notifyListeners();
  }

  // Kept for any external callers; now a no-op since start is auto-detected.
  @Deprecated('Start point is now determined automatically')
  void setUseCampusAsStart(bool value) {
  }
}
