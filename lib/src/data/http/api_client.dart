class ApiClient {
  const ApiClient({
    this.baseUrl = const String.fromEnvironment('MOZART_API_BASE_URL'),
  });

  final String baseUrl;

  Uri endpoint(String path) {
    final normalizedBase = baseUrl.isEmpty
        ? 'https://example.invalid'
        : baseUrl.replaceAll(RegExp(r'/$'), '');
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBase$normalizedPath');
  }
}
