class PendingTokenStorage {
  static final Map<String, String> _values = {};

  static String? read(String key) => _values[key];
  static void write(String key, String value) => _values[key] = value;
  static void remove(String key) => _values.remove(key);
}
