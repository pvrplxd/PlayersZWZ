import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class CloudflareService {
  // Replace with your actual deployed Cloudflare Worker URL
  final String _workerUrl = 'https://player-tracker-backend.afaqaamir01.workers.dev';
  StreamSubscription<Position>? _positionStream;

  /// Starts listening to device GPS and sending data to the Edge
  void startTracking({
    required String userId,
    required String playerName,
    required Function(Position) onPositionUpdate,
  }) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      onPositionUpdate(position);
      _updateLocationOnEdge(userId, playerName, position.latitude, position.longitude);
    });
  }

  Future<void> _updateLocationOnEdge(String userId, String name, double lat, double lng) async {
    try {
      await http.post(
        Uri.parse('$_workerUrl/update-location'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'playerName': name,
          'lat': lat,
          'lng': lng,
        }),
      );
    } catch (e) {
      print('Edge sync failed: $e');
    }
  }

  /// Fetches the live radar state from the KV store
  Future<List<dynamic>> getGlobalLocations() async {
    try {
      final response = await http.get(Uri.parse('$_workerUrl/get-locations'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Failed to fetch radar state: $e');
    }
    return [];
  }

  /// Rigorous cleanup to prevent memory/battery leaks
  void dispose() {
    _positionStream?.cancel();
    _positionStream = null;
  }
}