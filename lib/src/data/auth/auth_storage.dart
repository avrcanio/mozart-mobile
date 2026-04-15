import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class AuthStorage {
  Future<void> saveToken(String token);

  Future<String?> readToken();

  Future<void> clearToken();
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
