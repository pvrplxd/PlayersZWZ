import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'cloudflare_service.dart';

class LiveRadarScreen extends StatefulWidget {
  final String userId;
  final String playerName;

  const LiveRadarScreen({Key? key, required this.userId, required this.playerName}) : super(key: key);

  @override
  _LiveRadarScreenState createState() => _LiveRadarScreenState();
}

class _LiveRadarScreenState extends State<LiveRadarScreen> {
  final CloudflareService _radarService = CloudflareService();
  final MapController _mapController = MapController();
  
  Timer? _pollingTimer;
  List<dynamic> _globalPlayers = [];
  LatLng? _myLocation;
  bool _isCameraCentered = false;

  final Color _neonLime = const Color(0xFFDAF51E);
  final Color _crimsonRed = const Color(0xFFFF2A2A);

  @override
  void initState() {
    super.initState();
    _initializeRadar();
  }

  void _initializeRadar() {
    // 1. Get local GPS and broadcast to Edge
    _radarService.startTracking(
      userId: widget.userId,
      playerName: widget.playerName,
      onPositionUpdate: (Position pos) {
        final newLoc = LatLng(pos.latitude, pos.longitude);
        if (mounted) {
          setState(() {
            _myLocation = newLoc; // Immediately updates YOUR local indicator
          });
          
          // Snap camera to you on first load
          if (!_isCameraCentered) {
            _mapController.move(newLoc, 16.0);
            _isCameraCentered = true;
          }
        }
      },
    );

    // 2. Poll global player state every 3 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final players = await _radarService.getGlobalLocations();
      if (mounted) {
        setState(() => _globalPlayers = players);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _radarService.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13), // Deep dark modern background
      body: Stack(
        children: [
          // Map Layer
          _myLocation == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: _neonLime, strokeWidth: 2),
                      const SizedBox(height: 24),
                      Text("ESTABLISHING SATELLITE LINK...", 
                        style: TextStyle(color: _neonLime, letterSpacing: 3, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _myLocation!,
                    initialZoom: 16.0,
                    backgroundColor: const Color(0xFF0F0F13),
                  ),
                  children: [
                    // Modern CartoDB Dark Matter Tiles (No API Key required)
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.playerszwz.app',
                    ),
                    MarkerLayer(
                      markers: _buildAllMarkers(),
                    ),
                  ],
                ),
                
          // Modern HUD Overlay
          if (_myLocation != null)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // System Status
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A24).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4))
                        ]
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(color: _neonLime, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              const Text('UPLINK SECURE', style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 2)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('TARGETS: ${_globalPlayers.length}', 
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
        ],
      ),
      
      // Recenter Button
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1A1A24),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white12, width: 1),
        ),
        child: Icon(Icons.gps_fixed, color: _neonLime),
        onPressed: () {
          if (_myLocation != null) {
            _mapController.move(_myLocation!, 16.0);
          }
        },
      ),
    );
  }

  // Merges your local GPS marker with the edge server markers
  List<Marker> _buildAllMarkers() {
    List<Marker> markers = [];

    // 1. ALWAYS draw your local device marker first (Guarantees no lag)
    if (_myLocation != null) {
      markers.add(
        Marker(
          point: _myLocation!,
          width: 90,
          height: 90,
          child: _buildRadarBlip(isMe: true, name: widget.playerName),
        ),
      );
    }

    // 2. Draw all other players fetched from Cloudflare
    for (var player in _globalPlayers) {
      // Skip your own Edge ID so we don't draw a duplicate dot over yourself
      if (player['userId'] == widget.userId) continue;

      markers.add(
        Marker(
          point: LatLng(player['lat'], player['lng']),
          width: 80,
          height: 80,
          child: _buildRadarBlip(isMe: false, name: player['playerName']),
        ),
      );
    }

    return markers;
  }

  // The visual design for the dots
  Widget _buildRadarBlip({required bool isMe, required String name}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Name Tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: isMe ? _neonLime.withOpacity(0.5) : Colors.transparent),
          ),
          child: Text(
            isMe ? "YOU" : name.toUpperCase(),
            style: TextStyle(
              color: isMe ? _neonLime : Colors.white,
              fontWeight: isMe ? FontWeight.w900 : FontWeight.bold,
              fontSize: isMe ? 12 : 10,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Glowing Dot
        Container(
          width: isMe ? 20 : 14,
          height: isMe ? 20 : 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isMe ? _neonLime : _crimsonRed,
            border: Border.all(
              color: Colors.white,
              width: isMe ? 3 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isMe ? _neonLime.withOpacity(0.9) : _crimsonRed.withOpacity(0.6),
                blurRadius: isMe ? 12 : 6,
                spreadRadius: isMe ? 4 : 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}