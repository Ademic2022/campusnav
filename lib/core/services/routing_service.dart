import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

/// Mapbox route profile
enum RouteProfile { walking, driving }

class RouteStep {
  final String instruction;
  final String maneuverType;
  final String? maneuverModifier;
  final double distanceMetres;
  final double durationSeconds;
  /// [lng, lat] of the point where this maneuver begins.
  final List<double> maneuverLocation;

  const RouteStep({
    required this.instruction,
    required this.maneuverType,
    this.maneuverModifier,
    required this.distanceMetres,
    required this.durationSeconds,
    required this.maneuverLocation,
  });

  String get distanceLabel {
    if (distanceMetres < 1000) return '${distanceMetres.round()} m';
    return '${(distanceMetres / 1000).toStringAsFixed(1)} km';
  }

  IconData get icon {
    if (maneuverType == 'arrive') return Icons.location_on_rounded;
    if (maneuverType == 'depart') return Icons.navigation_rounded;
    switch (maneuverModifier) {
      case 'left':        return Icons.turn_left_rounded;
      case 'right':       return Icons.turn_right_rounded;
      case 'slight left': return Icons.turn_slight_left_rounded;
      case 'slight right':return Icons.turn_slight_right_rounded;
      case 'sharp left':  return Icons.turn_sharp_left_rounded;
      case 'sharp right': return Icons.turn_sharp_right_rounded;
      case 'uturn':       return Icons.u_turn_left_rounded;
      default:            return Icons.straight_rounded;
    }
  }
}

class RouteResult {
  final List<List<double>> coordinates; // [[lng, lat], ...]
  final double distanceMetres;
  final double durationSeconds;
  final List<RouteStep> steps;

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
  final bool isNetworkError;
  const RoutingException(this.message, {this.isNetworkError = false});

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
    final profileStr =
        profile == RouteProfile.walking ? 'walking' : 'driving-traffic';
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
      final steps = <RouteStep>[];
      for (final leg in legs) {
        final legSteps =
            (leg as Map<String, dynamic>)['steps'] as List<dynamic>;
        for (final step in legSteps) {
          final stepMap = step as Map<String, dynamic>;
          final maneuver = stepMap['maneuver'] as Map<String, dynamic>;
          final instruction = maneuver['instruction'] as String? ?? '';
          if (instruction.isEmpty) continue;
          final loc = maneuver['location'] as List<dynamic>? ?? [];
          steps.add(RouteStep(
            instruction: instruction,
            maneuverType: maneuver['type'] as String? ?? '',
            maneuverModifier: maneuver['modifier'] as String?,
            distanceMetres: (stepMap['distance'] as num).toDouble(),
            durationSeconds: (stepMap['duration'] as num).toDouble(),
            maneuverLocation: loc.length >= 2
                ? [(loc[0] as num).toDouble(), (loc[1] as num).toDouble()]
                : [0.0, 0.0],
          ));
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
          throw const RoutingException(
            'No internet connection. Check your network and try again.',
            isNetworkError: true,
          );
        default:
          throw const RoutingException('Route request failed.');
      }
    }
  }
}
