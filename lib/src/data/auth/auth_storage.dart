import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class AuthStorage {
  Future<void> saveToken(String token);

  Future<String?> readToken();

  Future<void> clearToken();

  Future<void> saveBaseUrl(String baseUrl);

  Future<String?> readBaseUrl();
}

abstract class SecureKeyValueStore {
  Future<void> write({
    required String key,
    required String value,
  });

  Future<String?> read({
    required String key,
  });

  Future<void> delete({
    required String key,
  });
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete({required String key}) {
    return _storage.delete(key: key);
  }

  @override
  Future<String?> read({required String key}) {
    return _storage.read(key: key);
  }

  @override
  Future<void> write({
    required String key,
    required String value,
  }) {
    return _storage.write(key: key, value: value);
  }
}

class SecureAuthStorage implements AuthStorage {
  SecureAuthStorage({
    SecureKeyValueStore? store,
  }) : _store = store ?? FlutterSecureKeyValueStore();

  static const String tokenKey = 'mozart_auth_token';
  static const String baseUrlKey = 'mozart_api_base_url';

  final SecureKeyValueStore _store;

  @override
  Future<void> clearToken() {
    return _store.delete(key: tokenKey);
  }

  @override
  Future<String?> readBaseUrl() {
    return _store.read(key: baseUrlKey);
  }

  @override
  Future<String?> readToken() {
    return _store.read(key: tokenKey);
  }

  @override
  Future<void> saveBaseUrl(String baseUrl) {
    return _store.write(key: baseUrlKey, value: baseUrl);
  }

  @override
  Future<void> saveToken(String token) {
    return _store.write(key: tokenKey, value: token);
  }
}

class InMemoryAuthStorage implements AuthStorage {
  String? _token;
  String? _baseUrl;

  @override
  Future<void> clearToken() async {
    _token = null;
  }

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<String?> readBaseUrl() async => _baseUrl;

  @override
  Future<void> saveBaseUrl(String baseUrl) async {
    _baseUrl = baseUrl;
  }

  @override
  Future<void> saveToken(String token) async {
    _token = token;
  }
}
