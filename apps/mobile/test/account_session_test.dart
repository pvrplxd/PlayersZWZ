import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:playerszwz/core/api_client.dart';
import 'package:playerszwz/features/auth/account_session.dart';
import 'package:playerszwz/features/auth/account_session_gate.dart';
import 'package:playerszwz/features/auth/auth_service.dart';

class TestUser extends Fake implements User {
  @override
  String get uid => 'player-1';
  @override
  String? get displayName => 'Afaq Aamir';
  int refreshes = 0;
  Completer<void>? nameUpdate;
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    if (forceRefresh) refreshes++;
    return forceRefresh || refreshes > 0 ? 'refreshed-token' : 'test-token';
  }

  @override
  Future<void> updateDisplayName(String? displayName) async {
    await nameUpdate?.future;
  }
}

class TestCredential extends Fake implements UserCredential {
  TestCredential(this.user);
  @override
  final User user;
}

class TestFirebaseAuth extends Fake implements FirebaseAuth {
  final events = StreamController<User?>.broadcast(sync: true);
  final user = TestUser();
  @override
  User? get currentUser => user;
  @override
  Stream<User?> authStateChanges() => events.stream;
  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    events.add(user);
    return TestCredential(user);
  }
}

Map<String, Object?> accountJson() => {
      'user': {
        'user_id': 'player-1',
        'name': 'Afaq Aamir',
        'email': 'afaq@example.com',
        'role': 'player',
        'status': 'active',
      },
      'profile': {'profile_id': 'player-1', 'user_id': 'player-1'},
      'role': 'player',
    };

