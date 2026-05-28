import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

class AvatarFile {
  const AvatarFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

Future<AvatarFile?> pickAvatarFile() async {
  final selected = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 85,
    requestFullMetadata: false,
  );
  if (selected == null) return null;

  return AvatarFile(name: selected.name, bytes: await selected.readAsBytes());
}
