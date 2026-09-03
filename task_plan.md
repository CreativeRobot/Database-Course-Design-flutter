# Task Plan: 管理台关联图书快捷管理

## Goal
在作者、出版社和分类管理项中增加“查看图书”入口，跳转至现有图书管理页并自动应用相应筛选，保留编辑、上下架与删除能力。

## Phases
- [x] 建立干净基线提交：`63e26be`
- [ ] 调研现有管理台列表、图书管理页和路由/筛选状态
- [ ] 编写并运行失败的筛选上下文单元测试（RED）
- [ ] 实现筛选上下文、导航入口与图书页筛选说明（GREEN）
- [ ] 执行格式化、静态分析和可运行测试
- [ ] 提交功能改动

## Constraints
- 复用现有图书管理页，不新建重复管理页。
- 作者、出版社、分类入口均能传递筛选条件。
- 一级分类筛选必须沿用后端的直属二级分类展开规则。
- 不改动后端数据模型或 API 合同，除非调研发现现有管理列表接口缺少必要筛选。

## Errors Encountered
| Error | Attempt | Resolution |
|---|---:|---|
| 无 | 0 | — |

## Errors Encountered (continued)
| Error | Attempt | Resolution |
|---|---:|---|
| `dart test` cannot find direct `package:test` dependency | 1 | Keep the project-standard `flutter_test` file for later; add a dependency-free executable assertion script to observe the required RED/GREEN cycle with the installed Dart SDK. |

## Errors Encountered (continued)
| Error | Attempt | Resolution |
|---|---:|---|
| Batch source edit stopped because a category action snippet did not match exactly | 1 | Earlier independent replacements were written; inspect the partial diff, then apply the remaining category and generic-list edits using line-targeted replacements. Do not rerun the batch. |

## Errors Encountered (continued)
| Error | Attempt | Resolution |
|---|---:|---|
| Dart analyzer found one required-argument error and two unused locals in `admin_catalog_pages.dart` | 1 | Diagnose the generated generic-list and category-recursion call sites before changing code; runtime filter-helper assertions already pass. |

## 2026-08-27 本轮任务
- 已完成图书、作者、出版社及分类管理的关键词搜索链路；分类前后端新增 keyword 参数并保留旧服务方法兼容调用。
- 地址编辑弹窗会优先使用已有地址，收货人和联系电话为空时回填个人资料中的显示名与手机号。
- 结算页从个人资料返回后等待重新请求地址，并清除已失效的选中地址。
- Flutter `diff --check` 无新增空白错误；`flutter analyze --no-pub` 在约30秒无输出后中止，未取得分析通过证据。
- 后端 Maven 编译成功；完整测试执行 43 项，0 failures、3 errors，错误来自既有 Spring 上下文/文件报告权限问题，非本轮编译错误。

---
## 2026-08-29 测试修复、基线提交与用户退款功能

### Goal
先修复当前 Flutter 的 4 个失败测试；完整验证后提交现有改动为基线（不包含 `.dart-appdata/`）；随后在独立功能分支实现普通用户的仅退款/退货退款申请与售后记录。

### Phases
- [ ] 复现并确认 4 个测试失败的根因
- [ ] 最小化修复测试/实现并跑完整 Flutter 测试
- [ ] 提交基线版本（排除 `.dart-appdata/`）
- [ ] 创建退款功能分支/隔离工作目录并确认干净基线
- [ ] TDD 实现普通用户退款/退货退款及售后记录
- [ ] 完整验证并提交退款功能

### Constraints
- 不使用 `git reset --hard`。
- 基线提交包含当前已有业务改动和本轮测试修复；不得包含 `.dart-appdata/`。
- 退款功能复用后端现有 `/api/orders/{orderId}/refunds`、`/api/orders/refunds` 和详情接口。
- 新增生产行为必须先有可正确失败的测试。
- [x] 复现并确认 4 个测试失败的根因
- [x] 最小化修复测试/实现并跑完整 Flutter 测试
- [x] 提交基线版本（排除 `.dart-appdata/`）：`5d62c2d feat: refine customer and admin storefront flows`
- [ ] 创建退款功能分支/隔离工作目录并确认干净基线
- [ ] TDD 实现普通用户退款/退货退款及售后记录
- [ ] 完整验证并提交退款功能

## 2026-08-30 本轮任务：管理员图书折扣

