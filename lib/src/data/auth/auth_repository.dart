import '../../domain/user_session.dart';
import '../http/api_client.dart';
import 'auth_storage.dart';

class AuthRepository {
  AuthRepository({
    required ApiClient apiClient,
    required AuthStorage storage,
  })  : _apiClient = apiClient,
        _storage = storage;

  final ApiClient _apiClient;
  final AuthStorage _storage;

  Uri get tokenEndpoint => _apiClient.endpoint('/api/token/');

  Uri get meEndpoint => _apiClient.endpoint('/api/me/');

  Future<UserSession> login({
    required String username,
    required String password,
  }) async {
    if (username.trim().isEmpty || password.trim().isEmpty) {
      throw const AuthException('Username and password are required.');
    }

    final token = 'demo-token-${username.trim()}';
    await _storage.saveToken(token);

    return UserSession(
      token: token,
      fullName: 'Mozart Operator',
      email: username.trim(),
    );
  }

  Future<UserSession?> restoreSession() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    return UserSession(
      token: token,
      fullName: 'Mozart Operator',
      email: 'operator@mozart.local',
    );
  }

  Future<void> logout() async {
    await _storage.clearToken();
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;
}
