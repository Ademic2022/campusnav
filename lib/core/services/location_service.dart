import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../constants/oau_bounds.dart';
import '../services/campus_boundary_service.dart';
import '../services/landmark_service.dart';

/// A geofence crossing.
enum CampusTransition {
  /// Device moved from outside the fence to inside it.
  entered,

  /// Device moved from inside the fence to outside it.
  exited,
}

/// A geofence crossing with the position that triggered it.
class CampusTransitionEvent {
  const CampusTransitionEvent({
    required this.transition,
    required this.position,
    required this.distanceToFenceMetres,
  });

  final CampusTransition transition;

  /// The fix that crossed the fence.
  final Position position;

  /// Signed metres to the fence edge at that fix: positive just after exiting,
  /// negative just after entering.
  final double distanceToFenceMetres;
}

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// How far outside the fence the device must get before an exit is declared.
  ///
  /// Without this, a user standing on the boundary flaps in and out on every
  /// GPS jitter, which spams the banner and the transition stream.
  static const double exitBufferMetres = 60.0;

  /// How far inside the fence the device must get before an entry is declared.
  ///
  /// Smaller than [exitBufferMetres] on purpose: the band between the two is
  /// the dead zone that makes the state stable.
  static const double enterBufferMetres = 20.0;

  Position? _lastPosition;
  StreamController<Position>? _controller;
  StreamSubscription<Position>? _positionSubscription;
  StreamController<CampusTransitionEvent>? _transitionController;
  bool _userOnCampus = false;

  /// Whether the fence has been armed yet. False until the first fix is
  /// classified, so "not yet known" is never reported as "off campus".
  bool _hasFenceState = false;

  Position? get lastPosition => _lastPosition;

  /// True only when the device's real GPS fix is inside the campus fence.
  /// False when the user is off-campus or location is unavailable.
  bool get userOnCampus => _userOnCampus;

  /// Geofence crossings. Broadcast, so late subscribers still get the next one.
  Stream<CampusTransitionEvent> get transitions =>
      (_transitionController ??= StreamController.broadcast()).stream;

  /// Request permission and return current position.
  /// Falls back to Main Gate from landmark data if unavailable.
  Future<Position> getCurrentPosition() async {
    final permission = await _ensurePermission();
    if (!permission) return _mainGateReferencePosition();

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!isOnCampus(pos)) {
        _userOnCampus = false;
        final fallback = await _mainGateReferencePosition();
        _lastPosition = fallback;
        return fallback;
      }
      _classify(pos);
      _lastPosition = pos;
      return pos;
    } catch (_) {
      return _lastPosition ?? await _mainGateReferencePosition();
    }
  }

  /// Continuous stream of location updates, annotated with the fence state.
  ///
  /// Replaces any previously returned stream, cancelling the underlying
  /// platform subscription so repeated calls cannot leak listeners.
  Stream<Position> getPositionStream() {
    _positionSubscription?.cancel();
    _controller?.close();
    final controller = StreamController<Position>.broadcast();
    _controller = controller;

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // metres
      ),
    ).listen(
      (pos) {
        // Classify first: a fix outside the fence still has to be able to
        // trigger an "exited" event, so it cannot be dropped before this.
        final onCampus = _classify(pos);
        _lastPosition = pos;
        if (!onCampus) {
          // Historically the stream only carried on-campus fixes. Keep that
          // contract so callers are not handed a position they treat as
          // on campus; crossings arrive via `transitions` instead.
          return;
        }
        if (!controller.isClosed) controller.add(pos);
      },
      onError: (Object error) {
        debugPrint('Position stream error: $error');
      },
    );

    return controller.stream;
  }

  /// Whether [pos] is inside the campus fence.
  ///
  /// Delegates to [CampusBoundary], which is the same polygon the map draws.
  /// Returns false when the fence has not loaded, so a missing asset can never
  /// read as a confirmed "on campus".
  bool isOnCampus(Position pos) {
    final boundary = CampusBoundary.instance;
    if (!boundary.isLoaded) {
      // Coarse pre-reject still gives a usable answer if the asset is missing.
      return OauBounds.withinRetiredBox(pos.latitude, pos.longitude) &&
          _userOnCampus;
    }
    return boundary.contains(pos.latitude, pos.longitude);
  }

  /// Classifies a fix against the fence and emits a transition on a crossing.
  ///
  /// Entry needs [enterBufferMetres] of clearance inside, exit needs
  /// [exitBufferMetres] outside. The gap between them is a dead zone, so a
  /// device loitering on the boundary keeps its current state instead of
  /// flapping.
  ///
  /// Returns the (possibly unchanged) on-campus state.
  bool _classify(Position pos) {
    final boundary = CampusBoundary.instance;
    if (!boundary.isLoaded) return _userOnCampus;

    final signedMetres = boundary.signedDistanceMetres(
      pos.latitude,
      pos.longitude,
    );
    if (signedMetres == double.infinity) return _userOnCampus;

    final wasOnCampus = _userOnCampus;
    if (!_hasFenceState) {
      // First fix only establishes the baseline, so launching the app outside
      // campus does not fire a spurious "exited" event.
      _userOnCampus = signedMetres <= 0;
      _hasFenceState = true;
      return _userOnCampus;
    }

    if (wasOnCampus) {
      if (signedMetres > exitBufferMetres) {
        _userOnCampus = false;
      }
    } else {
      if (signedMetres <= -enterBufferMetres) {
        _userOnCampus = true;
      }
    }

    if (_userOnCampus != wasOnCampus) {
      _emit(
        CampusTransitionEvent(
          transition: _userOnCampus
              ? CampusTransition.entered
              : CampusTransition.exited,
          position: pos,
          distanceToFenceMetres: signedMetres,
        ),
      );
    }
    return _userOnCampus;
  }

  void _emit(CampusTransitionEvent event) {
    final controller = _transitionController;
    if (controller != null && !controller.isClosed) controller.add(event);
  }

  Future<bool> _ensurePermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<Position> _mainGateReferencePosition() async {
    try {
      final all = await LandmarkService.instance.getAll();
      final gate = all.firstWhere(
        (l) => l.id == 1,
        orElse: () => all.firstWhere(
          (l) => l.name.toLowerCase() == 'main gate',
          orElse: () => all.first,
        ),
      );
      return Position(
        latitude: gate.lat,
        longitude: gate.lng,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    } catch (_) {
      return _campusCentrePosition();
    }
  }

  Position _campusCentrePosition() {
    return Position(
      latitude: OauBounds.fallbackLat,
      longitude: OauBounds.fallbackLng,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  Future<void> dispose() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    await _controller?.close();
    _controller = null;
    await _transitionController?.close();
    _transitionController = null;
  }
}
