# API 环境、认证拒绝响应与路由拆分 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不改变书店既有 API、页面 URL 或后端权限语义的前提下，支持安全的 Flutter 多环境 API 地址，拆分集中式 Router，并统一后端 401/403 JSON 拒绝响应。

**Architecture:** Flutter 继续经由 `AppConfig -> ApiClient` 获取基础地址，但环境解析成为独立、可直接单测的工厂；GoRouter 继续由 Riverpod 装配，不过路径、跳转决策和页面路由表各自独立。后端以 Spring 组件 `SecurityErrorResponseWriter` 序列化现有 `Result.error(...)`，供 Security 入口、JWT Filter 和保留的 JWT Interceptor 共用。

**Tech Stack:** Flutter/Dart 3、flutter_test、Riverpod、GoRouter、Dio；Spring Boot、Spring Security、Jackson、JUnit 5、MockHttpServletResponse。

**Spec:** `docs/superpowers/specs/2026-08-23-api-environment-security-routing-design.md`

## Global Constraints

- 既有 REST URL、成功响应字段与错误 JSON 的 `code/message/data` 字段不变。
- `APP_ENV` 缺省为 `development`；仅开发环境允许默认 `http://localhost:8080`。
- `staging` 与 `production` 必须显式传入 `API_BASE_URL`，且只能是绝对 HTTP(S) URL。
- 前端路由守卫不是服务端权限校验的替代品；Spring Security 仍是最终授权来源。
- 保留 `JwtInterceptor`，只替换其重复的响应写入过程；不删除或重命名现有 API。
- 前端验证使用无空格的映射路径（例如 `X:`）以避开 Windows 工具链路径问题。
- 两个仓库都已有未提交内容；只暂存本计划每个任务明确列出的文件，禁止 reset、checkout 或清理无关改动。

---

## File Structure

| 文件 | 责任 |
| --- | --- |
| `lib/core/config/app_environment.dart` | 解析和表示 development/staging/production。 |
| `lib/core/config/app_config.dart` | 解析 `--dart-define`、校验和规范化 API 基地址，同时保留现有测试可用的 `AppConfig(baseUrl: ...)` 构造方式。 |
| `lib/core/providers.dart` | 从运行时环境构造唯一的 `AppConfig`。 |
| `lib/app/router/app_route_paths.dart` | 路径常量与 auth/admin/customer 路径分类。 |
| `lib/app/router/app_route_guard.dart` | 输入 `AuthState` 和 matched location 的纯 redirect 函数。 |
| `lib/app/router/app_routes.dart` | 公共、用户、管理员 `GoRoute` 分组及动态 ID 页面构建。 |
| `lib/app/router/app_router.dart` | GoRouter、认证刷新监听和守卫装配。 |
| `test/app_config_test.dart` | 环境地址配置单测。 |
| `test/app_route_guard_test.dart` | 不依赖 Widget 的访问策略矩阵测试。 |
| `test/app_routes_test.dart` | 路由表保留现有公开、用户和管理路径的回归测试。 |
| `README.md` | 本地、Android 模拟器、staging 和 production 的 `--dart-define` 命令。 |
| `../demo/src/main/java/com/example/demo/common/config/SecurityErrorResponseWriter.java` | 统一安全拒绝响应的 HTTP/JSON 写入器。 |
| `../demo/src/main/java/com/example/demo/common/config/SecurityConfig.java` | 认证入口和拒绝访问处理器委托 writer。 |
| `../demo/src/main/java/com/example/demo/common/config/JwtAuthenticationFilter.java` | Filter 的 token 拒绝分支委托 writer。 |
| `../demo/src/main/java/com/example/demo/common/config/JwtInterceptor.java` | 遗留 Interceptor 的 token 拒绝分支委托 writer。 |
| `../demo/src/test/java/com/example/demo/common/config/SecurityErrorResponseWriterTests.java` | writer 的 401/403 响应体和响应头测试。 |
| `../demo/src/test/java/com/example/demo/common/config/JwtAuthenticationFilterTests.java` | 缺少 Token 时使用标准 401 响应的回归测试。 |

