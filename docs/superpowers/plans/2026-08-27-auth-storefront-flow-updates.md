# Authentication and Storefront Flow Updates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the agreed captcha policy, recommendation-only customer homepage, role-aware login routing, shared brand mark, and checkout address refresh.

**Architecture:** Spring Boot accepts an absent login captcha while continuing to validate a supplied pair and keeping registration mandatory; Flutter owns the agreed rolling, per-device interaction threshold. The existing recommendation API, `Role` session data, shared commerce widgets, and Riverpod providers are reused rather than adding new endpoints or state frameworks.

**Tech Stack:** Java 21, Spring Boot, Caffeine, JUnit 5, Mockito, Flutter/Dart 3, Riverpod, GoRouter, SharedPreferences, flutter_test.

**Spec:** `docs/superpowers/specs/2026-08-27-auth-storefront-flow-updates-design.md`

## Global Constraints

- Do not modify, revert, stage, or commit the user's existing unrelated working-tree changes.
- Login submissions persist per device in a rolling 30-minute window; entries one through three do not need captcha and entry four onward does.
- A successful login counts as a login submission and does not reset the rolling window.
- Registration always requires a complete, single-use captcha pair.
- Captcha cache expiration and `CaptchaVo.expiresInSeconds` must both equal 300 seconds.
- Password recovery, schema migrations, external dependencies, and new API paths are out of scope.

---

### Task 1: Make the Backend Login Captcha Optional and Five Minutes Long

**Files:**
- Modify: `D:/no game/Code/DatabaseHomework/demo/src/main/java/com/example/demo/common/config/CacheConfig.java`
- Modify: `D:/no game/Code/DatabaseHomework/demo/src/main/java/com/example/demo/service/CaptchaService.java`
- Modify: `D:/no game/Code/DatabaseHomework/demo/src/main/java/com/example/demo/dto/LoginDTO.java`
- Modify: `D:/no game/Code/DatabaseHomework/demo/src/main/java/com/example/demo/service/AuthService.java`
- Modify: `D:/no game/Code/DatabaseHomework/demo/src/test/java/com/example/demo/service/CaptchaServiceTests.java`
- Modify: `D:/no game/Code/DatabaseHomework/demo/src/test/java/com/example/demo/service/AuthServiceTests.java`
- Create: `D:/no game/Code/DatabaseHomework/demo/src/test/java/com/example/demo/dto/LoginDTOValidationTests.java`

**Interfaces:**
- Consumes: `LoginDTO.getCaptchaId()`, `LoginDTO.getCaptchaCode()`, and `CaptchaService.verifyAndConsume(String, String)`.
- Produces: `AuthService.login(LoginDTO)` accepts both captcha fields absent, accepts both supplied, and rejects exactly one supplied; `CaptchaService.issue()` returns `expiresInSeconds == 300`.

- [ ] **Step 1: Write failing backend tests**

Add these cases to `AuthServiceTests.java`:

```java
@Test
void loginWithoutCaptchaDoesNotInvokeCaptchaService() {
    LoginDTO request = loginRequest();
    arrangeAuthenticatedCustomer();

    authService.login(request);

    verify(captchaService, never()).verifyAndConsume(any(), any());
}

@Test
void loginRejectsPartialCaptchaPairBeforeLookingUpUser() {
    LoginDTO request = loginRequest();
    request.setCaptchaId("captcha-id");

    assertThrows(BusinessException.class, () -> authService.login(request));

    verify(userRepository, never()).findByUsernameIgnoreCase(any());
}
```

Add `issuesCaptchaWithFiveMinuteLifetime()` to `CaptchaServiceTests.java`:

```java
assertEquals(300, captchaService.issue().getExpiresInSeconds());
```

Create `LoginDTOValidationTests.java` using a Jakarta `Validator` and assert an otherwise valid `LoginDTO` with both captcha properties absent has no captcha-field violations, while an otherwise valid `RegisterDTO` with no captcha properties still has both violations.

- [ ] **Step 2: Run the focused tests and observe RED**

Run:

