import 'api_client.dart';
import 'secure_store.dart';

/// The authenticated user profile returned by login / `/auth/me`.
class ApiUser {
  final String id;
  final String name;
  final String? email;
  final List<String> roles;
  final String scope; // "read" or "read write"
  const ApiUser({required this.id, required this.name, this.email, this.roles = const [], this.scope = 'read'});

  bool get canWrite => scope.contains('write');

  factory ApiUser.fromJson(Map<String, dynamic> j, {String scope = 'read'}) {
    final rolesRaw = j['roles'];
    return ApiUser(
      id: (j['id'] ?? j['sub'] ?? '').toString(),
      name: (j['name'] ?? j['fullName'] ?? j['username'] ?? 'User').toString(),
      email: j['email']?.toString(),
      roles: rolesRaw is List ? rolesRaw.map((e) => e.toString()).toList() : const [],
      scope: (j['scope'] ?? scope).toString(),
    );
  }
}

class AuthResult {
  final ApiUser user;
  final String scope;
  const AuthResult(this.user, this.scope);
}

/// Auth endpoints: login / refresh / logout / me.
class AuthApi {
  AuthApi(this._client, this._store);
  final ApiClient _client;
  final SecureStore _store;

  Future<AuthResult> login({
    required String username,
    required String password,
    required String deviceName,
  }) async {
    final deviceId = await _store.deviceId();
    final m = await _client.postJson(
      '/auth/login',
      auth: false,
      body: {
        'username': username,
        'password': password,
        'deviceId': deviceId,
        'deviceName': deviceName,
      },
    );

    final access = m['accessToken'] as String?;
    final refresh = m['refreshToken'] as String?;
    if (access == null || refresh == null) {
      throw const ApiException('BAD_RESPONSE', 'Unexpected login response from the server.');
    }
    final scope = (m['scope'] ?? 'read').toString();
    _client.setAccessToken(access);
    await _store.saveTokens(access: access, refresh: refresh, scope: scope);

    final userJson = m['user'];
    final user = userJson is Map<String, dynamic>
        ? ApiUser.fromJson(userJson, scope: scope)
        : ApiUser(id: '', name: username, scope: scope);
    return AuthResult(user, scope);
  }

  Future<ApiUser> me() async {
    final m = await _client.getJson('/auth/me');
    final scope = await _store.scope ?? 'read';
    return ApiUser.fromJson(m, scope: scope);
  }

  Future<void> logout() async {
    final refresh = await _store.refreshToken;
    try {
      if (refresh != null && refresh.isNotEmpty) {
        await _client.postNoContent('/auth/logout', body: {'refreshToken': refresh});
      }
    } catch (_) {
      // Best-effort; clear locally regardless.
    }
    _client.setAccessToken(null);
    await _store.clearTokens();
  }
}
