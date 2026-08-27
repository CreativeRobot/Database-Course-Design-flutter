import 'package:flutter_application_bookstore/features/auth/presentation/login_captcha_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  late SharedPreferences preferences;
  late LoginCaptchaPolicy policy;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    now = DateTime.utc(2026, 8, 27, 10);
    preferences = await SharedPreferences.getInstance();
    policy = LoginCaptchaPolicy(preferences, now: () => now);
  });

  test(
    'requires captcha on the fourth submission in a rolling window',
    () async {
      await policy.recordSubmission();
      await policy.recordSubmission();
      await policy.recordSubmission();

      expect(await policy.requiresCaptcha(), isTrue);
    },
  );

  test('successful submissions count the same as failed submissions', () async {
    await policy.recordSubmission();
    await policy.recordSubmission();
    await policy.recordSubmission();

    expect(await policy.requiresCaptcha(), isTrue);
  });

  test('submissions exactly thirty minutes old are pruned', () async {
    await policy.recordSubmission();
    now = now.add(const Duration(minutes: 30));
    await policy.recordSubmission();
    await policy.recordSubmission();

    expect(await policy.requiresCaptcha(), isFalse);
  });

  test(
    'recording after pruning uses only the retained rolling window',
    () async {
      await policy.recordSubmission();
      now = now.add(const Duration(minutes: 30, milliseconds: 1));
      await policy.recordSubmission();
      await policy.recordSubmission();
      await policy.recordSubmission();

      expect(await policy.requiresCaptcha(), isTrue);
    },
  );
}
