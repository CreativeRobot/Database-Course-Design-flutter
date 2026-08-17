# BookStore Flutter 修复与优化计划

## 目标

确认 VS Code 当前显示的 Dart/Flutter 报错，修复可归因于项目代码或配置的问题，并完成可重复的静态分析、格式化和测试验证。基于现状整理后续值得做的改进与优化，避免把环境问题误判为代码问题。

## 阶段

- [completed] 1. 环境与项目基线调查
- [completed] 2. 复现并定位分析/编译错误（用户终端 `flutter analyze` 返回 72 项，其中 17 项 error）
- [in_progress] 3. 编写最小回归测试并实施修复
- [completed] 4. 运行格式化、静态分析、测试和构建验证（格式检查完成；其余三项均记录为依赖阻塞）
- [completed] 5. 形成后续优化路线图

## 约束与决策

- 不覆盖或回滚用户已有修改。
- 先确认根因，再修改业务代码。
- 业务行为修复优先采用测试先行；纯配置或格式调整单独验证。

## 错误记录

| 错误 | 尝试 | 处理 |
|---|---:|---|
| `python` 命令不存在 | 1 | 改用可用的 PowerShell/Flutter 工具链；后续如需脚本先定位运行时 |
| Git 报 `detected dubious ownership` | 1 | 使用单次 `-c safe.directory=...` 参数，不修改全局配置 |
| 内置 `rg.exe` 启动被拒绝 | 1 | 改用 PowerShell 文件遍历和文本搜索 |
| Flutter 无法写入默认用户状态目录 | 1 | 将 `APPDATA`/`LOCALAPPDATA` 重定向到可写临时目录 |
| `flutter.bat`/`dart.bat` 触发 SDK engine 脚本失败 | 1 | 改用 SDK 内置 `dart.exe`，并注入临时 Git 安全目录 |
| `dart analyze` 报 907 个问题 | 1 | 追溯后确认是依赖包路径不可用造成的级联错误，先恢复 Pub 依赖 |
| `dart pub get --offline` 找不到 `flutter_lints` | 1 | 改为在线获取，使用可写的临时 `PUB_CACHE` |
| 沙箱内 `dart pub get` 访问 `https://pub.dev` 返回 socket 错误 | 1 | 尝试受控外部网络权限；该权限请求被运行环境拒绝，改查现有本地缓存 |
| 用户缓存中的包源码可读，但包 `pubspec.yaml` 访问受限 | 1 | 最后尝试显式指定现有 `PUB_CACHE` 离线解析；失败后停止重复尝试 |
| 显式 `PUB_CACHE` 离线解析仍找不到 `flutter_lints`，Analyzer 仍报第三方 URI 不存在 | 1 | 判定 Dart 进程无法直接使用受限缓存路径；尝试复制已有包到可写临时目录做独立分析 |
| 复制 88 个缓存包到临时目录全部被拒绝 | 1 | 当前 Agent 身份无法递归读取用户 Pub 缓存；改为串行验证 Flutter wrapper 是否可直接使用已有配置 |
| `flutter analyze --no-pub` 仍在分析前尝试访问 `pub.dev`，提示找不到 `test` 包 | 1 | 确认项目级分析被依赖恢复阻塞；不继续盲改源码，转做格式/测试/构建阻塞记录 |

## 验证记录