void main() {
  test('session posts a verified token and name, accepts the server account',
      () async {
    final user = TestUser();
    final api = ApiClient(
      baseUrl: 'https://example.com/',
      accessTokenProvider: user.getIdToken,
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/auth/session');
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(jsonDecode(request.body), {'name': 'Afaq Aamir'});
        return http.Response(jsonEncode(accountJson()), 200);
      }),
    );
    addTearDown(api.close);
    final account = await AccountSessionService(api).establish(user);
    expect(account.userId, user.uid);
    expect(account.email, 'afaq@example.com');
    expect(account.role, 'player');
  });

  test('rejected token refreshes once; repeated rejection stops', () async {
    for (final succeeds in [true, false]) {
      final user = TestUser();
      var calls = 0;
      final api = ApiClient(
        baseUrl: 'https://example.com',
        accessTokenProvider: user.getIdToken,
        client: MockClient((request) async {
          calls++;
          if (calls == 2) {
            expect(request.headers['Authorization'], 'Bearer refreshed-token');
            if (succeeds) return http.Response(jsonEncode(accountJson()), 200);
          }
          return http.Response(
              '{"error":{"code":"INVALID_TOKEN","message":"Invalid token"}}',
              401);
        }),
      );
      addTearDown(api.close);
      final future = AccountSessionService(api).establish(user);
      if (succeeds) {
        expect((await future).userId, user.uid);
      } else {
        await expectLater(future, throwsA(isA<ApiException>()));
      }
      expect(calls, 2);
      expect(user.refreshes, 1);
    }
  });

  test('malformed, cross-account, and inactive responses never grant entry',
      () {
    for (final json in [
      null,
      <String, dynamic>{},
      {
        ...accountJson(),
        'profile': {'profile_id': 'other', 'user_id': 'other'}
      },
      {...accountJson(), 'role': 'admin'},
      {
        ...accountJson(),
        'user': {'user_id': 'player-1', 'status': 'suspended'}
      },
    ]) {
      expect(() => AccountSession.fromJson(json, expectedUid: 'player-1'),
          throwsA(isA<ApiException>()));
    }
  });

  test('missing configuration or token prevents requests; slow API times out',
      () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return http.Response('{}', 200);
    });
    for (final configuration in [
      ('', 'token', 'CONFIGURATION_ERROR'),
      ('https://example.com', null, 'UNAUTHORIZED'),
      ('https://example.com', 'token', 'REQUEST_TIMEOUT')
    ]) {
      final api = ApiClient(
        baseUrl: configuration.$1,
        accessTokenProvider: () async => configuration.$2,
        client: client,
        requestTimeout: const Duration(milliseconds: 5),
      );
      await expectLater(
          api.post('/api/v1/auth/session', body: {}),
          throwsA(isA<ApiException>()
              .having((e) => e.code, 'code', configuration.$3)));
    }
    expect(calls, 1);
    client.close();
  });

  test('auth event waits until signup display-name update completes', () async {
    final firebase = TestFirebaseAuth();
    firebase.user.nameUpdate = Completer<void>();
    final auth = AuthService(firebaseAuth: firebase);
    final received = <User?>[];
    final subscription = auth.userChanges.listen(received.add);
    final signup = auth.createAccount(
        email: 'afaq@example.com',
        password: 'password123',
        displayName: 'Afaq Aamir');
    await Future<void>.delayed(Duration.zero);
    expect(received, isEmpty);
    firebase.user.nameUpdate!.complete();
    await signup;
    await Future<void>.delayed(Duration.zero);
    expect(received, [firebase.user]);
    await subscription.cancel();
    await firebase.events.close();
  });

  const account = AccountSession(
      userId: 'player-1',
      name: 'Afaq',
      email: 'afaq@example.com',
      role: 'player');
  Widget gate(
          {required Future<AccountSession> Function() load,
          Future<void> Function()? signOut,
          String identity = 'player-1'}) =>
      MaterialApp(
        home: AccountSessionGate(
          key: ValueKey(identity),
          loadSession: load,
          signOut: signOut ?? () async {},
          builder: (_) => const Text('Account ready'),
        ),
      );

  testWidgets('restored identity loads once across rebuilds and gates entry',
      (tester) async {
    var calls = 0;
    final pending = Completer<AccountSession>();
    Future<AccountSession> load() {
      calls++;
      return pending.future;
    }

    await tester.pumpWidget(gate(load: load));
    expect(find.text('Loading your account…'), findsOneWidget);
    expect(find.text('Account ready'), findsNothing);
    await tester.pumpWidget(gate(load: load));
    expect(calls, 1);
    pending.complete(account);
    await tester.pumpAndSettle();
    expect(find.text('Account ready'), findsOneWidget);
  });

  testWidgets(
      'network failure permits one retry and sign-out failure can recover',
      (tester) async {
    var calls = 0;
    var signOuts = 0;
    final retry = Completer<AccountSession>();
    await tester.pumpWidget(gate(load: () async {
      calls++;
      if (calls == 1) throw const ApiException(0, 'NETWORK_ERROR', 'offline');
      return retry.future;
    }, signOut: () async {
      signOuts++;
      throw StateError('offline');
    }));
    await tester.pumpAndSettle();
    expect(find.text('Account ready'), findsNothing);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(signOuts, 1);
    expect(find.text('Could not sign out. Please try again.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Try again'), findsNothing);
    expect(calls, 2);
    retry.complete(account);
    await tester.pumpAndSettle();
    expect(find.text('Account ready'), findsOneWidget);
  });

  testWidgets('suspension blocks entry and retry, leaving sign-out available',
      (tester) async {
    await tester.pumpWidget(gate(
        load: () async =>
            throw const ApiException(403, 'ACCOUNT_SUSPENDED', 'suspended')));
    await tester.pumpAndSettle();
    expect(find.text('Account ready'), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Try again'), findsNothing);
    expect(find.text('Sign out').hitTestable(), findsOneWidget);
  });

  testWidgets(
      'late result from a previous identity cannot unlock another account',
      (tester) async {
    final previous = Completer<AccountSession>();
    final current = Completer<AccountSession>();
    await tester.pumpWidget(gate(load: () => previous.future));
    await tester
        .pumpWidget(gate(load: () => current.future, identity: 'player-2'));
    previous.complete(account);
    await tester.pump();
    expect(find.text('Account ready'), findsNothing);
    expect(find.text('Loading your account…'), findsOneWidget);
    // Disposing while the current request is pending must also be safe.
    await tester.pumpWidget(const SizedBox());
    current.complete(account);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
