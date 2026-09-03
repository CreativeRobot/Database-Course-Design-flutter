# Community Exchange System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有网上书店中实现可发帖、带多图、关联图书、评论/回复、按时间浏览和搜索的社区交流系统。

**Architecture:** 后端新增独立 community 领域模块和 Flyway V13 数据模型，帖子图片复用文件存储但使用 `posts/{userId}` 目录；Flutter 新增 feature-first community 模块，复用现有网络、鉴权、分页和图书搜索能力。客户端图片先上传取得 URL，再提交帖子，避免改变现有上传请求限制。

**Tech Stack:** Spring Boot 4.1, Spring Data JPA, Flyway, MySQL, JWT, Flutter, Riverpod, Dio, go_router, file_picker, cached_network_image, intl.

**Spec:** `docs/superpowers/specs/2026-09-03-community-system-design.md`

## Global Constraints

- 帖子标题长度为 1～120，正文长度为 1～5000，评论长度为 1～1000。
- 每帖最多 9 张图片，每张图片沿用 JPG、PNG、GIF、WEBP 和 5MB 限制。
- 写接口必须从 JWT 的 `@RequestAttribute("userId")` 获取用户身份，不信任请求体 userId。
- 帖子按 `create_time DESC, id DESC` 排序；只返回 `status = 1` 数据。
- 不复用 `book_review`；第一版不实现点赞、收藏、关注、私信和实时 WebSocket。

---

### Task 1: 持久化结构与后端领域契约

**Files:**
- Create: `demo/src/main/resources/db/migration/V13__add_community.sql`
- Create: `demo/src/main/java/com/example/demo/entity/CommunityPost.java`
- Create: `demo/src/main/java/com/example/demo/entity/CommunityPostImage.java`
- Create: `demo/src/main/java/com/example/demo/entity/CommunityPostBook.java`
- Create: `demo/src/main/java/com/example/demo/entity/CommunityPostBookId.java`
- Create: `demo/src/main/java/com/example/demo/entity/CommunityComment.java`
- Create: `demo/src/main/java/com/example/demo/repository/CommunityPostRepository.java`
- Create: `demo/src/main/java/com/example/demo/repository/CommunityCommentRepository.java`
- Test: `demo/src/test/java/com/example/demo/service/CommunityServiceTests.java`

**Interfaces:**
- `CommunityPostRepository` exposes `Page<CommunityPost> search(String keyword, Long bookId, Pageable pageable)` and `Optional<CommunityPost> findVisibleById(Long id)`.
- `CommunityCommentRepository` exposes visible comments by post ordered by creation and parent validation lookup.
- Entities expose user/book/post relationships and status fields for the service and VO mappers.

- [ ] **Step 1: Write failing service tests** covering title/content validation, maximum image count, invalid book IDs, and reply parent belonging to another post.
- [ ] **Step 2: Run `mvn -Dtest=CommunityServiceTests test` and verify failure because the community service/contracts do not exist.**
- [ ] **Step 3: Add V13 schema and JPA entities/repositories with the exact constraints above.**
- [ ] **Step 4: Run the focused test again; keep the expected service-level failures until Task 2 supplies the service.**

### Task 2: 后端社区服务、DTO/VO 与 HTTP 接口

**Files:**
- Create: `demo/src/main/java/com/example/demo/dto/CreateCommunityPostDTO.java`
- Create: `demo/src/main/java/com/example/demo/dto/CreateCommunityCommentDTO.java`
- Create: `demo/src/main/java/com/example/demo/vo/CommunityPostVo.java`
- Create: `demo/src/main/java/com/example/demo/vo/CommunityCommentVo.java`
- Create: `demo/src/main/java/com/example/demo/service/CommunityService.java`
- Create: `demo/src/main/java/com/example/demo/controller/CommunityController.java`
- Modify: `demo/src/main/java/com/example/demo/service/FileStorageService.java`
- Create: `demo/src/main/java/com/example/demo/controller/UploadController.java`
- Test: `demo/src/test/java/com/example/demo/service/CommunityServiceTests.java`

