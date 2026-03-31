import '../../domain/user_session.dart';
import '../http/api_client.dart';
import 'auth_storage.dart';
import 'models/token_dto.dart';
import 'models/user_profile_dto.dart';

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
    final normalizedUsername = username.trim();
    final normalizedPassword = password.trim();
    if (normalizedUsername.isEmpty || normalizedPassword.isEmpty) {
      throw const AuthException('Username and password are required.');
    }

    try {
      final tokenJson = await _apiClient.postJson(
        '/api/token/',
        body: <String, dynamic>{
          'username': normalizedUsername,
          'password': normalizedPassword,
        },
      );
      final token = TokenDto.fromJson(tokenJson).token;
      await _storage.saveToken(token);
      return await _fetchSession(token);
    } on ApiException catch (error) {
      throw AuthException(error.message);
    } on FormatException catch (error) {
      throw AuthException(error.message);
    }
  }

  Future<UserSession?> restoreSession() async {
    final token = await _storage.readToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      return await _fetchSession(token);
    } on ApiException {
      await _storage.clearToken();
      return null;
    } on FormatException {
      await _storage.clearToken();
      return null;
    }
  }

  Future<void> logout() async {
    await _storage.clearToken();
  }

  Future<UserSession> _fetchSession(String token) async {
    final meJson = await _apiClient.getJson('/api/me/', authToken: token);
    final profile = UserProfileDto.fromJson(meJson);
    return profile.toDomain(token);
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;
}
