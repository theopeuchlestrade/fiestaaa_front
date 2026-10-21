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
- Node 22 remains the tooling LTS branch. Node 26 is scheduled to enter LTS on
  2026-10-28; this change does not migrate Node.
- Android builds run on Temurin JDK 25 LTS, declared in `.java-version` and read
  by CI. Local `JAVA_HOME`, Flutter's `jdk-dir` and Android Studio's Gradle JDK
  must select that same major. The private Android publication workflow reads
  the version from the selected frontend source, falling back to JDK 17 for
  historical tags without `.java-version`. Java/Kotlin compilation targets
  remain 17; the build JDK is independent of Android's supported Java APIs.
- Android uses Gradle 9.8.2, AGP 9.4.1, Kotlin 2.4.21 and Google Services 4.5.0.
  AGP 9.4 requires Gradle >=9.6 and JDK >=17; Gradle supports running on
  Java 25 since 9.1. Kotlin documents full testing through
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
[Gradle releases](https://gradle.org/releases/),
[Gradle Java compatibility](https://docs.gradle.org/current/userguide/compatibility.html),
[Android build JDKs](https://developer.android.com/build/jdks).
