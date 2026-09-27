import 'package:flutter_test/flutter_test.dart';
import 'package:oau_navigator/core/constants/travel_pace.dart';

void main() {
  group('walking', () {
    test('uses 80 m per minute', () {
      expect(TravelPace.minutesFor(800, isDriving: false), 10);
      expect(TravelPace.minutesFor(1600, isDriving: false), 20);
    });
  });

  group('driving', () {
    test('is far faster than walking for the same distance', () {
      expect(TravelPace.minutesFor(4000, isDriving: true), 10);
      expect(TravelPace.minutesFor(4000, isDriving: false), 50);
    });
  });

  test('rounds partial minutes up', () {
    expect(TravelPace.minutesFor(1, isDriving: false), 1);
    expect(TravelPace.minutesFor(81, isDriving: false), 2);
    expect(TravelPace.minutesFor(160, isDriving: false), 2);
    expect(TravelPace.minutesFor(161, isDriving: false), 3);
  });

  test('never returns zero for a non-negative distance', () {
    expect(TravelPace.minutesFor(0, isDriving: false), 1);
    expect(TravelPace.minutesFor(0, isDriving: true), 1);
  });

  test('metresPerMinute matches the documented constants', () {
    expect(TravelPace.metresPerMinute(false), 80.0);
    expect(TravelPace.metresPerMinute(true), 400.0);
  });
}
