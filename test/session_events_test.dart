import 'package:flutter_application_bookstore/core/auth/session_events.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('token expiration events are broadcast to the app layer', () async {
    final event = SessionEvents.tokenExpired.first;

    SessionEvents.notifyTokenExpired();

    await event;
    expect(true, isTrue);
  });
}
