# Findings

- The approved design is in `docs/superpowers/specs/2026-08-19-home-recommendations-design.md`.
- The branch already contains `RecommendationHome` and `RecommendationBook` models plus tests that describe the missing repository, controller, and widget.
- `BooksPage` is the storefront home surface and already supplies the API base URL and book-detail navigation.
- Existing `ApiClient` automatically attaches the current bearer token to requests.
- The user's mapped-drive test output confirmed the intended red phase: model tests passed while missing recommendation repository/controller/section files caused the other tests to fail at compile time.
- The current production implementation uses the existing `BookRepository` for an isolated search provider keyed by the route's initial keyword; filters and pagination do not share `BooksController` state.
- The first post-implementation analyzer run exposed only two feature errors: a duplicated provider declaration and an unconstrained dropdown helper generic. The widget test exposed a missing Material ancestor around `InkWell`; all three were localized and corrected.
- The subsequent user rerun showed the focused recommendation suite passing (`+3`) and exposed only stale generic call-site errors, now corrected.
- Final user analyzer output has no errors; remaining 56 diagnostics are pre-existing style/lint items outside this feature. Local whitespace validation passes.
- Final verification from the mapped `X:` checkout succeeded: `flutter pub get`, full `flutter test` (25 tests), and Chrome startup all completed successfully.
- The direct `D:\no game\Code` path is unsuitable for Flutter native-asset compilation because its spaces are split by the Windows toolchain; the existing `X:` mapping is the supported execution path.

## 2026-08-23: API 环境、认证拒绝响应与路由拆分（调查中）

- 本工作区 `D:\no game\Code\DatabaseHomework\BookStore_Flutter` 只是容器目录；实际 Flutter Git 仓库为其子目录 `flutter_application_bookstore`。
- 子仓库属于本机用户 `COMPUTER/liyil`，而当前沙箱用户不同；Git 在未配置临时安全目录前会拒绝读取状态。后续只做本仓库作用域的 Git 安全目录配置，绝不写全局配置。
- 该目录中已有上一项推荐功能的计划与验证记录；本项工作以追加章节方式保留历史，不覆盖已有记录。
- 当前 `AppConfig` 仅支持单一 `API_BASE_URL`，默认固定为 `http://localhost:8080`；没有环境名、平台开发地址映射、URL 校验或统一运行命令说明。
- 当前 Router 在 `app_router.dart` 内同时持有 13 类路由、动态参数解析、管理员子路由循环、认证状态订阅及所有登录/角色重定向规则，正是 R1 的集中点。
- `AuthState` 已提供可复用的 `isAuthenticated` 和 `session.role`，且 Router 通过 Riverpod 监听认证变化；拆分应保留这一状态来源而不把权限信息复制到页面层。
- 后端 `SecurityConfig`、`JwtAuthenticationFilter` 与仍存在的 `JwtInterceptor` 分别手写 JSON 拒绝响应；前两者产生同一 `Result` 形状，401 的 `WWW-Authenticate` / `Cache-Control` 细节却不一致。
- 现有 Filter 测试只断言 401 且非空，未锁定 `code/message/data`、响应头和 JSON 序列化契约；本项应先补足这些回归测试，再将三处逻辑委托给统一写入器。
