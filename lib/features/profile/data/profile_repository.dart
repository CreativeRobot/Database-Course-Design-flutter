import '../../../core/constants/api_paths.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/profile/user_address.dart';
import '../../../data/models/profile/user_profile.dart';
import '../../../data/models/auth/security_question.dart';

class ProfileRepository {
  const ProfileRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<UserProfile> getProfile() async {
    final response = await _apiClient.get<UserProfile>(
      ApiPaths.me,
      parser: UserProfile.fromJson,
    );
    return response.data;
  }

  Future<UserProfile> updateProfile({
    required String nickname,
    required String email,
    required String phone,
  }) async {
    final response = await _apiClient.put<UserProfile>(
      ApiPaths.me,
      data: {'nickname': nickname, 'email': email, 'phone': phone},
      parser: UserProfile.fromJson,
    );
    return response.data;
  }

  Future<UserProfile> uploadAvatar({
    required List<int> bytes,
    required String filename,
  }) async {
    final response = await _apiClient.postMultipart<UserProfile>(
      ApiPaths.meAvatar,
      bytes: bytes,
      filename: filename,
      parser: UserProfile.fromJson,
    );
    return response.data;
  }

  Future<List<SecurityQuestion>> getSecurityQuestions() async {
    final response = await _apiClient.get<List<SecurityQuestion>>(
      ApiPaths.meSecurityQuestions,
      parser: (value) => (value as List).map(SecurityQuestion.fromJson).toList(growable: false),
    );
    return response.data;
  }

  Future<void> updateSecurityQuestions({required List<SecurityAnswer> questions}) async {
    await _apiClient.put<Object?>(ApiPaths.meSecurityQuestions, data: {
      'questions': questions.map((item) => item.toJson()).toList(),
    });
  }
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _apiClient.put<Object?>(
      ApiPaths.mePassword,
      data: {
        'oldPassword': oldPassword,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
    );
  }

  Future<List<UserAddress>> listAddresses() async {
    final response = await _apiClient.get<List<UserAddress>>(
      ApiPaths.addresses,
      parser: (value) {
        if (value is! List) {
          throw const FormatException('\u5730\u5740\u5217\u8868\u54cd\u5e94\u683c\u5f0f\u4e0d\u6b63\u786e');
        }
        return value.map(UserAddress.fromJson).toList(growable: false);
      },
    );
    return response.data;
  }

  Future<UserAddress> createAddress(UserAddressInput input) async {
    final response = await _apiClient.post<UserAddress>(
      ApiPaths.addresses,
      data: input.toJson(),
      parser: UserAddress.fromJson,
    );
    return response.data;
  }

  Future<UserAddress> updateAddress(
    int addressId,
    UserAddressInput input,
  ) async {
    final response = await _apiClient.put<UserAddress>(
      ApiPaths.address(addressId),
      data: input.toJson(),
      parser: UserAddress.fromJson,
    );
    return response.data;
  }

  Future<UserAddress> setDefaultAddress(int addressId) async {
    final response = await _apiClient.put<UserAddress>(
      ApiPaths.defaultAddress(addressId),
      parser: UserAddress.fromJson,
    );
    return response.data;
  }

  Future<void> deleteAddress(int addressId) async {
    await _apiClient.delete<Object?>(ApiPaths.address(addressId));
  }
}

