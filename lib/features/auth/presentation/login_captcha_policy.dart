import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LoginCaptchaPolicy {
  LoginCaptchaPolicy(this._preferences, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const _storageKey = 'bookstore.loginCaptchaAttempts';
  static const _window = Duration(minutes: 30);

  final SharedPreferences _preferences;
  final DateTime Function() _now;

  Future<bool> requiresCaptcha() async {
    final timestamps = _prune();
    return timestamps.length >= 3;
  }

  Future<void> recordSubmission() async {
    final timestamps = _prune()..add(_now().millisecondsSinceEpoch);
    await _preferences.setString(_storageKey, jsonEncode(timestamps));
  }

  List<int> _prune() {
    final cutoff = _now().subtract(_window).millisecondsSinceEpoch;
    final raw = _preferences.getString(_storageKey);
    final values = raw == null
        ? <dynamic>[]
        : (jsonDecode(raw) as List<dynamic>);
    final retained = values
        .whereType<num>()
        .map((value) => value.toInt())
        .where((value) => value > cutoff)
        .toList();
    if (raw != null) {
      _preferences.setString(_storageKey, jsonEncode(retained));
    }
    return retained;
  }
}
