import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../config/api_keys.dart';

class MapTilerService {
  static const String _baseUrl = 'https://api.maptiler.com';
  final Dio _dio = Dio();

  Future<bool> validateApiKey() async {
    if (!ApiKeys.isValidMapTilerKey()) {
      return false;
    }

    try {
      final response = await _dio.get(
        '$_baseUrl/maps/streets/style.json',
        queryParameters: {
          'key': ApiKeys.mapTilerApiKey,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print('MapTiler API key validation failed: $e');
      return false;
    }
  }

  String get apiKey => ApiKeys.mapTilerApiKey;

  String get styleUrl => ApiKeys.mapLibreStyleUrl;

  // Get tile URL template for offline maps
  String getTileUrl(int z, int x, int y) {
    return '$_baseUrl/maps/streets/$z/$x/$y.png?key=$apiKey';
  }

  // Get static map URL
  String getStaticMapUrl({
    required LatLng center,
    required int zoom,
    int width = 600,
    int height = 400,
    List<LatLng>? markers,
    List<LatLng>? path,
  }) {
    final params = <String, String>{
      'center': '${center.longitude},${center.latitude}',
      'zoom': zoom.toString(),
      'size': '${width}x$height',
      'key': apiKey,
    };

    if (markers != null && markers.isNotEmpty) {
      params['markers'] = markers
          .map((m) => '${m.longitude},${m.latitude}')
          .join('|');
    }

    if (path != null && path.isNotEmpty) {
      params['path'] = path
          .map((p) => '${p.longitude},${p.latitude}')
          .join('|');
    }

    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return '$_baseUrl/maps/static?$queryString';
  }

  // Get bounds for a list of points
  static LatLngBounds getBounds(List<LatLng> points) {
    if (points.isEmpty) {
      throw Exception('Cannot create bounds from empty points list');
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    return LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
  }
}
