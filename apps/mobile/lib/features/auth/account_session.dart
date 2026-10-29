import 'package:firebase_auth/firebase_auth.dart';

import '../../core/api_client.dart';
import '../location/location_service.dart';

/// Server-confirmed account data. Authorization is always enforced by the API.
class AccountSession {
  const AccountSession({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.profileComplete = false,
    this.locationComplete = false,
    this.area,
  });

  final String userId;
  final String name;
  final String? email;
  final String role;
  final bool profileComplete;
  final bool locationComplete;
  final Area? area;

  factory AccountSession.fromJson(dynamic json, {required String expectedUid}) {
    if (json is Map<String, dynamic>) {
      final user = json['user'];
      final profile = json['profile'];
      final role = json['role'];
      if (user is Map<String, dynamic> &&
          profile is Map<String, dynamic> &&
          user['user_id'] == expectedUid &&
          profile['user_id'] == expectedUid &&
          profile['profile_id'] == expectedUid &&
          user['name'] is String &&
          (user['email'] == null || user['email'] is String) &&
          role is String &&
          role.isNotEmpty &&
          user['role'] == role &&
          user['status'] == 'active') {
        return AccountSession(
          userId: expectedUid,
          name: user['name'] as String,
          email: user['email'] as String?,
          role: role,
          profileComplete: profile['setup_complete'] == true,
          locationComplete: Area.fromProfile(profile) != null,
          area: Area.fromProfile(profile),
        );
      }
    }
    throw const ApiException(0, 'INVALID_RESPONSE',
        'Your account could not be loaded. Please try again.');
  }
}

class AccountSessionService {
  const AccountSessionService(this._api);

  final ApiClient _api;

  Future<AccountSession> establish(User user) async {
    final name = user.displayName?.trim();
    final body = {
      if (name != null && name.isNotEmpty) 'name': name,
    };
    dynamic json;
    try {
      json = await _api.post('/api/v1/auth/session', body: body);
    } on ApiException catch (error) {
      if (error.statusCode != 401) rethrow;
      // Refresh once; never loop on a rejected identity. Setup is idempotent.
      await user.getIdToken(true).timeout(const Duration(seconds: 20));
      json = await _api.post('/api/v1/auth/session', body: body);
    }
    return AccountSession.fromJson(json, expectedUid: user.uid);
  }
}
