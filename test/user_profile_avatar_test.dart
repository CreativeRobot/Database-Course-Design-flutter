import 'package:flutter_application_bookstore/data/models/profile/user_profile.dart';
import 'package:flutter_application_bookstore/core/constants/api_paths.dart';
import 'package:flutter_application_bookstore/core/utils/media_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('user profile keeps the avatar URL returned by the API', () {
    final profile = UserProfile.fromJson({
      'id': 42,
      'username': 'reader',
      'nickname': '读者',
      'email': '',
      'phone': '',
      'role': 'CUSTOMER',
      'status': 1,
      'avatarUrl': '/uploads/avatars/42/portrait.png',
    });

    expect(profile.avatarUrl, '/uploads/avatars/42/portrait.png');
  });

  test('builds the authenticated avatar endpoint', () {
    expect(ApiPaths.meAvatar, '/api/user/me/avatar');
  });

  test('resolves relative media paths against the API base URL', () {
    expect(
      resolveMediaUrl('http://localhost:8080/', '/uploads/avatar.png'),
      'http://localhost:8080/uploads/avatar.png',
    );
    expect(
      resolveMediaUrl(
        'http://localhost:8080',
        'https://cdn.example/avatar.png',
      ),
      'https://cdn.example/avatar.png',
    );
    expect(
      resolveMediaUrl('http://localhost:8080', '/uploads/covers/cover.png'),
      'http://localhost:8080/uploads/covers/cover.png',
    );
  });
}