```powershell
.\mvnw.cmd -Dtest=CaptchaServiceTests,AuthServiceTests,LoginDTOValidationTests test
```

Expected: the lifetime assertion fails at 120, absent-login captcha validation fails, and the partial-pair behavior is not yet implemented.

- [ ] **Step 3: Implement the smallest compatible backend change**

Set the Caffeine captcha cache and `CaptchaService.EXPIRES_IN_SECONDS` to five minutes / 300 seconds. Remove `@NotBlank` only from `LoginDTO.captchaId` and `LoginDTO.captchaCode`, retaining their maximum-length constraints. In `AuthService.login`, add a private pair validator before user lookup:

```java
private void verifyLoginCaptcha(LoginDTO loginDTO) {
    boolean hasId = StringUtils.hasText(loginDTO.getCaptchaId());
    boolean hasCode = StringUtils.hasText(loginDTO.getCaptchaCode());
    if (hasId != hasCode) {
        throw new BusinessException(HttpStatus.BAD_REQUEST, "请完整填写验证码");
    }
    if (hasId) {
        captchaService.verifyAndConsume(loginDTO.getCaptchaId(), loginDTO.getCaptchaCode());
    }
}
```

Replace the unconditional login captcha call with `verifyLoginCaptcha(loginDTO)`. Do not change `RegisterDTO` or `AuthService.register`.

- [ ] **Step 4: Run focused tests and the backend regression suite**

Run:

```powershell
.\mvnw.cmd -Dtest=CaptchaServiceTests,AuthServiceTests,LoginDTOValidationTests test
.\mvnw.cmd test
```

Expected: focused captcha/auth tests and all existing backend tests pass.

- [ ] **Step 5: Record the independently verified change**

Run:

```powershell
git -c safe.directory='D:/no game/Code/DatabaseHomework/demo' diff --check
```

Record the test output in the task progress log. Do not stage or commit unless Git write permission is explicitly available and only Task 1 files are staged.

### Task 2: Add the Rolling Login-Captcha Policy and Role Destinations

**Files:**
- Create: `D:/no game/Code/DatabaseHomework/BookStore_Flutter/flutter_application_bookstore/lib/features/auth/presentation/login_captcha_policy.dart`
- Modify: `D:/no game/Code/DatabaseHomework/BookStore_Flutter/flutter_application_bookstore/lib/features/auth/data/auth_repository.dart`
- Modify: `D:/no game/Code/DatabaseHomework/BookStore_Flutter/flutter_application_bookstore/lib/features/auth/presentation/auth_controller.dart`
- Modify: `D:/no game/Code/DatabaseHomework/BookStore_Flutter/flutter_application_bookstore/lib/features/auth/presentation/auth_pages.dart`
- Modify: `D:/no game/Code/DatabaseHomework/BookStore_Flutter/flutter_application_bookstore/lib/app/router/app_route_guard.dart`
- Modify: `D:/no game/Code/DatabaseHomework/BookStore_Flutter/flutter_application_bookstore/test/auth_controller_captcha_test.dart`
- Modify: `D:/no game/Code/DatabaseHomework/BookStore_Flutter/flutter_application_bookstore/test/auth_pages_captcha_test.dart`
- Modify: `D:/no game/Code/DatabaseHomework/BookStore_Flutter/flutter_application_bookstore/test/auth_repository_captcha_test.dart`
- Modify: `D:/no game/Code/DatabaseHomework/BookStore_Flutter/flutter_application_bookstore/test/app_route_guard_test.dart`
- Create: `D:/no game/Code/DatabaseHomework/BookStore_Flutter/flutter_application_bookstore/test/login_captcha_policy_test.dart`

**Interfaces:**
- Consumes: `SharedPreferences`, `AuthRepository.login`, `AuthSession.role`, and `redirectForRoute`.
- Produces: `LoginCaptchaPolicy.requiresCaptcha()` and `LoginCaptchaPolicy.recordSubmission()`; `destinationForRole(String role)` returning `/admin` for `ADMIN`, otherwise `/books`.

- [ ] **Step 1: Write failing Flutter unit tests**

