# Findings

- 2026-08-26：本功能开始前，Flutter 工作区干净；已建立空基线提交 `63e26be`。
- 待确认：图书管理页当前是否已有作者、出版社与分类筛选参数，以及路由如何传递页面参数。
- 2026-08-26：`rg.exe` 被沙箱拒绝启动，后续代码搜索改用 PowerShell 原生命令。
- 现有 `AdminBooksPage`、作者/出版社/分类页面均位于 `lib/features/admin/presentation/admin_catalog_pages.dart`。
- `AdminPage` 以 `AdminSection` 切换各管理面板，而不是为每个管理项使用独立路由。
- `AdminRepository.books` 与 `adminBooksProvider` 是图书管理列表的数据入口；下一步需确认其参数是否已经覆盖作者、出版社和分类。
- `AdminPage` 通过 `AdminSection` 在单个管理台 Scaffold 内切换内容；进入图书管理应传递一个页面级筛选上下文，而非 GoRouter 新路由。
- 当前 Flutter `AdminRepository.books` 与 `adminBooksProvider` 只传 `status/page`，前端需要扩展作者、出版社、分类参数。
- 后端检索结果过宽被截断；下一步将直接读取管理员图书控制器和服务方法，确认其现有筛选能力。
- 管理端后端 `GET /api/admin/books` 当前只支持 `status/page/size`，因此“查看某作者/出版社/分类图书”需要扩展管理员图书查询 API 及 `BookService.listAllBooks`。
- 公共图书搜索已有作者、出版社、分类谓词；分类筛选使用 `resolveSearchCategoryIds`，可复用以满足一级分类包含直属二级分类的规则。
- Flutter 已使用 Riverpod。最小改动是新增持久的 `AdminBookFilter` 状态，在作者/出版社/分类点击操作时写入状态并切换到 `AdminSection.books`；图书页据此查询并提供清除筛选。
- 2026-08-26：直接执行 `dart test` 无法使用间接依赖的 `package:test`（项目只声明 `flutter_test`）。不增加依赖；保留 Flutter 标准测试文件，并以无依赖的 Dart 断言脚本验证核心 filter helper 的 RED/GREEN。

- 2026-08-27：分类管理页现支持按分类名称搜索，后端 `CategoryRepository`、`CategoryService`、`AdminCategoryController` 已同步增加 keyword 查询。
- 2026-08-27：前端 `AdminRepository`/providers/pages 已同步传递分类 keyword；图书管理页新增按书名搜索框。
- 2026-08-27：地址预填和结算返回刷新实现已落盘，保留原有用户模型及控制器改动。

- 2026-08-29：用户明确顺序为：修复 4 个 Flutter 测试失败 → 提交当前基线（排除 `.dart-appdata/`）→ 开发普通用户退款/退货退款。
- 当前失败测试文件：`test/admin_error_message_test.dart`、`test/books_admin_navigation_test.dart`、`test/books_home_navigation_test.dart`、`test/widget_test.dart`。开始时工作区已有多项未提交业务改动，不能丢弃。
- 初步发现：`admin_error_message_test.dart` 调用了已不存在的 `showAdminActionError`；搜索筛选测试仍期待旧文案 `全部分类`；管理导航测试的类结束锚点或文本断言可能滞后；登录 widget 测试需要单独复现并检查认证状态/路由初始化。
- 2026-08-29：单文件 `flutter test --no-pub test/admin_error_message_test.dart` 无输出悬挂约 120 秒，已中断；这与先前完整测试报告的 4 项普通失败不一致，需先排查进程/锁或 Flutter 前端工具启动状态。
- 2026-08-29：`flutter --verbose test` 同样在输出测试日志前悬挂，初步定位为 Flutter CLI/SDK 级启动阻塞，非单一测试框架输出。测试行为根因调查先以 `dart analyze` 和源代码进行；运行验证需采取不同于直接 Flutter CLI 的策略。
- 2026-08-29：绕过 `flutter.bat.lock` 直接调用 Flutter 工具快照时，工具明确报 `bin/cache/lockfile` 无法打开，确认 SDK 全局锁正在被外部进程持有。当前进程清单不含 Dart/Flutter，且无法在非提升权限下查询文件句柄；不终止不明用户进程，改寻找备用 SDK。
- 2026-08-29：已用受限工作区外 SDK 锁写权限实际复现 4 个失败：
  1. `admin_error_message_test.dart` 编译失败，调用已删除的 `showAdminActionError`。
  2. `books_admin_navigation_test.dart` 在查找已不存在的 `class _BookStoreMark` 时得到 `RangeError`；管理员按钮和头像导航文本仍存在。
  3. `books_home_navigation_test.dart` 仍断言旧文案 `全部分类`，当前分级筛选实现为一级/二级分类。
  4. `widget_test.dart` 没有找到 `欢迎回来`，尚需检查实际初始路由渲染/认证 Provider 状态，不能仅更新断言。
