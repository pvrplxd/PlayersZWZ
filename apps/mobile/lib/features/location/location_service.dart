import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class Area {
  const Area(this.latitude, this.longitude, this.label, this.source);
  final double latitude, longitude;
  final String label, source;
  static Area? fromProfile(dynamic profile) {
    if (profile is! Map || profile['location'] is! Map) return null;
    final coordinates = profile['location'] as Map;
    final lat = coordinates['latitude'], lon = coordinates['longitude'];
    if (lat is! num ||
        lon is! num ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180) {
      return null;
    }
    final label = profile['location_label'];
    return Area(
        lat.toDouble(),
        lon.toDouble(),
        label is String && label.trim().isNotEmpty ? label : 'Saved area',
        profile['location_source'] == 'gps' ? 'gps' : 'manual');
  }

  Map<String, Object> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'label': label,
        'source': source
      };
}

class LocationFailure implements Exception {
  const LocationFailure(this.message, {this.settings = false});
  final String message;
  final bool settings;
}

class LocationService {
  LocationService({required this.apiKey, http.Client? client})
      : _client = client ?? http.Client();
  final String apiKey;
  final http.Client _client;

  Future<Area> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure(
          'Location services are off. Turn them on or search for an area.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
          'Location access is disabled. Open Settings or choose an area manually.',
          settings: true);
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      throw const LocationFailure(
          'Location permission was not granted. You can choose an area below.');
    }
    final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 20)));
    var label = 'Current location';
    if (apiKey.isNotEmpty) {
      try {
        final areas = await _lookup('reverse',
            {'lat': '${position.latitude}', 'lon': '${position.longitude}'});
        if (areas.isNotEmpty) label = areas.first.label;
      } catch (_) {
        // A geocoder outage must not discard a successful position fix.
      }
    }
    return Area(position.latitude, position.longitude, label, 'gps');
  }

  Future<List<Area>> search(String text) async {
    if (apiKey.isEmpty) {
      throw const LocationFailure(
          'Area search is not configured yet. You can still use your current location.');
    }
    if (text.trim().length < 3) return [];
    return _lookup('autocomplete', {'text': text.trim(), 'type': 'locality'});
  }

  Future<List<Area>> _lookup(String endpoint, Map<String, String> query) async {
    final response = await _client
        .get(Uri.https('api.geoapify.com', '/v1/geocode/$endpoint',
            {...query, 'apiKey': apiKey, 'format': 'json', 'limit': '5'}))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw const LocationFailure('Area search is unavailable. Please retry.');
    }
    final json = jsonDecode(response.body);
    if (json is! Map || json['results'] is! List) {
      throw const LocationFailure(
          'Could not read the area results. Please retry.');
    }
    final results = <Area>[];
    for (final item in json['results'] as List) {
      if (item is! Map ||
          item['lat'] is! num ||
          item['lon'] is! num ||
          item['formatted'] is! String) {
        continue;
      }
      final lat = (item['lat'] as num).toDouble(),
          lon = (item['lon'] as num).toDouble();
      final label = item['formatted'] as String;
      if (lat.isFinite &&
          lon.isFinite &&
          lat.abs() <= 90 &&
          lon.abs() <= 180 &&
          label.isNotEmpty &&
          label.length <= 300) {
        results.add(Area(lat, lon, label, 'manual'));
      }
    }
    return results;
  }

  Future<bool> openSettings() => Geolocator.openAppSettings();
  void close() => _client.close();
}