| 命令 | 结果 |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | formatter 检查了 56 个文件并报告 20 个文件需格式化 |
| `dart format lib test` | 13 个文件成功写入格式化结果；7 个文件因 ACL 拒绝未能写回 |
| `flutter analyze --no-pub` | 依赖恢复阶段失败：无法从 `https://pub.dev` 找到 `test` |
| `flutter test --no-pub` | 依赖恢复阶段失败：无法从 `https://pub.dev` 找到 `test` |
| `flutter build web --no-pub` | 依赖恢复阶段失败：无法从 `https://pub.dev` 找到 `test` |
| `git diff --check` | 通过，无空白错误；当前源码 diff 来自 formatter |
| 用户终端 `flutter pub get` | 成功：依赖已下载，14 个包有可升级版本但不满足当前约束 |
| Codex 沙箱重新运行 `flutter analyze --no-pub` | 仍失败：当前执行身份无法读取用户终端下载的 Pub 缓存，继续提示无法找到 `test` |
| 用户终端 `flutter analyze` | 依赖恢复后成功运行；发现 17 个 error、若干 warning/info |
| 用户终端修复后 `flutter analyze` | 已无 error；剩余 56 项为 info/warning，测试文件另有 1 条 unused import 已修正 |
| 用户终端 `flutter test test/books_page_dependencies_test.dart` | 未进入测试执行；`objective_c` native-assets hook 因 Windows 路径空格将 `D:\no` 截断 |
| 映射 `X:` 后执行 `flutter pub get` | 通过，依赖成功解析 |
| 映射 `X:` 后执行 `flutter analyze` | 通过，无 error；剩余 55 项 info/warning |
| 映射 `X:` 后执行目标测试 | 通过，`+2: All tests passed!` |

## 当前真实错误簇

- `books_page.dart` 使用 `CommerceLoadingState`、`CommerceErrorState`、`BookReview`、`BookReviewSummary`，但当前导入/定义链不完整。
- `books_page.dart` 在评价卡片渲染中直接访问可空 review，缺少空值分支。
- `commerce_widgets.dart:158` 将 `Object` 直接传给需要 `String` 的文本参数。

## 当前修复

- 已添加 `test/books_page_dependencies_test.dart`，覆盖加载状态文案渲染和评价模型依赖。
- 已在 `books_page.dart` 补充 `book_review.dart`、`commerce_widgets.dart` 导入。
- 已将 `CommerceLoadingState.message` 从 `Object` 收窄为 `String`，消除 `Text` 参数类型错误。
- 已完成相关文件格式化和 `git diff --check`；等待用户终端重新运行 Analyzer/目标测试确认 GREEN。

## 后续优化路线图

### P0：先恢复可重复开发环境

- 在用户本机普通 VS Code 终端执行 `flutter pub get`，确认 `.dart_tool/package_config.json` 指向当前可读的 Pub 缓存。
- 保持 `pubspec.lock` 纳入版本控制；避免提交 `.dart_tool`、`build` 等生成目录。
- 在 CI 中固定 Flutter/Dart 版本，执行 `flutter pub get`、`flutter analyze`、`flutter test` 和至少一个平台构建。

### P1：修复核心行为并补齐回归测试

- 为 `BooksState.copyWith` 增加清除价格筛选的测试，再补 `clearMinPrice/clearMaxPrice` 或等价的显式清除语义。
- 为 Books/Cart/Orders/Reviews controller 覆盖首次加载、刷新、分页、重复提交、401、网络失败和并发请求场景。
- 将 API 异常映射集中到网络层，减少每个 controller 的重复错误文案和分支。
- 为 `AppConfig` 增加平台/环境地址验证，避免 Android 设备继续使用 `localhost`。

### P2：降低复杂度与运行成本

- 拆分超大页面文件，把列表项、筛选面板、表单、对话框和状态视图移到独立文件。
- 给搜索/筛选请求增加 debounce 和请求序列校验，避免旧请求覆盖新筛选结果。
- 缓存 `SharedPreferences` 实例；评估把 TokenStorage 替换为更清晰的 session store 接口。
- 优化订单刷新策略，避免逐页串行请求；必要时改为服务端刷新接口或限制恢复页数。

### P3：体验与可维护性

- 增加 widget/integration 测试覆盖登录、检索、购物车、下单、确认收货和评价闭环。
- 统一主题、加载/错误/空状态组件，补充 Semantics、键盘操作和小屏布局检查。
- 再评估引入不可变状态模型/代码生成，减少手写 `copyWith` 的可空字段陷阱。
