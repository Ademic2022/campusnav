// OAU Campus Bounding Box Constants
class OauBounds {
  OauBounds._();

  static const double centerLat = 7.5174;
  static const double centerLng = 4.5228;

  static const double swLat = 7.490;
  static const double swLng = 4.490;

  static const double neLat = 7.540;
  static const double neLng = 4.560;

  /// Approximate radius of campus from center in km
  static const double radiusKm = 4.0;

  /// Bounds check for geofencing
  static bool isOnCampus(double lat, double lng) {
    return lat >= swLat && lat <= neLat && lng >= swLng && lng <= neLng;
  }

  /// Fallback coordinates if GPS is outside campus (center of OAU)
  static const double fallbackLat = centerLat;
  static const double fallbackLng = centerLng;

  /// Mapbox camera defaults
  static const double defaultZoom = 15.5;
  static const double searchZoom = 17.0;
  static const double overviewZoom = 14.0;
}
