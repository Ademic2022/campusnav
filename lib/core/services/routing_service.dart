import 'package:dio/dio.dart';

/// Mapbox route profile
enum RouteProfile { walking, driving }

class RouteResult {
  final List<List<double>> coordinates; // [[lng, lat], ...]
  final double distanceMetres;
  final double durationSeconds;
  final List<String> steps;

  const RouteResult({
    required this.coordinates,
    required this.distanceMetres,
    required this.durationSeconds,
    required this.steps,
  });

  String get distanceLabel {
    if (distanceMetres < 1000) return '${distanceMetres.round()}m';
    return '${(distanceMetres / 1000).toStringAsFixed(1)}km';
  }

  String get durationLabel {
    final mins = (durationSeconds / 60).round();
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return '${h}h ${m}min';
  }
}

class RoutingException implements Exception {
  final String message;
  const RoutingException(this.message);

  @override
  String toString() => message;
}

class RoutingService {
  RoutingService._();
  static final RoutingService instance = RoutingService._();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.mapbox.com/directions/v5/mapbox',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  /// Get a route from [fromLat],[fromLng] to [toLat],[toLng].
  /// Pass your Mapbox access token in [accessToken].
  Future<RouteResult?> getRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
    required String accessToken,
    RouteProfile profile = RouteProfile.walking,
  }) async {
    final profileStr = profile == RouteProfile.walking ? 'walking' : 'driving';
    final coords = '$fromLng,$fromLat;$toLng,$toLat';

    try {
      final response = await _dio.get(
        '/$profileStr/$coords',
        queryParameters: {
          'access_token': accessToken,
          'geometries': 'geojson',
          'steps': 'true',
          'overview': 'full',
        },
      );

      final data = response.data as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>;
      if (routes.isEmpty) {
        throw const RoutingException('No route found for this destination.');
      }

      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final rawCoords = geometry['coordinates'] as List<dynamic>;
      final coordinates = rawCoords
          .map((c) => [
                (c as List<dynamic>)[0] as double,
                c[1] as double,
              ])
          .toList();

      // Directions geometry is road-snapped and may start/end near the input
      // points. Ensure rendered polyline touches exact requested coordinates.
      final exactStart = [fromLng, fromLat];
      final exactEnd = [toLng, toLat];
      if (coordinates.isEmpty ||
          coordinates.first[0] != exactStart[0] ||
          coordinates.first[1] != exactStart[1]) {
        coordinates.insert(0, exactStart);
      }
      if (coordinates.last[0] != exactEnd[0] ||
          coordinates.last[1] != exactEnd[1]) {
        coordinates.add(exactEnd);
      }

      final legs = route['legs'] as List<dynamic>;
      final steps = <String>[];
      for (final leg in legs) {
        final legSteps =
            (leg as Map<String, dynamic>)['steps'] as List<dynamic>;
        for (final step in legSteps) {
          final maneuver = (step as Map<String, dynamic>)['maneuver']
              as Map<String, dynamic>;
          final instruction = maneuver['instruction'] as String? ?? '';
          if (instruction.isNotEmpty) steps.add(instruction);
        }
      }

      return RouteResult(
        coordinates: coordinates,
        distanceMetres: (route['distance'] as num).toDouble(),
        durationSeconds: (route['duration'] as num).toDouble(),
        steps: steps,
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['message'] as String?;
        if (message != null && message.isNotEmpty) {
          throw RoutingException(message);
        }
      }

      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.connectionError:
          throw const RoutingException('Network error. Check connection.');
        default:
          throw const RoutingException('Route request failed.');
      }
    }
  }
}
