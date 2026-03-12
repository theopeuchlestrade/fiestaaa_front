import 'package:fiestaaa_front/src/features/auth/data/auth_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('logout sends bearer authorization when a token is provided', () async {
    late http.BaseRequest capturedRequest;
    final api = AuthApi(
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response('', 200);
      }),
    );

    await api.logout(token: 'native-session-token');

    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url.path, endsWith('/auth/logout'));
    expect(
      capturedRequest.headers['Authorization'],
      'Bearer native-session-token',
    );
  });

  test('logout omits authorization when no token is provided', () async {
    late http.BaseRequest capturedRequest;
    final api = AuthApi(
      client: MockClient((request) async {
        capturedRequest = request;
        return http.Response('', 200);
      }),
    );

    await api.logout();

    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url.path, endsWith('/auth/logout'));
    expect(capturedRequest.headers.containsKey('Authorization'), isFalse);
  });
}