- Flutter CLI 初始无法执行是沙箱拒绝写 Flutter SDK 锁文件；使用受控的提升权限测试命令后已正常得到测试输出。
- 2026-08-29：widget 测试临时输出确认实际渲染为 `Home | Page Not Found`，不是认证持久化或登录文案问题。`BookStoreApp` 的 GoRouter 在测试环境未解析初始路径；下一步读取 `AppRoutePaths` 与现有路由测试，定位 `initialLocation`/路由配置为何落到 Not Found，并以路由级回归测试驱动最小修复。诊断输出将在修复后移除。
- 2026-08-29：验证显示：`admin_error_message_test.dart`、`books_admin_navigation_test.dart`、`books_home_navigation_test.dart` 已通过；`widget_test.dart` 仍失败。`overridePlatformDefaultLocation: true` 单独不足以让测试环境解析 `/login`，需继续调查 GoRouter 初始 URI/测试绑定。
- 2026-08-29：最终根因已确认：`widget_test.dart` 的 ProviderScope 未覆盖 `appConfigProvider`，令认证依赖在 GoRouter redirect 中构造时抛出 `API_BASE_URL is required when APP_ENV is development`；GoRouter 将其包装为 redirect 异常，显示 Page Not Found。已撤销未通过的根路由改动，改为在测试中注入 `http://127.0.0.1:1` 的 AppConfig 并清空 SharedPreferences。该单测已实际通过。

## 2026-08-30 管理员图书折扣任务
- 实际 Flutter Git 仓库位于 `D:\no game\Code\DatabaseHomework\BookStore_Flutter\flutter_application_bookstore`，当前 `HEAD` 为 `32412ea chore: save current workspace state`，工作区干净。
- 需求已确认：管理员设置 0–100% 折扣；100% 原价，0% 免费；原价保留，前台使用折后价。
- 本轮尚未修改业务代码。
- `flutter test --no-pub` was started for fresh baseline verification but produced no output for ~45 seconds and was interrupted; the existing project history records a prior full-suite pass, but this run is not evidence of a current pass.
- `rg.exe` could not start in the sandbox (`拒绝访问`), so code search uses PowerShell `Get-ChildItem` + `Select-String`.
- Existing backend and Flutter contracts already persist `originalPrice` and `salePrice`; no discount column/API field exists. The least invasive implementation is to add a discount-rate input in the admin edit dialog and calculate/persist `salePrice` through the existing API. Customer catalog/detail already show sale price and strike-through original price when discounted.
- TDD RED attempt: the new `test/book_pricing_test.dart` correctly references the not-yet-created pricing utility, but direct Dart test startup failed before test collection because Dart analytics attempted to create `C:\Users\liyil\AppData\Roaming\.dart-tool` and was denied. Next run suppresses analytics and redirects HOME/APPDATA to a writable temp folder.
- The backend `BookService.updateBook` resolves omitted originalPrice from the existing book and validates the new salePrice, so a discount-only update can safely reuse the existing update contract; no Java/schema change is required for this UI feature.

## 2026-09-03 社区三项修改发现
- 评论页面当前直接遍历 `page.records`，需要在渲染前进行父子排列。
- `CommunityComment` 已有 `parentId` 和 `isReply`，无需改 API 模型。
- 发帖页已经一次加载全部 `Book` 选项，可进行本地书名搜索。
- 首页桌面端社区入口当前是 `TextButton.icon`；相邻随机图书和购物车均是 `Tooltip + IconButton`。