In `login_captcha_policy_test.dart`, initialize mocked preferences and a fixed clock. Assert the fourth recorded submission requires captcha, a successful submission is indistinguishable from a failed one, and submissions exactly 30 minutes old are pruned:

```dart
test('requires captcha on the fourth submission in a rolling window', () async {
  final policy = LoginCaptchaPolicy(preferences, now: () => clock.now());
  await policy.recordSubmission();
  await policy.recordSubmission();
  await policy.recordSubmission();

  expect(await policy.requiresCaptcha(), isTrue);
});
```

Add route expectations for an authenticated administrator going to `/admin` after login and when attempting `/books`. Update repository/controller tests to verify an absent pair is omitted from the login JSON and a full pair remains serialized.

- [ ] **Step 2: Run Flutter tests and observe RED**

Run:

```powershell
flutter test test/login_captcha_policy_test.dart test/auth_controller_captcha_test.dart test/auth_pages_captcha_test.dart test/auth_repository_captcha_test.dart test/app_route_guard_test.dart
```

Expected: compilation fails because `LoginCaptchaPolicy` and `destinationForRole` do not exist; existing login tests still require a captcha pair.

- [ ] **Step 3: Implement the policy, optional request, and destinations**

Implement `LoginCaptchaPolicy` with a JSON list of Unix-millisecond timestamps stored under a dedicated `bookstore.loginCaptchaAttempts` key. On every read or write, retain only timestamps newer than `now - const Duration(minutes: 30)`. `requiresCaptcha()` returns true when the retained list has at least three entries; `recordSubmission()` appends the current timestamp.

Make captcha fields nullable in `AuthRepository.login` and `AuthController.login`; only add them to JSON when both non-null. Make `LoginPage` load a captcha only when `requiresCaptcha()` is true, conditionally render `CaptchaField`, block a required captcha fetch failure, and call `recordSubmission()` once after a locally valid submit regardless of the request result. Replace its hard-coded `/books` success target with `destinationForRole(ref.read(authControllerProvider).session!.role)`. Use the same resolver after registration.

In `app_route_guard.dart`, add:

```dart
String destinationForRole(String role) =>
    role == 'ADMIN' ? AppRoutePaths.admin : AppRoutePaths.books;
```

Use it for authenticated authentication routes and redirect an authenticated administrator requesting `AppRoutePaths.books` to `AppRoutePaths.admin`.

- [ ] **Step 4: Run tests, formatting, and analysis**

Run:

```powershell
dart format lib/features/auth/presentation/login_captcha_policy.dart lib/features/auth/data/auth_repository.dart lib/features/auth/presentation/auth_controller.dart lib/features/auth/presentation/auth_pages.dart lib/app/router/app_route_guard.dart test/login_captcha_policy_test.dart test/auth_controller_captcha_test.dart test/auth_pages_captcha_test.dart test/auth_repository_captcha_test.dart test/app_route_guard_test.dart
flutter test test/login_captcha_policy_test.dart test/auth_controller_captcha_test.dart test/auth_pages_captcha_test.dart test/auth_repository_captcha_test.dart test/app_route_guard_test.dart
flutter analyze
```

Expected: all listed tests pass and analysis reports no errors.

- [ ] **Step 5: Record the independently verified change**

Run:

```powershell
git -c safe.directory='D:/no game/Code/DatabaseHomework/BookStore_Flutter/flutter_application_bookstore' diff --check
```

Record verification output without staging unrelated files.

### Task 3: Make the Customer Homepage Recommendation-Only and Reuse the Cart Brand

