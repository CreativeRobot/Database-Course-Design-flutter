import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/auth/auth_session.dart';

class TokenStorage {
  static const _tokenKey = 'bookstore.jwt';
  static const _sessionKey = 'bookstore.session';

  Future<String?> readToken() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_tokenKey);
  }

  Future<void> saveToken(String token) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tokenKey, token);
  }

  Future<AuthSession?> readSession() async {
    final preferences = await SharedPreferences.getInstance();
    final rawSession = preferences.getString(_sessionKey);
    if (rawSession == null || rawSession.isEmpty) {
      return null;
    }
    try {
      return AuthSession.fromJson(
        jsonDecode(rawSession) as Map<String, dynamic>,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> saveSession(AuthSession session) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _sessionKey,
      jsonEncode({
        'id': session.id,
        'username': session.username,
        'nickname': session.nickname,
        'role': session.role,
        'token': session.token,
      }),
    );
  }

  Future<void> clearToken() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
    await preferences.remove(_sessionKey);
  }
}
