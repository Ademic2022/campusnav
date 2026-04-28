import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../constants/oau_bounds.dart';
import '../services/landmark_service.dart';

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  Position? _lastPosition;
  StreamController<Position>? _controller;

  Position? get lastPosition => _lastPosition;

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
      // Ignore simulator/device locations that are far from OAU.
      if (!isOnCampus(pos)) {
        final fallback = await _mainGateReferencePosition();
        _lastPosition = fallback;
        return fallback;
      }
      _lastPosition = pos;
      return pos;
    } catch (_) {
      return _lastPosition ?? await _mainGateReferencePosition();
    }
  }

  /// Continuous stream of location updates (geofenced to campus).
  Stream<Position> getPositionStream() {
    _controller?.close();
    _controller = StreamController<Position>.broadcast();

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // metres
      ),
    ).listen(
      (pos) {
        if (!isOnCampus(pos)) return;
        _lastPosition = pos;
        _controller?.add(pos);
      },
      onError: (_) {
        // silently ignore stream errors
      },
    );

    return _controller!.stream;
  }

  /// Returns true if [pos] is within OAU campus bounding box
  bool isOnCampus(Position pos) {
    return OauBounds.isOnCampus(pos.latitude, pos.longitude);
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

  void dispose() {
    _controller?.close();
    _controller = null;
  }
}
