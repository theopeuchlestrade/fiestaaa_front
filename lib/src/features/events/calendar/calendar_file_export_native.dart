import 'dart:typed_data';
import 'dart:ui';

import 'package:share_plus/share_plus.dart';

Future<void> exportCalendarFile(
  Uint8List bytes,
  String fileName,
  Rect shareOrigin,
) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, mimeType: 'text/calendar', name: fileName)],
      fileNameOverrides: [fileName],
      sharePositionOrigin: shareOrigin,
    ),
  );
}