### Task 1: Flutter 多环境 API 配置

**Files:**
- Create: `lib/core/config/app_environment.dart`
- Modify: `lib/core/config/app_config.dart`
- Modify: `lib/core/providers.dart`
- Modify: `README.md`
- Create: `test/app_config_test.dart`

**Interfaces:**
- Produces `AppEnvironment.parse(String rawValue) -> AppEnvironment`。
- Produces `AppConfig.fromDartDefines()` 和 `AppConfig.fromValues({required String environment, String? apiBaseUrl})`。
- 保留 `const AppConfig({required String baseUrl, AppEnvironment environment = AppEnvironment.development})`，以兼容现有 `ApiClient` 测试中的显式本地 HTTP server 地址。

- [ ] **Step 1: 写失败测试**

```dart
import 'package:flutter_application_bookstore/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('development uses localhost when no API base URL is supplied', () {
    final config = AppConfig.fromValues(environment: 'development');
    expect(config.baseUrl, 'http://localhost:8080');
  });

  test('normalizes an explicit HTTPS API base URL', () {
    final config = AppConfig.fromValues(
      environment: 'production',
      apiBaseUrl: ' https://api.example.com/ ',
    );
    expect(config.baseUrl, 'https://api.example.com');
  });

  test('requires an API base URL outside development', () {
    expect(
      () => AppConfig.fromValues(environment: 'staging'),
      throwsA(isA<StateError>()),
    );
  });

  test('rejects unknown environments and non-HTTP URLs', () {
    expect(
      () => AppConfig.fromValues(environment: 'preview', apiBaseUrl: 'https://api.example.com'),
      throwsA(isA<StateError>()),
    );
    expect(
      () => AppConfig.fromValues(environment: 'production', apiBaseUrl: 'ftp://api.example.com'),
      throwsA(isA<StateError>()),
    );
  });
}
```

- [ ] **Step 2: 运行测试，确认 RED**

Run: `flutter test test/app_config_test.dart`

Expected: 编译失败，原因是 `AppConfig.fromValues` 与环境解析 API 尚不存在。

- [ ] **Step 3: 实施最小环境解析与配置工厂**

```dart
enum AppEnvironment {
  development,
  staging,
  production;

  static AppEnvironment parse(String rawValue) {
    return switch (rawValue.trim().toLowerCase()) {
      'development' => AppEnvironment.development,
      'staging' => AppEnvironment.staging,
      'production' => AppEnvironment.production,
      _ => throw StateError('Unsupported APP_ENV: $rawValue'),
    };
  }
}

class AppConfig {
  const AppConfig({
    required this.baseUrl,
    this.environment = AppEnvironment.development,
  });

  factory AppConfig.fromDartDefines() => AppConfig.fromValues(
    environment: const String.fromEnvironment('APP_ENV', defaultValue: 'development'),
    apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
  );

  factory AppConfig.fromValues({
    required String environment,
    String? apiBaseUrl,
  }) {
    final parsedEnvironment = AppEnvironment.parse(environment);
    final candidate = apiBaseUrl?.trim() ?? '';
    if (candidate.isEmpty) {
      if (parsedEnvironment == AppEnvironment.development) {
        return AppConfig(
          baseUrl: 'http://localhost:8080',
          environment: parsedEnvironment,
        );
      }
      throw StateError('API_BASE_URL is required when APP_ENV is ${parsedEnvironment.name}');
    }
    final uri = Uri.tryParse(candidate);
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw StateError('API_BASE_URL must be an absolute HTTP(S) URL');
    }
    return AppConfig(
      baseUrl: candidate.replaceFirst(RegExp(r'/+$'), ''),
      environment: parsedEnvironment,
    );
  }

  final String baseUrl;
  final AppEnvironment environment;
}
```

Change `appConfigProvider` to return `AppConfig.fromDartDefines()`. Add README commands for normal local development, `10.0.2.2` Android emulation, staging and production exactly as defined in the spec.

- [ ] **Step 4: 运行测试并格式化，确认 GREEN**

