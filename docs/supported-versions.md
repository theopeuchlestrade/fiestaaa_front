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

## Firebase compatibility (reviewed 2026-10-31)

Use `firebase_core` 4.15.2 and `firebase_messaging` 16.7.1 with the reviewed
Firebase Apple SDK 12.19.3 maintenance release. These updates retain the
existing notification registration, rotation and logout contract.

Firebase Core 5 / Messaging 17 select Firebase Apple SDK 13 through Swift
Package Manager. That SDK requires GTMSessionFetcher >=4, while the published
`google_sign_in_ios` plugin still selects GoogleSignIn 9, requiring
GTMSessionFetcher <4. GoogleSignIn 10.1 supports Firebase 13, but the official
Flutter plugin does not yet select it. Do not disable Swift Package Manager
or maintain an authentication plugin fork solely to bypass this conflict.

Dependabot defers Firebase Core 5.x, Messaging 17.x and Messaging platform
interface 4.11.x, which requires Core ^5.1.0. The pinned 4.10.0 test interface
remains aligned with Messaging 16. Maintenance updates remain enabled. Remove
these deferrals when the official Flutter Google Sign-In implementation supports a compatible native SDK and validate
the complete iOS build and notification lifecycle before adopting Firebase 17.

Sources: [Firebase Core changelog](https://pub.dev/packages/firebase_core/versions/4.15.2/changelog),
[Messaging changelog](https://pub.dev/packages/firebase_messaging/versions/16.7.1/changelog),
[Messaging platform interface 4.11.1](https://pub.dev/packages/firebase_messaging_platform_interface/versions/4.11.1),
[Google Sign-In Flutter implementation](https://pub.dev/packages/google_sign_in_ios),
[GoogleSignIn iOS 10.1 release](https://github.com/google/GoogleSignIn-iOS/releases/tag/10.1.0).
