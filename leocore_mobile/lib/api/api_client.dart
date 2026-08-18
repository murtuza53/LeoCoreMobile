import 'package:dio/dio.dart';

import 'secure_store.dart';

/// Typed error mapped from the API's `{ "error": { code, message } }` envelope
/// (or from transport failures).
class ApiException implements Exception {
  final String code;
  final String message;
  final int? status;
  const ApiException(this.code, this.message, {this.status});

  bool get isAuth => status == 401 || code == 'UNAUTHENTICATED';
  bool get isForbidden => status == 403 || code == 'FORBIDDEN';

  /// The user's mobile access was revoked (never granted, turned off, or the
  /// seat was reassigned). Can arrive on login, refresh, or any data call.
  bool get isAccessRevoked => code == 'MOBILE_ACCESS_DISABLED';

  /// The account signed in on another device — this session is terminated.
  /// A hard sign-out (never refresh).
  bool get isSessionTerminated => code == 'SESSION_TERMINATED';

  @override
  String toString() => message;
}

/// Central HTTP client for `/api/mobile/v1`.
///
/// Responsibilities: build the base URL from the user's server address, attach
/// the Bearer access token, translate the error envelope into [ApiException],
/// and transparently refresh + retry once on a 401 (rotating refresh token).
class ApiClient {
  ApiClient(this._store) {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      contentType: Headers.jsonContentType,
      // Don't let dio throw on non-2xx — we translate the envelope ourselves.
      validateStatus: (_) => true,
    ));
  }

  final SecureStore _store;
  late final Dio _dio;

  String? _baseUrl; // e.g. https://leocoredemo.seksolution.com/api/mobile/v1
  String? _accessToken;

  /// Called on login/refresh to keep the in-memory token hot.
  void setAccessToken(String? token) => _accessToken = token;

  /// Normalizes a user-entered host into a full API base URL.
  static String normalizeBase(String server) {
    var s = server.trim();
    if (s.isEmpty) return s;
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      s = 'https://$s';
    }
    s = s.replaceAll(RegExp(r'/+$'), '');
    if (!s.contains('/api/mobile/v1')) s = '$s/api/mobile/v1';
    return s;
  }

  Future<void> useServer(String server) async {
    _baseUrl = normalizeBase(server);
  }

  String get baseUrl => _baseUrl ?? '';

  // Callback invoked when refresh fails and the session is unrecoverable.
  void Function()? onSessionExpired;

  /// Invoked when the server reports the user's mobile access was revoked
  /// (403 `MOBILE_ACCESS_DISABLED`). Carries the server's message. The app must
  /// clear tokens and return to login WITHOUT running the refresh flow.
  void Function(String message)? onAccessRevoked;

  /// The `error.code` from an envelope response, or null.
  String? _errorCode(Response<dynamic> res) {
    final data = res.data;
    if (data is Map && data['error'] is Map) {
      final c = (data['error'] as Map)['code'];
      return c?.toString();
    }
    return null;
  }

  Future<Map<String, dynamic>> getJson(String path, {Map<String, dynamic>? query}) async {
    final res = await _send('GET', path, query: query);
    return _asMap(res.data);
  }

  Future<List<dynamic>> getList(String path, {Map<String, dynamic>? query}) async {
    final res = await _send('GET', path, query: query);
    final data = res.data;
    if (data is List) return data;
    if (data is Map) {
      // Common pagination envelopes: {items:[...]} / {data:[...]} / {results:[...]}
      for (final k in ['items', 'data', 'results', 'value']) {
        if (data[k] is List) return data[k] as List;
      }
    }
    return const [];
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Object? body,
    bool auth = true,
    String? idempotencyKey,
  }) async {
    final res = await _send('POST', path, body: body, auth: auth, idempotencyKey: idempotencyKey);
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> patchJson(String path, {Object? body, bool auth = true}) async {
    final res = await _send('PATCH', path, body: body, auth: auth);
    return _asMap(res.data);
  }

  Future<Map<String, dynamic>> putJson(String path, {Object? body, bool auth = true}) async {
    final res = await _send('PUT', path, body: body, auth: auth);
    return _asMap(res.data);
  }

  Future<void> postNoContent(String path, {Object? body, bool auth = true}) async {
    await _send('POST', path, body: body, auth: auth);
  }

  Future<void> deleteNoContent(String path, {bool auth = true}) async {
    await _send('DELETE', path, auth: auth);
  }

  /// Uploads files as `multipart/form-data` under [field].
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required String field,
    required List<String> filePaths,
  }) async {
    final form = FormData();
    for (final p in filePaths) {
      form.files.add(MapEntry(field, await MultipartFile.fromFile(p)));
    }
    final res = await _send('POST', path, body: form);
    return _asMap(res.data);
  }

  /// Host origin without the `/api/mobile/v1` suffix — used to resolve
  /// server-relative asset URLs such as `/Files/Pictures/x.png`.
  String get origin {
    final b = _baseUrl ?? '';
    final i = b.indexOf('/api/mobile/v1');
    return i < 0 ? b : b.substring(0, i);
  }

  /// Bearer header for authenticated image loads.
  Map<String, String> get authHeaders =>
      _accessToken == null ? const {} : {'Authorization': 'Bearer $_accessToken'};

  /// Downloads binary content (e.g. a PDF). Returns the bytes plus the filename
  /// parsed from Content-Disposition (falls back to [fallbackName]).
  Future<({List<int> bytes, String filename, String contentType})> downloadBytes(
    String path, {
    Map<String, dynamic>? query,
    required String fallbackName,
  }) async {
    final res = await _send('GET', path, query: query, responseBytes: true);
    return _bytesResult(res, fallbackName);
  }

  /// POSTs [body] and expects a binary response (e.g. `POST /labels/print` → PDF).
  Future<({List<int> bytes, String filename, String contentType})> postBytes(
    String path, {
    Object? body,
    required String fallbackName,
  }) async {
    final res = await _send('POST', path, body: body, responseBytes: true);
    return _bytesResult(res, fallbackName);
  }

  ({List<int> bytes, String filename, String contentType}) _bytesResult(
      Response<dynamic> res, String fallbackName) {
    final data = res.data;
    final List<int> bytes = data is List<int> ? data : (data is String ? data.codeUnits : const []);
    var name = fallbackName;
    final cd = res.headers.value('content-disposition');
    if (cd != null) {
      final m = RegExp(r'filename\*?=(?:UTF-8'')?"?([^";]+)"?', caseSensitive: false).firstMatch(cd);
      if (m != null) name = Uri.decodeComponent(m.group(1)!.trim());
    }
    final ct = res.headers.value('content-type') ?? '';
    return (bytes: bytes, filename: name, contentType: ct);
  }

  Future<Response<dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
    bool auth = true,
    bool isRetry = false,
    bool responseBytes = false,
    String? idempotencyKey,
  }) async {
    if (_baseUrl == null || _baseUrl!.isEmpty) {
      throw const ApiException('NO_SERVER', 'No server address configured.');
    }
    final options = Options(
      method: method,
      responseType: responseBytes ? ResponseType.bytes : ResponseType.json,
      headers: {
        if (auth && _accessToken != null) 'Authorization': 'Bearer $_accessToken',
        // Safe-retry key: replaying the same key returns the original record
        // instead of creating a duplicate document.
        if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
      },
    );

    Response<dynamic> res;
    try {
      res = await _dio.request(
        '$_baseUrl$path',
        data: body,
        queryParameters: query,
        options: options,
      );
    } on DioException catch (e) {
      throw ApiException('NETWORK', _networkMessage(e));
    }

    // Hard sign-out cases — bounce to login immediately, never refresh:
    //  • 403 MOBILE_ACCESS_DISABLED — mobile access revoked.
    //  • 401 SESSION_TERMINATED — the account signed in on another device.
    final errCode = _errorCode(res);
    if ((res.statusCode == 403 && errCode == 'MOBILE_ACCESS_DISABLED') ||
        (res.statusCode == 401 && errCode == 'SESSION_TERMINATED')) {
      final ex = _envelope(res);
      onAccessRevoked?.call(ex.message);
      throw ex;
    }

    if (res.statusCode == 401 && auth && !isRetry) {
      // Try one rotating refresh, then retry the original request.
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return _send(method, path,
            query: query,
            body: body,
            auth: auth,
            isRetry: true,
            responseBytes: responseBytes,
            idempotencyKey: idempotencyKey);
      }
      onSessionExpired?.call();
    }

    if (res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300) {
      return res;
    }
    throw _envelope(res);
  }

  bool _refreshing = false;

  Future<bool> _tryRefresh() async {
    if (_refreshing) return false;
    _refreshing = true;
    try {
      final refresh = await _store.refreshToken;
      if (refresh == null || refresh.isEmpty) return false;
      final res = await _dio.post(
        '$_baseUrl/auth/refresh',
        data: {'refreshToken': refresh},
      );
      if (res.statusCode == 200) {
        final m = _asMap(res.data);
        final access = m['accessToken'] as String?;
        final newRefresh = m['refreshToken'] as String?;
        if (access != null && newRefresh != null) {
          _accessToken = access;
          await _store.saveTokens(access: access, refresh: newRefresh, scope: m['scope'] as String?);
          return true;
        }
      }
      // Access revoked during refresh → route to the access-revoked handler
      // (not a generic session-expiry) so the user sees the real reason.
      if (res.statusCode == 403 && _errorCode(res) == 'MOBILE_ACCESS_DISABLED') {
        onAccessRevoked?.call(_envelope(res).message);
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      _refreshing = false;
    }
  }

  ApiException _envelope(Response<dynamic> res) {
    final data = res.data;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      return ApiException(
        (err['code'] ?? 'ERROR').toString(),
        (err['message'] ?? 'Request failed.').toString(),
        status: res.statusCode,
      );
    }
    return ApiException('HTTP_${res.statusCode}', 'Request failed (${res.statusCode}).', status: res.statusCode);
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

  String _networkMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The server took too long to respond. Check your connection.';
      case DioExceptionType.connectionError:
        return 'Could not reach the server. Check the address and your connection.';
      case DioExceptionType.badCertificate:
        return 'The server certificate could not be verified.';
      default:
        return 'Network error. Please try again.';
    }
  }
}
