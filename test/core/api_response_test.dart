import 'package:fiestaaa_front/src/core/api_response.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('apiExceptionFromResponse prefers non-empty details', () {
    final exception = apiExceptionFromResponse(
      http.Response(
        '{"error":"invalid_request","details":"Champ invalide"}',
        400,
      ),
      fallbackMessage: 'Erreur API',
    );

    expect(exception.message, 'Champ invalide');
    expect(exception.code, 'invalid_request');
    expect(exception.statusCode, 400);
  });

  test('apiExceptionFromResponse falls back to error code', () {
    final exception = apiExceptionFromResponse(
      http.Response('{"error":"not_found","details":""}', 404),
      fallbackMessage: 'Erreur API',
    );

    expect(exception.message, 'not_found');
    expect(exception.code, 'not_found');
    expect(exception.statusCode, 404);
  });

  test(
    'apiExceptionFromResponse keeps string error with malformed details',
    () {
      final exception = apiExceptionFromResponse(
        http.Response(
          '{"error":"bad_payload","details":{"field":"email"}}',
          422,
        ),
        fallbackMessage: 'Erreur API',
      );

      expect(exception.message, 'bad_payload');
      expect(exception.code, 'bad_payload');
      expect(exception.statusCode, 422);
    },
  );

  test(
    'apiExceptionFromResponse uses fallback for invalid response bodies',
    () {
      final exception = apiExceptionFromResponse(
        http.Response('<html>server error</html>', 502),
        fallbackMessage: 'Erreur API',
      );

      expect(exception.message, 'Erreur API (502)');
      expect(exception.code, isNull);
      expect(exception.statusCode, 502);
    },
  );
}
