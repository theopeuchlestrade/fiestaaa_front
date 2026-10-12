@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;
import 'package:fiestaaa_front/src/features/auth/data/session_storage.dart';
import 'package:fiestaaa_front/src/features/auth/domain/session_data.dart';
import 'package:fiestaaa_front/src/core/pending_token_storage.dart';
import 'package:fiestaaa_front/src/core/query_param_sanitizer_web.dart';

void main() {
  test(
    'browser stores identity hints without persisting bearer credentials',
    () async {
      await SessionStorage.clear();
      await SessionStorage.save(
        SessionData(
          token: 'fixture-bearer',
          email: 'qa@example.invalid',
          handle: 'guest',
          publicId: 'fixture-public-id',
        ),
      );
      final loaded = await SessionStorage.load();
      expect(loaded!.token, isEmpty);
      expect(loaded.email, 'qa@example.invalid');
      expect(loaded.publicId, 'fixture-public-id');
      expect(web.window.sessionStorage.getItem('fiestaaa_token'), isNull);
      expect(await SessionStorage.shouldProbeCookieSession(), isTrue);
      await SessionStorage.save(
        SessionData(token: 'other-bearer', email: 'other@example.invalid'),
      );
      final changed = await SessionStorage.load();
      expect(changed!.email, 'other@example.invalid');
      expect(changed.handle, isNull);
      expect(changed.publicId, isNull);
      await SessionStorage.clear();
      expect(await SessionStorage.load(), isNull);
      expect(await SessionStorage.shouldProbeCookieSession(), isFalse);
    },
  );
  test(
    'pending links survive read and are removed only on explicit completion',
    () {
      const key = 'coverage-fixture-link';
      PendingTokenStorage.write(key, 'fictional-token');
      expect(PendingTokenStorage.read(key), 'fictional-token');
      expect(PendingTokenStorage.read(key), 'fictional-token');
      PendingTokenStorage.remove(key);
      expect(PendingTokenStorage.read(key), isNull);
    },
  );
  test(
    'URL cleanup removes only sensitive fields and preserves destination and filters',
    () {
      final original = web.window.location.href;
      try {
        web.window.history.replaceState(
          null,
          '',
          '/events/7/items?token=fixture&q=dinner&view=invitations#needs',
        );
        removeQueryParameters(['token', 'missing']);
        final cleaned = Uri.parse(web.window.location.href);
        expect(cleaned.path, '/events/7/items');
        expect(cleaned.queryParameters, {'q': 'dinner', 'view': 'invitations'});
        expect(cleaned.fragment, 'needs');
        removeQueryParameters(['q', 'view']);
        expect(Uri.parse(web.window.location.href).query, isEmpty);
        final before = web.window.location.href;
        removeQueryParameters(['absent']);
        expect(web.window.location.href, before);
      } finally {
        web.window.history.replaceState(null, '', original);
      }
    },
  );
}
