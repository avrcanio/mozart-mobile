import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class AuthStorage {
  Future<void> saveToken(String token);

  Future<String?> readToken();

  Future<void> clearToken();
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

  final SecureKeyValueStore _store;

  @override
  Future<void> clearToken() {
    return _store.delete(key: tokenKey);
  }

  @override
  Future<String?> readToken() {
    return _store.read(key: tokenKey);
  }

  @override
  Future<void> saveToken(String token) {
    return _store.write(key: tokenKey, value: token);
  }
}

class InMemoryAuthStorage implements AuthStorage {
  String? _token;

  @override
  Future<void> clearToken() async {
    _token = null;
  }

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> saveToken(String token) async {
    _token = token;
  }
}
