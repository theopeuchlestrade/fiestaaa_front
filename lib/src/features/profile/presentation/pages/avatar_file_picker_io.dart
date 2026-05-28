import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

class AvatarFile {
  const AvatarFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

Future<AvatarFile?> pickAvatarFile() async {
  const typeGroup = XTypeGroup(
    label: 'images',
    extensions: ['jpg', 'jpeg', 'png', 'webp'],
    mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
    uniformTypeIdentifiers: ['public.image'],
    webWildCards: ['image/*'],
  );

  final selected = await openFile(acceptedTypeGroups: [typeGroup]);
  if (selected == null) return null;

  return AvatarFile(name: selected.name, bytes: await selected.readAsBytes());
}
