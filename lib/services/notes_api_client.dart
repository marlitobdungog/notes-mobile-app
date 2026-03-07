import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class NotesApiClient {
  NotesApiClient({required this.baseUrl});

  static const String defaultBaseUrl = 'https://let-notes-api-1083135128051.asia-southeast1.run.app';
  static const String _authorizationHeader = String.fromEnvironment('LET_NOTES_API_AUTH_HEADER', defaultValue: '');
  static const String _apiKeyHeader = String.fromEnvironment('LET_NOTES_API_KEY', defaultValue: '');
  static String? _runtimeAuthorizationHeader;
  final String baseUrl;
  static const Duration _requestTimeout = Duration(seconds: 12);

  static void setRuntimeAuthorizationHeader(String? value) {
    final normalized = value?.trim();
    _runtimeAuthorizationHeader = (normalized == null || normalized.isEmpty) ? null : normalized;
  }

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$normalizedBase$path').replace(queryParameters: queryParameters);
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
  }) async {
    final uri = _uri(path, queryParameters);
    late final http.Response response;
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    final effectiveAuthorizationHeader = _runtimeAuthorizationHeader ?? _authorizationHeader.trim();
    if (effectiveAuthorizationHeader.isNotEmpty) {
      headers['Authorization'] = effectiveAuthorizationHeader;
    }
    if (_apiKeyHeader.trim().isNotEmpty) {
      headers['x-api-key'] = _apiKeyHeader.trim();
    }
    final encoded = body == null ? null : jsonEncode(body);

    switch (method) {
      case 'GET':
        response = await http.get(uri, headers: headers).timeout(_requestTimeout);
        break;
      case 'POST':
        response = await http.post(uri, headers: headers, body: encoded).timeout(_requestTimeout);
        break;
      case 'PUT':
        response = await http.put(uri, headers: headers, body: encoded).timeout(_requestTimeout);
        break;
      case 'DELETE':
        response = await http.delete(uri, headers: headers).timeout(_requestTimeout);
        break;
      default:
        throw Exception('Unsupported HTTP method: $method');
    }

    final raw = response.body;
    dynamic data;
    if (raw.isNotEmpty) {
      data = jsonDecode(raw);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = (data is Map<String, dynamic>) ? data['detail'] : null;
      if (response.statusCode == 401 && effectiveAuthorizationHeader.isEmpty) {
        throw Exception(
          'API 401 unauthorized. Set LET_NOTES_API_AUTH_HEADER (for example: Bearer <token>).',
        );
      }
      throw Exception('API ${response.statusCode}: ${detail ?? raw}');
    }

    return data;
  }

  Future<Map<String, dynamic>> loginUser({
    required String email,
    required String password,
  }) async {
    return (await _request(
      'POST',
      '/api/users/login',
      body: {
        'email': email,
        'password': password,
      },
    )) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createApiKey({
    required String email,
    required String password,
    String? name,
  }) async {
    final payload = <String, dynamic>{
      'email': email,
      'password': password,
    };
    if (name != null && name.trim().isNotEmpty) {
      payload['name'] = name.trim();
    }

    try {
      return (await _request(
        'POST',
        '/users/api-keys',
        body: payload,
      )) as Map<String, dynamic>;
    } catch (_) {
      return (await _request(
        'POST',
        '/api/users/api-keys',
        body: payload,
      )) as Map<String, dynamic>;
    }
  }

  Future<List<Map<String, dynamic>>> getAllNotes({
    required int userId,
    int pageSize = 100,
  }) async {
    final all = <Map<String, dynamic>>[];
    var skip = 0;

    while (true) {
      final result = await _request(
        'GET',
        '/api/notes/',
        queryParameters: {
          'user_id': '$userId',
          'skip': '$skip',
          'limit': '$pageSize',
        },
      ) as List<dynamic>;

      final batch = result.cast<Map<String, dynamic>>();
      all.addAll(batch);
      if (batch.length < pageSize) break;
      skip += pageSize;
    }

    return all;
  }

  Future<List<Map<String, dynamic>>> getLabels({required int userId}) async {
    final result = await _request(
      'GET',
      '/api/labels/',
      queryParameters: {'user_id': '$userId'},
    ) as List<dynamic>;
    return result.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createLabel({
    required int userId,
    required String name,
    String color = '#3b82f6',
  }) async {
    return (await _request(
      'POST',
      '/api/labels/',
      body: {
        'user_id': userId,
        'name': name,
        'color': color,
      },
    )) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createNote(Map<String, dynamic> payload) async {
    return (await _request('POST', '/api/notes/', body: payload)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateNote({
    required int remoteNoteId,
    required int userId,
    required Map<String, dynamic> payload,
  }) async {
    return (await _request(
      'PUT',
      '/api/notes/$remoteNoteId',
      queryParameters: {'user_id': '$userId'},
      body: payload,
    )) as Map<String, dynamic>;
  }

  Future<void> deleteNote({
    required int remoteNoteId,
    required int userId,
  }) async {
    await _request(
      'DELETE',
      '/api/notes/$remoteNoteId',
      queryParameters: {'user_id': '$userId'},
    );
  }
}
