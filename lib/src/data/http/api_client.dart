import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef JsonMap = Map<String, dynamic>;

class ApiClient {
  ApiClient({
    this.baseUrl = const String.fromEnvironment(
      'MOZART_API_BASE_URL',
      defaultValue: 'https://mozart.sibenik1983.hr',
    ),
    this.requestTimeout = const Duration(seconds: 15),
    ApiTransport? transport,
  }) : _transport = transport ?? HttpApiTransport();

  final String baseUrl;
  final Duration requestTimeout;
  final ApiTransport _transport;

  Future<JsonMap> getJson(
    String path, {
    String? authToken,
    Map<String, String>? queryParameters,
    Iterable<MapEntry<String, String>>? queryParametersList,
  }) async {
    final response = await _send(
      ApiRequest(
        method: 'GET',
        uri: _endpoint(
          path,
          queryParameters: queryParameters,
          queryParametersList: queryParametersList,
        ),
        headers: _headers(authToken: authToken),
      ),
    );
    return _decodeMap(response);
  }

  Future<JsonMap> getJsonUri(
    Uri uri, {
    String? authToken,
  }) async {
    final response = await _send(
      ApiRequest(
        method: 'GET',
        uri: uri,
        headers: _headers(authToken: authToken),
      ),
    );
    return _decodeMap(response);
  }

  Future<List<dynamic>> getJsonList(
    String path, {
    String? authToken,
    Map<String, String>? queryParameters,
    Iterable<MapEntry<String, String>>? queryParametersList,
  }) async {
    final response = await _send(
      ApiRequest(
        method: 'GET',
        uri: _endpoint(
          path,
          queryParameters: queryParameters,
          queryParametersList: queryParametersList,
        ),
        headers: _headers(authToken: authToken),
      ),
    );

    final decoded = _decode(response.body);
    if (decoded is List<dynamic>) {
      return decoded;
    }
    if (decoded is JsonMap && decoded['results'] is List<dynamic>) {
      return decoded['results'] as List<dynamic>;
    }
    throw ApiException(
      'Expected a JSON list response.',
      statusCode: response.statusCode,
      uri: response.request.uri,
    );
  }

  Future<JsonMap> postJson(
    String path, {
    JsonMap? body,
    String? authToken,
  }) async {
    final response = await _send(
      ApiRequest(
        method: 'POST',
        uri: _endpoint(path),
        headers: _headers(authToken: authToken),
        body: body == null ? null : jsonEncode(body),
      ),
    );
    return _decodeMap(response);
  }

  Future<JsonMap> patchJson(
    String path, {
    required JsonMap body,
    String? authToken,
  }) async {
    final response = await _send(
      ApiRequest(
        method: 'PATCH',
        uri: _endpoint(path),
        headers: _headers(authToken: authToken),
        body: jsonEncode(body),
      ),
    );
    return _decodeMap(response);
  }

  Future<JsonMap> putJson(
    String path, {
    required JsonMap body,
    String? authToken,
  }) async {
    final response = await _send(
      ApiRequest(
        method: 'PUT',
        uri: _endpoint(path),
        headers: _headers(authToken: authToken),
        body: jsonEncode(body),
      ),
    );
    return _decodeMap(response);
  }

  Uri endpoint({
    required String path,
    Map<String, String>? queryParameters,
    Iterable<MapEntry<String, String>>? queryParametersList,
  }) => _endpoint(
        path,
        queryParameters: queryParameters,
        queryParametersList: queryParametersList,
      );

  Future<void> probeReachability({
    String path = '/api/me/',
  }) async {
    final request = ApiRequest(
      method: 'GET',
      uri: _endpoint(path),
      headers: _headers(),
    );

    try {
      await _transport.send(request).timeout(requestTimeout);
    } on SocketException {
      throw ApiException(
        'Veza s Mozart servisom trenutno nije dostupna. Pokusajte ponovno za nekoliko trenutaka.',
        uri: request.uri,
        isConnectivityIssue: true,
      );
    } on HandshakeException {
      throw ApiException(
        'Veza s Mozart servisom trenutno nije dostupna. Pokusajte ponovno za nekoliko trenutaka.',
        uri: request.uri,
        isConnectivityIssue: true,
      );
    } on HttpException {
      throw ApiException(
        'Veza s Mozart servisom trenutno nije dostupna. Pokusajte ponovno za nekoliko trenutaka.',
        uri: request.uri,
        isConnectivityIssue: true,
      );
    } on TimeoutException {
      throw ApiException(
        'Veza s Mozart servisom je prespora ili privremeno nedostupna. Pokusajte ponovno za nekoliko trenutaka.',
        uri: request.uri,
        isConnectivityIssue: true,
      );
    }
  }

