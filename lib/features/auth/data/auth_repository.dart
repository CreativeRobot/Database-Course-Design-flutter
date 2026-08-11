import '../../../core/constants/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/auth/auth_session.dart';

class AuthRepository {
  const AuthRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final response = await _apiClient.post<AuthSession>(
      ApiPaths.login,
      data: {
        'username': username,
        'password': password,
      },
      parser: AuthSession.fromJson,
    );
    return response.data;
  }

  Future<AuthSession> register({
    required String username,
    required String password,
    String? nickname,
    String? email,
    String? phone,
  }) async {
    final response = await _apiClient.post<AuthSession>(
      ApiPaths.register,
      data: {
        'username': username,
        'password': password,
        if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
        if (email != null && email.isNotEmpty) 'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      },
      parser: AuthSession.fromJson,
    );
    return response.data;
  }
}
