import 'dart:async';
import 'dart:ui' as ui;

import 'package:fiestaaa_front/src/core/native_http_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _TrackingClient extends MockClient {
  _TrackingClient(super.handler);
  bool closed = false;

  @override
  void close() {
    closed = true;
    super.close();
  }
}

Future<ImageInfo> _resolve(NativeHttpImage provider) async {
  final result = Completer<ImageInfo>();
  final stream = provider.resolve(ImageConfiguration.empty);
  final listener = ImageStreamListener(
    (image, _) => result.complete(image),
    onError: (error, stack) => result.completeError(error, stack),
  );
  stream.addListener(listener);
  try {
    return await result.future;
  } finally {
    stream.removeListener(listener);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  test(
    'decodes and caches avatar bytes without attaching session credentials',
    () async {
      var calls = 0;
      final recorder = ui.PictureRecorder();
      ui.Canvas(
        recorder,
      ).drawColor(const ui.Color(0xFF00FF00), ui.BlendMode.src);
      final picture = recorder.endRecording();
      final sourceImage = await picture.toImage(1, 1);
      final png = (await sourceImage.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      sourceImage.dispose();
      picture.dispose();
      final client = _TrackingClient((request) async {
        calls++;
        expect(request.url, Uri.parse('https://example.invalid/avatar.png'));
        expect(request.headers.containsKey('authorization'), isFalse);
        return http.Response.bytes(png, 200);
      });
      final provider = NativeHttpImage(
        'https://example.invalid/avatar.png',
        clientFactory: () => client,
      );
      final image = await _resolve(provider);
      expect(image.image.width, 1);
      expect(client.closed, isTrue);
      await _resolve(provider);
      expect(calls, 1);
    },
  );

  test('a failed download closes its client and can be retried', () async {
    final clients = <_TrackingClient>[];
    final provider = NativeHttpImage(
      'https://example.invalid/missing.png',
      clientFactory: () {
        final client = _TrackingClient((_) async => http.Response('', 404));
        clients.add(client);
        return client;
      },
    );
    await expectLater(
      _resolve(provider),
      throwsA(isA<NetworkImageLoadException>()),
    );
    await Future<void>.delayed(Duration.zero);
    await expectLater(
      _resolve(provider),
      throwsA(isA<NetworkImageLoadException>()),
    );
    expect(clients, hasLength(2));
    expect(clients.every((client) => client.closed), isTrue);
  });

  test(
    'an empty successful response is rejected and resources are released',
    () async {
      final client = _TrackingClient((_) async => http.Response('', 200));
      final provider = NativeHttpImage(
        'https://example.invalid/empty.png',
        clientFactory: () => client,
      );
      await expectLater(_resolve(provider), throwsStateError);
      expect(client.closed, isTrue);
    },
  );
}
