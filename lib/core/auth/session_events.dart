import 'dart:async';

/// Broadcasts authentication failures from the network layer to the app state.
/// Keeping this event independent avoids coupling ApiClient to Riverpod.
abstract final class SessionEvents {
  static final StreamController<void> _tokenExpiredController =
      StreamController<void>.broadcast(sync: true);

  static Stream<void> get tokenExpired => _tokenExpiredController.stream;

  static void notifyTokenExpired() {
    if (!_tokenExpiredController.isClosed) {
      _tokenExpiredController.add(null);
    }
  }
}
