import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

/// 后端用户信息（登录/注册/me 接口返回的 user 字段）
class AuthUser {
  final int? id;
  final String email;
  final String nickname;

  const AuthUser({this.id, required this.email, required this.nickname});

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] is int
            ? json['id'] as int
            : int.tryParse(json['id']?.toString() ?? ''),
        email: json['email']?.toString() ?? '',
        nickname: json['nickname']?.toString() ?? '',
      );

  @override
  String toString() => 'AuthUser(id: $id, email: $email, nickname: $nickname)';
}

/// 后端认证异常（携带可直接展示给用户的错误信息）
class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}

/// 认证服务：真实后端账号注册 / 登录 / 刷新 / 登出 / 资料查询
///
/// - token 存储用 SharedPreferences（键 `auth_access_token` / `auth_refresh_token`）。
///   注意：SharedPreferences 是明文本地存储，**正式版应替换为
///   flutter_secure_storage**（本阶段保持零新依赖）。
/// - 带 token 的请求遇到 401 时自动尝试 refresh 并重试一次。
/// - 未配置 API_BASE_URL 时所有方法安全降级（不请求网络）。
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  /// token 存储键（SharedPreferences）
  static const kAccessTokenKey = 'auth_access_token';
  static const kRefreshTokenKey = 'auth_refresh_token';

  /// 请求超时时间
  static const _timeout = Duration(seconds: 20);

  /// 是否已配置真实后端（API_BASE_URL 非空）
  bool get isBackendConfigured => ApiConfig.backendBaseUrl.isNotEmpty;

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Uri _uri(String path) => Uri.parse('${ApiConfig.backendBaseUrl}$path');

  /// 读取 access token（null = 未登录）
  Future<String?> getAccessToken() async {
    final prefs = await _prefs;
    return prefs.getString(kAccessTokenKey);
  }

  /// 注册
  Future<AuthUser> register({
    required String email,
    required String password,
    required String nickname,
  }) async {
    final resp = await http
        .post(
          _uri('/api/v1/auth/register'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'password': password,
            'nickname': nickname,
          }),
        )
        .timeout(_timeout);
    if (resp.statusCode != 201) {
      throw AuthException(_extractError(resp, '注册失败'));
    }
    return _handleAuthSuccess(resp.body);
  }

  /// 登录
  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    final resp = await http
        .post(
          _uri('/api/v1/auth/login'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(_timeout);
    if (resp.statusCode != 200) {
      throw AuthException(_extractError(resp, '登录失败'));
    }
    return _handleAuthSuccess(resp.body);
  }

  /// 解析登录/注册响应：持久化 token 对 + 本地登录态
  Future<AuthUser> _handleAuthSuccess(String body) async {
    final map = _decodeMap(body);
    final tokenMap = map['token'];
    if (tokenMap is! Map) {
      throw const AuthException('后端响应缺少 token 字段');
    }
    final tokens = Map<String, dynamic>.from(tokenMap);
    await _saveTokens(
      accessToken: tokens['accessToken']?.toString() ?? '',
      refreshToken: tokens['refreshToken']?.toString() ?? '',
    );
    final userMap = map['user'];
    if (userMap is! Map) {
      throw const AuthException('后端响应缺少 user 字段');
    }
    return AuthUser.fromJson(Map<String, dynamic>.from(userMap));
  }

  /// 持久化 token 对与本地登录态（is_logged_in 供 main.dart 分流）
  Future<void> _saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final prefs = await _prefs;
    await prefs.setString(kAccessTokenKey, accessToken);
    await prefs.setString(kRefreshTokenKey, refreshToken);
    await prefs.setBool('is_logged_in', true);
  }

  /// 用 refresh token 换新的 token 对；成功返回 true
  Future<bool> refresh() async {
    final prefs = await _prefs;
    final refreshToken = prefs.getString(kRefreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) return false;

    final resp = await http
        .post(
          _uri('/api/v1/auth/refresh'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        )
        .timeout(_timeout);
    if (resp.statusCode != 200) return false;

    final map = _decodeMap(resp.body);
    final tokenMap = map['token'];
    if (tokenMap is! Map) return false;
    final tokens = Map<String, dynamic>.from(tokenMap);
    await _saveTokens(
      accessToken: tokens['accessToken']?.toString() ?? '',
      refreshToken: tokens['refreshToken']?.toString() ?? '',
    );
    return true;
  }

  /// 带鉴权的 POST：自动附加 Bearer token，401 时自动 refresh 并重试一次
  Future<http.Response> authedPost(String path, {Object? body}) =>
      _authedRequest('POST', path, body: body);

  /// 带鉴权的 GET：自动附加 Bearer token，401 时自动 refresh 并重试一次
  Future<http.Response> authedGet(String path) =>
      _authedRequest('GET', path);

  Future<http.Response> _authedRequest(
    String method,
    String path, {
    Object? body,
  }) async {
    var token = await getAccessToken();
    var resp = await _send(method, path, token: token, body: body);
    if (resp.statusCode == 401) {
      debugPrint('AuthService: 收到 401，尝试刷新 token 并重试一次');
      final ok = await refresh();
      if (ok) {
        token = await getAccessToken();
        resp = await _send(method, path, token: token, body: body);
      }
    }
    return resp;
  }

  Future<http.Response> _send(
    String method,
    String path, {
    String? token,
    Object? body,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final uri = _uri(path);
    if (method == 'GET') {
      return http.get(uri, headers: headers).timeout(_timeout);
    }
    final encoded = body == null ? null : jsonEncode(body);
    return http
        .post(uri, headers: headers, body: encoded)
        .timeout(_timeout);
  }

  /// 获取当前登录用户资料（未登录或请求失败返回 null）
  Future<AuthUser?> fetchMe() async {
    final resp = await authedGet('/api/v1/user/me');
    if (resp.statusCode != 200) return null;
    final map = _decodeMap(resp.body);
    final userMap = map['user'];
    if (userMap is! Map) return null;
    return AuthUser.fromJson(Map<String, dynamic>.from(userMap));
  }

  /// 退出登录：通知后端（如已配置）+ 清除本地 token 与登录态
  Future<void> logout() async {
    if (isBackendConfigured) {
      try {
        await authedPost('/api/v1/auth/logout');
      } catch (e) {
        debugPrint('AuthService: 登出通知失败（忽略，继续清理本地）: $e');
      }
    }
    final prefs = await _prefs;
    await prefs.remove(kAccessTokenKey);
    await prefs.remove(kRefreshTokenKey);
    await prefs.setBool('is_logged_in', false);
  }

  /// 从后端错误响应提取用户可读信息（后端错误格式: {"error": "..."}）
  String _extractError(http.Response resp, String fallback) {
    try {
      final map = _decodeMap(resp.body);
      final err = map['error']?.toString();
      if (err != null && err.isNotEmpty) return err;
    } catch (_) {
      // 响应体非 JSON，走兜底文案
    }
    return '$fallback（HTTP ${resp.statusCode}）';
  }

  Map<String, dynamic> _decodeMap(String body) {
    final data = jsonDecode(body);
    if (data is! Map) {
      throw const AuthException('后端响应格式错误');
    }
    return Map<String, dynamic>.from(data);
  }
}