Run: `dart format lib/core/config/app_environment.dart lib/core/config/app_config.dart lib/core/providers.dart test/app_config_test.dart`

Run: `flutter test test/app_config_test.dart test/api_client_session_expiry_test.dart`

Expected: 新配置测试和已有 `AppConfig(baseUrl: ...)` 调用都通过。

- [ ] **Step 5: 仅提交此任务的前端文件**

```powershell
git add README.md lib/core/config/app_environment.dart lib/core/config/app_config.dart lib/core/providers.dart test/app_config_test.dart
git commit -m "feat: support explicit API environments"
```

### Task 2: 路径常量和纯路由守卫

**Files:**
- Create: `lib/app/router/app_route_paths.dart`
- Create: `lib/app/router/app_route_guard.dart`
- Create: `test/app_route_guard_test.dart`

**Interfaces:**
- Produces `AppRoutePaths` static path constants and `isAuthenticationRoute`, `isAdminRoute`, `isCustomerProtectedRoute` helpers.
- Produces `String? redirectForRoute({required AuthState authState, required String matchedLocation})`.
- Consumes `AuthState.status`, `AuthState.isAuthenticated` and `AuthState.session?.role`; it does not read a provider or `BuildContext`.

- [ ] **Step 1: 写失败测试，覆盖访问矩阵**

```dart
import 'package:flutter_application_bookstore/app/router/app_route_guard.dart';
import 'package:flutter_application_bookstore/app/router/app_route_paths.dart';
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
      redirectForRoute(authState: state, matchedLocation: '${AppRoutePaths.admin}/books'),
      AppRoutePaths.login,
    );
  });

  test('authenticated customers leave auth pages and cannot open admin routes', () {
    const state = AuthState.authenticated(_customerSession);
    expect(
      redirectForRoute(authState: state, matchedLocation: AppRoutePaths.login),
      AppRoutePaths.books,
    );
    expect(
      redirectForRoute(authState: state, matchedLocation: AppRoutePaths.admin),
      AppRoutePaths.books,
    );
  });

  test('checking state and public book routes do not redirect', () {
    expect(
      redirectForRoute(authState: const AuthState.checking(), matchedLocation: '/books/12'),
      isNull,
    );
    expect(
      redirectForRoute(authState: const AuthState.unauthenticated(), matchedLocation: '/search'),
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
```

Add a matching administrator session assertion: `/register` redirects to `/admin` and `/admin/orders` returns `null`.

- [ ] **Step 2: 运行守卫测试，确认 RED**

Run: `flutter test test/app_route_guard_test.dart`

Expected: 编译失败，因为路径与守卫模块尚不存在。

- [ ] **Step 3: 实施路径分类和无副作用的 redirect 函数**

```dart
abstract final class AppRoutePaths {
  static const login = '/login';
  static const register = '/register';
  static const books = '/books';
  static const search = '/search';
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const orders = '/orders';
  static const reviews = '/reviews';
  static const profile = '/profile';
  static const admin = '/admin';

  static bool isAuthenticationRoute(String location) =>
      location == login || location == register;
  static bool isAdminRoute(String location) =>
      location == admin || location.startsWith('$admin/');
  static bool isCustomerProtectedRoute(String location) =>
      location == cart ||
      location == checkout ||
      location == orders ||
      location.startsWith('$orders/') ||
      location == reviews ||
      location == profile;
}

String? redirectForRoute({
  required AuthState authState,
  required String matchedLocation,
}) {
  if (authState.status == AuthStatus.checking || authState.status == AuthStatus.loading) {
    return null;
  }
  final isAdmin = authState.session?.role == 'ADMIN';
  if (authState.isAuthenticated && AppRoutePaths.isAuthenticationRoute(matchedLocation)) {
    return isAdmin ? AppRoutePaths.admin : AppRoutePaths.books;
  }
  if (!authState.isAuthenticated &&
      (AppRoutePaths.isCustomerProtectedRoute(matchedLocation) ||
          AppRoutePaths.isAdminRoute(matchedLocation))) {
    return AppRoutePaths.login;
  }
  if (authState.isAuthenticated &&
      AppRoutePaths.isAdminRoute(matchedLocation) &&
      !isAdmin) {
    return AppRoutePaths.books;
  }
  return null;
}
```

