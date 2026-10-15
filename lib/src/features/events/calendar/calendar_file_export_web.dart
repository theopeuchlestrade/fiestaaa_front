import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui';

import 'package:web/web.dart' as web;

Future<void> exportCalendarFile(
  Uint8List bytes,
  String fileName,
  Rect shareOrigin,
) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'text/calendar;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  try {
    web.document.body!.appendChild(anchor);
    anchor.click();
  } finally {
    anchor.remove();
    // Let the browser consume the object URL before releasing it.
    Timer(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
  }
}
