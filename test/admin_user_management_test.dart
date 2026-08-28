import 'package:flutter_application_bookstore/core/constants/api_paths.dart';
import 'package:flutter_application_bookstore/features/admin/data/admin_models.dart';
import 'package:flutter_application_bookstore/features/admin/presentation/admin_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin user parses profile fields and status helpers', () {
    final user = AdminUser.fromJson({
      'id': 7,
      'username': 'alice',
      'nickname': 'Alice',
      'email': 'alice@example.com',
      'phone': '13800000000',
      'role': 'CUSTOMER',
      'status': 1,
      'createTime': '2026-08-28T10:20:30',
    });

    expect(user.id, 7);
    expect(user.username, 'alice');
    expect(user.roleLabel, '普通用户');
    expect(user.statusLabel, '正常');
    expect(user.createTime, isNotNull);
  });

  test('admin user management paths and navigation section are defined', () {
    expect(ApiPaths.adminUsers, '/api/admin/users');
    expect(ApiPaths.adminUser(7), '/api/admin/users/7');
    expect(ApiPaths.adminUserStatus(7), '/api/admin/users/7/status');
    expect(AdminSection.users.path, 'users');
    expect(AdminSection.users.label, '用户管理');
  });
}
