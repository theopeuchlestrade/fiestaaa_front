# Supported build versions

Use a maintained LTS branch where upstream provides one, and the latest
supported stable otherwise. Reviewed on 2026-10-21:

- Flutter uses its stable channel, currently 3.47.7, and its bundled Dart SDK.
  Update the pubspec Flutter minimum, CI `FLUTTER_VERSION` and Docker build
  argument together. Private mobile workflows read this minimum from the
  selected frontend source. An older Docker bootstrap SDK is replaced and its
  final version verified before dependency resolution or compilation.
- Nginx uses the maintained 1.30 stable branch, currently 1.30.6, with its exact
  image digest and reviewed Alpine package security fixes. Stable is not LTS.
- Node 22 and Temurin Java 17 remain maintained LTS branches. Validate Android
  Gradle compatibility before changing Java.

Policies: [Flutter channels](https://docs.flutter.dev/install/archive),
[Nginx downloads](https://nginx.org/en/download.html),
[Node](https://github.com/nodejs/Release),
[Temurin](https://adoptium.net/support/).
