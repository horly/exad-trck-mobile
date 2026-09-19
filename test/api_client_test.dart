import 'dart:convert';

import 'package:exad_tracking_mobile/core/api/api_client.dart';
import 'package:exad_tracking_mobile/core/api/api_exception.dart';
import 'package:exad_tracking_mobile/core/session/session_controller.dart';
import 'package:exad_tracking_mobile/core/storage/token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'partage une rotation et rejoue le corps des requêtes concurrentes',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'mobile_access_token': 'old-access',
        'mobile_refresh_token': 'old-refresh',
        'mobile_session_id': 'old-session',
      });
      var refreshCalls = 0;
      Map<String, dynamic>? replayedCommand;

      final client = MockClient((request) async {
        final authorization = request.headers['authorization'];
        if (request.url.path.endsWith('/auth/refresh')) {
          refreshCalls++;
          expect(authorization, 'Bearer old-refresh');
          await Future<void>.delayed(const Duration(milliseconds: 15));
          return http.Response(
            jsonEncode({
              'data': {
                'tokens': {
                  'access_token': 'new-access',
                  'refresh_token': 'new-refresh',
                  'session_id': 'new-session',
                },
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        if (authorization == 'Bearer old-access') {
          return http.Response(
            jsonEncode({'message': 'Expired'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        }

        expect(authorization, 'Bearer new-access');
        if (request.url.path.endsWith('/dashboard')) {
          return http.Response(
            jsonEncode({'data': <String, dynamic>{}}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        replayedCommand = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({'message': 'Commande enregistrée'}),
          202,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = ApiClient(
        tokenStore: TokenStore(storage: const FlutterSecureStorage()),
        client: client,
        baseUrl: 'https://example.test/api/v1/mobile',
      );

      final results = await Future.wait<Object>([
        api.dashboard(),
        api.requestEngineCommand(7, 'immobilize', 2),
      ]);

      expect(refreshCalls, 1);
      expect(results.last, 'Commande enregistrée');
      expect(replayedCommand, {
        'action': 'immobilize',
        'output': 2,
        'confirmation': true,
      });
    },
  );

  test(
    'conserve les jetons si le renouvellement échoue temporairement',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'mobile_access_token': 'old-access',
        'mobile_refresh_token': 'old-refresh',
        'mobile_session_id': 'old-session',
      });
      final store = TokenStore(storage: const FlutterSecureStorage());
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          return http.Response(
            jsonEncode({'message': 'Service indisponible'}),
            503,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'message': 'Access token expiré'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = ApiClient(
        tokenStore: store,
        client: client,
        baseUrl: 'https://example.test/api/v1/mobile',
      );

      await expectLater(api.dashboard(), throwsA(isA<ApiException>()));

      final tokens = await store.readTokens();
      expect(tokens?.accessToken, 'old-access');
      expect(tokens?.refreshToken, 'old-refresh');
      expect(tokens?.sessionId, 'old-session');
    },
  );

  test(
    'garde la session en restauration si le serveur est indisponible',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'mobile_access_token': 'saved-access',
        'mobile_refresh_token': 'saved-refresh',
        'mobile_session_id': 'saved-session',
      });
      final store = TokenStore(storage: const FlutterSecureStorage());
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({'message': 'Maintenance temporaire'}),
          503,
          headers: {'content-type': 'application/json'},
        ),
      );
      final api = ApiClient(
        tokenStore: store,
        client: client,
        baseUrl: 'https://example.test/api/v1/mobile',
      );
      final session = SessionController(tokenStore: store, apiClient: api);

      await session.initialize();

      expect(session.stage, SessionStage.booting);
      expect(session.message, 'Maintenance temporaire');
      expect((await store.readTokens())?.refreshToken, 'saved-refresh');
    },
  );

  test(
    'efface les jetons uniquement si le renouvellement est refusé',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'mobile_access_token': 'revoked-access',
        'mobile_refresh_token': 'revoked-refresh',
        'mobile_session_id': 'revoked-session',
      });
      final store = TokenStore(storage: const FlutterSecureStorage());
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Jeton révoqué'}),
          401,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = ApiClient(
        tokenStore: store,
        client: client,
        baseUrl: 'https://example.test/api/v1/mobile',
      );

      await expectLater(api.dashboard(), throwsA(isA<ApiException>()));

      expect(await store.readTokens(), isNull);
    },
  );

  test('envoie la langue choisie aux flux événements et alertes', () async {
    FlutterSecureStorage.setMockInitialValues({
      'mobile_access_token': 'access-token',
      'mobile_refresh_token': 'refresh-token',
      'mobile_session_id': 'session-id',
    });
    final requestedPaths = <String>[];
    final client = MockClient((request) async {
      expect(request.headers['accept-language'], 'fr');
      requestedPaths.add(request.url.path);

      if (request.url.path.endsWith('/events')) {
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 11,
                'type': 'movement_started',
                'title': 'Début de déplacement',
                'message': 'Le véhicule a démarré.',
                'vehicle': {'name': 'Suzuki Horly'},
                'duration_seconds': 12,
                'started_at': '2026-09-18T12:00:00Z',
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }

      return http.Response(
        jsonEncode({
          'data': [
            {
              'id': 21,
              'type': 'overspeed',
              'severity': 'high',
              'status': 'new',
              'title': 'Excès de vitesse',
              'message': 'Limite dépassée.',
              'occurred_at': '2026-09-18T12:01:00Z',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiClient(
      tokenStore: TokenStore(storage: const FlutterSecureStorage()),
      client: client,
      baseUrl: 'https://example.test/api/v1/mobile',
    )..setLanguageCode('fr');

    final events = await api.notificationEvents();
    final alerts = await api.notificationAlerts();

    expect(events.single.title, 'Début de déplacement');
    expect(events.single.vehicle, 'Suzuki Horly');
    expect(events.single.durationSeconds, 12);
    expect(alerts.single.title, 'Excès de vitesse');
    expect(requestedPaths, ['/api/v1/mobile/events', '/api/v1/mobile/alerts']);
  });
}
