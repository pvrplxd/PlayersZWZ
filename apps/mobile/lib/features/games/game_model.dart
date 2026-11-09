class Game {
  const Game({
    required this.id,
    required this.sport,
    required this.startTime,
    required this.latitude,
    required this.longitude,
    required this.locationLabel,
    required this.requiredPlayers,
    this.feeAmount = 0,
    required this.approvedCount,
    required this.status,
    required this.organizerId,
    required this.organizerName,
    required this.notes,
    this.participation,
    this.distanceKm,
    this.players = const [],
  });

  /// Up to three approved players (host first), for map bubbles.
  final List<GamePlayer> players;

  final String id,
      sport,
      locationLabel,
      status,
      organizerId,
      organizerName,
      notes;
  final DateTime startTime;
  final double latitude, longitude;
  final int requiredPlayers, approvedCount, feeAmount;
  final String? participation;
  final double? distanceKm;

  int get openSpots =>
      (requiredPlayers - approvedCount).clamp(0, requiredPlayers).toInt();

  factory Game.fromJson(dynamic value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid game response.');
    }
    final parsedStartTime =
        DateTime.tryParse(value['start_time'] as String? ?? '');
    final startTime = parsedStartTime?.toLocal();
    final latitude = value['latitude'], longitude = value['longitude'];
    if (value['id'] is! String ||
        value['sport'] is! String ||
        startTime == null ||
        latitude is! num ||
        longitude is! num ||
        value['required_players'] is! num ||
        value['approved_count'] is! num) {
      throw const FormatException('Invalid game response.');
    }
    return Game(
      id: value['id'] as String,
      sport: value['sport'] as String,
      startTime: startTime,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      locationLabel: value['location_label'] as String? ?? 'Game location',
      requiredPlayers: (value['required_players'] as num).toInt(),
      feeAmount:
          value['fee_amount'] is num ? (value['fee_amount'] as num).toInt() : 0,
      approvedCount: (value['approved_count'] as num).toInt(),
      status: value['status'] as String? ?? 'open',
      organizerId: value['organizer_id'] as String? ?? '',
      organizerName: value['organizer_name'] as String? ?? 'Player',
      notes: value['notes'] as String? ?? '',
      participation: value['participation'] as String?,
      distanceKm: value['distance_km'] is num
          ? (value['distance_km'] as num).toDouble()
          : null,
      players: [
        for (final item in (value['players'] as List? ?? const []))
          if (item is Map && item['user_id'] is String)
            GamePlayer(
              userId: item['user_id'] as String,
              name: item['name'] as String? ?? 'Player',
              hasPhoto: item['has_photo'] == true,
            ),
      ],
    );
  }
}

class GamePlayer {
  const GamePlayer({required this.userId, required this.name, this.hasPhoto = false});
  final String userId, name;
  final bool hasPhoto;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}

class GameJoinRequest {
  const GameJoinRequest({
    required this.id,
    required this.userId,
    required this.name,
    required this.sports,
    this.roles = const {},
    this.levels = const {},
  });

  final String id, userId, name;
  final List<String> sports;

  /// Sport -> roles the player plays (e.g. Cricket -> [Batter]).
  final Map<String, List<String>> roles;

  /// Sport -> skill level (Beginner, Intermediate, Advanced).
  final Map<String, String> levels;

  factory GameJoinRequest.fromJson(dynamic value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['user_id'] is! String) {
      throw const FormatException('Invalid join request.');
    }
    return GameJoinRequest(
      id: value['id'] as String,
      userId: value['user_id'] as String,
      name: value['name'] as String? ?? 'Player',
      sports:
          (value['sports'] as List? ?? const []).whereType<String>().toList(),
      roles: {
        for (final entry in ((value['roles'] as Map?) ?? const {}).entries)
          if (entry.key is String && entry.value is List)
            entry.key as String:
                (entry.value as List).whereType<String>().toList(),
      },
      levels: {
        for (final entry in ((value['levels'] as Map?) ?? const {}).entries)
          if (entry.key is String && entry.value is String)
            entry.key as String: entry.value as String,
      },
    );
  }
}
