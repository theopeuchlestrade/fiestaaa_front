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
- Node 22 and Temurin Java 17 remain maintained LTS branches.
- Android uses Gradle 9.8.2, AGP 9.4.1, Kotlin 2.4.21 and Google Services 4.5.0.
  AGP 9.4 requires Gradle >=9.6 and JDK 17. Kotlin documents full testing through
  Gradle 9.7/AGP 9.3, while permitting newer releases; the project's complete
  debug and release builds validate this current stable combination. Keep the
  Flutter compatibility opt-outs until all plugins support built-in Kotlin.

CI compiles web, Android debug/release APKs, an Android release app bundle and
an unsigned iOS release app. Android CI uses the local debug signing fallback;
official mobile signing remains in the private publication workflows.

Policies: [Flutter channels](https://docs.flutter.dev/install/archive),
[Nginx downloads](https://nginx.org/en/download.html),
[Node](https://github.com/nodejs/Release),
[Temurin](https://adoptium.net/support/).

Android policies: [AGP compatibility](https://developer.android.com/build/releases/gradle-plugin),
[Kotlin compatibility](https://kotlinlang.org/docs/gradle-configure-project.html),
[Gradle releases](https://gradle.org/releases/).
