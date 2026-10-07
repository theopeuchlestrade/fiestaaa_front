import 'package:fiestaaa_front/src/core/borrowed_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _Transport extends MockClient {
  _Transport() : super((_) async => http.Response('ok', 200));
  int closes = 0;

  @override
  void close() {
    closes++;
    throw StateError('Synchronous native TLS shutdown is unsafe');
  }
}

void main() {
  test(
    'closing an image handle leaves the shared API transport usable',
    () async {
      final transport = _Transport();
      final image = BorrowedHttpClient(transport);
      final api = BorrowedHttpClient(transport);
      expect(
        (await image.get(Uri.parse('https://example.invalid/avatar'))).body,
        'ok',
      );
      expect(image.close, returnsNormally);
      expect(image.close, returnsNormally);
      expect(transport.closes, 0);
      expect(
        (await api.get(Uri.parse('https://example.invalid/me'))).body,
        'ok',
      );
      expect(api.close, returnsNormally);
      expect(transport.closes, 0);
    },
  );

  test(
    'a closed handle rejects reuse while a fresh handle still works',
    () async {
      final transport = _Transport();
      final first = BorrowedHttpClient(transport)..close();
      await expectLater(
        first.get(Uri.parse('https://example.invalid/avatar')),
        throwsA(isA<http.ClientException>()),
      );
      final second = BorrowedHttpClient(transport);
      expect(
        (await second.get(
          Uri.parse('https://example.invalid/avatar'),
        )).statusCode,
        200,
      );
      second.close();
      expect(transport.closes, 0);
    },
  );
}
