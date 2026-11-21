import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class ApiClient {
  static const _storage = FlutterSecureStorage();
  String? accessToken;

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');
  Map<String, String> _headers({bool auth = false}) => {
    'Content-Type': 'application/json; charset=utf-8',
    if (auth && accessToken != null) 'Authorization': 'Bearer $accessToken',
  };

  Future<http.Response> _request(
    Future<http.Response> Function(Map<String, String>) send, {
    required bool auth,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    var response = await send(_headers(auth: auth))
        .timeout(timeout);
    if (auth && response.statusCode == 401 && await _refreshAccess()) {
      response = await send(_headers(auth: true))
          .timeout(timeout);
    }
    return response;
  }

  Future<bool> _refreshAccess() async {
    final refresh = await _storage.read(key: 'refreshToken');
    if (refresh == null) return false;
    try {
      final result = await post('/api/auth/refresh', {'refreshToken': refresh});
      await persistSession(result);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
    Duration timeout = const Duration(seconds: 15),
  }) async => _decode(
    await _request(
      (headers) =>
          http.post(_uri(path), headers: headers, body: jsonEncode(body)),
      auth: auth,
      timeout: timeout,
    ),
  );

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async => _decode(
    await _request(
      (headers) =>
          http.put(_uri(path), headers: headers, body: jsonEncode(body)),
      auth: auth,
    ),
  );

  Future<Map<String, dynamic>> get(String path, {bool auth = false}) async =>
      _decode(
        await _request(
          (headers) => http.get(_uri(path), headers: headers),
          auth: auth,
        ),
      );

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body, {
    bool auth = false,
  }) async => _decode(
    await _request(
      (headers) =>
          http.patch(_uri(path), headers: headers, body: jsonEncode(body)),
      auth: auth,
    ),
  );

  Future<Map<String, dynamic>> uploadBytes(
    String path,
    Uint8List bytes, {
    required String contentType,
    bool auth = false,
  }) async => _decode(
    await _request((headers) {
      headers['Content-Type'] = contentType;
      return http.post(_uri(path), headers: headers, body: bytes);
    }, auth: auth),
  );

  Future<Map<String, dynamic>> delete(
    String path, {
    bool auth = false,
    Map<String, dynamic>? body,
  }) async => _decode(
    await _request(
      (headers) => http.delete(
        _uri(path),
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
      auth: auth,
    ),
  );

  Map<String, dynamic> _decode(http.Response response) {
    final Object? value = response.body.isEmpty
        ? null
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final map = value is Map<String, dynamic>
          ? value
          : const <String, dynamic>{};
      throw ApiException(
        (map['message'] ??
                map['detail'] ??
                map['title'] ??
                'Yêu cầu chưa thực hiện được (${response.statusCode}).')
            .toString(),
      );
    }
    return value is Map<String, dynamic> ? value : {'data': value};
  }

  Future<void> persistSession(Map<String, dynamic> result) async {
    accessToken = result['accessToken'] as String?;
    await _storage.write(
      key: 'refreshToken',
      value: result['refreshToken'] as String?,
    );
    await _storage.write(key: 'role', value: result['role'] as String?);
    await _storage.write(
      key: 'profileComplete',
      value: '${result['profileComplete']}',
    );
    await _storage.write(
      key: 'onboardingStep',
      value: '${result['onboardingStep'] ?? 1}',
    );
  }

  Future<Map<String, dynamic>?> restoreSession() async {
    final refresh = await _storage.read(key: 'refreshToken');
    if (refresh == null) return null;
    try {
      final result = await post('/api/auth/refresh', {'refreshToken': refresh});
      await persistSession(result);
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    accessToken = null;
    await _storage.deleteAll();
  }

  Future<void> logout() async {
    final refresh = await _storage.read(key: 'refreshToken');
    if (refresh != null) {
      try {
        await post('/api/auth/logout', {'refreshToken': refresh});
      } catch (_) {
        /* Offline logout still clears local credentials. */
      }
    }
    await clearSession();
  }
}

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
