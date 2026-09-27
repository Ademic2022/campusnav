import 'package:flutter_test/flutter_test.dart';
import 'package:oau_navigator/core/services/routing_service.dart';

void main() {
  Map<String, dynamic> routeResponse({
    required List<List<num>> coordinates,
    List<Map<String, dynamic>>? steps,
    double distance = 1200,
    double duration = 900,
  }) {
    return {
      'routes': [
        {
          'distance': distance,
          'duration': duration,
          'geometry': {'type': 'LineString', 'coordinates': coordinates},
          'legs': [
            {'steps': steps ?? <Map<String, dynamic>>[]},
          ],
        },
      ],
    };
  }

  Map<String, dynamic> step({
    String instruction = 'Head north',
    String type = 'depart',
    String? modifier,
    num distance = 120,
    num duration = 90,
    List<num>? location,
  }) {
    return {
      'distance': distance,
      'duration': duration,
      'maneuver': {
        'instruction': instruction,
        'type': type,
        'modifier': modifier,
        'location': location ?? [4.5225, 7.4976],
      },
    };
  }

  group('parseRouteResponse', () {
    test('regression: integer coordinates do not throw a TypeError', () {
      // JSON decodes "4" as an int, so a naive `as double` cast fails.
      final result = RoutingService.parseRouteResponse(
        routeResponse(coordinates: [
          [4, 7],
          [5, 8],
        ]),
        fromLat: 7.0,
        fromLng: 4.0,
        toLat: 8.0,
        toLng: 5.0,
      );

      expect(result.coordinates, isNotEmpty);
      // The whole-number inputs must have been widened, not left as ints.
      expect(result.coordinates.first[0], 4.0);
      expect(result.coordinates.first[1], 7.0);
      expect(result.coordinates.last[0], 5.0);
      expect(result.coordinates.last[1], 8.0);
    });

    test('parses mixed int and double coordinates', () {
      final result = RoutingService.parseRouteResponse(
        routeResponse(coordinates: [
          [4.5225, 7.4976],
          [4, 7.5],
          [4.53, 8],
        ]),
        fromLat: 7.4976,
        fromLng: 4.5225,
        toLat: 7.5016,
        toLng: 4.5225,
      );
      expect(result.coordinates.first, [4.5225, 7.4976]);
      expect(result.coordinates[1], [4.0, 7.5]);
      expect(result.coordinates[2], [4.53, 8.0]);
    });

    test('inserts the exact start and end coordinates when snapped', () {
      final result = RoutingService.parseRouteResponse(
        routeResponse(coordinates: [
          [4.5226, 7.4977],
          [4.5230, 7.4990],
        ]),
        fromLat: 7.4976,
        fromLng: 4.5225,
        toLat: 7.5016,
        toLng: 4.5240,
      );

      expect(result.coordinates.first, [4.5225, 7.4976]);
      expect(result.coordinates.last, [4.5240, 7.5016]);
    });

    test('does not duplicate endpoints that already match', () {
      final result = RoutingService.parseRouteResponse(
        routeResponse(coordinates: [
          [4.5225, 7.4976],
          [4.5230, 7.4990],
          [4.5240, 7.5016],
        ]),
        fromLat: 7.4976,
        fromLng: 4.5225,
        toLat: 7.5016,
        toLng: 4.5240,
      );
      expect(result.coordinates.length, 3);
    });

    test('parses steps with distance, duration and maneuver', () {
      final result = RoutingService.parseRouteResponse(
        routeResponse(
          coordinates: [
            [4.5225, 7.4976],
            [4.5230, 7.4990],
          ],
          steps: [
            step(instruction: 'Head north', type: 'depart'),
            step(
              instruction: 'Turn left onto Amina Way',
              type: 'turn',
              modifier: 'left',
              distance: 80,
              duration: 60,
            ),
            step(instruction: 'You have arrived', type: 'arrive'),
          ],
        ),
        fromLat: 7.4976,
        fromLng: 4.5225,
        toLat: 7.4990,
        toLng: 4.5230,
      );

      expect(result.steps.length, 3);
      expect(result.steps[0].instruction, 'Head north');
      expect(result.steps[1].maneuverModifier, 'left');
      expect(result.steps[1].distanceMetres, 80.0);
      expect(result.steps[2].maneuverType, 'arrive');
      expect(result.steps[2].distanceLabel, '120 m');
    });

    test('skips steps with no instruction', () {
      final result = RoutingService.parseRouteResponse(
        routeResponse(
          coordinates: [
            [4.5225, 7.4976],
            [4.5230, 7.4990],
          ],
          steps: [
            step(instruction: '', type: 'turn'),
            step(instruction: 'Continue', type: 'turn'),
          ],
        ),
        fromLat: 7.4976,
        fromLng: 4.5225,
        toLat: 7.4990,
        toLng: 4.5230,
      );
      expect(result.steps.length, 1);
      expect(result.steps.single.instruction, 'Continue');
    });

    test('falls back to a null maneuver location safely', () {
      final result = RoutingService.parseRouteResponse(
        routeResponse(
          coordinates: [
            [4.5225, 7.4976],
            [4.5230, 7.4990],
          ],
          steps: [step(instruction: 'Continue', location: [])],
        ),
        fromLat: 7.4976,
        fromLng: 4.5225,
        toLat: 7.4990,
        toLng: 4.5230,
      );
      expect(result.steps.single.maneuverLocation, [0.0, 0.0]);
    });

    test('throws a RoutingException when there are no routes', () {
      expect(
        () => RoutingService.parseRouteResponse(
          {'routes': <dynamic>[]},
          fromLat: 7.0,
          fromLng: 4.0,
          toLat: 7.1,
          toLng: 4.1,
        ),
        throwsA(isA<RoutingException>()),
      );
    });

    test('throws a RoutingException rather than a TypeError on bad shapes', () {
      expect(
        () => RoutingService.parseRouteResponse(
          {'routes': 'not-a-list'},
          fromLat: 7.0,
          fromLng: 4.0,
          toLat: 7.1,
          toLng: 4.1,
        ),
        throwsA(isA<RoutingException>()),
      );
      expect(
        () => RoutingService.parseRouteResponse(
          <String, dynamic>{},
          fromLat: 7.0,
          fromLng: 4.0,
          toLat: 7.1,
          toLng: 4.1,
        ),
        throwsA(isA<RoutingException>()),
      );
    });
  });

  group('RouteResult labels', () {
    test('formats distance and duration', () {
      const r = RouteResult(
        coordinates: [],
        distanceMetres: 850,
        durationSeconds: 3000,
        steps: [],
      );
      expect(r.distanceLabel, '850m');
      expect(r.durationLabel, '50 min');
    });

    test('formats long distances and durations', () {
      const r = RouteResult(
        coordinates: [],
        distanceMetres: 4200,
        durationSeconds: 7500,
        steps: [],
      );
      expect(r.distanceLabel, '4.2km');
      expect(r.durationLabel, '2h 5min');
    });
  });
}
