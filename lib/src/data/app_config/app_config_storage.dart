import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

import '../auth/auth_storage.dart';

const String defaultMozartApiBaseUrl = String.fromEnvironment(
  'MOZART_API_BASE_URL',
  defaultValue: 'https://mozart.sibenik1983.hr',
);

String resolveApiBaseUrl(
  String? savedUrl, {
  String fallbackUrl = defaultMozartApiBaseUrl,
}) {
  if (savedUrl == null || savedUrl.trim().isEmpty) {
    return fallbackUrl;
  }
  return normalizeApiBaseUrl(savedUrl);
}

String normalizeApiBaseUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('Server URL je obavezan.');
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null ||
      !uri.hasScheme ||
      !uri.hasAuthority ||
      (uri.scheme != 'http' && uri.scheme != 'https')) {
    throw const FormatException('Unesite ispravan server URL.');
  }

  return trimmed.replaceAll(RegExp(r'/$'), '');
}

abstract class AppConfigStorage {
  Future<String?> readApiBaseUrl();

  Future<void> saveApiBaseUrl(String url);

  Future<void> clearApiBaseUrl();
}

class SecureAppConfigStorage implements AppConfigStorage {
  SecureAppConfigStorage({
    FlutterSecureStorage? storage,
    PlainKeyValueStore? fallbackStore,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _fallbackStore = fallbackStore ?? const SharedPreferencesKeyValueStore();

  static const String apiBaseUrlKey = 'mozart_api_base_url';

  final FlutterSecureStorage _storage;
  final PlainKeyValueStore _fallbackStore;

  @override
  Future<void> clearApiBaseUrl() async {
    try {
      await _storage.delete(key: apiBaseUrlKey);
    } on PlatformException {
      // Fallback cleanup still needs to run when Keychain is unavailable.
    }
    await _fallbackStore.delete(key: apiBaseUrlKey);
  }

  @override
  Future<String?> readApiBaseUrl() async {
    try {
      return await _storage.read(key: apiBaseUrlKey);
    } on PlatformException {
      return _fallbackStore.read(key: apiBaseUrlKey);
    }
  }

  @override
  Future<void> saveApiBaseUrl(String url) async {
    try {
      await _storage.write(key: apiBaseUrlKey, value: url);
      await _fallbackStore.delete(key: apiBaseUrlKey);
    } on PlatformException {
      await _fallbackStore.write(key: apiBaseUrlKey, value: url);
    }
  }
}

class InMemoryAppConfigStorage implements AppConfigStorage {
  InMemoryAppConfigStorage({this.apiBaseUrl});

  String? apiBaseUrl;

  @override
  Future<void> clearApiBaseUrl() async {
    apiBaseUrl = null;
  }

  @override
  Future<String?> readApiBaseUrl() async => apiBaseUrl;

  @override
  Future<void> saveApiBaseUrl(String url) async {
    apiBaseUrl = url;
  }
}
