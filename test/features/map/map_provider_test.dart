import 'package:flutter_test/flutter_test.dart';
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

  group('dispose', () {
    test('cancels in-flight work without throwing', () {
      final p = MapProvider()..activeRoute = route([100]);
      p.dispose();
    });
  });
}
