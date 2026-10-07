import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;

import 'platform_http_client_stub.dart'
    if (dart.library.io) 'platform_http_client_native.dart'
    if (dart.library.js_interop) 'platform_http_client_web.dart';

/// Loads public avatar bytes through the same native transport as API calls.
/// Session authorization headers are deliberately not attached to image URLs.
class NativeHttpImage extends ImageProvider<NativeHttpImage> {
  const NativeHttpImage(
    this.url, {
    this.scale = 1,
    this.clientFactory = createPlatformHttpClient,
  });

  final String url;
  final double scale;
  final http.Client Function() clientFactory;

  @override
  Future<NativeHttpImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  // ImageProvider still uses this callback for custom providers.
  // ignore: deprecated_member_use
  ImageStreamCompleter loadImage(
    NativeHttpImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _load(decode),
      scale: scale,
      debugLabel: url,
    );
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final client = clientFactory();
    try {
      final uri = Uri.parse(url);
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw NetworkImageLoadException(
          statusCode: response.statusCode,
          uri: uri,
        );
      }
      if (response.bodyBytes.isEmpty) throw StateError('Empty image response');
      return await decode(
        await ui.ImmutableBuffer.fromUint8List(response.bodyBytes),
      );
    } catch (_) {
      scheduleMicrotask(() => PaintingBinding.instance.imageCache.evict(this));
      rethrow;
    } finally {
      client.close();
    }
  }

  @override
  bool operator ==(Object other) =>
      other is NativeHttpImage && other.url == url && other.scale == scale;

  @override
  int get hashCode => Object.hash(url, scale);
}
