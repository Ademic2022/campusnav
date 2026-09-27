import '../constants/travel_pace.dart';
import '../utils/geo.dart';

class Landmark {
  final int id;
  final String name;
  final String category;
  final double lat;
  final double lng;
  final String description;
  final String icon;

  const Landmark({
    required this.id,
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
    required this.description,
    required this.icon,
  });

  factory Landmark.fromJson(Map<String, dynamic> json) {
    return Landmark(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      category: json['category'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      description: json['description'] as String,
      icon: json['icon'] as String? ?? json['category'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'lat': lat,
        'lng': lng,
        'description': description,
        'icon': icon,
      };

  /// Haversine distance in metres from this landmark to [otherLat],[otherLng]
  double distanceTo(double otherLat, double otherLng) {
    return haversineMetres(
      lat1: lat,
      lng1: lng,
      lat2: otherLat,
      lng2: otherLng,
    );
  }

  /// Friendly distance string
  String friendlyDistance(double userLat, double userLng) {
    final d = distanceTo(userLat, userLng);
    if (d < 1000) return '${d.round()}m away';
    return '${(d / 1000).toStringAsFixed(1)}km away';
  }

  /// Estimated walking time in minutes.
  int walkingMinutes(double userLat, double userLng) {
    return TravelPace.minutesFor(
      distanceTo(userLat, userLng),
      isDriving: false,
    );
  }

  /// Human-readable category label
  String get categoryLabel {
    switch (category) {
      case 'hostel':
        return 'Hostel';
      case 'faculty':
        return 'Faculty';
      case 'admin':
        return 'Admin';
      case 'food':
        return 'Food';
      case 'banks':
        return 'Bank';
      case 'health':
        return 'Health';
      case 'gate':
        return 'Gate';
      case 'sports':
        return 'Sports';
      case 'lecture':
        return 'Lecture Hall';
      case 'department':
        return 'Department';
      default:
        if (category.isEmpty) return 'Place';
        return category[0].toUpperCase() + category.substring(1);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Landmark && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Landmark($id, $name, $category)';
}
