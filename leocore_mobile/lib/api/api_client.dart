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

  /// One page of a paged list: `{ page, pageSize, total, hasMore, items }`.
  /// Falls back to `page * pageSize < total` (older servers) and then to
  /// "a full page came back" when the envelope has neither.
  Future<({List<dynamic> items, bool hasMore})> getPage(String path, {required Map<String, dynamic> query}) async {
    final res = await _send('GET', path, query: query);
    final data = res.data;
    if (data is List) return (items: data, hasMore: false);
    if (data is! Map) return (items: const <dynamic>[], hasMore: false);
    var items = const <dynamic>[];
    for (final k in ['items', 'data', 'results', 'value']) {
      if (data[k] is List) {
        items = data[k] as List;
        break;
      }
    }
    final hm = data['hasMore'];
    if (hm is bool) return (items: items, hasMore: hm);
    final total = data['total'];
    final page = data['page'] ?? query['page'];
    final size = data['pageSize'] ?? query['pageSize'];
    if (total is num && page is num && size is num) return (items: items, hasMore: page * size < total);
    return (items: items, hasMore: size is num && items.length >= size);
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

  Future<Map<String, dynamic>> deleteJson(String path, {bool auth = true}) async {
    final res = await _send('DELETE', path, auth: auth);
    return _asMap(res.data);
  }

  /// Uploads files as `multipart/form-data` under [field].
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required String field,
    required List<String> filePaths,
    Map<String, String>? fields,
  }) async {
    final form = FormData();
    fields?.forEach((k, v) => form.fields.add(MapEntry(k, v)));
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

  /// Fetches raw image bytes from an **absolute** URL (product photos live off
  /// the API base, e.g. `https://host/Files/Pictures/x.jpg`) using the same
  /// Bearer token and rotating-refresh retry as every other call. Returns null
  /// on any failure so the UI can show a graceful placeholder. This is more
  /// reliable than `Image.network(headers: …)`, which on some devices drops the
  /// auth header on redirects and renders a broken image.
  Future<List<int>?> getImageBytes(String url, {bool isRetry = false}) async {
    if (url.isEmpty) return null;
    Response<dynamic> res;
    try {
      res = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          headers: {if (_accessToken != null) 'Authorization': 'Bearer $_accessToken'},
          validateStatus: (_) => true,
        ),
      );
    } on DioException {
      return null;
    }
    if (res.statusCode == 401 && !isRetry) {
      if (await _tryRefresh()) return getImageBytes(url, isRetry: true);
      return null;
    }
    final code = res.statusCode ?? 0;
    if (code >= 200 && code < 300) {
      final data = res.data;
      // Guard against an HTML login page returned with 200 (cookie-auth hosts).
      final ct = (res.headers.value('content-type') ?? '').toLowerCase();
      if (ct.contains('text/html')) return null;
      if (data is List<int> && data.isNotEmpty) return data;
    }
    return null;
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

    // Hard sign-out: 403 MOBILE_ACCESS_DISABLED — mobile access revoked.
    // A 401 SESSION_TERMINATED is NOT trusted on a data call: a request still
    // carrying the previous access token can land while the server is rotating
    // the session's refresh token and see the session as momentarily ended.
    // It goes through the refresh below instead, and the refresh endpoint —
    // which knows whether another device really took over — decides.
    final errCode = _errorCode(res);
    final terminated = res.statusCode == 401 && errCode == 'SESSION_TERMINATED';
    if ((res.statusCode == 403 && errCode == 'MOBILE_ACCESS_DISABLED') ||
        (terminated && (isRetry || !auth))) {
      final ex = _envelope(res);
      onAccessRevoked?.call(ex.message);
      throw ex;
    }

    if (res.statusCode == 401 && auth && !isRetry) {
      // Try one rotating refresh, then retry the original request.
      final outcome = await _refresh();
      if (outcome == RefreshOutcome.ok) {
        return _send(method, path,
            query: query,
            body: body,
            auth: auth,
            isRetry: true,
            responseBytes: responseBytes,
            idempotencyKey: idempotencyKey);
      }
      // Only a refresh token the server rejected ends the session. If the
      // phone is offline, keep the session and report a network error.
      if (outcome == RefreshOutcome.offline) {
        throw const ApiException('NETWORK', 'No connection to the server. Check your internet and try again.');
      }
      // `revoked` already signed out with the server's own reason.
      if (outcome == RefreshOutcome.rejected) onSessionExpired?.call();
    }

    if (res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300) {
      return res;
    }
    throw _envelope(res);
  }

  Future<RefreshOutcome>? _inflightRefresh;

  /// Rotates the refresh token. Concurrent callers share one in-flight refresh:
  /// the server revokes the old token on use, so a second parallel refresh
  /// would be rejected and wrongly sign the user out.
  Future<RefreshOutcome> _refresh() =>
      _inflightRefresh ??= _doRefresh().whenComplete(() => _inflightRefresh = null);

  Future<bool> _tryRefresh() async => await _refresh() == RefreshOutcome.ok;

  /// Renews the session on app open / resume. Each refresh restarts the
  /// server's refresh-token lifetime, so a regularly used app stays signed in.
  Future<RefreshOutcome> renewSession() => _refresh();

  Future<RefreshOutcome> _doRefresh() async {
    final refresh = await _store.refreshToken;
    if (refresh == null || refresh.isEmpty) return RefreshOutcome.rejected;
    final Response<dynamic> res;
    try {
      res = await _dio.post(
        '$_baseUrl/auth/refresh',
        data: {'refreshToken': refresh},
      );
    } on DioException {
      return RefreshOutcome.offline;
    }
    if (res.statusCode == 200) {
      final m = _asMap(res.data);
      final access = m['accessToken'] as String?;
      final newRefresh = m['refreshToken'] as String?;
      if (access != null && newRefresh != null) {
        _accessToken = access;
        await _store.saveTokens(access: access, refresh: newRefresh, scope: m['scope'] as String?);
        return RefreshOutcome.ok;
      }
    }
    // Access revoked during refresh → route to the access-revoked handler
    // (not a generic session-expiry) so the user sees the real reason.
    final code = _errorCode(res);
    if ((res.statusCode == 403 && code == 'MOBILE_ACCESS_DISABLED') ||
        (res.statusCode == 401 && code == 'SESSION_TERMINATED')) {
      onAccessRevoked?.call(_envelope(res).message);
      return RefreshOutcome.revoked;
    }
    // A server error (5xx, proxy page) isn't a verdict on the token.
    if (res.statusCode == 401 || res.statusCode == 400 || res.statusCode == 403) {
      return RefreshOutcome.rejected;
    }
    return RefreshOutcome.offline;
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

/// Result of a refresh-token rotation.
enum RefreshOutcome {
  ok,

  /// The server refused the refresh token — the user must sign in again.
  rejected,

  /// Access was revoked or another device signed in. The client has already
  /// signed out via [ApiClient.onAccessRevoked] with the server's message.
  revoked,

  /// Network or server trouble — keep the session and try again later.
  offline,
}
