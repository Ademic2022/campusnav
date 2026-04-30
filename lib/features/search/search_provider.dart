import 'package:flutter/material.dart';
import '../../core/models/landmark.dart';
import '../../core/services/landmark_service.dart';

class SearchProvider extends ChangeNotifier {
  String _query = '';
  String _selectedCategory = 'all';
  List<Landmark> _results = [];
  bool _isSearching = false;

  String get query => _query;
  String get selectedCategory => _selectedCategory;
  List<Landmark> get results => _results;
  bool get isSearching => _isSearching;

  static const List<String> categories = [
    'all',
    'hostel',
    'faculty',
    'department',
    'lecture',
    'admin',
    'food',
    'banks',
    'health',
    'gate',
    'sports',
  ];

  Future<void> onQueryChanged(String query) async {
    _query = query;
    await _runSearch();
  }

  Future<void> onCategoryChanged(String category) async {
    _selectedCategory = category;
    await _runSearch();
  }

  Future<void> _runSearch() async {
    _isSearching = true;
    notifyListeners();

    List<Landmark> results;
    if (_query.trim().isEmpty) {
      results = await LandmarkService.instance.getByCategory(_selectedCategory);
    } else {
      final searched = await LandmarkService.instance.search(_query);
      if (_selectedCategory == 'all') {
        results = searched;
      } else {
        results = searched.where((l) => l.category == _selectedCategory).toList();
      }
    }

    _results = results;
    _isSearching = false;
    notifyListeners();
  }

  void reset() {
    _query = '';
    _selectedCategory = 'all';
    _results = [];
    _isSearching = false;
    notifyListeners();
  }
}