- [ ] **Step 4: 运行测试并格式化，确认 GREEN**

Run: `dart format lib/app/router/app_route_paths.dart lib/app/router/app_route_guard.dart test/app_route_guard_test.dart`

Run: `flutter test test/app_route_guard_test.dart`

Expected: 匿名、普通用户、管理员和 loading/checking 分支均通过，且测试不需要启动 Widget。

- [ ] **Step 5: 仅提交此任务的前端文件**

```powershell
git add lib/app/router/app_route_paths.dart lib/app/router/app_route_guard.dart test/app_route_guard_test.dart
git commit -m "refactor: isolate route access decisions"
```

### Task 3: 路由表从 Router 装配层拆出

**Files:**
- Create: `lib/app/router/app_routes.dart`
- Modify: `lib/app/router/app_router.dart`
- Create: `test/app_routes_test.dart`

**Interfaces:**
- Consumes `AppRoutePaths` 和 `redirectForRoute`。
- Produces `List<RouteBase> buildAppRoutes()`，包含与当前 Router 相同的页面和 malformed book/order ID fallback。
- `appRouterProvider` 继续提供 `GoRouter`，但只负责 refresh listener、initial location、guard 和 `buildAppRoutes()` 装配。

- [ ] **Step 1: 写失败测试，锁定现有路由表**

```dart
import 'package:flutter_application_bookstore/app/router/app_route_paths.dart';
import 'package:flutter_application_bookstore/app/router/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('route table retains public, customer, and administrator entry paths', () {
    final paths = buildAppRoutes()
        .whereType<GoRoute>()
        .map((route) => route.path)
        .toSet();

    expect(paths, containsAll({
      AppRoutePaths.login,
      AppRoutePaths.register,
      AppRoutePaths.books,
      AppRoutePaths.search,
      '${AppRoutePaths.books}/:bookId',
      AppRoutePaths.cart,
      AppRoutePaths.checkout,
      AppRoutePaths.orders,
      '${AppRoutePaths.orders}/:orderId',
      AppRoutePaths.reviews,
      AppRoutePaths.profile,
      AppRoutePaths.admin,
    }));
  });
}
```

- [ ] **Step 2: 运行路由表测试，确认 RED**

Run: `flutter test test/app_routes_test.dart`

Expected: 编译失败，因为 `buildAppRoutes` 尚不存在。

- [ ] **Step 3: 移动页面 builders，保持 URL 和 fallback 行为**

```dart
List<RouteBase> buildAppRoutes() => [
  ..._publicRoutes(),
  ..._customerRoutes(),
  ..._administratorRoutes(),
];

List<GoRoute> _publicRoutes() => [
  GoRoute(path: AppRoutePaths.login, builder: (_, _) => const LoginPage()),
  GoRoute(path: AppRoutePaths.register, builder: (_, _) => const RegisterPage()),
  GoRoute(path: AppRoutePaths.books, builder: (_, _) => const BooksPage()),
  GoRoute(
    path: '${AppRoutePaths.books}/:bookId',
    builder: (_, state) {
      final bookId = int.tryParse(state.pathParameters['bookId'] ?? '');
      return bookId == null ? const BooksPage() : BookDetailPage(bookId: bookId);
    },
  ),
];
```

Complete the same file with the existing search route, customer routes, `/orders/:orderId` fallback, `/admin`, and the `AdminSection.values` loop. Replace `app_router.dart` route literals and local redirect conditions with:

```dart
redirect: (_, state) => redirectForRoute(
  authState: ref.read(authControllerProvider),
  matchedLocation: state.matchedLocation,
),
routes: buildAppRoutes(),
```

Keep `_AuthRouterRefresh` unchanged because it is the existing correct bridge between Riverpod authentication changes and GoRouter refreshes.

