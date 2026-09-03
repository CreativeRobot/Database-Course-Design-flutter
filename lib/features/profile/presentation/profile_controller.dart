import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/providers.dart';
import '../../../data/models/profile/user_address.dart';
import '../../../data/models/profile/user_profile.dart';
import '../../../data/models/auth/security_question.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/profile_repository.dart';

enum ProfileStatus { initial, loading, ready, failure }

class ProfileState {
  const ProfileState({
    this.status = ProfileStatus.initial,
    this.profile,
    this.addresses = const [],
    this.submitting = false,
    this.busyAddressId,
    this.errorMessage,
  });

  final ProfileStatus status;
  final UserProfile? profile;
  final List<UserAddress> addresses;
  final bool submitting;
  final int? busyAddressId;
  final String? errorMessage;

  UserAddress? get defaultAddress {
    for (final address in addresses) {
      if (address.defaultAddress) {
        return address;
      }
    }
    return null;
  }

  ProfileState copyWith({
    ProfileStatus? status,
    UserProfile? profile,
    List<UserAddress>? addresses,
    bool? submitting,
    int? busyAddressId,
    bool clearBusyAddress = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProfileState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      addresses: addresses ?? this.addresses,
      submitting: submitting ?? this.submitting,
      busyAddressId: clearBusyAddress ? null : busyAddressId ?? this.busyAddressId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class ProfileController extends StateNotifier<ProfileState> {
  ProfileController({
    required ProfileRepository repository,
    required AuthController authController,
  })  : _repository = repository,
        _authController = authController,
        super(const ProfileState());

  final ProfileRepository _repository;
  final AuthController _authController;

  Future<void> load() async {
    state = state.copyWith(
      status: ProfileStatus.loading,
      clearError: true,
    );
    try {
      final results = await Future.wait<Object>([
        _repository.getProfile(),
        _repository.listAddresses(),
      ]);
      state = state.copyWith(
        status: ProfileStatus.ready,
        profile: results[0] as UserProfile,
        addresses: results[1] as List<UserAddress>,
        clearError: true,
      );
    } on ApiException catch (error) {
      state = state.copyWith(
        status: ProfileStatus.failure,
        errorMessage: await _messageFor(error),
      );
    } catch (_) {
      state = state.copyWith(
        status: ProfileStatus.failure,
        errorMessage: '\u7528\u6237\u4e2d\u5fc3\u6682\u65f6\u65e0\u6cd5\u52a0\u8f7d',
      );
    }
  }

  Future<bool> updateProfile({
    required String nickname,
    required String email,
    required String phone,
  }) async {
    state = state.copyWith(submitting: true, clearError: true);
    try {
      final profile = await _repository.updateProfile(
        nickname: nickname,
        email: email,
        phone: phone,
      );
      await _authController.updateNickname(profile.nickname);
      state = state.copyWith(
        profile: profile,
        submitting: false,
        clearError: true,
      );
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(
        submitting: false,
        errorMessage: await _messageFor(error),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        submitting: false,
        errorMessage: '\u4fdd\u5b58\u8d44\u6599\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5',
      );
      return false;
    }
  }

  Future<bool> uploadAvatar({
    required List<int> bytes,
    required String filename,
  }) async {
    state = state.copyWith(submitting: true, clearError: true);
    try {
      final profile = await _repository.uploadAvatar(
        bytes: bytes,
        filename: filename,
      );
      state = state.copyWith(
        profile: profile,
        submitting: false,
        clearError: true,
      );
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(
        submitting: false,
        errorMessage: await _messageFor(error),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        submitting: false,
        errorMessage: '上传头像失败，请稍后再试',
      );
      return false;
    }
  }

  Future<bool> updateSecurityQuestions({required List<SecurityAnswer> questions}) async {
    state = state.copyWith(submitting: true, clearError: true);
    try {
      await _repository.updateSecurityQuestions(questions: questions);
      await load();
      state = state.copyWith(submitting: false, clearError: true);
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(submitting: false, errorMessage: await _messageFor(error));
      return false;
    } catch (_) {
      state = state.copyWith(submitting: false, errorMessage: '保存密保问题失败，请稍后再试');
      return false;
    }
  }
  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    state = state.copyWith(submitting: true, clearError: true);
    try {
      await _repository.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      state = state.copyWith(submitting: false, clearError: true);
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(
        submitting: false,
        errorMessage: await _messageFor(error),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        submitting: false,
        errorMessage: '\u4fee\u6539\u5bc6\u7801\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5',
      );
      return false;
    }
  }

  Future<bool> saveAddress({
    required UserAddressInput input,
    int? addressId,
  }) async {
    state = state.copyWith(
      busyAddressId: addressId ?? -1,
      clearError: true,
    );
    try {
      if (addressId == null) {
        await _repository.createAddress(input);
      } else {
        await _repository.updateAddress(addressId, input);
      }
      await _reloadAddresses();
      state = state.copyWith(clearBusyAddress: true, clearError: true);
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(
        clearBusyAddress: true,
        errorMessage: await _messageFor(error),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        clearBusyAddress: true,
        errorMessage: '\u4fdd\u5b58\u5730\u5740\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5',
      );
      return false;
    }
  }

  Future<bool> setDefaultAddress(int addressId) async {
    state = state.copyWith(busyAddressId: addressId, clearError: true);
    try {
      await _repository.setDefaultAddress(addressId);
      await _reloadAddresses();
      state = state.copyWith(clearBusyAddress: true, clearError: true);
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(
        clearBusyAddress: true,
        errorMessage: await _messageFor(error),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        clearBusyAddress: true,
        errorMessage: '\u66f4\u65b0\u9ed8\u8ba4\u5730\u5740\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5',
      );
      return false;
    }
  }

  Future<bool> deleteAddress(int addressId) async {
    state = state.copyWith(busyAddressId: addressId, clearError: true);
    try {
      await _repository.deleteAddress(addressId);
      await _reloadAddresses();
      state = state.copyWith(clearBusyAddress: true, clearError: true);
      return true;
    } on ApiException catch (error) {
      state = state.copyWith(
        clearBusyAddress: true,
        errorMessage: await _messageFor(error),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        clearBusyAddress: true,
        errorMessage: '\u5220\u9664\u5730\u5740\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5',
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> _reloadAddresses() async {
    final addresses = await _repository.listAddresses();
    state = state.copyWith(addresses: addresses);
  }

  Future<String> _messageFor(ApiException error) async {
    if (error.isUnauthorized) {
      await _authController.logout();
      return '\u767b\u5f55\u5df2\u8fc7\u671f\uff0c\u8bf7\u91cd\u65b0\u767b\u5f55';
    }
    if (error.message == 'Unable to connect to the server') {
      return '\u6682\u65f6\u65e0\u6cd5\u8fde\u63a5\u670d\u52a1\uff0c\u8bf7\u786e\u8ba4\u540e\u7aef\u5df2\u542f\u52a8';
    }
    if (error.message == 'Connection to server timed out') {
      return '\u8fde\u63a5\u670d\u52a1\u8d85\u65f6\uff0c\u8bf7\u7a0d\u540e\u518d\u8bd5';
    }
    return error.message;
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(apiClientProvider));
});

final profileControllerProvider =
    StateNotifierProvider.autoDispose<ProfileController, ProfileState>((ref) {
  return ProfileController(
    repository: ref.watch(profileRepositoryProvider),
    authController: ref.watch(authControllerProvider.notifier),
  );
});