**Interfaces:**
- `CommunityService.listPosts(String keyword, Long bookId, int page, int size)` returns `PageVo<CommunityPostVo>`.
- `CommunityService.getPost(Long postId)` returns `CommunityPostVo`.
- `CommunityService.createPost(Long userId, CreateCommunityPostDTO dto)` returns `CommunityPostVo`.
- `CommunityService.listComments(Long postId, int page, int size)` returns `PageVo<CommunityCommentVo>`.
- `CommunityService.createComment(Long userId, Long postId, CreateCommunityCommentDTO dto)` returns `CommunityCommentVo`.
- `FileStorageService.storePostImage(Long userId, MultipartFile file)` returns existing `UploadFileVo`.

- [ ] **Step 1: Extend failing tests to assert successful post creation, list filtering/order, comment creation, and image upload directory behavior.**
- [ ] **Step 2: Run focused tests and observe failures for missing service/controller behavior.**
- [ ] **Step 3: Implement transactional service, request validation, visible search, VO mapping, and controllers.**
- [ ] **Step 4: Run focused tests plus migration/resource tests and verify all pass.**

### Task 3: Flutter 数据层与路由契约

**Files:**
- Create: `flutter_application_bookstore/lib/features/community/data/community_models.dart`
- Create: `flutter_application_bookstore/lib/features/community/data/community_repository.dart`
- Create: `flutter_application_bookstore/lib/features/community/presentation/community_controller.dart`
- Modify: `flutter_application_bookstore/lib/core/constants/api_paths.dart`
- Modify: `flutter_application_bookstore/lib/app/router/app_route_paths.dart`
- Modify: `flutter_application_bookstore/lib/app/router/app_routes.dart`
- Test: `flutter_application_bookstore/test/community_models_test.dart`
- Test: `flutter_application_bookstore/test/community_api_paths_test.dart`

**Interfaces:**
- Models parse post/comment/page JSON and serialize create-post/create-comment payloads.
- Repository exposes list/detail/comments/createPost/uploadImage/createComment using `ApiClient`.
- Controller exposes list/search, detail/comments, submit post and submit comment state transitions.

- [ ] **Step 1: Write failing model, API path, and repository contract tests.**
- [ ] **Step 2: Run the focused Flutter tests and verify failure due to missing community types/paths.**
- [ ] **Step 3: Implement models, repository, controller providers, and three route definitions.**
- [ ] **Step 4: Run focused Dart tests and `dart analyze lib/features/community ...`; verify pass.**

### Task 4: Flutter 社区页面与图书选择/图片上传

**Files:**
- Create: `flutter_application_bookstore/lib/features/community/presentation/community_page.dart`
- Create: `flutter_application_bookstore/lib/features/community/presentation/post_detail_page.dart`
- Create: `flutter_application_bookstore/lib/features/community/presentation/post_editor_page.dart`
- Create: `flutter_application_bookstore/lib/features/community/presentation/community_widgets.dart`
- Modify: existing book/home/profile entry page identified during implementation
- Test: `flutter_application_bookstore/test/community_pages_test.dart`

**Interfaces:**
- `CommunityPage` supports keyword input, book filter, refresh, pagination and navigation.
- `PostDetailPage` displays post media/books/comments and sends new comments/replies.
- `PostEditorPage` validates fields, picks up to 9 images, uploads sequentially and submits selected book IDs.

- [ ] **Step 1: Write failing widget/contract tests for visible page labels, search controls, post card and editor limits.**
- [ ] **Step 2: Run focused tests and verify missing page behavior.**
- [ ] **Step 3: Implement responsive Material UI with existing app theme and auth redirects.**
- [ ] **Step 4: Run focused tests and static analysis.**

### Task 5: 集成入口、回归验证与提交

**Files:**
- Modify: the smallest existing navigation entry file for the community icon/link
- Modify: `task_plan_community.md`, `findings_community.md`, `progress_community.md`

- [ ] **Step 1: Add a visible entry from the existing customer navigation/home without changing admin behavior.**
- [ ] **Step 2: Run `mvn test` in `D:/no game/Code/DatabaseHomework/demo`.**
- [ ] **Step 3: Run `flutter analyze` and `flutter test` in `flutter_application_bookstore`.**
- [ ] **Step 4: Inspect diffs and commit only community changes separately in each repository with message `feat: add community exchange system`.**

---

## Errors Encountered

| Error | Attempt | Resolution |
|---|---:|---|
| `python` command unavailable on Windows runtime | 1 | Continue with PowerShell for planning files; no impact on product implementation |
| First status command used malformed working directory | 1 | Corrected working directory and reran successfully |
