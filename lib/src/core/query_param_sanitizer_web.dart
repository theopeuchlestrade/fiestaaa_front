import 'package:web/web.dart' as web;

void removeQueryParameters(List<String> keys) {
  final current = Uri.base;
  final query = Map<String, String>.from(current.queryParameters);
  var changed = false;

  for (final key in keys) {
    changed = query.remove(key) != null || changed;
  }

  if (!changed) {
    return;
  }

  final sanitized = current.replace(
    queryParameters: query.isEmpty ? null : query,
  );
  web.window.history.replaceState(null, '', sanitized.toString());
}
