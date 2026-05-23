import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RoutingResult {
  final List<LatLng> points;
  final double distanceMeters;
  final Duration duration;
  const RoutingResult({
    required this.points,
    required this.distanceMeters,
    required this.duration,
  });

  double get distanceKm => distanceMeters / 1000.0;
}

class RoutingService {
  static const _base = 'https://router.project-osrm.org/route/v1/foot';

  /// Computes a walking route between [start] and [end] using the free public
  /// OSRM instance. Returns `null` if the call fails or no route exists.
  Future<RoutingResult?> foot(LatLng start, LatLng end) async {
    final url = Uri.parse(
      '$_base/${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
      '?overview=full&geometries=geojson',
    );
    try {
      final response =
          await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final body = json.decode(response.body) as Map<String, dynamic>;
      if (body['code'] != 'Ok') return null;
      final routes = body['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;
      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coords = geometry['coordinates'] as List;
      final points = coords
          .map((c) => LatLng(
                ((c as List)[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              ))
          .toList();
      return RoutingResult(
        points: points,
        distanceMeters: (route['distance'] as num).toDouble(),
        duration: Duration(seconds: (route['duration'] as num).round()),
      );
    } catch (_) {
      return null;
    }
  }
}
