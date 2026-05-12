import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class AuthStorage {
  Future<void> saveToken(String token);

  Future<String?> readToken();

  Future<void> clearToken();

  Future<void> saveBaseUrl(String baseUrl);

  Future<String?> readBaseUrl();
}

abstract class SecureKeyValueStore {
  Future<void> write({required String key, required String value});

  Future<String?> read({required String key});

  Future<void> delete({required String key});
}

abstract class PlainKeyValueStore {
  Future<void> write({required String key, required String value});

  Future<String?> read({required String key});

  Future<void> delete({required String key});
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  FlutterSecureKeyValueStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

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
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }
}

class SharedPreferencesKeyValueStore implements PlainKeyValueStore {
  const SharedPreferencesKeyValueStore();

  Future<SharedPreferences> _prefs() {
    return SharedPreferences.getInstance();
  }

  @override
  Future<void> delete({required String key}) async {
    final prefs = await _prefs();
    await prefs.remove(key);
  }

  @override
  Future<String?> read({required String key}) async {
    final prefs = await _prefs();
    return prefs.getString(key);
  }

  @override
  Future<void> write({required String key, required String value}) async {
    final prefs = await _prefs();
    await prefs.setString(key, value);
  }
}

class SecureAuthStorage implements AuthStorage {
  SecureAuthStorage({
    SecureKeyValueStore? store,
    PlainKeyValueStore? fallbackStore,
  }) : _store = store ?? FlutterSecureKeyValueStore(),
       _fallbackStore = fallbackStore ?? const SharedPreferencesKeyValueStore();

  static const String tokenKey = 'mozart_auth_token';
  static const String baseUrlKey = 'mozart_api_base_url';

  final SecureKeyValueStore _store;
  final PlainKeyValueStore _fallbackStore;

  @override
  Future<void> clearToken() async {
    await _deleteFromAllStores(key: tokenKey);
  }

  @override
  Future<String?> readToken() async {
    try {
      return await _store.read(key: tokenKey);
    } on PlatformException {
      return _fallbackStore.read(key: tokenKey);
    }
  }

  @override
  Future<void> saveToken(String token) async {
    try {
      await _store.write(key: tokenKey, value: token);
      await _fallbackStore.delete(key: tokenKey);
    } on PlatformException {
      await _fallbackStore.write(key: tokenKey, value: token);
    }
  }

  @override
  Future<String?> readBaseUrl() async {
    try {
      return await _store.read(key: baseUrlKey);
    } on PlatformException {
      return _fallbackStore.read(key: baseUrlKey);
    }
  }

  @override
  Future<void> saveBaseUrl(String baseUrl) async {
    try {
      await _store.write(key: baseUrlKey, value: baseUrl);
      await _fallbackStore.delete(key: baseUrlKey);
    } on PlatformException {
      await _fallbackStore.write(key: baseUrlKey, value: baseUrl);
    }
  }

  Future<void> _deleteFromAllStores({required String key}) async {
    try {
      await _store.delete(key: key);
    } on PlatformException {
      // Fallback cleanup still needs to run when Keychain is unavailable.
    }
    await _fallbackStore.delete(key: key);
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
