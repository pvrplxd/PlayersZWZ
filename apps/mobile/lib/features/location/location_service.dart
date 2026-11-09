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

  Future<Area> current({bool requestPermission = true}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure(
          'Location services are off. Turn them on to refresh your live location.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
          'Location access is disabled. Open Settings to refresh your live location.',
          settings: true);
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      throw const LocationFailure(
          'Location permission is needed to refresh your live location.');
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

  Future<List<Area>> searchVenue(String text) async {
    if (apiKey.isEmpty) {
      throw const LocationFailure('Location search is not configured yet.');
    }
    if (text.trim().length < 3) return [];
    return _lookup('autocomplete', {'text': text.trim()});
  }

  Future<List<Area>> nearbySportsPlaces(Area center, String sport) async {
    if (apiKey.isEmpty) {
      throw const LocationFailure('Nearby place search is not configured.');
    }
    final categories = switch (sport) {
      'Football' || 'Cricket' =>
        'sport.pitch,sport.sports_centre,sport.stadium,leisure.park',
      'Basketball' || 'Badminton' || 'Tennis' =>
        'sport.pitch,sport.sports_hall,sport.sports_centre,leisure.park',
      'Skating' => 'sport.skateboard,leisure.park,sport.pitch',
      _ => 'sport.sports_centre,sport.pitch,leisure.park',
    };
    final location = '${center.longitude},${center.latitude}';
    final response = await _client
        .get(Uri.https('api.geoapify.com', '/v2/places', {
          'categories': categories,
          'filter': 'circle:$location,7000',
          'bias': 'proximity:$location',
          'limit': '12',
          'lang': 'en',
          'apiKey': apiKey,
        }))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw const LocationFailure('Nearby place search failed. Please retry.');
    }
    final json = jsonDecode(response.body);
    if (json is! Map || json['features'] is! List) {
      throw const LocationFailure('Could not read nearby places.');
    }
    final places = <Area>[];
    for (final feature in json['features'] as List) {
      if (feature is! Map ||
          feature['geometry'] is! Map ||
          feature['properties'] is! Map) {
        continue;
      }
      final coordinates = (feature['geometry'] as Map)['coordinates'];
      final properties = feature['properties'] as Map;
      if (coordinates is! List || coordinates.length < 2) continue;
      final lon = coordinates[0], lat = coordinates[1];
      if (lat is! num || lon is! num) continue;
      final label = _shortLabel(properties);
      if (label == null) continue;
      places.add(Area(lat.toDouble(), lon.toDouble(), label, 'manual'));
    }
    return places;
  }

  Future<Area> pin(double latitude, double longitude) async {
    var label = 'Pinned location';
    if (apiKey.isNotEmpty) {
      try {
        final results = await _lookup('reverse', {
          'lat': '$latitude',
          'lon': '$longitude',
        });
        if (results.isNotEmpty) label = results.first.label;
      } catch (_) {
        // A geocoder error does not prevent dropping a pin.
      }
    }
    return Area(latitude, longitude, label, 'manual');
  }

  Future<List<Area>> _lookup(String endpoint, Map<String, String> query) async {
    final response = await _client
        .get(Uri.https('api.geoapify.com', '/v1/geocode/$endpoint',
            {...query, 'apiKey': apiKey, 'format': 'json', 'limit': '5', 'lang': 'en'}))
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
      if (item is! Map || item['lat'] is! num || item['lon'] is! num) {
        continue;
      }
      final lat = (item['lat'] as num).toDouble(),
          lon = (item['lon'] as num).toDouble();
      final label = _shortLabel(item);
      if (lat.isFinite &&
          lon.isFinite &&
          lat.abs() <= 90 &&
          lon.abs() <= 180 &&
          label != null &&
          label.isNotEmpty &&
          label.length <= 300) {
        results.add(Area(lat, lon, label, 'manual'));
      }
    }
    return results;
  }

  String? _shortLabel(Map properties) {
    String? value(Object? input) => input is String && input.trim().isNotEmpty
        ? input.trim()
        : null;
    // Prefer English names; OSM `name` is often in the local script.
    final international = properties['name_international'];
    final datasource = properties['datasource'];
    final raw = datasource is Map ? datasource['raw'] : null;
    final english = (international is Map ? value(international['en']) : null) ??
        (raw is Map ? value(raw['name:en']) : null);
    String? latin(Object? input) {
      final text = value(input);
      return text != null && !_nonLatin.hasMatch(text) ? text : null;
    }
    final name = english ??
        latin(properties['name']) ??
        latin(properties['street']) ??
        latin(properties['address_line1']);
    final locality = value(properties['city']) ??
        value(properties['town']) ??
        value(properties['village']) ??
        value(properties['suburb']) ??
        value(properties['district']);
    if (name != null &&
        locality != null &&
        name.toLowerCase() != locality.toLowerCase()) {
      return '$name · $locality';
    }
    return name ?? locality ?? latin(properties['formatted']) ??
        value(properties['formatted']);
  }

  /// Arabic-script ranges (Urdu, Arabic, Persian).
  static final _nonLatin =
      RegExp(r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]');

  Future<bool> openSettings() => Geolocator.openAppSettings();
  void close() => _client.close();
}