## 2026-09-03 管理员社区帖子管理发现
- `CommunityPost.status` 已使用 1=正常、0=屏蔽；普通列表和详情查询已经限制 `status = 1`，因此管理员改为 0 后无需额外修改普通社区查询。
- `/api/admin/**` 已由安全配置限制为管理员角色。
- Flutter 管理端已有评价审核的筛选、确认、屏蔽/恢复交互，可复用其视觉和状态语义。
- 后端仓库已有未跟踪运行时目录 `uploads/posts/`，本轮必须保持不变且不提交。
- 后端管理员帖子管理已实现并提交为 `5453e5a feat: add admin community post moderation`；`uploads/posts/` 保持未跟踪且未提交。
- Flutter 管理端实现已落盘但尚未提交；工作区另有并行产生的社区图书详情/图片画廊改动和 `.planning/`，本轮提交必须显式暂存，不能使用 `git add .`。
- 提交前新鲜验证已完成：相关 Flutter 回归 17/17 通过，管理员帖子页面与新增测试静态分析无问题；后端 `CommunityServiceTests` 14/14 通过。
## 2026-09-03 主页、个人中心与找回密码界面调整
- 当前 Flutter 工作区已有并行未提交改动：`community_widgets.dart`、`post_detail_page.dart` 与 `.planning/`；本轮不会修改或暂存它们。
- 初步定位：主页分区在 `features/books/presentation/homepage_sections.dart`，社区页在 `features/community/presentation/community_page.dart`，个人中心在 `features/profile/presentation/profile_page.dart`。
- 社区帖子模型与仓库位于 `features/community/data/`；后端已有完整分类管理和层级服务，需要进一步定位其运行时初始化/种子数据入口。
- 用户要求只验证编译性，因此本轮不执行功能测试。- `CommunityRepository.listPosts` 目前仅支持关键字、图书和分页筛选，不能按当前用户过滤；“我的帖子”需要增加受登录态约束的最小查询接口或等价查询能力。
- 现有公开路由已经包含社区、发帖和帖子详情，删除社区顶部按钮无需删除路由。
- 数据库的课堂演示数据位于后端 `sql/02_data.sql`；将优先在该脚本补充二级分类，而不伪造前端分类。

