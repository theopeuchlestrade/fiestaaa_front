bool isSafeAbsoluteHttpUri(Uri uri) {
  if (!uri.hasScheme) return false;

  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    return false;
  }

  return uri.host.isNotEmpty;
}

Uri? tryParseSafeAbsoluteHttpUri(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(value);
  if (uri == null) {
    return null;
  }

  return isSafeAbsoluteHttpUri(uri) ? uri : null;
}
