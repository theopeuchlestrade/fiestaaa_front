import 'dart:io';

String _argument(List<String> arguments, String name) {
  final prefix = '--$name=';
  final value = arguments
      .where((argument) => argument.startsWith(prefix))
      .map((argument) => argument.substring(prefix.length))
      .firstOrNull;
  if (value == null || value.trim().isEmpty) {
    throw ArgumentError('Missing required argument --$name');
  }
  return value.trim();
}

String _origin(Uri uri) {
  if (!uri.hasScheme || uri.host.isEmpty) {
    throw ArgumentError.value(uri, 'api-base-url', 'Must be an absolute URL');
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    throw ArgumentError.value(
      uri,
      'api-base-url',
      'Only HTTP and HTTPS URLs are supported',
    );
  }
  return uri.replace(path: '', query: null, fragment: null).toString();
}

void main(List<String> arguments) {
  final apiUri = Uri.parse(_argument(arguments, 'api-base-url'));
  final templatePath = _argument(arguments, 'template');
  final outputPath = _argument(arguments, 'output');
  final apiOrigin = _origin(apiUri);
  final wsOrigin = apiUri
      .replace(
        scheme: apiUri.scheme == 'https' ? 'wss' : 'ws',
        path: '',
        query: null,
        fragment: null,
      )
      .toString();

  final rendered = File(templatePath)
      .readAsStringSync()
      .replaceAll('{{FIESTAAA_API_ORIGIN}}', apiOrigin)
      .replaceAll('{{FIESTAAA_WS_ORIGIN}}', wsOrigin);
  if (rendered.contains('{{FIESTAAA_')) {
    throw StateError('The nginx template still contains unresolved values');
  }

  final output = File(outputPath);
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(rendered);
}
