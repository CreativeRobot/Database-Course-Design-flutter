import '../../../core/constants/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/auth/captcha.dart';
import '../../../data/models/auth/auth_session.dart';

class AuthRepository {
  const AuthRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<Captcha> fetchCaptcha() async {
    final response = await _apiClient.get<Captcha>(
      ApiPaths.captcha,
      parser: Captcha.fromJson,
    );
    return response.data;
  }

  Future<void> validateSession() async {
    await _apiClient.get<dynamic>(ApiPaths.me, parser: (value) => value);
  }

  Future<AuthSession> login({
    required String username,
    required String password,
    required String captchaId,
    required String captchaCode,
  }) async {
    final response = await _apiClient.post<AuthSession>(
      ApiPaths.login,
      data: {
        'username': username,
        'password': password,
        'captchaId': captchaId,
        'captchaCode': captchaCode,
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
    required String captchaId,
    required String captchaCode,
  }) async {
    final response = await _apiClient.post<AuthSession>(
      ApiPaths.register,
      data: {
        'username': username,
        'password': password,
        if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
        if (email != null && email.isNotEmpty) 'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'captchaId': captchaId,
        'captchaCode': captchaCode,
      },
      parser: AuthSession.fromJson,
    );
    return response.data;
  }
}
