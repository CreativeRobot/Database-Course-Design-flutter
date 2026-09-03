# 社区交流系统设计规格

## 目标
为网上书店增加一个以图书讨论为中心的社区交流系统，支持帖子、图片、关联图书、评论/回复，以及按时间和条件浏览。

## 范围
### 第一版包含
- 登录用户发布帖子：标题、正文、最多 9 张图片、可关联多本图书。
- 所有访客浏览帖子列表和帖子详情；登录用户可以发表评论和回复评论。
- 帖子按 `create_time DESC, id DESC` 排序。
- 帖子列表支持标题关键词搜索和按关联图书筛选，两个条件可组合。
- 评论支持 `parent_id` 回复关系；客户端展示一级评论及其直接回复。
- 图片采用先上传、后提交帖子 JSON 的两步流程，避免超过现有单请求 5MB 限制。

### 第一版不包含
点赞、收藏、关注、私信、WebSocket 实时评论、推荐算法、图片裁剪和社区管理后台。

## 数据模型
- `community_post`: `id`, `user_id`, `title`, `content`, `status`, `create_time`, `update_time`。
- `community_post_image`: `id`, `post_id`, `image_url`, `sort_order`, `create_time`。
- `community_post_book`: `post_id`, `book_id`，联合主键。
- `community_comment`: `id`, `post_id`, `user_id`, `parent_id`, `content`, `status`, `create_time`, `update_time`。
- 帖子和评论使用状态字段软删除/隐藏；默认状态为 1。
- 外键引用 `users`, `book`, `community_post`，删除帖子时由服务层处理关联数据。

## HTTP 接口
- `GET /api/community/posts?keyword=&bookId=&page=1&size=10`：公开分页列表。
- `GET /api/community/posts/{postId}`：公开帖子详情。
- `POST /api/community/posts`：登录后创建帖子。
- `GET /api/community/posts/{postId}/comments?page=1&size=20`：公开评论分页。
- `POST /api/community/posts/{postId}/comments`：登录后创建评论或回复。
- `POST /api/uploads/images`：登录后逐张上传帖子图片，返回图片 URL。

创建帖子 JSON：
```json
{
  "title": "标题",
  "content": "正文",
  "imageUrls": ["/uploads/posts/1/a.jpg"],
  "bookIds": [1, 2]
}
```

创建评论 JSON：
```json
{
  "content": "评论内容",
  "parentId": 12
}
```

## 校验与安全
- 所有写操作的用户 ID 只能从 JWT 注入的 `@RequestAttribute("userId")` 获取。
- 标题去除首尾空白后长度 1～120；正文 1～5000；评论 1～1000。
- 每帖最多 9 张图片；每张图片沿用已有的 JPG、PNG、GIF、WEBP 和 5MB 限制。
- 关联图书必须存在且为可展示图书；无效 ID 返回 400。
- `parentId` 必须属于同一帖子且为有效评论，否则返回 400。
- 列表只返回 `status = 1` 的帖子；评论只返回 `status = 1` 的评论。

## Flutter 交互
- 新增 `/community`、`/community/posts/new`、`/community/posts/:postId` 路由。
- 交流首页包含标题搜索框、图书筛选、按时间倒序的帖子卡片和发布入口。
- 详情页展示作者、标题、正文、图片轮播、图书标签、评论及回复输入框。
- 发布页使用 `file_picker` 多选图片，最多 9 张；图片逐张上传后提交帖子。
- 未登录用户可浏览，但发布和评论时跳转登录。
- 复用现有 `ApiClient`、`PageResponse`、图书模型和会话状态。

## 错误处理
后端沿用统一 `Result` 和 `BusinessException`；客户端沿用 `ApiException` 的登录过期、网络错误和业务错误文案。
