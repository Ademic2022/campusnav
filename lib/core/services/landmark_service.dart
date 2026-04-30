import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/landmark.dart';

class LandmarkService {
  LandmarkService._();
  static final LandmarkService instance = LandmarkService._();

  List<Landmark>? _cache;

  /// Load all landmarks from bundled JSON asset (cached after first load)
  Future<List<Landmark>> getAll() async {
    if (_cache != null) return _cache!;
    final jsonStr = await rootBundle.loadString('assets/data/landmarks.json');
    final jsonList = jsonDecode(jsonStr) as List<dynamic>;
    final list = jsonList
        .map((e) => Landmark.fromJson(e as Map<String, dynamic>))
        .toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    _cache = list;
    return _cache!;
  }

  /// Full-text search on name + description + category
  Future<List<Landmark>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final all = await getAll();
    final q = query.toLowerCase().trim();
    return all.where((l) {
      return l.name.toLowerCase().contains(q) ||
          l.description.toLowerCase().contains(q) ||
          l.category.toLowerCase().contains(q) ||
          l.categoryLabel.toLowerCase().contains(q);
    }).toList();
  }

  /// Filter by category (pass '' or 'all' to get everything)
  Future<List<Landmark>> getByCategory(String category) async {
    final all = await getAll();
    if (category.isEmpty || category == 'all') return all;
    return all.where((l) => l.category == category).toList();
  }

  /// Get nearby landmarks, sorted by distance from [userLat],[userLng]
  Future<List<Landmark>> getNearby({
    required double userLat,
    required double userLng,
    String category = 'all',
    int limit = 20,
  }) async {
    final landmarks = await getByCategory(category);
    final sorted = List<Landmark>.from(landmarks)
      ..sort((a, b) => a
          .distanceTo(userLat, userLng)
          .compareTo(b.distanceTo(userLat, userLng)));
    return sorted.take(limit).toList();
  }
}
