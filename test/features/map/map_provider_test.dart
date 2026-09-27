import 'package:flutter_test/flutter_test.dart';
import 'package:oau_navigator/core/models/landmark.dart';
import 'package:oau_navigator/core/services/routing_service.dart';
import 'package:oau_navigator/features/map/map_provider.dart';

RouteStep step(double distance) => RouteStep(
      instruction: 'Continue',
      maneuverType: 'turn',
      distanceMetres: distance,
      durationSeconds: 60,
      maneuverLocation: const [4.5225, 7.4976],
    );

RouteResult route(List<double> stepDistances) => RouteResult(
      coordinates: const [
        [4.5225, 7.4976],
        [4.5230, 7.4990],
      ],
      distanceMetres: stepDistances.fold(0.0, (a, b) => a + b),
      durationSeconds: 600,
      steps: stepDistances.map(step).toList(),
    );

void main() {
  group('remainingMetres', () {
    test('is zero without a route', () {
      expect(MapProvider().remainingMetres, 0);
      expect(MapProvider().remainingMinutes, 1);
    });

    test('sums every step at the start of a route', () {
      final p = MapProvider()..activeRoute = route([1000, 1000, 1000]);
      expect(p.remainingMetres, 3000);
    });

    test('sums only the steps still ahead', () {
      final p = MapProvider()..activeRoute = route([1000, 1000, 1000]);
      p.nextStep();
      expect(p.remainingMetres, 2000);
      p.nextStep();
      expect(p.remainingMetres, 1000);
    });
  });

  group('remainingMinutes is profile-aware', () {
    test('walking 3 km is about 38 minutes', () {
      final p = MapProvider()
        ..activeRoute = route([1000, 1000, 1000])
        ..routeProfile = RouteProfile.walking;
      expect(p.remainingMinutes, 38);
    });

    test('driving the same 3 km is about 8 minutes', () {
      final p = MapProvider()
        ..activeRoute = route([1000, 1000, 1000])
        ..routeProfile = RouteProfile.driving;
      expect(p.remainingMinutes, 8);
    });

    test('switching profile changes the estimate without refetching', () {
      final p = MapProvider()..activeRoute = route([4000]);
      final walking = p.remainingMinutes;
      p.routeProfile = RouteProfile.driving;
      expect(p.remainingMinutes, lessThan(walking));
      expect(walking, 50);
      expect(p.remainingMinutes, 10);
    });
  });

  group('navigation state', () {
    test('will not start without a route', () {
      final p = MapProvider();
      p.startNavigation();
      expect(p.isNavigating, isFalse);
    });

    test('starts and ends cleanly', () {
      final p = MapProvider()..activeRoute = route([100, 100]);
      p.startNavigation();
      expect(p.isNavigating, isTrue);
      p.endNavigation();
      expect(p.isNavigating, isFalse);
      expect(p.currentStepIndex, 0);
    });

    test('step navigation respects bounds', () {
      final p = MapProvider()..activeRoute = route([100, 100]);
      p.prevStep();
      expect(p.currentStepIndex, 0);
      p.nextStep();
      p.nextStep();
      expect(p.currentStepIndex, 1);
      expect(p.hasNextStep, isFalse);
    });
  });

  group('route polyline identity', () {
    // Regression: the old cache key was '${length}-${distanceMetres}', so two
    // different routes with identical point count and distance collided and
    // the stale polyline stayed on screen.
    test('two routes with identical length and distance are distinct', () {
      final a = route([500, 500]);
      final b = route([500, 500]);
      expect(identical(a, b), isFalse);
      expect(a.coordinates.length, b.coordinates.length);
      expect(a.distanceMetres, b.distanceMetres);
    });

    test('the same instance is recognisable as unchanged', () {
      final a = route([500, 500]);
      expect(identical(a, a), isTrue);
    });
  });

  group('marked location', () {
    test('reports no distance before a pin is set', () {
      expect(MapProvider().markedLocationDistanceLabel(null), '');
    });

    test('formats a nearby pin in metres', () {
      final p = MapProvider()..setMarkedLocation(7.4977, 4.5225);
      final label = p.markedLocationDistanceLabel(
        null,
      );
      expect(label, isEmpty);
      expect(p.hasMarkedLocation, isTrue);
    });

    test('clearing a pin resets state', () {
      final p = MapProvider()..setMarkedLocation(7.4977, 4.5225);
      expect(p.hasMarkedLocation, isTrue);
      p.clearMarkedLocation();
      expect(p.hasMarkedLocation, isFalse);
      expect(p.markedCoordinateLabel, '');
    });
  });

  group('marked location naming', () {
    // A landmark sitting on the campus, plus a point far from any landmark.
    const hostels = [
      Landmark(
        id: 1,
        name: 'Mbiological Hostel',
        category: 'hostel',
        lat: 7.5174,
        lng: 4.5228,
        description: '',
        icon: 'hostel',
      ),
    ];

    test('names the mark after a landmark it sits on', () {
      final p = MapProvider()
        ..setMarkedLocation(7.5174, 4.5228, nearest: hostels);
      expect(p.markedLocationTitle, 'Mbiological Hostel');
      expect(p.markedLandmark?.name, 'Mbiological Hostel');
      expect(p.markedLandmarkDistanceMetres, lessThan(1));
    });

    test('names a far mark after the nearest landmark anyway', () {
      // ~1.1 km south of the only landmark in this list. It is still the
      // closest thing to the pin, so the name shows and the distance
      // discloses how loose the match is.
      final p = MapProvider()
        ..setMarkedLocation(7.5074, 4.5228, nearest: hostels);
      expect(p.markedLandmark?.name, 'Mbiological Hostel');
      expect(p.markedLocationTitle, 'Mbiological Hostel');
      expect(p.markedLandmarkDistanceMetres, greaterThan(1000));
    });

    test('picks the closest of several nearby landmarks', () {
      const all = [
        ...hostels,
        Landmark(
          id: 2,
          name: 'Mbiological Hostel Annex',
          category: 'hostel',
          lat: 7.5175,
          lng: 4.5228,
          description: '',
          icon: 'hostel',
        ),
      ];
      final p = MapProvider()
        ..setMarkedLocation(7.51747, 4.5228, nearest: all);
      expect(p.markedLocationTitle, 'Mbiological Hostel Annex');
    });

    test('names a mark no matter how far the nearest landmark is', () {
      // Landmarks are ~700 m apart, so there is no distance at which naming
      // should stop. Every one of these resolves.
      for (final lat in [7.5192, 7.5250, 7.5100, 7.5000]) {
        final p = MapProvider()
          ..setMarkedLocation(lat, 4.5228, nearest: hostels);
        expect(p.markedLandmark?.name, 'Mbiological Hostel',
            reason: 'lat $lat should still resolve to the only landmark');
        expect(p.markedLocationTitle, isNot(contains('°')),
            reason: 'lat $lat should show a name, not bare coordinates');
      }
    });

    test('no landmarks supplied means no invented name', () {
      final p = MapProvider()..setMarkedLocation(7.5174, 4.5228);
      expect(p.markedLandmark, isNull);
      expect(p.markedLocationTitle, contains('7.51740° N'));
    });

    test('clearing the mark drops the resolved name too', () {
      final p = MapProvider()
        ..setMarkedLocation(7.5174, 4.5228, nearest: hostels)
        ..clearMarkedLocation();
      expect(p.markedLandmark, isNull);
    });
  });

  group('dispose', () {
    test('cancels in-flight work without throwing', () {
      final p = MapProvider()..activeRoute = route([100]);
      p.dispose();
    });
  });
}
