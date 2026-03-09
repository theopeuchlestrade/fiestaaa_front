import 'query_param_sanitizer_stub.dart'
    if (dart.library.html) 'query_param_sanitizer_web.dart';

void removeSensitiveQueryParameters(List<String> keys) {
  removeQueryParameters(keys);
}