  Uri _endpoint(
    String path, {
    Map<String, String>? queryParameters,
    Iterable<MapEntry<String, String>>? queryParametersList,
  }) {
    if (baseUrl.isEmpty) {
      throw const ApiException(
        'Missing API base URL.',
      );
    }

    final normalizedBase = baseUrl.replaceAll(RegExp(r'/$'), '');
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$normalizedBase$normalizedPath');
    final allEntries = <MapEntry<String, String>>[
      if (queryParametersList != null) ...queryParametersList,
      if (queryParameters != null) ...queryParameters.entries,
    ];
    if (allEntries.isEmpty) {
      return uri;
    }
    final query = allEntries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
    return uri.replace(query: query);
  }

  Map<String, String> _headers({String? authToken}) {
    return <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (authToken != null && authToken.isNotEmpty)
        'Authorization': 'Token $authToken',
    };
  }

  Future<ApiResponse> _send(ApiRequest request) async {
    late final ApiResponse response;
    try {
      response = await _transport.send(request).timeout(requestTimeout);
    } on SocketException {
      throw ApiException(
        'Veza s Mozart servisom trenutno nije dostupna. Pokusajte ponovno za nekoliko trenutaka.',
        uri: request.uri,
        isConnectivityIssue: true,
      );
    } on HandshakeException {
      throw ApiException(
        'Veza s Mozart servisom trenutno nije dostupna. Pokusajte ponovno za nekoliko trenutaka.',
        uri: request.uri,
        isConnectivityIssue: true,
      );
    } on HttpException {
      throw ApiException(
        'Veza s Mozart servisom trenutno nije dostupna. Pokusajte ponovno za nekoliko trenutaka.',
        uri: request.uri,
        isConnectivityIssue: true,
      );
    } on TimeoutException {
      throw ApiException(
        'Veza s Mozart servisom je prespora ili privremeno nedostupna. Pokusajte ponovno za nekoliko trenutaka.',
        uri: request.uri,
        isConnectivityIssue: true,
      );
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }

    throw ApiException(
      _extractErrorMessage(response.body),
      statusCode: response.statusCode,
      uri: request.uri,
    );
  }

  JsonMap _decodeMap(ApiResponse response) {
    final decoded = _decode(response.body);
    if (decoded is JsonMap) {
      return decoded;
    }
    throw ApiException(
      'Expected a JSON object response.',
      statusCode: response.statusCode,
      uri: response.request.uri,
    );
  }

  dynamic _decode(String body) {
    if (body.isEmpty) {
      return <String, dynamic>{};
    }
    return jsonDecode(body);
  }

  String _extractErrorMessage(String body) {
    if (body.isEmpty) {
      return 'Request failed.';
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is String && decoded.isNotEmpty) {
        return decoded;
      }
      if (decoded is JsonMap) {
        final detail = decoded['detail'];
        if (detail is String && detail.isNotEmpty) {
          return detail;
        }
        final nonFieldErrors = decoded['non_field_errors'];
        if (nonFieldErrors is List && nonFieldErrors.isNotEmpty) {
          return nonFieldErrors.first.toString();
        }
        final fieldMessages = <String>[];
        decoded.forEach((key, value) {
          if (value is List && value.isNotEmpty) {
            fieldMessages.add('$key: ${value.first}');
            return;
          }
          if (value is String && value.isNotEmpty) {
            fieldMessages.add('$key: $value');
          }
        });
        if (fieldMessages.isNotEmpty) {
          return fieldMessages.join('\n');
        }
      }
    } catch (_) {
      return body;
    }

    return 'Request failed.';
  }
}

class ApiRequest {
  const ApiRequest({
    required this.method,
    required this.uri,
    required this.headers,
    this.body,
  });

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final String? body;
}

class ApiResponse {
  const ApiResponse({
    required this.request,
    required this.statusCode,
    required this.body,
  });

  final ApiRequest request;
  final int statusCode;
  final String body;
}

abstract class ApiTransport {
  Future<ApiResponse> send(ApiRequest request);
}

class HttpApiTransport implements ApiTransport {
  HttpApiTransport({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  @override
  Future<ApiResponse> send(ApiRequest request) async {
    final ioRequest = await _client.openUrl(request.method, request.uri);
    request.headers.forEach(ioRequest.headers.set);
    if (request.body != null) {
      ioRequest.write(request.body);
    }

    final ioResponse = await ioRequest.close();
    final body = await utf8.decoder.bind(ioResponse).join();

    return ApiResponse(
      request: request,
      statusCode: ioResponse.statusCode,
      body: body,
    );
  }
}

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.uri,
    this.isConnectivityIssue = false,
  });

  final String message;
  final int? statusCode;
  final Uri? uri;
  final bool isConnectivityIssue;

  @override
  String toString() => 'ApiException(statusCode: $statusCode, message: $message)';
}
