# 管理员社区帖子管理实施计划

**日期：** 2026-09-03
**目标：** 管理员可分页查看社区全部帖子，按标题关键词、发布用户和状态筛选，并可屏蔽或恢复帖子；被屏蔽帖子继续由现有普通社区接口自动隐藏。

## 约束与决策

- 在现有工作区直接实施，不创建新 worktree（用户此前明确要求“在原地”修改）。
- 后端沿用 `CommunityPost.status`：`1` 正常、`0` 已屏蔽。
- 新接口放在 `/api/admin/community/posts` 下，由现有 Spring Security 管理员规则保护。
- 管理端列表展示足够的帖子摘要；仅正常帖子提供普通详情入口，已屏蔽帖子不新增额外管理员详情接口。
- 不触碰或提交后端已有的 `uploads/posts/` 运行时目录。
- 新增行为遵循 TDD：先写测试并确认失败，再实现最小代码使其通过。

## Task 1：后端管理员帖子查询与状态变更

1. 在 `CommunityServiceTests` 新增管理员列表、屏蔽、恢复、非法状态、不存在帖子测试。
2. 运行 `mvn -Dtest=CommunityServiceTests test`，确认新增测试处于 RED。
3. 新增 `CommunityPostStatusDTO`、`AdminCommunityPostController`。
4. 在 `CommunityPostRepository` 增加不限制可见状态的管理员筛选查询。
5. 在 `CommunityService` 增加管理员分页查询和状态修改。
6. 再次运行专项 Maven 测试并确认 GREEN。
7. 检查后端 diff，确保不包含 `uploads/posts/`，然后提交：`feat: add admin community post moderation`。

## Task 2：Flutter 管理数据层

1. 新建 `test/admin_community_posts_test.dart`，先覆盖 API 路径、管理导航项、状态/动作标签和页面类型。
2. 运行该测试并确认因未实现符号而 RED。
3. 在 `ApiPaths` 增加管理员帖子列表和状态变更路径。
4. 在 `AdminRepository` 增加管理员帖子查询与状态修改方法。
5. 在 `admin_providers.dart` 增加筛选记录与分页 Provider。

## Task 3：Flutter 管理页面和导航

1. 新建 `admin_community_posts_page.dart`，实现标题关键词、用户 ID、状态筛选、分页、帖子摘要、正常/已屏蔽标签以及屏蔽/恢复确认操作。
2. 在 `AdminSection` 和 `AdminPage` 中接入“帖子管理”。
3. 仅正常帖子显示可用的“查看”入口；已屏蔽帖子依靠管理卡片内容审核。
4. 运行专项 Flutter 测试，确认 GREEN。

## Task 4：验证与提交

1. 执行 Dart 格式化。
2. 执行 Flutter 专项测试和相关目录静态分析。
3. 执行后端专项测试；可行时执行更完整测试并如实记录既有失败。
4. 执行 `git diff --check` 和状态检查。
5. 提交 Flutter：`feat: add admin community post management`。
6. 汇总实现内容、验证证据及任何既有测试问题。
