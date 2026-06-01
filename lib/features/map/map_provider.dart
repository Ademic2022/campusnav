import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
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

  // Voice guidance
  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;
  bool voiceEnabled = true;

  Future<void> _initTts() async {
    if (_ttsReady) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _ttsReady = true;
  }

  void _speak(String text) async {
    if (!voiceEnabled || text.isEmpty) return;
    await _initTts();
    await _tts.stop();
    await _tts.speak(text);
  }

  void toggleVoice() {
    voiceEnabled = !voiceEnabled;
    if (!voiceEnabled) _tts.stop();
    HapticFeedback.selectionClick();
    notifyListeners();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

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
    HapticFeedback.mediumImpact();
    _speak(currentStep?.instruction ?? '');
    notifyListeners();
  }

  void endNavigation() {
    isNavigating = false;
    _currentStepIndex = 0;
    _tts.stop();
    notifyListeners();
  }

  void nextStep() {
    if (!hasNextStep) return;
    _currentStepIndex++;
    _speak(currentStep?.instruction ?? '');
    notifyListeners();
  }

  void prevStep() {
    if (!hasPrevStep) return;
    _currentStepIndex--;
    _speak(currentStep?.instruction ?? '');
    notifyListeners();
  }

  void _checkStepAdvance(Position pos) {
    if (!isNavigating) return;
    final step = currentStep;
    if (step == null || step.maneuverLocation[0] == 0.0) return;
    final dist = const Distance().as(
      LengthUnit.Meter,
      LatLng(pos.latitude, pos.longitude),
      LatLng(step.maneuverLocation[1], step.maneuverLocation[0]),
    );
    if (dist < 20) {
      HapticFeedback.mediumImpact();
      if (hasNextStep) {
        _currentStepIndex++;
        _speak(currentStep?.instruction ?? '');
      } else {
        isNavigating = false;
        _currentStepIndex = 0;
        _speak('You have arrived at your destination.');
      }
    }
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
    if (isNavigating) endNavigation();
    notifyListeners();
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