**Files:**
- Modify: `D:/no game/Code/DatabaseHomework/BookStore_Flutter/flutter_application_bookstore/lib/features/cart/presentation/commerce_widgets.dart`
- Modify: `D:/no game/Code/DatabaseHomework/BookStore_Flutter/flutter_application_bookstore/lib/features/recommendations/presentation/recommendation_section.dart`
- Modify: `D:/no game/Code/DatabaseHomework/BookStore_Flutter/flutter_application_bookstore/lib/features/books/presentation/books_page.dart`
- Modify: `D:/no game/Code/DatabaseHomework/BookStore_Flutter/flutter_application_bookstore/lib/features/auth/presentation/auth_pages.dart`
- Modify: `D:/no game/Code/DatabaseHomework/BookStore_Flutter/flutter_application_bookstore/lib/features/admin/presentation/admin_page.dart`
- Modify: `D:/no game/Code/DatabaseHomework/BookStore_Flutter/flutter_application_bookstore/test/recommendation_section_test.dart`
- Modify: `D:/no game/Code/DatabaseHomework/BookStore_Flutter/flutter_application_bookstore/test/books_page_dependencies_test.dart`
- Modify: `D:/no game/Code/DatabaseHomework/BookStore_Flutter/flutter_application_bookstore/test/books_home_navigation_test.dart`
- Create: `D:/no game/Code/DatabaseHomework/BookStore_Flutter/flutter_application_bookstore/test/bookstore_brand_test.dart`

**Interfaces:**
- Consumes: `RecommendationHome`, `RecommendationController`, `CommerceHeader`, and existing `BooksPage` search navigation.
- Produces: reusable `BookstoreBrand` widget and full-page `RecommendationHomeGrid`; authenticated customers see recommendations only, while unauthenticated visitors see a sign-in action.

- [ ] **Step 1: Write failing presentation tests**

Add a `BookstoreBrand` widget test that finds `Icons.auto_stories_outlined` and `Text('书间')`. Add a recommendation-home test that renders a multi-row grid from 12 `RecommendationBook` values, not a horizontal list. Update the books-page dependency test to assert it does not call `booksControllerProvider.notifier.loadInitial()` and that a signed-out state offers navigation to `/login`.

```dart
await tester.pumpWidget(const MaterialApp(home: BookstoreBrand()));
expect(find.text('书间'), findsOneWidget);
expect(find.byIcon(Icons.auto_stories_outlined), findsOneWidget);
```

- [ ] **Step 2: Run presentation tests and observe RED**

Run:

```powershell
flutter test test/bookstore_brand_test.dart test/recommendation_section_test.dart test/books_page_dependencies_test.dart test/books_home_navigation_test.dart
```

Expected: `BookstoreBrand` and the full-grid home component do not exist; the old books homepage still starts the catalog controller.

- [ ] **Step 3: Implement recommendation-only customer content and shared identity**

Extract the current `CommerceHeader` logo `InkWell` into `BookstoreBrand`, retaining its `/books` target and compact dimensions. Make `CommerceHeader` compose that widget. Replace the left-side brand widgets in `AuthFrame`, `_BooksHeader`, and the administration scaffold with `BookstoreBrand`, preserving their existing navigation/search controls.

Add `RecommendationHomeGrid` to `recommendation_section.dart`. Render a responsive `GridView` / `SliverGrid` of recommendation cards using the existing `CommerceCover`, title, reason, price, and detail navigation. Keep `RecommendationBooks` unchanged for any existing narrow-section consumers.

In `BooksPage`, remove the normal `BooksController` load and ordinary catalog grid from the homepage. Authenticated non-admin users load `RecommendationController` with `limit: 12` and render its loading, error/retry, empty, and `RecommendationHomeGrid` states as the main body. Unauthenticated users render a sign-in call to action. Preserve the search field and the existing `/search` navigation. Administrators are redirected by Task 2 before this page is used.

- [ ] **Step 4: Run Flutter presentation verification**

Run:

```powershell
dart format lib/features/cart/presentation/commerce_widgets.dart lib/features/recommendations/presentation/recommendation_section.dart lib/features/books/presentation/books_page.dart lib/features/auth/presentation/auth_pages.dart lib/features/admin/presentation/admin_page.dart test/bookstore_brand_test.dart test/recommendation_section_test.dart test/books_page_dependencies_test.dart test/books_home_navigation_test.dart
flutter test test/bookstore_brand_test.dart test/recommendation_section_test.dart test/books_page_dependencies_test.dart test/books_home_navigation_test.dart test/recommendation_controller_test.dart
flutter analyze
```

Expected: the homepage tests confirm no catalog dependency and all presentation tests pass.

