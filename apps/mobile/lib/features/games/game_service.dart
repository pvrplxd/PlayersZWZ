import 'dart:convert';
import 'dart:typed_data';

import '../../core/api_client.dart';
import '../location/location_service.dart';
import 'game_model.dart';

class GamePage {
  const GamePage(this.games, this.nextCursor, this.radiusKm);
  final List<Game> games;
  final String? nextCursor;
  final double radiusKm;
}

class GameService {
  const GameService(this.api);
  final ApiClient api;

  /// Player photos by user id, shared across screens for this app session.
  static final _photos = <String, Future<Uint8List?>>{};

  /// Avatar of an approved player in [gameId]; null when they have none.
  Future<Uint8List?> playerPhoto(String gameId, String userId) =>
      _photos.putIfAbsent(userId, () async {
        try {
          final response =
              await api.get('/api/v1/games/$gameId/players/$userId/photo');
          final photo = response is Map ? response['photo'] : null;
          if (photo is! Map || photo['image'] is! String) return null;
          return base64Decode(photo['image'] as String);
        } catch (_) {
          // Let a later bubble retry instead of caching the failure.
          Future.microtask(() => _photos.remove(userId));
          return null;
        }
      });

  Future<GamePage> nearby(
    Area area, {
    String? sport,
    String? timeWindow,
    double? radiusKm,
    String? cursor,
  }) async {
    final response = await api.get('/api/v1/games/open', query: {
      'latitude': '${area.latitude}',
      'longitude': '${area.longitude}',
      if (sport != null && sport != 'All') 'sport': sport,
      if (timeWindow != null) 'time_window': timeWindow,
      if (radiusKm != null) 'radius_km': '$radiusKm',
      if (cursor != null) 'cursor': cursor,
    });
    if (response is! Map || response['games'] is! List) {
      throw const FormatException('Could not read nearby games.');
    }
    return GamePage(
      (response['games'] as List).map(Game.fromJson).toList(),
      response['next_cursor']?.toString(),
      response['radius_km'] is num
          ? (response['radius_km'] as num).toDouble()
          : 10,
    );
  }

  Future<Game> create({
    required String sport,
    required DateTime startTime,
    required Area location,
    required int requiredPlayers,
    required int feeAmount,
    required String notes,
  }) async {
    final response = await api.post('/api/v1/games', body: {
      'sport': sport,
      'start_time': startTime.toUtc().toIso8601String(),
      'latitude': location.latitude,
      'longitude': location.longitude,
      'location_label': location.label,
      'required_players': requiredPlayers,
      'fee_amount': feeAmount,
      'notes': notes,
    });
    if (response is! Map) throw const FormatException('Could not create game.');
    return Game.fromJson(response['game']);
  }

  Future<Game> update({
    required String id,
    required String sport,
    required DateTime startTime,
    required Area location,
    required int requiredPlayers,
    required int feeAmount,
    required String notes,
  }) async {
    final response = await api.patch('/api/v1/games/$id', body: {
      'sport': sport,
      'start_time': startTime.toUtc().toIso8601String(),
      'latitude': location.latitude,
      'longitude': location.longitude,
      'location_label': location.label,
      'required_players': requiredPlayers,
      'fee_amount': feeAmount,
      'notes': notes,
    });
    if (response is! Map) throw const FormatException('Could not update game.');
    return Game.fromJson(response['game']);
  }

  Future<void> cancelGame(String id) async {
    await api.delete('/api/v1/games/$id');
  }

  Future<Game> details(String id) async {
    final response = await api.get('/api/v1/games/$id');
    if (response is! Map) throw const FormatException('Could not load game.');
    return Game.fromJson(response['game']);
  }

  Future<void> join(String id) async {
    await api.post('/api/v1/games/$id/join');
  }

  Future<void> cancel(String id) async {
    await api.delete('/api/v1/games/$id/join');
  }

  Future<List<GameJoinRequest>> requests(String id) async {
    final response = await api.get('/api/v1/games/$id/requests');
    if (response is! Map || response['requests'] is! List) {
      throw const FormatException('Could not load join requests.');
    }
    return (response['requests'] as List).map(GameJoinRequest.fromJson).toList();
  }

  Future<void> review(String requestId, {required bool approve}) async {
    await api.patch('/api/v1/join-requests/$requestId',
        body: {'action': approve ? 'approve' : 'reject'});
  }

  Future<Map<String, List<Game>>> activity() async {
    final response = await api.get('/api/v1/me/games');
    if (response is! Map) throw const FormatException('Could not load activity.');
    return {
      for (final key in ['hosted', 'joined', 'history'])
        key: (response[key] as List? ?? const []).map(Game.fromJson).toList(),
    };
  }
}
