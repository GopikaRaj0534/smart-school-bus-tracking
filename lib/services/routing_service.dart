import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteResult {
  final List<LatLng> polylinePoints;
  final double distanceMeters;
  final double durationSeconds;
  final bool success;
  final String? errorMessage;

  RouteResult({
    required this.polylinePoints,
    this.distanceMeters = 0.0,
    this.durationSeconds = 0.0,
    this.success = true,
    this.errorMessage,
  });

  String get formattedDistance {
    if (distanceMeters <= 0) return '';
    final km = distanceMeters / 1000.0;
    return '${km.toStringAsFixed(1)} km';
  }

  String get formattedDuration {
    if (durationSeconds <= 0) return '';
    final mins = (durationSeconds / 60.0).round();
    if (mins < 1) return '1 min';
    if (mins >= 60) {
      final hrs = mins ~/ 60;
      final remMins = mins % 60;
      return remMins > 0 ? '$hrs hr $remMins mins' : '$hrs hr';
    }
    return '$mins mins';
  }
}

class RoutingService {
  static final Map<String, RouteResult> _cache = {};

  static Future<RouteResult> getRoadRoute(List<LatLng> waypoints) async {
    if (waypoints.length < 2) {
      return RouteResult(
        polylinePoints: waypoints,
        success: true,
      );
    }

    // Generate unique cache key from waypoints
    final cacheKey = waypoints
        .map((p) => '${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}')
        .join(';');

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      // Format coordinates as lon,lat;lon,lat;... for OSRM API
      final coordString = waypoints
          .map((p) => '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}')
          .join(';');

      final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/$coordString?overview=full&geometries=geojson',
      );

      debugPrint('OSRM Route Request: $url');

      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'RouteSafeSchoolBusTracker/1.0',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map &&
            data['code'] == 'Ok' &&
            data['routes'] is List &&
            (data['routes'] as List).isNotEmpty) {
          final route = (data['routes'] as List)[0];
          final geometry = route['geometry'];
          final distance = (route['distance'] as num?)?.toDouble() ?? 0.0;
          final duration = (route['duration'] as num?)?.toDouble() ?? 0.0;

          final List<LatLng> decodedPoints = [];
          if (geometry is Map && geometry['coordinates'] is List) {
            final coords = geometry['coordinates'] as List;
            for (var pt in coords) {
              if (pt is List && pt.length >= 2) {
                final lon = (pt[0] as num).toDouble();
                final lat = (pt[1] as num).toDouble();
                decodedPoints.add(LatLng(lat, lon));
              }
            }
          }

          if (decodedPoints.isNotEmpty) {
            final result = RouteResult(
              polylinePoints: decodedPoints,
              distanceMeters: distance,
              durationSeconds: duration,
              success: true,
            );
            _cache[cacheKey] = result;
            return result;
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('OSRM Routing Error: $e\n$stackTrace');
    }

    // Return fallback straight waypoints if OSRM server call fails
    return RouteResult(
      polylinePoints: waypoints,
      success: false,
      errorMessage: 'Road routing service unreachable',
    );
  }
}