- [ ] **Step 5: Record the independently verified change**

Run:

```powershell
git -c safe.directory='D:/no game/Code/DatabaseHomework/BookStore_Flutter/flutter_application_bookstore' diff --check
```

Record output without staging unrelated files.

### Task 4: Refresh Checkout Addresses After Profile Return and Remove the Subtitle

**Files:**
- Modify: `D:/no game/Code/DatabaseHomework/BookStore_Flutter/flutter_application_bookstore/lib/features/orders/presentation/checkout_page.dart`
- Create: `D:/no game/Code/DatabaseHomework/BookStore_Flutter/flutter_application_bookstore/test/checkout_address_return_test.dart`

**Interfaces:**
- Consumes: `checkoutAddressesProvider`, `GoRouter.push`, and the existing profile route.
- Produces: a checkout profile-navigation callback that awaits route return and then calls `ref.invalidate(checkoutAddressesProvider)`.

- [ ] **Step 1: Write the failing checkout widget test**

Create a `ProviderScope` test with a fake GoRouter profile route and an overridden address provider whose invocation count is observable. Tap both `管理地址` and the empty-state add-address action, pop each profile route, then assert the address provider executes again. Also assert that this literal is absent from the checkout page:

```dart
'选择收货地址并最后确认商品，订单金额由服务端重新计算。'
```

- [ ] **Step 2: Run the checkout test and observe RED**

Run:

```powershell
flutter test test/checkout_address_return_test.dart
```

Expected: provider execution remains unchanged after route pop and the obsolete subtitle is still rendered.

- [ ] **Step 3: Implement the return refresh**

Add one private helper on `_CheckoutPageState`:

```dart
Future<void> _manageAddresses() async {
  await context.push('/profile');
  if (mounted) {
    ref.invalidate(checkoutAddressesProvider);
  }
}
```

Use this helper for the `管理地址` and empty-address `onAdd` actions. Remove only the requested `CommerceTitle.subtitle` copy; retain the `送到哪里？` title and checkout mechanics.

- [ ] **Step 4: Run focused and full Flutter verification**

Run:

```powershell
dart format lib/features/orders/presentation/checkout_page.dart test/checkout_address_return_test.dart
flutter test test/checkout_address_return_test.dart
flutter test
flutter analyze
```

Expected: the route-return test passes, the full Flutter suite passes, and analysis reports no errors.

- [ ] **Step 5: Record the independently verified change**

Run:

```powershell
git -c safe.directory='D:/no game/Code/DatabaseHomework/BookStore_Flutter/flutter_application_bookstore' diff --check
```

Record output without staging unrelated files.

### Task 5: End-to-End Regression and Delivery

**Files:**
- Modify: `D:/no game/Code/DatabaseHomework/BookStore_Flutter/flutter_application_bookstore/docs/superpowers/user-flow-updates/task_plan.md`
- Modify: `D:/no game/Code/DatabaseHomework/BookStore_Flutter/flutter_application_bookstore/docs/superpowers/user-flow-updates/progress.md`

**Interfaces:**
- Consumes: all completed tasks and existing backend/Flutter build toolchains.
- Produces: recorded verification evidence and a concise delivery summary.

- [ ] **Step 1: Run complete backend verification**

Run:

```powershell
.\mvnw.cmd test
```

- [ ] **Step 2: Run complete Flutter verification**

Run:

```powershell
flutter test
flutter analyze
```

- [ ] **Step 3: Check formatting and unintended changes**

Run:

```powershell
git -c safe.directory='D:/no game/Code/DatabaseHomework/demo' diff --check
git -c safe.directory='D:/no game/Code/DatabaseHomework/BookStore_Flutter/flutter_application_bookstore' diff --check
```

Review the changed-file list and confirm it contains only files from Tasks 1 through 4 plus this task's tracking files.

- [ ] **Step 4: Update persistent progress and report results**

Mark all completed plan phases in `docs/superpowers/user-flow-updates/task_plan.md`, record exact test commands and outcomes in `progress.md`, and report the changed behavior, files, and any verification limitation to the user.
