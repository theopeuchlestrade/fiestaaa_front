# fiestaaa_front

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Run the app

```bash
flutter run -d chrome --web-port=5001 --dart-define=FIESTAAA_API_BASE_URL=http://127.0.0.1:8080
```

```bash
flutter run -d chrome --web-port=5001 --dart-define=FIESTAAA_API_BASE_URL=http://127.0.0.1:8080 --dart-define=FIESTAAA_FCM_VAPID_KEY=your_fcm_vapid_key
```

```bash
flutter run -d emulator-5554 \
  --dart-define=FIESTAAA_API_BASE_URL=http://10.0.2.2:8080 \
  --dart-define=FIESTAAA_FCM_VAPID_KEY=your_fcm_vapid_key
```