- [ ] **Step 4: 运行路由回归测试，确认 GREEN**

Run: `dart format lib/app/router/app_routes.dart lib/app/router/app_router.dart test/app_routes_test.dart`

Run: `flutter test test/app_route_guard_test.dart test/app_routes_test.dart test/books_admin_navigation_test.dart test/books_home_navigation_test.dart`

Expected: 路由表和既有主页/管理台导航测试均通过。

- [ ] **Step 5: 仅提交此任务的前端文件**

```powershell
git add lib/app/router/app_routes.dart lib/app/router/app_router.dart test/app_routes_test.dart
git commit -m "refactor: split router composition from route definitions"
```

### Task 4: 后端统一安全拒绝响应写入器

**Files:**
- Create: `../demo/src/main/java/com/example/demo/common/config/SecurityErrorResponseWriter.java`
- Create: `../demo/src/test/java/com/example/demo/common/config/SecurityErrorResponseWriterTests.java`

**Interfaces:**
- Produces `void SecurityErrorResponseWriter.write(HttpServletResponse response, HttpStatus status, String message) throws IOException`。
- Consumes the Spring-configured Jackson `ObjectMapper` and existing `Result.error(int, String)`.
- Produces `WWW-Authenticate: Bearer` and `Cache-Control: no-store` only for HTTP 401.

- [ ] **Step 1: 写失败测试，锁定 JSON 与响应头契约**

```java
class SecurityErrorResponseWriterTests {
    private final ObjectMapper objectMapper = new ObjectMapper();
    private final SecurityErrorResponseWriter writer =
            new SecurityErrorResponseWriter(objectMapper);

    @Test
    void writesUnauthorizedResultAndBearerHeaders() throws Exception {
        MockHttpServletResponse response = new MockHttpServletResponse();

        writer.write(response, HttpStatus.UNAUTHORIZED, "未登录或Token已失效");

        assertEquals(401, response.getStatus());
        assertEquals("Bearer", response.getHeader("WWW-Authenticate"));
        assertEquals("no-store", response.getHeader("Cache-Control"));
        JsonNode body = objectMapper.readTree(response.getContentAsString());
        assertEquals(401, body.path("code").asInt());
        assertEquals("未登录或Token已失效", body.path("message").asText());
        assertTrue(body.path("data").isNull());
    }

    @Test
    void writesForbiddenResultWithoutAuthenticationChallenge() throws Exception {
        MockHttpServletResponse response = new MockHttpServletResponse();

        writer.write(response, HttpStatus.FORBIDDEN, "无权访问");

        assertEquals(403, response.getStatus());
        assertNull(response.getHeader("WWW-Authenticate"));
        assertNull(response.getHeader("Cache-Control"));
        JsonNode body = objectMapper.readTree(response.getContentAsString());
        assertEquals(403, body.path("code").asInt());
        assertEquals("无权访问", body.path("message").asText());
        assertTrue(body.path("data").isNull());
    }
}
```

- [ ] **Step 2: 运行 writer 测试，确认 RED**

Run: `./mvnw.cmd -Dtest=SecurityErrorResponseWriterTests test`

Expected: 测试编译失败，因为 `SecurityErrorResponseWriter` 不存在。

- [ ] **Step 3: 以 Jackson 和 Result 实施唯一写入点**

```java
@Component
public class SecurityErrorResponseWriter {
    private final ObjectMapper objectMapper;

    public SecurityErrorResponseWriter(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    public void write(HttpServletResponse response, HttpStatus status, String message)
            throws IOException {
        response.setStatus(status.value());
        if (status == HttpStatus.UNAUTHORIZED) {
            response.setHeader("WWW-Authenticate", "Bearer");
            response.setHeader("Cache-Control", "no-store");
        }
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        objectMapper.writeValue(response.getWriter(), Result.error(status.value(), message));
    }
}
```

Use `jakarta.servlet.http.HttpServletResponse`, `org.springframework.http.HttpStatus`, `org.springframework.http.MediaType`, `java.nio.charset.StandardCharsets`, and `java.io.IOException`. Do not add an alternate response DTO.

