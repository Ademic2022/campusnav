import 'package:flutter/material.dart';
import '../../core/models/landmark.dart';
import '../../core/services/landmark_service.dart';
import '../../core/utils/geo.dart';

class NearbyProvider extends ChangeNotifier {
  static const double _reloadThresholdMetres = 50.0;

  String _selectedCategory = 'all';
  List<Landmark> _nearby = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  double? _userLat;
  double? _userLng;

  String get selectedCategory => _selectedCategory;
  List<Landmark> get nearby => _nearby;
  bool get isLoading => _isLoading;

  /// True once a load has completed, so the UI can tell "no results" apart
  /// from "never received a position".
  bool get hasLoaded => _hasLoaded;

  double? get userLat => _userLat;
  double? get userLng => _userLng;

  static const List<String> categories = [
    'all',
    'food',
    'banks',
    'hostel',
    'health',
    'lecture',
    'faculty',
    'sports',
  ];

  /// Loads results for [userLat]/[userLng] unless the position has barely
  /// moved since the last load, so GPS jitter does not refetch repeatedly.
  Future<void> ensureLoaded(double userLat, double userLng) async {
    if (!needsReloadFor(userLat, userLng)) return;
    await load(userLat, userLng);
  }

  /// True when [userLat]/[userLng] is far enough from the last loaded position
  /// to justify refetching. Safe to call from `build`.
  bool needsReloadFor(double userLat, double userLng) =>
      !_isSamePlace(userLat, userLng);

  bool _isSamePlace(double userLat, double userLng) {
    if (!_hasLoaded || _userLat == null || _userLng == null) return false;
    final moved = haversineMetres(
      lat1: _userLat!,
      lng1: _userLng!,
      lat2: userLat,
      lng2: userLng,
    );
    return moved < _reloadThresholdMetres;
  }

  Future<void> load(double userLat, double userLng) async {
    _userLat = userLat;
    _userLng = userLng;
    await _fetchNearby();
  }

  Future<void> onCategoryChanged(String category) async {
    _selectedCategory = category;
    await _fetchNearby();
  }

  Future<void> _fetchNearby() async {
    if (_userLat == null || _userLng == null) return;
    _isLoading = true;
    notifyListeners();

    _nearby = await LandmarkService.instance.getNearby(
      userLat: _userLat!,
      userLng: _userLng!,
      category: _selectedCategory,
      limit: 25,
    );
    _hasLoaded = true;

    _isLoading = false;
    notifyListeners();
  }
}
