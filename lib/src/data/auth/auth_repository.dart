import '../../domain/user_session.dart';
import '../http/api_client.dart';
import 'auth_storage.dart';
import 'models/token_dto.dart';
import 'models/user_profile_dto.dart';

class AuthRepository {
  AuthRepository({
    required ApiClient apiClient,
    required AuthStorage storage,
    this.logoutPath,
  })  : _apiClient = apiClient,
        _storage = storage;

  final ApiClient _apiClient;
  final AuthStorage _storage;
  final String? logoutPath;

  String get currentBaseUrl => _apiClient.baseUrl;

  void configureBaseUrl(String baseUrl) {
    _apiClient.setBaseUrl(baseUrl);
  }

  Future<String?> readStoredBaseUrl() {
    return _storage.readBaseUrl();
  }

  Future<void> saveBaseUrl(String baseUrl) async {
    try {
      final normalizedBaseUrl = normalizeApiBaseUrl(baseUrl);
      configureBaseUrl(normalizedBaseUrl);
      await _storage.saveBaseUrl(normalizedBaseUrl);
    } on FormatException catch (error) {
      throw AuthException(error.message);
    }
  }

  Future<void> clearBaseUrl() async {
    _apiClient.setBaseUrl('');
    await _storage.saveBaseUrl('');
  }

  Uri get tokenEndpoint => _apiClient.endpoint(path: '/api/token/');

  Uri get meEndpoint => _apiClient.endpoint(path: '/api/me/');

  Future<UserSession> login({
    required String username,
    required String password,
  }) async {
    final normalizedUsername = username.trim();
    final normalizedPassword = password.trim();
    if (_apiClient.baseUrl.trim().isEmpty) {
      throw const AuthException('URL servisa je obavezan.');
    }
    if (normalizedUsername.isEmpty || normalizedPassword.isEmpty) {
      throw const AuthException('Korisničko ime i lozinka su obavezni.');
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

  bool get supportsRemoteLogout =>
      logoutPath != null && logoutPath!.trim().isNotEmpty;

  Future<void> logout({String? authToken}) async {
    try {
      if (supportsRemoteLogout &&
          authToken != null &&
          authToken.trim().isNotEmpty) {
        await _apiClient.postJson(logoutPath!, authToken: authToken);
      }
    } on ApiException {
      // Local sign-out remains authoritative even if backend invalidation fails.
    } on FormatException {
      // Local sign-out remains authoritative even if backend invalidation fails.
    } finally {
      await _storage.clearToken();
    }
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
