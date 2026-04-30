import 'dart:math';

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
    const earthRadius = 6371000.0; // metres
    final dLat = _toRad(otherLat - lat);
    final dLng = _toRad(otherLng - lng);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat)) *
            cos(_toRad(otherLat)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRad(double deg) => deg * pi / 180;

  /// Friendly distance string
  String friendlyDistance(double userLat, double userLng) {
    final d = distanceTo(userLat, userLng);
    if (d < 1000) return '${d.round()}m away';
    return '${(d / 1000).toStringAsFixed(1)}km away';
  }

  /// Estimated walking time in minutes (avg 80m/min)
  int walkingMinutes(double userLat, double userLng) {
    final d = distanceTo(userLat, userLng);
    return max(1, (d / 80).round());
  }

  /// Human-readable category label
  String get categoryLabel {
    switch (category) {
      case 'hostel': return 'Hostel';
      case 'faculty': return 'Faculty';
      case 'admin': return 'Admin';
      case 'food': return 'Food';
      case 'banks': return 'Bank';
      case 'health': return 'Health';
      case 'gate': return 'Gate';
      case 'sports': return 'Sports';
      case 'lecture': return 'Lecture Hall';
      case 'department': return 'Department';
      default: return category[0].toUpperCase() + category.substring(1);
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
