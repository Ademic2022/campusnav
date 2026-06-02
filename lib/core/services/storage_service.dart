import 'package:hive_ce_flutter/hive_flutter.dart';
import '../models/landmark.dart';
import '../models/saved_location.dart';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  static const String _boxName = 'saved_locations';
  static const String _settingsBoxName = 'app_settings';
  late Box<SavedLocation> _box;
  late Box _settingsBox;

  Future<void> init() async {
    _box = await Hive.openBox<SavedLocation>(_boxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
  }

  bool get hasSeenOnboarding =>
      _settingsBox.get('onboarding_seen', defaultValue: false) as bool;

  Future<void> markOnboardingSeen() =>
      _settingsBox.put('onboarding_seen', true);

  List<SavedLocation> getAll() {
    return _box.values.toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  }

  bool isSaved(int landmarkId) {
    return _box.values.any((s) => s.landmarkId == landmarkId);
  }

  Future<void> save(Landmark landmark) async {
    if (isSaved(landmark.id)) return;
    await _box.add(SavedLocation(
      landmarkId: landmark.id,
      name: landmark.name,
      category: landmark.category,
      lat: landmark.lat,
      lng: landmark.lng,
      description: landmark.description,
      savedAt: DateTime.now(),
    ));
  }

  Future<void> remove(int landmarkId) async {
    final key = _box.keys.firstWhere(
      (k) => _box.get(k)?.landmarkId == landmarkId,
      orElse: () => null,
    );
    if (key != null) await _box.delete(key);
  }

  Future<void> toggle(Landmark landmark) async {
    if (isSaved(landmark.id)) {
      await remove(landmark.id);
    } else {
      await save(landmark);
    }
  }
}
