import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/models/landmark.dart';
import '../../core/services/landmark_service.dart';
import '../../core/services/location_service.dart';
import '../../core/services/routing_service.dart';
import '../../core/constants/oau_bounds.dart';
import '../../core/constants/travel_pace.dart';
import '../../core/utils/geo.dart';

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

  CancelToken? _routeCancelToken;
  int _routeRequestId = 0;

  int get currentStepIndex => _currentStepIndex;
  int get totalSteps => activeRoute?.steps.length ?? 0;

  bool get _isDriving => routeProfile == RouteProfile.driving;

  /// Remaining metres to the destination from the current step onward.
  double get remainingMetres {
    final steps = activeRoute?.steps;
    if (steps == null || steps.isEmpty) return 0;
    final from = _currentStepIndex.clamp(0, steps.length);
    return steps.skip(from).fold(0.0, (sum, step) => sum + step.distanceMetres);
  }

  /// Profile-aware remaining time estimate.
  int get remainingMinutes =>
      TravelPace.minutesFor(remainingMetres, isDriving: _isDriving);

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
    final dist = haversineMetres(
      lat1: pos.latitude,
      lng1: pos.longitude,
      lat2: step.maneuverLocation[1],
      lng2: step.maneuverLocation[0],
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

    final distance = minDistanceToPolylineMetres(
      lat: pos.latitude,
      lng: pos.longitude,
      coordinates: route.coordinates,
    );
    if (distance < _offRouteThresholdMetres) return; // still on route
    _triggerReroute();
  }

  Future<void> _triggerReroute() async {
    final pos = userPosition;
    final dest = routeDestination;
    if (isRerouting || dest == null || pos == null || mapboxToken.isEmpty) {
      return;
    }

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

  // ── Map POI layer ─────────────────────────────────────────────────────────

  /// Active category filter for map POIs. 'all' means no filtering.
  String poiCategory = 'all';

  void setPoiCategory(String category) {
    if (poiCategory == category) return;
    poiCategory = category;
    notifyListeners();
  }

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
      ? (userPosition?.latitude ??
          _mainGateLatFromData ??
          OauBounds.fallbackLat)
      : (_mainGateLatFromData ?? OauBounds.fallbackLat);
  double get routeStartLng => userIsOnCampus
      ? (userPosition?.longitude ??
          _mainGateLngFromData ??
          OauBounds.fallbackLng)
      : (_mainGateLngFromData ?? OauBounds.fallbackLng);

  StreamSubscription<Position>? _positionSubscription;

  Future<void> initLocation() async {
    _isLocating = true;
    notifyListeners();
    await _loadMainGateFromLandmarks();
    userPosition = await LocationService.instance.getCurrentPosition();
    _isLocating = false;
    notifyListeners();

    await _positionSubscription?.cancel();
    _positionSubscription =
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

    // Supersede any in-flight request so the last *requested* profile wins
    // rather than whichever HTTP response happens to arrive first.
    _routeCancelToken?.cancel('superseded');
    final cancelToken = CancelToken();
    _routeCancelToken = cancelToken;
    final requestId = ++_routeRequestId;

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
        cancelToken: cancelToken,
      );
      if (requestId != _routeRequestId) return;

      activeRoute = result;
      routeDestination = selectedLandmark;
    } on RouteCancelledException {
      return;
    } on RoutingException catch (e) {
      if (requestId != _routeRequestId) return;
      routeError = e.message;
      routeIsNetworkError = e.isNetworkError;
    }

    if (requestId != _routeRequestId) return;
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
    _routeRequestId++;
    _routeCancelToken?.cancel('cleared');
    _routeCancelToken = null;
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
    final latStr =
        '${_markedLat!.abs().toStringAsFixed(5)}° ${_markedLat! >= 0 ? 'N' : 'S'}';
    final lngStr =
        '${_markedLng!.abs().toStringAsFixed(5)}° ${_markedLng! >= 0 ? 'E' : 'W'}';
    return '$latStr, $lngStr';
  }

  String markedLocationDistanceLabel(Position? userPos) {
    if (userPos == null || _markedLat == null || _markedLng == null) return '';
    final d = haversineMetres(
      lat1: userPos.latitude,
      lng1: userPos.longitude,
      lat2: _markedLat!,
      lng2: _markedLng!,
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

  @override
  void dispose() {
    _routeRequestId++;
    _routeCancelToken?.cancel('disposed');
    _routeCancelToken = null;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    super.dispose();
  }

  // Kept for any external callers; now a no-op since start is auto-detected.
  @Deprecated('Start point is now determined automatically')
  void setUseCampusAsStart(bool value) {}
}
