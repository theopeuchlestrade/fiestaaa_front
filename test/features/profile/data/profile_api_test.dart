import 'dart:convert';

import 'package:fiestaaa_front/src/core/api_response.dart';
import 'package:fiestaaa_front/src/features/profile/data/profile_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const profileJson = {
    'email': 'alice@example.com',
    'handle': 'alice',
    'exp': 1893456000,
    'avatar_url': 'https://example.test/avatar.png',
  };

  test(
    'profile operations decode responses and send expected payloads',
    () async {
      final requests = <http.Request>[];
      final api = ProfileApi(
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/handles/availability')) {
            return http.Response('{"available":true}', 200);
          }
          if (request.method == 'DELETE') return http.Response('', 204);
          return http.Response(jsonEncode(profileJson), 200);
        }),
      );

      final profile = await api.fetchProfile('token');
      final available = await api.checkHandleAvailability('alice');
      final updated = await api.updateHandle(token: 'token', handle: 'alice');
      await api.deleteAccount(token: 'token');

      expect(profile.handle, 'alice');
      expect(profile.avatarUrl, 'https://example.test/avatar.png');
      expect(available, isTrue);
      expect(updated.email, 'alice@example.com');
      expect(requests[2].method, 'PATCH');
      expect(jsonDecode(requests[2].body), {'handle': 'alice'});
      expect(requests.every((request) => request.url.host.isNotEmpty), isTrue);
    },
  );

  test('profile errors preserve backend error codes', () async {
    final api = ProfileApi(
      client: MockClient(
        (_) async => http.Response('{"error":"handle_taken"}', 409),
      ),
    );

    await expectLater(
      api.updateHandle(token: 'token', handle: 'alice'),
      throwsA(
        isA<ApiException>().having((error) => error.statusCode, 'status', 409),
      ),
    );
  });
}
