# API Environment, Security Error Response, and Router Design

## Goal

Reduce three concrete sources of accidental complexity without changing the bookstore's public API paths, successful response fields, or server-side authorization rules:

1. Centralize the Spring Security `401` and `403` response protocol.
2. Make the Flutter API base URL safe and explicit across development, staging, and production builds.
3. Split route paths, route definitions, and access decisions out of the single Flutter router file.

## Scope and Compatibility

The implementation keeps the existing REST paths, the Flutter `ApiClient` dependency direction, Riverpod authentication state, GoRouter, and Spring Security authorization rules.

- Development continues to default to `http://localhost:8080` when no API address is supplied.
- Staging and production builds require `API_BASE_URL`; they will fail at application startup with a clear configuration error when it is missing or invalid.
- Existing API error JSON remains `{ "code": <http status>, "message": <message>, "data": null }`.
- The Flutter guard improves navigation only. The backend remains the authority for every protected API call.
- `JwtInterceptor` is not deleted in this change. It will use the shared error writer so any legacy or future registration has the same response contract.

## Flutter Environment Configuration

### Components

`lib/core/config/app_environment.dart` will expose the supported environment values:

- `development`
- `staging`
- `production`

`AppConfig` will continue to be the only object injected into `ApiClient`, but it will gain a deterministic factory such as `AppConfig.fromValues({required String environment, required String apiBaseUrl})`. The runtime constructor/factory will read:

- `APP_ENV`, defaulting to `development`
- `API_BASE_URL`, defaulting only in development

The factory will trim the address, require an absolute HTTP or HTTPS URI, and store a version without a trailing slash. Unknown environment names, missing staging/production addresses, and invalid URLs produce an explanatory `StateError` before the first request can be sent.

This allows unit tests to exercise configuration without relying on compile-time `String.fromEnvironment` values. `appConfigProvider` continues to create the runtime configuration once; repositories and pages do not receive raw URLs.

### Build Commands

The README will document the supported deployment commands:

```powershell
flutter run --dart-define=APP_ENV=development
flutter run --dart-define=APP_ENV=development --dart-define=API_BASE_URL=http://10.0.2.2:8080
flutter run --dart-define=APP_ENV=staging --dart-define=API_BASE_URL=https://staging.example.com
flutter build web --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://api.example.com
```

`10.0.2.2` is only an Android-emulator example; a physical device must use an address reachable from that device. No secret is stored in these client-side defines.

## Flutter Routing

### Module Boundaries

The current `app_router.dart` combines route strings, route builders, authentication subscriptions, and redirect policy. It will be separated as follows:

| File | Responsibility |
| --- | --- |
| `lib/app/router/app_route_paths.dart` | Route path constants plus small path-classification helpers. |
| `lib/app/router/app_route_guard.dart` | A pure access-decision function accepting `AuthState` and the matched path, returning a redirect target or `null`. |
| `lib/app/router/app_routes.dart` | `GoRoute` definitions grouped as public, customer-protected, and administrator routes; dynamic ID parsing remains next to its page builder. |
| `lib/app/router/app_router.dart` | Creates `GoRouter`, observes authentication changes, supplies the guard, and owns no individual route builder or policy condition. |

The guard rules are intentionally unchanged:

- Anonymous users may browse books, search, and view book details.
- Anonymous users navigating to cart, checkout, orders, reviews, profile, or `/admin/**` go to `/login`.
- An authenticated user navigating to login or register goes to `/admin` when their role is `ADMIN`, otherwise `/books`.
- An authenticated non-admin navigating to `/admin/**` goes to `/books`.
- While authentication is `checking` or `loading`, the guard returns `null` so the current application lifecycle remains unchanged.

Route path checks will use the matched location and explicit helpers rather than repeated string literals. The route list will still include every current path, including the admin-section loop and fallback behavior for malformed book/order IDs.

## Backend Security Error Responses

### Shared Writer

`SecurityErrorResponseWriter` will be a Spring component in `com.example.demo.common.config`. It receives the project's configured Jackson `ObjectMapper` and has one operation conceptually equivalent to:

```java
void write(HttpServletResponse response, HttpStatus status, String message)
```

It will:

1. Set the supplied HTTP status.
2. For `401`, set `WWW-Authenticate: Bearer` and `Cache-Control: no-store`.
3. Set `application/json` and UTF-8.
4. Serialize `Result.error(status.value(), message)` through Jackson.

Using Jackson instead of string concatenation means response escaping and future changes to the common `Result` DTO have one implementation point.

### Call Sites

`SecurityConfig` will receive the writer through constructor injection. Its `AuthenticationEntryPoint` writes the existing `401` message (`未登录或Token已失效`), and its `AccessDeniedHandler` writes the existing `403` message (`无权访问`).

`JwtAuthenticationFilter` and `JwtInterceptor` will receive the same writer and delegate their rejection branches to it. The existing token validation and request-publicness decisions are not changed. The previous mismatch—filter/interceptor responses setting `401` headers while the security entry point did not—therefore disappears.

`GlobalExceptionHandler` is intentionally not used for these errors because filter-chain authentication and authorization failures need an immediate servlet response and do not reliably enter the MVC controller-advice pipeline.

## Test-First Plan

Production code will be written only after the following focused tests exist and have been observed failing for the expected missing behavior.

### Flutter Tests

- `AppConfig.fromValues` accepts the development default and a supplied HTTP(S) address, trims a trailing slash, rejects invalid/unknown configuration, and rejects staging/production without an explicit address.
- The pure route guard covers anonymous, authenticated customer, and administrator redirect decisions for public, customer-only, and administrator paths.
- Existing route/widget tests remain responsible for actual GoRouter page construction; no page-specific authorization logic is duplicated in the new guard tests.

### Backend Tests

- `SecurityErrorResponseWriter` returns `401` and `403` with the current `code`, `message`, and `data: null` JSON shape.
- Its `401` response carries `WWW-Authenticate: Bearer` and `Cache-Control: no-store`; `403` does not imply an authentication challenge.
- `JwtAuthenticationFilterTests` strengthens its missing-token assertion to check the standard shared response rather than only a nonblank body.

## Verification

After the focused tests turn green, verification will run from the existing no-space mapped Flutter checkout when required by the Windows toolchain:

1. Focused Flutter tests for environment and route guard behavior.
2. `flutter test` and `flutter analyze`, subject to the existing SDK/cache permissions.
3. Focused Maven tests for the writer and JWT filter, then the relevant broader backend test selection.