## 2026-09-04 continued investigation
- Re-read the active plan and confirmed the user-approved scope is limited to the five requested UI/data changes; verification is limited to formatting and Flutter analysis/compilation-related checks.
- Home sections use `_SectionShell(title, subtitle, child)`; the three current auxiliary subtitles are for 折扣与活动、发售日历、热门. Removing subtitle at the shared shell removes the requested right-aligned helper text consistently.
- Community page has both an AppBar “发布帖子” action and a separate floating “发布” button; only the AppBar action should be removed.
- The expected backend path was incorrectly addressed as `..\\demo`; from the Flutter app its likely sibling must be located before implementation. This failed lookup will not be retried unchanged.
- `AuthFrame` is defined in `auth_pages.dart`, not a separate file. It currently requires eyebrow, headline, description, and bullets; make decorative left-column fields optional so ForgotPassword can supply only headline without altering login/register.
- The backend project is a sibling of `BookStore_Flutter` at `D:\no game\Code\DatabaseHomework\demo`; its community controller is confirmed at `demo\src\main\java\com\example\demo\controller\CommunityController.java`.
- Profile navigation derives both desktop and mobile controls from `ProfileSection.values`, so adding a posts enum value should expose it in both layouts.
- Profile main content uses an exhaustive `switch (_section)` with only overview/orders/security; add a `posts` case and use a self-contained posts section. Existing `SingleChildScrollView` means the section should avoid nested scrolling.
- `AuthFrame` passes its four current textual fields straight into `_EditorialPanel` in desktop and compact layouts. Update those field types to nullable and conditionally omit the eyebrow, decorative line, description, and bullet block for Forgot Password only; retain the headline.
- Existing public feed is deliberately limited to active posts through `CommunityService.listPosts`; the service already has pagination, a `PageRequest` helper, `toPostVo`, and the repository’s admin search. A secure user-owned listing should accept user ID solely from `@RequestAttribute("userId")` and query all that user’s posts (including status 0), not reuse the public feed or accept arbitrary userId from the client.
- The Flutter `CommunityPost` model already includes `userId`, title, timestamps, image URLs, associated books, and comment count, so the profile tab can render a compact card without new response fields.
- Category seed table is named `category`, uses `INSERT IGNORE`, and already contains Computer Science > Database/Programming/Artificial Intelligence, Literature > Classic Literature, and Science > Popular Science. Add non-conflicting direct children using parent-name selects.
- `CommunityPostRepository` has public `search` and admin `searchForAdmin`; add a separate `findByUser_Id` query ordered newest first for the authenticated “我的帖子” endpoint. This keeps normal users from querying other users’ posts while allowing their own hidden posts to be visible to them.
- `CommunityService` already maps the exact response required via `toPostVo` and validates user identity through `getActiveUser`. Reuse its page validation/sorting for `listMyPosts(userId, page, size)`.
- Client API path convention places user-specific resources under the existing domain endpoint; use `GET /api/community/posts/mine` and add it as `ApiPaths.myCommunityPosts`.
- Profile page imports have no community dependencies yet. Add `AppRoutePaths`, `CommunityRepository`/`CommunityPost`, and `CommunityColors` or render the lightweight cards in the existing profile visual palette; navigation can directly call `context.go(AppRoutePaths.communityPost(post.id))`.
- Existing `community_api_paths_test.dart` and `community_pages_test.dart` could be extended, but the user explicitly requested only compilation/static analysis rather than behavior validation; no new functional tests will be added or run in this pass.
- For the password panel, nulling just text fields is insufficient because the existing decorative rule remains; implement a clear `headlineOnly` option that removes eyebrow, rule, description, bullet spacing, including in compact layout.
- Exact profile section label/icon switches are at the end of `profile_page.dart`; both need a posts case (`我的帖子`, an article/forum icon) to retain exhaustive-switch compilation.
- `CommunityPostCard` is an existing reusable card that already shows title, content, images, associated books, timestamp, and comment count and only needs post/baseUrl/onTap. Reuse it from the profile tab rather than duplicating the community presentation.
- `communityRepositoryProvider` is declared in `community_controller.dart`, so profile can define a local `FutureProvider.autoDispose` backed by that provider and `CommunityRepository.listMyPosts`.
- Elevated profile write succeeded. Auth page is still unchanged because the forgot-password call-site uses a different formatting shape than the expected text; next inspect the precise block rather than retrying the same replacement.
- The auth page has mixed LF/CRLF line endings. A per-fragment mixed-EOL replacement helper was necessary; it successfully added `headlineOnly` and suppresses the Forgot Password left-panel eyebrow, decoration, description, and bullet list while retaining the large headline.
- Profile now includes a `我的帖子` navigation item and loads authenticated posts via a local Riverpod provider; it uses the existing `CommunityPostCard`, allows opening post detail, and labels a hidden post as self-visible only.
- Frontend endpoint contract is `GET /api/community/posts/mine?page=&size=`; remaining implementation is the matching authenticated backend endpoint and additional category seeds.
- Backend implementation added `GET /api/community/posts/mine`, obtains the account from the authentication request attribute, validates it through `getActiveUser`, and uses a user-filtered paginated repository query. It is placed before the dynamic `{postId}` mapping.
- Three extra direct children were added to existing categories for test data: Computer Science > Web Development, Literature > Essays, and Science > Astronomy.
- Scoped `git diff --check` emitted no whitespace errors for either Flutter or backend files. It did emit existing line-ending conversion warnings only; these are not whitespace-error findings.
- `dart format` completed on all six changed Dart files and rewrote three.
- Backend compilation check passed: `mvn -DskipTests compile` compiled 219 Java source files and reported `BUILD SUCCESS`.
- Flutter analysis of the six changed Dart files reported 12 existing-style/deprecation/unused-declaration issues and exited non-zero, but it reported no Dart `error` diagnostics. The two warning-level diagnostics (`auth_repository.dart` unused import and `_BrandMark` unused declaration) and the remaining info-level style/deprecation diagnostics pre-existed in these long-standing files; no new compile error was reported.
- To obtain direct Flutter compilation evidence despite the analyzer's warning exit, run `flutter build web --debug --no-pub` next. This is a compile-only build, not a behavior test.
- Flutter web compilation check succeeded: `flutter build web --debug --no-pub` compiled `lib/main.dart` and produced `build/web` successfully. No automated behavior tests were run.
- Final scoped whitespace checks for Flutter and backend both exited successfully; only Git line-ending conversion warnings were emitted.
- Existing parallel Flutter changes remain untouched: `lib/features/community/presentation/community_widgets.dart`, `lib/features/community/presentation/post_detail_page.dart`, and `.planning/`. Backend also has pre-existing/unrelated untracked `uploads/posts/`, which was not modified.