### Goal
先确认并提交当前工作区基线，再为管理员端增加图书折扣设置，并让前台售价按折扣计算。

### Phases
- [x] 验证干净基线并提交“折扣开发前”版本
- [ ] 梳理管理员图书管理与前台售价数据流
- [x] 先写失败测试（折扣边界、售价计算）
- [x] 实现折扣字段/接口/管理端 UI/前台价格展示
- [x] 运行格式化、静态分析、测试并提交功能版本

### Decisions
- 折扣范围：0–100%，100% 表示原价，0% 表示免费。
- 保留原价字段，折后价运行时计算。

### Errors Encountered
| Error | Attempt | Resolution |
|---|---:|---|
| 初始工作目录不是 Git 根目录，实际仓库在 `flutter_application_bookstore` 子目录 | 1 | 后续所有 Git/代码操作定位到子目录 |
| Python 命令不可用 | 1 | 不依赖 session-catchup，改用 PowerShell 和现有计划文件恢复上下文 |
| Git safe.directory 拒绝仓库所有权 | 1 | 使用单次命令配置 `safe.directory=*`，不修改全局配置 |

---
## 2026-09-03 本轮任务：社区评论与关联图书体验

### Goal
完成三项社区体验修改：回复紧跟父评论、发帖关联图书支持书名搜索、首页社区入口与相邻入口一致为图标按钮且悬停显示“社区”。

### Phases
- [x] 确认需求范围与现有实现位置
- [x] 为评论排列和图书筛选编写失败测试（RED）
- [x] 实现评论排列、图书搜索和社区 Tooltip 图标入口（GREEN）
- [x] 格式化并执行专项测试、静态分析和差异检查
- [x] 提交本轮改动

### Decisions
- 一级评论保持接口原始顺序；直接回复紧跟对应父评论并保持回复原始顺序；孤立回复放在末尾。
- 图书搜索按书名大小写不敏感包含匹配；已选但不匹配的图书仍显示且排在前面。
- 桌面端和移动端社区入口统一为 `Tooltip(message: '社区') + IconButton`。

### Errors Encountered
| Error | Attempt | Resolution |
|---|---:|---|
| Git 因沙箱用户与仓库所有者不同报告 dubious ownership | 1 | 所有 Git 命令使用单次 `-c safe.directory=<repo>`，不修改全局配置。 |
| 查询不存在的 `lib/data/models/books` 路径失败 | 1 | 已用 `rg` 定位实际模型路径为 `lib/data/models/book/book.dart`。 |
| `flutter test` 在沙箱中 90 秒无输出且未结束 | 1 | 已中止；先确认 Flutter 可执行路径及仓库已有的本地缓存环境配置，再以相同测试重试。 |
| 精确文本替换因源文件换行符与脚本片段不一致而停止；仅新 helper 文件已写入，页面尚未改动 | 1 | 改用自动适配源文件 LF/CRLF 的 guarded replacement，不重复原命令。 |
| 针对 `books_page.dart` 的静态分析返回 4 个既有未使用私有组件 warning | 1 | 本次改动未涉及这些组件；保留警告记录，另对社区目录和新增测试执行无警告分析。 |
| 完整 `flutter test --no-pub` 运行 98 项通过、4 个测试文件加载失败 | 1 | 失败均来自本轮未修改的既有测试/API 漂移：3 个验证码测试缺少 `securityQuestions` 参数，`homepage_sections_test.dart` 缺少 `BookCategory` 导入；保留专项 12/12 通过作为本轮验证，并在最终说明。 |

---
## 2026-09-03 管理员社区帖子管理

### Goal
管理员可查看全部社区帖子，按标题关键词、用户和状态筛选，并可屏蔽或恢复帖子；屏蔽后普通社区列表、详情和评论入口继续不可见。

### Phases
- [x] 完成设计确认与实施计划
- [x] 后端测试 RED：管理员列表与状态修改
- [x] 后端实现 GREEN 并提交：`5453e5a`
- [x] Flutter 测试 RED：路径、导航、状态交互
- [x] Flutter 数据层、页面和导航实现 GREEN
- [x] 格式化、提交前新鲜验证
- [ ] Flutter 提交

### Constraints
- 在现有工作区原地修改。
- 不修改/提交 `demo/uploads/posts/`。
- 状态值仅允许 0/1，并支持屏蔽后恢复。

