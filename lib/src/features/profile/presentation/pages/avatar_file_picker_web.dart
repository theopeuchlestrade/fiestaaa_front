import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

class AvatarFile {
  const AvatarFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

Future<AvatarFile?> pickAvatarFile() {
  final completer = Completer<AvatarFile?>();
  final input = (web.document.createElement('input') as web.HTMLInputElement)
    ..type = 'file'
    ..accept = 'image/jpeg,image/png,image/webp,image/*'
    ..multiple = false;
  input.setAttribute('style', 'display: none');

  void complete(AvatarFile? file) {
    if (!completer.isCompleted) {
      input.remove();
      completer.complete(file);
    }
  }

  void completeError(Object error) {
    if (!completer.isCompleted) {
      input.remove();
      completer.completeError(error);
    }
  }

  input.onChange.first
      .then((_) async {
        final files = input.files;
        if (files == null || files.length == 0) {
          complete(null);
          return;
        }

        final file = files.item(0);
        if (file == null) {
          complete(null);
          return;
        }

        try {
          final buffer = await file.arrayBuffer().toDart;
          complete(
            AvatarFile(
              name: file.name,
              bytes: Uint8List.fromList(buffer.toDart.asUint8List()),
            ),
          );
        } catch (error) {
          completeError(error);
        }
      })
      .catchError((Object error) {
        completeError(error);
        return null;
      });

  input.onError.first.then((event) {
    completeError(Exception('Unable to select avatar file: ${event.type}'));
  });

  input.addEventListener('cancel', ((web.Event _) => complete(null)).toJS);

  web.document.body?.appendChild(input);
  input.click();
  return completer.future;
}
