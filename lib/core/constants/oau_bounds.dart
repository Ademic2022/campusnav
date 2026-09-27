// OAU Campus Bounding Box Constants
class OauBounds {
  OauBounds._();

  static const double centerLat = 7.5174;
  static const double centerLng = 4.5228;

  /// Retired fence corners. The axis-aligned box spanned 5.5 x 7.7 km
  /// (~43 km2), overshooting the northernmost landmark by 1.3 km and the
  /// westernmost by 2.1 km, so parts of Ile-Ife town counted as "on campus".
  ///
  /// Kept only for the camera default and as a cheap pre-reject. Do not use it
  /// as a geofence - use [CampusBoundary.contains], which is what the map
  /// draws, so the visible boundary and the fence cannot disagree.
  static const double swLat = 7.490;
  static const double swLng = 4.490;

  static const double neLat = 7.540;
  static const double neLng = 4.560;

  /// Approximate radius of campus from center in km
  static const double radiusKm = 4.0;

  /// Coarse reject against the retired bounding box.
  ///
  /// True means "possibly on campus"; it never confirms membership. The real
  /// polygon is strictly inside this box, so a false here is a definite
  /// off-campus result and lets the caller skip the containment test.
  static bool withinRetiredBox(double lat, double lng) {
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