### Errors Encountered（管理员帖子管理）
| Error | Attempt | Resolution |
|---|---:|---|
| `dart format` 通过 Flutter 的 `dart.bat` 启动后 60 秒无输出 | 1 | 中止卡住的包装脚本；已确认 SDK 内直接 `dart.exe` 存在，改用直接可执行文件完成格式化，避免重复同一失败路径。 |
| 直接 `dart.exe format` 因无法写入用户 `AppData\Roaming\.dart-tool` 失败 | 2 | 根因是 Dart analytics 初始化写入沙箱外目录；设置可写临时 `APPDATA`/`HOME` 并禁用 analytics 后格式化成功。 |

| 实施计划文档存在行尾空格和 EOF 多余空行，git diff --cached --check 失败 | 1 | 清理每行行尾及 EOF 后重新暂存并复查。 |
---
## 2026-09-03 主页、个人中心与找回密码界面调整

### Goal
删除主页分区右上角辅助文案、移除社区页顶部发帖按钮、在个人中心增加“我的帖子”、补充测试二级分类，并精简忘记密码页左侧文案。

### Phases
- [x] 确认相关页面、帖子查询链路和分类初始化位置
- [ ] 完成主页、社区页、个人中心及找回密码页的界面调整
- [ ] 通过项目既有初始化方式补充二级分类测试数据
- [ ] 格式化并运行相关 Flutter 静态分析（用户选择手动进行功能验收）

### Constraints
- 仅删除社区页右上角的可见发帖按钮，不删除已有发帖路由。
- “我的帖子”只能读取当前登录用户的帖子；优先复用已有接口，确有必要时才新增最小后端接口。
- 不触碰或提交现有未提交的社区画廊改动：`community_widgets.dart`、`post_detail_page.dart`、`.planning/`。
- 本轮不运行功能测试；按用户要求仅执行可编译性/静态分析检查。

| `python` executable was not available while applying the scoped Flutter edit | 1 | The script did not execute and made no file changes. Use the supplied Node.js REPL filesystem capability instead of retrying the unavailable Python command. |

| Node.js source replacements stopped at the API-path pattern because that file uses a different line-ending/text form | 2 | Earlier independent Flutter edits may have been written. Inspect the partial diff and finish remaining edits with line-ending-tolerant replacements; do not rerun the full batch. |

| Node.js REPL filesystem write was denied for `profile_page.dart` after independent API/repository changes had already completed | 3 | Do not retry Node editing. Inspect partial diff and finish the profile/auth changes with PowerShell/.NET writes, which operate under the workspace write policy. |

| Workspace-sandboxed PowerShell/.NET writes were also denied for `profile_page.dart` | 3 | No profile writes were persisted. Request a narrowly scoped elevated PowerShell write for the files the workspace sandbox unexpectedly refuses to modify. |

| Second AuthFrame edit used exact fragments without a leading newline but still found no matching text | 2 | The elevated write did not begin. Diagnose each intended fragment with literal indices and use a deliberately more robust, line-number based transformation. |
- [x] 完成主页、社区页、个人中心及找回密码页的界面调整
- [ ] 通过项目既有初始化方式补充二级分类测试数据
- [ ] 运行格式化并执行 Flutter 静态分析/编译相关检查（用户选择手动进行功能验收）
- [x] 通过项目既有初始化方式补充二级分类测试数据
- [ ] 运行格式化并执行 Flutter 静态分析/编译相关检查（用户选择手动进行功能验收）

| Dart-format setup assigned to PowerShell's read-only `$HOME` variable | 1 | The formatter did not run. Rename the local variable to `$dartHome` while still setting the environment variables; do not repeat the same command unchanged. |

| Flutter analyzer returned exit code 1 with 12 warning/info diagnostics, no error diagnostics | 1 | Do not conceal the result. Since user requested compile-related validation, run a direct Flutter web debug build (no tests) to establish compilation evidence. |
- [x] 运行格式化并执行 Flutter 静态分析/编译相关检查（用户选择手动进行功能验收）

## 2026-09-03 本轮完成摘要
- 已完成主页辅助小字、社区顶部发帖按钮、个人中心“我的帖子”、二级分类测试数据与忘记密码页左侧文案调整。
- 已完成前后端编译相关验证；未运行功能测试，按用户要求留待手动验收。
