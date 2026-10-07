# Dart JNI bindings resolve these native networking classes and members by name.
# R8 cannot see those references when shrinking a release APK or app bundle.
-keep class com.example.ok_http.** { *; }
-keep interface com.example.ok_http.** { *; }
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class okio.ByteString** { *; }
