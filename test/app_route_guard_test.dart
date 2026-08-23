import 'package:flutter_application_bookstore/app/router/app_route_guard.dart';
import 'package:flutter_application_bookstore/app/router/app_route_paths.dart';
import 'package:flutter_application_bookstore/data/models/auth/auth_session.dart';
import 'package:flutter_application_bookstore/features/auth/presentation/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('anonymous users are redirected from customer and admin routes', () {
    const state = AuthState.unauthenticated();

    expect(
      redirectForRoute(authState: state, matchedLocation: AppRoutePaths.cart),
      AppRoutePaths.login,
    );
    expect(
      redirectForRoute(authState: state, matchedLocation: '/admin/books'),
      AppRoutePaths.login,
    );
  });

  test(
    'authenticated customers leave auth pages and cannot open admin routes',
    () {
      const state = AuthState.authenticated(_customerSession);

      expect(
        redirectForRoute(
          authState: state,
          matchedLocation: AppRoutePaths.login,
        ),
        AppRoutePaths.books,
      );
      expect(
        redirectForRoute(
          authState: state,
          matchedLocation: AppRoutePaths.admin,
        ),
        AppRoutePaths.books,
      );
    },
  );

  test('administrators leave auth pages and can open admin routes', () {
    const state = AuthState.authenticated(_administratorSession);

    expect(
      redirectForRoute(
        authState: state,
        matchedLocation: AppRoutePaths.register,
      ),
      AppRoutePaths.admin,
    );
    expect(
      redirectForRoute(authState: state, matchedLocation: '/admin/orders'),
      isNull,
    );
  });

  test('checking state and public book routes do not redirect', () {
    expect(
      redirectForRoute(
        authState: const AuthState.checking(),
        matchedLocation: '/books/12',
      ),
      isNull,
    );
    expect(
      redirectForRoute(
        authState: const AuthState.unauthenticated(),
        matchedLocation: AppRoutePaths.search,
      ),
      isNull,
    );
  });
}

const _customerSession = AuthSession(
  id: 1,
  username: 'reader',
  nickname: 'Reader',
  role: 'CUSTOMER',
  token: 'token',
);

const _administratorSession = AuthSession(
  id: 2,
  username: 'administrator',
  nickname: 'Administrator',
  role: 'ADMIN',
  token: 'token',
);