- [ ] **Step 4: 运行 writer 测试，确认 GREEN**

Run: `./mvnw.cmd -Dtest=SecurityErrorResponseWriterTests test`

Expected: 401/403 status, JSON `code/message/data`, content type/charset, and 401-only headers all pass.

- [ ] **Step 5: 仅提交此任务的后端文件**

```powershell
git add src/main/java/com/example/demo/common/config/SecurityErrorResponseWriter.java src/test/java/com/example/demo/common/config/SecurityErrorResponseWriterTests.java
git commit -m "refactor: centralize security error responses"
```

### Task 5: 将 SecurityConfig、JWT Filter 与 Interceptor 委托给 writer

**Files:**
- Modify: `../demo/src/main/java/com/example/demo/common/config/SecurityConfig.java`
- Modify: `../demo/src/main/java/com/example/demo/common/config/JwtAuthenticationFilter.java`
- Modify: `../demo/src/main/java/com/example/demo/common/config/JwtInterceptor.java`
- Modify: `../demo/src/test/java/com/example/demo/common/config/JwtAuthenticationFilterTests.java`
- Modify: `../demo/src/test/java/com/example/demo/common/config/JwtInterceptorTests.java` only if it needs explicit writer injection for a rejection test.

**Interfaces:**
- Consumes `SecurityErrorResponseWriter` from Task 4.
- `SecurityConfig` retains the same public matcher and role configuration.
- `JwtAuthenticationFilter` receives `SecurityErrorResponseWriter` through constructor injection.
- `JwtInterceptor` receives it through the existing Spring field-injection style or a minimal constructor conversion, without changing public-request or claim-validation rules.

- [ ] **Step 1: 先强化 Filter 的失败测试**

Replace the nonblank-body assertion in `rejectsMissingTokenForProtectedRequest` with exact response assertions and construct the filter with a real writer:

```java
SecurityErrorResponseWriter writer = new SecurityErrorResponseWriter(new ObjectMapper());
JwtAuthenticationFilter filter = new JwtAuthenticationFilter(
        mock(JwtUtils.class), mock(UserRepository.class), writer);

filter.doFilter(request, response, chain);

assertEquals(401, response.getStatus());
assertEquals("Bearer", response.getHeader("WWW-Authenticate"));
assertEquals("no-store", response.getHeader("Cache-Control"));
assertTrue(response.getContentAsString().contains("\"code\":401"));
assertTrue(response.getContentAsString().contains("\"data\":null"));
verify(chain, never()).doFilter(request, response);
```

Update the two other `JwtAuthenticationFilter` constructor calls in the same class to pass the same kind of real writer. Add an Interceptor test that injects a writer, sends a protected request without `Authorization`, expects `false`, HTTP 401, and the standard body.

- [ ] **Step 2: 运行委托前的 Filter/Interceptor 测试，确认 RED**

Run: `./mvnw.cmd -Dtest=JwtAuthenticationFilterTests,JwtInterceptorTests test`

Expected: 编译失败，因为 Filter/Interceptor 尚未接受或调用 writer。

- [ ] **Step 3: 替换三处手写 JSON**

In `SecurityConfig`, extend the current constructor while preserving `JwtAuthenticationFilter` injection:

```java
public SecurityConfig(
        JwtAuthenticationFilter jwtAuthenticationFilter,
        SecurityErrorResponseWriter securityErrorResponseWriter) {
    this.jwtAuthenticationFilter = jwtAuthenticationFilter;
    this.securityErrorResponseWriter = securityErrorResponseWriter;
}
```

Its authentication and access-denied lambdas call `securityErrorResponseWriter.write(response, HttpStatus.UNAUTHORIZED, "未登录或Token已失效")` and `securityErrorResponseWriter.write(response, HttpStatus.FORBIDDEN, "无权访问")`. Delete its private `writeError` method and obsolete charset imports.

In `JwtAuthenticationFilter`, replace integer status arguments with `HttpStatus.UNAUTHORIZED`/`HttpStatus.FORBIDDEN`; its private `reject` becomes:

