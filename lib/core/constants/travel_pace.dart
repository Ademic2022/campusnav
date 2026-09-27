/// Average travel speeds used for on-device distance/time estimates.
///
/// Mapbox returns its own duration for real routes; these constants are only
/// used for the cheap pre-route estimates shown before a route is fetched.
class TravelPace {
  TravelPace._();

  static const double walkingMetresPerMinute = 80.0;

  static const double drivingMetresPerMinute = 400.0;

  static double metresPerMinute(bool isDriving) =>
      isDriving ? drivingMetresPerMinute : walkingMetresPerMinute;

  static int minutesFor(double metres, {required bool isDriving}) {
    final minutes = metres / metresPerMinute(isDriving);
    return minutes.ceil().clamp(1, 1 << 30);
  }
}
