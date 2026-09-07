import 'dart:convert';

import 'package:exad_tracking_mobile/core/api/api_client.dart';
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
}
