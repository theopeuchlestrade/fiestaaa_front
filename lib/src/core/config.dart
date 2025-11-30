const String apiBaseUrl = String.fromEnvironment(
  'FIESTAAA_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8080',
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
