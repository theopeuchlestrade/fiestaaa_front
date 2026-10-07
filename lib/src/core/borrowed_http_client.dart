import 'package:http/http.dart' as http;

/// A disposable handle to a transport owned by the application process.
/// Closing one handle must not shut down connections used by another handle.
class BorrowedHttpClient extends http.BaseClient {
  BorrowedHttpClient(this._transport);

  final http.Client _transport;
  bool _closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (_closed) {
      throw http.ClientException('HTTP client is closed', request.url);
    }
    return _transport.send(request);
  }

  @override
  void close() => _closed = true;
}