```java
private void reject(HttpServletResponse response, HttpStatus status, String message)
        throws IOException {
    securityErrorResponseWriter.write(response, status, message);
}
```

Remove its direct JSON/media-type/charset/header code. In `JwtInterceptor`, retain every existing rejection message and return value, but implement:

```java
private boolean reject(HttpServletResponse response, HttpStatus status, String message)
        throws IOException {
    securityErrorResponseWriter.write(response, status, message);
    return false;
}
```

Do not change `WebMvcConfig`, public path rules, token parsing, user-status decisions, or the messages currently returned for invalid user/token conditions. Preserve the existing uncommitted `/api/auth/captcha` public-path change in `JwtInterceptor` while applying this refactor.

- [ ] **Step 4: 运行后端回归测试，确认 GREEN**

Run: `./mvnw.cmd -Dtest=SecurityErrorResponseWriterTests,JwtAuthenticationFilterTests,JwtInterceptorTests test`

Expected: writer, valid authentication, missing-token rejection, captcha allowance, and header/body contract tests all pass.

- [ ] **Step 5: 仅提交此任务的后端文件**

```powershell
git add src/main/java/com/example/demo/common/config/SecurityConfig.java src/main/java/com/example/demo/common/config/JwtAuthenticationFilter.java src/main/java/com/example/demo/common/config/JwtInterceptor.java src/test/java/com/example/demo/common/config/JwtAuthenticationFilterTests.java src/test/java/com/example/demo/common/config/JwtInterceptorTests.java
git commit -m "refactor: reuse security error response writer"
```

### Task 6: 完整验证与交付检查

**Files:**
- Modify only if needed: `task_plan.md`, `findings.md`, `progress.md` in their respective repository; do not stage historical user changes without explicit review.

**Interfaces:**
- Consumes all tasks above.
- Produces command output documenting test results and a whitespace-clean diff for the files touched by this work.

- [ ] **Step 1: 运行前端聚焦与完整验证**

```powershell
subst X: "D:\no game\Code\DatabaseHomework\BookStore_Flutter\flutter_application_bookstore"
Set-Location X:\
flutter test test/app_config_test.dart test/app_route_guard_test.dart test/app_routes_test.dart
flutter test
flutter analyze
```

Expected: 新增测试、现有完整 Flutter 测试通过；若 analyzer 有既有 warning/info，报告数量并区分新增错误与历史诊断。

- [ ] **Step 2: 运行后端聚焦与相关完整验证**

```powershell
Set-Location "D:\no game\Code\DatabaseHomework\demo"
.\mvnw.cmd -Dtest=SecurityErrorResponseWriterTests,JwtAuthenticationFilterTests,JwtInterceptorTests test
.\mvnw.cmd -Dtest=OrderServiceTests,JwtAuthenticationFilterTests,JwtInterceptorTests,SecurityErrorResponseWriterTests test
```

Expected: 所选测试全部通过。若全量 Spring context 或文件上传测试受既有数据库环境、Docker 或 Windows TEMP 权限阻塞，只记录为既有环境限制，不能表述为全量通过。

- [ ] **Step 3: 检查差异、暂存范围和文档命令**

```powershell
git diff --check -- README.md lib/core/config lib/core/providers.dart lib/app/router test/app_config_test.dart test/app_route_guard_test.dart test/app_routes_test.dart
git -C "D:\no game\Code\DatabaseHomework\demo" diff --check -- src/main/java/com/example/demo/common/config src/test/java/com/example/demo/common/config
```

Expected: 两个命令均无输出。确认 README 的四条 `--dart-define` 命令和实际 `AppConfig` 行为一致；确认每次 Git commit 只包含该任务列出的文件。

- [ ] **Step 4: 汇报结果**

在交付说明中列出：新增模块、保持不变的接口/权限边界、实际运行的测试命令及结果、未运行或被环境阻塞的验证，以及每个创建的 commit。不要将 Docker、数据库、Flutter SDK 权限等未运行验证写成通过。
