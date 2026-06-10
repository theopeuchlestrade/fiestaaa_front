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

const String sentryDsn = String.fromEnvironment(
  'FIESTAAA_SENTRY_DSN',
  defaultValue: '',
);

const String sentryEnvironment = String.fromEnvironment(
  'FIESTAAA_SENTRY_ENVIRONMENT',
  defaultValue: 'development',
);

const String sentryRelease = String.fromEnvironment(
  'FIESTAAA_SENTRY_RELEASE',
  defaultValue: '',
);

const String sentryTracesSampleRateValue = String.fromEnvironment(
  'FIESTAAA_SENTRY_TRACES_SAMPLE_RATE',
  defaultValue: '0',
);

double get sentryTracesSampleRate =>
    double.tryParse(sentryTracesSampleRateValue) ?? 0;

List<String> _buildPathSegments(Uri base, String path) {
  final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
  final relative = Uri.parse(normalizedPath);
  return <String>[
    ...base.pathSegments.where((segment) => segment.isNotEmpty),
    ...relative.pathSegments.where((segment) => segment.isNotEmpty),
  ];
}

Uri buildApiUri(String path, {Map<String, String>? queryParameters}) {
  final base = Uri.parse(apiBaseUrl);

  return base.replace(
    pathSegments: _buildPathSegments(base, path),
    queryParameters: queryParameters == null || queryParameters.isEmpty
        ? null
        : queryParameters,
  );
}

Uri buildWsUri(String path, {Map<String, String>? queryParameters}) {
  final base = Uri.parse(apiBaseUrl);
  final scheme = base.scheme == 'https' ? 'wss' : 'ws';

  return base.replace(
    scheme: scheme,
    pathSegments: _buildPathSegments(base, path),
    queryParameters: queryParameters == null || queryParameters.isEmpty
        ? null
        : queryParameters,
  );
}
