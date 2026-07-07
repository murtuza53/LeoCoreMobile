import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper over [FlutterSecureStorage] (iOS Keychain / Android Keystore)
/// for the few sensitive values the app persists: server URL, tokens, deviceId.
class SecureStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kServer = 'server_url';
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kScope = 'token_scope';
  static const _kDeviceId = 'device_id';

  Future<String?> get serverUrl => _storage.read(key: _kServer);
  Future<void> setServerUrl(String v) => _storage.write(key: _kServer, value: v);

  Future<String?> get accessToken => _storage.read(key: _kAccess);
  Future<String?> get refreshToken => _storage.read(key: _kRefresh);
  Future<String?> get scope => _storage.read(key: _kScope);

  Future<void> saveTokens({
    required String access,
    required String refresh,
    String? scope,
  }) async {
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
    if (scope != null) await _storage.write(key: _kScope, value: scope);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kScope);
  }

  /// Stable per-install device id sent with login (used for refresh-token
  /// binding / per-seat licensing on the server).
  Future<String> deviceId() async {
    var id = await _storage.read(key: _kDeviceId);
    if (id == null || id.isEmpty) {
      final r = Random();
      final bytes = List<int>.generate(16, (_) => r.nextInt(256));
      id = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      await _storage.write(key: _kDeviceId, value: id);
    }
    return id;
  }
}
