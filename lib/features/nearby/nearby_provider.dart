import 'package:flutter/material.dart';
import '../../core/models/landmark.dart';
import '../../core/services/landmark_service.dart';

class NearbyProvider extends ChangeNotifier {
  String _selectedCategory = 'all';
  List<Landmark> _nearby = [];
  bool _isLoading = false;
  double? _userLat;
  double? _userLng;

  String get selectedCategory => _selectedCategory;
  List<Landmark> get nearby => _nearby;
  bool get isLoading => _isLoading;

  static const List<String> categories = [
    'all',
    'food',
    'atm',
    'hostel',
    'health',
    'lecture',
    'faculty',
    'sports',
  ];

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

    _isLoading = false;
    notifyListeners();
  }
}
