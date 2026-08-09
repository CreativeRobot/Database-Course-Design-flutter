class AuthSession {
  const AuthSession({
    required this.id,
    required this.username,
    required this.nickname,
    required this.role,
    required this.token,
  });

  factory AuthSession.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('登录响应格式不正确');
    }
    return AuthSession(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String,
      nickname: json['nickname'] as String? ?? '',
      role: json['role'] as String,
      token: json['token'] as String,
    );
  }

  final int id;
  final String username;
  final String nickname;
  final String role;
  final String token;
}
