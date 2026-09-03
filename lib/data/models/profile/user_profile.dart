class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.nickname,
    required this.email,
    required this.phone,
    required this.role,
    required this.status,
    this.avatarUrl,
    this.createTime,
    this.updateTime,
    this.securityQuestionsConfigured = false,
  });

  factory UserProfile.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('\u7528\u6237\u8d44\u6599\u54cd\u5e94\u683c\u5f0f\u4e0d\u6b63\u786e');
    }
    return UserProfile(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      role: json['role'] as String? ?? 'CUSTOMER',
      status: (json['status'] as num?)?.toInt() ?? 0,
      avatarUrl: json['avatarUrl'] as String?,
      createTime: DateTime.tryParse(json['createTime'] as String? ?? ''),
      updateTime: DateTime.tryParse(json['updateTime'] as String? ?? ''),
      securityQuestionsConfigured: json['securityQuestionsConfigured'] as bool? ?? false,
    );
  }

  final int id;
  final String username;
  final String nickname;
  final String email;
  final String phone;
  final String role;
  final int status;
  final String? avatarUrl;
  final DateTime? createTime;
  final DateTime? updateTime;
  final bool securityQuestionsConfigured;

  String get displayName => nickname.trim().isEmpty ? username : nickname;
  bool get isAdmin => role == 'ADMIN';
  bool get isEnabled => status == 1;
}





