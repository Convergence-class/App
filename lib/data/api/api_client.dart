import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:emotion_app/core/config/api_config.dart';
import 'package:emotion_app/data/api/api_exception.dart';
import 'package:emotion_app/data/session/app_session.dart';

class ApiClient {
  ApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Uri _uri(String path, [Map<String, Object?>? query]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final base = Uri.parse(ApiConfig.baseUrl);
    final queryParameters = <String, String>{};
    query?.forEach((key, value) {
      if (value != null) queryParameters[key] = value.toString();
    });
    return base.replace(
      path: '${base.path}$normalizedPath',
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
  }

  Map<String, String> _headers({bool auth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = AppSession.instance.accessToken;
    if (auth && token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, Object?>? query,
    bool auth = true,
  }) async {
    final response = await _httpClient.get(
      _uri(path, query),
      headers: _headers(auth: auth),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?>? body,
    bool auth = true,
  }) async {
    final response = await _httpClient.post(
      _uri(path),
      headers: _headers(auth: auth),
      body: jsonEncode(body ?? const <String, Object?>{}),
    );
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    Object? decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        decoded = response.body;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = '요청에 실패했습니다.';
      if (decoded is Map<String, dynamic>) {
        message = (decoded['error'] ?? decoded['message'] ?? message)
            .toString();
      } else if (decoded is String && decoded.isNotEmpty) {
        message = decoded;
      }
      throw ApiException(
        message,
        statusCode: response.statusCode,
        body: decoded,
      );
    }

    if (decoded == null) return <String, dynamic>{};
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{'data': decoded};
  }
}
