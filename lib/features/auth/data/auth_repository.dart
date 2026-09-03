import '../../../core/constants/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/auth/captcha.dart';
import '../../../data/models/auth/auth_session.dart';
import '../../../data/models/auth/security_question.dart';

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
    String? captchaId,
    String? captchaCode,
  }) async {
    final response = await _apiClient.post<AuthSession>(
      ApiPaths.login,
      data: {
        'username': username,
        'password': password,
        if (captchaId != null && captchaCode != null) 'captchaId': captchaId,
        if (captchaId != null && captchaCode != null)
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
    required List<SecurityAnswer> securityQuestions,
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
        'securityQuestions': securityQuestions.map((item) => item.toJson()).toList(),
      },
      parser: AuthSession.fromJson,
    );
    return response.data;
  }

  Future<List<SecurityQuestion>> fetchSecurityQuestions(String username) async {
    final response = await _apiClient.get<List<SecurityQuestion>>(
      ApiPaths.securityQuestions,
      queryParameters: {'username': username},
      parser: (value) => (value as List).map(SecurityQuestion.fromJson).toList(growable: false),
    );
    return response.data;
  }

  Future<void> forgotPassword({required String username, required List<SecurityAnswer> answers, required String newPassword, required String confirmPassword}) async {
    await _apiClient.post<Object?>(ApiPaths.forgotPassword, data: {
      'username': username,
      'answers': answers.map((item) => item.toJson()).toList(),
      'newPassword': newPassword,
      'confirmPassword': confirmPassword,
    });
  }
}
