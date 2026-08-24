# Homepage Recommendations

## Goal

Complete the approved homepage recommendation frontend on the `recommend` branch.

## Plan

- [completed] 1. Recover the approved recommendation contract and inspect the existing Flutter books flow.
- [completed] 2. Confirm the existing recommendation tests fail because the repository, controller, and section are absent.
- [completed] 3. Implement recommendation data/state, homepage presentation, and the independent search results flow.
- [completed] 4. Run focused Flutter tests, static analysis, and Chrome startup verification from the mapped checkout.

## Decisions

- Use `GET /api/recommendations/home?limit=12` and the existing authenticated `ApiClient`.
- Keep the latest successful recommendation list visible when a refresh fails.
- Omit the section when the service returns no eligible books.

## Current Implementation

- Added `ApiPaths.recommendationsHome`, `RecommendationRepository`, and `RecommendationController` with refresh-state retention.
- Added the `RecommendationBooks` homepage section and connected customer-only loading plus independent search navigation in `BooksPage`.
- Added `SearchResultsController`, `BookCatalogGrid`, `SearchResultsPage`, and the public `/search` route with filters and pagination.

## Latest Verification Findings

- User analyzer output identified two new compile errors: a duplicate `searchResultsControllerProvider` and a generic dropdown value typed as `T` instead of `int?`.
- The recommendation widget test identified a missing `Material` ancestor for `InkWell`; the component now supplies its own transparent `Material` wrapper.
- These three issues were fixed and formatted; the mapped-drive focused tests and analyzer need one rerun.
- The user's latest rerun reported `+3: All tests passed!`; analyzer then found three stale generic type arguments at `_optionDropdown<int?>` call sites, which are now removed.
- The latest analyzer rerun reports 56 existing info/warning diagnostics and no errors. `git diff --check` passes.
- Codex reran `flutter pub get` successfully with network access, then ran the full suite from `X:`: all 25 tests passed.
- `flutter run -d chrome --web-port 7357` compiled and connected to Chrome successfully before a clean exit.

## Execution Blocker

- None. The dependency cache was resolved with network access and all final verification commands completed from the mapped checkout.

---

# API 环境、认证拒绝响应与路由拆分

## Goal

在不改变既有 API 路径和业务权限边界的前提下，统一后端 401/403 JSON 拒绝响应，集中 Flutter 多环境 API 配置，并将路由定义与权限跳转逻辑从单一 Router 拆分为可测试模块。

## Plan

- [in_progress] 1. 只读核对 Flutter 网络层、登录状态、Router 和后端 Security 认证拒绝响应的现状。
- [pending] 2. 向用户提交兼容性设计并取得明确批准。
- [pending] 3. 先编写失败测试，覆盖 API 环境解析、路由守卫和认证拒绝响应序列化。
- [pending] 4. 实施最小重构：集中环境配置、拆分 routes/guards、提取后端安全错误响应写入器。
- [pending] 5. 运行聚焦测试、静态分析、Maven 测试和差异检查。

## Constraints

- 仅在用户批准设计后修改业务/生产代码。
- 不重置、删除或覆盖已有未提交改动。
- 保持现有 API 成功与错误字段、路由地址和服务端权限校验兼容；前端路由守卫不替代后端授权。
