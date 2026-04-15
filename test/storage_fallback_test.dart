import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ordino/src/data/app_config/app_config_storage.dart';
import 'package:ordino/src/data/auth/auth_storage.dart';

void main() {
  test(
    'app config storage falls back when secure storage is unavailable',
    () async {
      final fallbackStore = _InMemoryPlainKeyValueStore();
      final storage = SecureAppConfigStorage(
        storage: _ThrowingFlutterSecureStorage(),
        fallbackStore: fallbackStore,
      );

      await storage.saveApiBaseUrl('https://example.test');
      expect(await storage.readApiBaseUrl(), 'https://example.test');

      await storage.clearApiBaseUrl();
      expect(await storage.readApiBaseUrl(), isNull);
    },
  );

  test('auth storage falls back when secure storage is unavailable', () async {
    final fallbackStore = _InMemoryPlainKeyValueStore();
    final storage = SecureAuthStorage(
      store: _ThrowingSecureKeyValueStore(),
      fallbackStore: fallbackStore,
    );

    await storage.saveToken('saved-token');
    expect(await storage.readToken(), 'saved-token');

    await storage.clearToken();
    expect(await storage.readToken(), isNull);
  });
}

class _InMemoryPlainKeyValueStore implements PlainKeyValueStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async => _values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }
}

class _ThrowingSecureKeyValueStore implements SecureKeyValueStore {
  @override
  Future<void> delete({required String key}) async {
    throw PlatformException(
      code: '-34018',
      message: 'A required entitlement is not present.',
    );
  }

  @override
  Future<String?> read({required String key}) async {
    throw PlatformException(
      code: '-34018',
      message: 'A required entitlement is not present.',
    );
  }

  @override
  Future<void> write({required String key, required String value}) async {
    throw PlatformException(
      code: '-34018',
      message: 'A required entitlement is not present.',
    );
  }
}

class _ThrowingFlutterSecureStorage extends FlutterSecureStorage {
  const _ThrowingFlutterSecureStorage();

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw PlatformException(
      code: '-34018',
      message: 'A required entitlement is not present.',
    );
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw PlatformException(
      code: '-34018',
      message: 'A required entitlement is not present.',
    );
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw PlatformException(
      code: '-34018',
      message: 'A required entitlement is not present.',
    );
  }
}
