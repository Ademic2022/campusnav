import 'package:flutter/material.dart';
import '../../core/models/saved_location.dart';
import '../../core/models/landmark.dart';
import '../../core/services/storage_service.dart';

class SavedProvider extends ChangeNotifier {
  List<SavedLocation> _saved = [];

  List<SavedLocation> get saved => _saved;
  bool get isEmpty => _saved.isEmpty;

  void load() {
    _saved = StorageService.instance.getAll();
    notifyListeners();
  }

  bool isSaved(int landmarkId) => StorageService.instance.isSaved(landmarkId);

  Future<void> toggle(Landmark landmark) async {
    await StorageService.instance.toggle(landmark);
    load();
  }

  Future<void> remove(int landmarkId) async {
    await StorageService.instance.remove(landmarkId);
    load();
  }
}
