const String apiBaseUrl = String.fromEnvironment(
  'FIESTAAA_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8080',
);

const String appBaseUrl = String.fromEnvironment(
  'FIESTAAA_APP_BASE_URL',
  defaultValue: 'https://fiestaaa.app',
);

const String googleWebClientId = String.fromEnvironment(
  'FIESTAAA_GOOGLE_WEB_CLIENT_ID',
  defaultValue: '',
);

const String appleServiceId = String.fromEnvironment(
  'FIESTAAA_APPLE_SERVICE_ID',
  defaultValue: '',
);

const String appleRedirectUri = String.fromEnvironment(
  'FIESTAAA_APPLE_REDIRECT_URI',
  defaultValue: '',
);

// Public VAPID key for FCM web push
const String fcmWebVapidKey = String.fromEnvironment(
  'FIESTAAA_FCM_VAPID_KEY',
  defaultValue: '',
);

Uri buildWsUri(String path, {Map<String, String>? queryParameters}) {
  final base = Uri.parse(apiBaseUrl);
  final scheme = base.scheme == 'https' ? 'wss' : 'ws';
  return Uri(
    scheme: scheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: path,
    queryParameters: queryParameters,
  );
}
