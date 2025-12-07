const String apiBaseUrl = String.fromEnvironment(
  'FIESTAAA_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8080',
);

const String googleWebClientId = String.fromEnvironment(
  'FIESTAAA_GOOGLE_WEB_CLIENT_ID',
  defaultValue:
      '900475997784-dlhlkhvo70sk0jpi72n32ugp85cq7etf.apps.googleusercontent.com',
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
  defaultValue:
      'BCyVeS1aOKK5gZLD7lKtr6U637mA5c3CZJCKle9jQdNEXsHT8drtq-2cC22vJ67OVHK82Epuefd8nqsV5NfPiKI',
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
