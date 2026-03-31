abstract class AuthStorage {
  Future<void> saveToken(String token);

  Future<String?> readToken();

  Future<void> clearToken();
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
