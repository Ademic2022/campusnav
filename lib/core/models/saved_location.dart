import 'package:hive_ce/hive.dart';

part 'saved_location.g.dart';

@HiveType(typeId: 0)
class SavedLocation extends HiveObject {
  @HiveField(0)
  int landmarkId;

  @HiveField(1)
  String name;

  @HiveField(2)
  String category;

  @HiveField(3)
  double lat;

  @HiveField(4)
  double lng;

  @HiveField(5)
  String description;

  @HiveField(6)
  DateTime savedAt;

  SavedLocation({
    required this.landmarkId,
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
    required this.description,
    required this.savedAt,
  });
}
