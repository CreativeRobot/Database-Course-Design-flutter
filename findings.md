# 调查发现

## 基线

- 项目目录：`D:\no game\Code\DatabaseHomework\BookStore_Flutter\flutter_application_bookstore`
- 当前存在 `.dart_tool`、`build`、`lib`、`test` 等 Flutter 项目目录。
- 当前分支为 `main`，最近提交为 `7b05e59`（改进评价加载与用户端缓存）。
- 工作区原本没有已修改文件；当前未跟踪的 `task_plan.md`、`findings.md`、`progress.md` 是本次排查创建的规划文件。
- 源码按 `app`、`core`、`data`、`features` 分层，已有 `test` 下的模型、会话和默认 Widget 测试。
- Analyzer 已执行；在当前 package 配置下产生 907 个问题，首要问题是第三方 URI 无法解析。
- `.dart_tool/package_config.json` 虽然存在，但依赖根路径指向 `C:\Users\liyil\AppData\Local\Pub\Cache`，当前执行身份无法使用这套缓存。
- `dart pub get --offline` 明确失败：缓存中找不到 `flutter_lints`，说明必须在线恢复依赖或提供可用缓存。
- 沙箱内在线 `dart pub get` 无法连接 `https://pub.dev`；受控外部网络权限请求也被执行环境拒绝。
- `C:\Users\liyil\AppData\Local\Pub\Cache` 及 `flutter_lints-6.0.0`、`flutter_riverpod-2.6.1`、`dio-5.11.0` 目录存在，但当前身份无法枚举 `hosted\pub.dev` 目录；这会影响 Pub 的缓存索引解析。
- 关键包的 `lib` 文件可以读取，但 `flutter_lints-6.0.0\pubspec.yaml` 读取被拒绝；因此 Analyzer/Pub 的失败涉及缓存元数据权限，不只是源码路径。
- 显式设置 `PUB_CACHE=C:\Users\liyil\AppData\Local\Pub\Cache` 后，离线 Pub 仍找不到 `flutter_lints`；Analyzer 对 `core`/`data` 仍报 Dio、Riverpod、SharedPreferences 等 URI 不存在。
- 当前最小可行替代是将现有包源码复制到可写临时目录，并用临时 package config 指向复制后的路径。
- 复制方案失败：缓存中的 88 个包目录均无法递归读取；PowerShell 只能读取少数已知文件路径，无法构造完整依赖树。
- 串行 `flutter analyze --no-pub` 仍提示无法在 `https://pub.dev` 找到 `test` 包，并未进入有效项目分析。
- 当前不能对“剩余真实错误”做可信归因，也不能按 TDD 修改业务代码；任何源码改动都会混入依赖缺失产生的级联错误。
- `dart format --output=none --set-exit-if-changed lib test` 可执行；实际写入格式化后，13 个文件产生 formatter diff，7 个文件因 ACL 拒绝未能写回。
- `git diff --check` 通过，无空白错误；当前 13 个源码文件的差异来自 Dart formatter，没有手工业务逻辑修改。
- 用户终端已成功执行 `flutter pub get`，但 Codex 沙箱重新运行 `flutter analyze --no-pub` 仍无法读取该用户缓存，提示找不到 `test`；需要用户终端直接提供 Analyzer 输出。
- 用户终端 Analyzer 已成功运行：共 72 项诊断，其中 17 项 error，错误集中在 `books_page.dart` 和 `commerce_widgets.dart`。
- `books_page.dart` 的模型/状态类型错误呈级联特征：缺少 `BookReview`/`BookReviewSummary` 导入会同时产生多个未定义类型和后续可空访问错误，需要先确认 import 与模型定义，再处理空值。
- `commerce_widgets.dart:158` 是独立的静态类型错误，需读取该组件的参数类型和调用方数据来源后再修复。
- 已确认 `CommerceLoadingState` 的 `message` 只在项目中以字符串使用，收窄为 `String` 不改变现有调用行为。
- 已确认 `books_page.dart` 需要导入 `BookReview`/`BookReviewSummary` 所在模型文件及公共 Commerce 状态组件文件。
- 用户修复后 Analyzer 不再报告 error；剩余 56 项均为 `info`/`warning` 级 lint。
- 测试失败发生在 native-assets hook 启动阶段，错误命令把带空格的 `D:\no game\...` 当成了 `D:\no`；测试本身没有开始执行。
- 通过 `subst` 将整个工作区和 Flutter SDK 映射到无空格盘符后，在映射盘符下重新执行 `flutter pub get`，可绕开该路径解析问题。
- 用户在 `X:` 映射盘下成功完成依赖获取、Analyzer 和目标测试；当前 55 项均为 info/warning，目标测试 2 项全部通过。
- 这次输出没有执行 `flutter run`，因此只能确认测试和分析成功，不能称为应用界面已启动。
- `flutter test --no-pub` 和 `flutter build web --no-pub` 均在依赖恢复阶段失败，错误均为无法从 `https://pub.dev` 找到 `test`。

## 环境问题

- 终端未找到 `python`。
- Git 需要临时标记该工作区为安全目录才能读取状态。
- 内置 `rg.exe` 无法启动，因此使用 PowerShell 原生命令替代。
- `flutter.bat` 和 `dart.bat` 位于 `D:\no game\Code\Enviroment\fluter\flutter\bin`，工具链可从 PATH 解析。
- Flutter SDK 的 Git 安全目录问题可通过进程级 `GIT_CONFIG_COUNT/GIT_CONFIG_KEY_0/GIT_CONFIG_VALUE_0` 临时配置绕过，不需要修改全局 Git 配置。
- Flutter 随后因无法写入 `C:\Users\liyil\AppData\Roaming\.flutter_tool_state` 退出；需要把 `APPDATA` 临时重定向到可写目录后再运行诊断。
- SDK 当前在 `stable` 分支，落后远端 4 个提交；本次先不升级 SDK，避免把环境升级混入项目修复。

## 当前假设

- 假设：使用当前 Dart 3.12.2 的 `dart.exe`，把 `PUB_CACHE` 指向可写临时目录并在线运行 `pub get`，可以生成当前用户可用的依赖配置。
- 验证方式：`dart pub get` 成功后检查 `.dart_tool/package_config.json` 的依赖路径，再重新运行 `dart analyze`。
- 当前替代路径：检查 `C:\Users\liyil\AppData\Local\Pub\Cache` 是否能被当前执行身份读取；若能读取，直接复用；若不能，项目依赖恢复需要用户本机工具链完成。

## 源码巡检

- 最大页面文件约 1905 行（profile）、1451 行（books）、1129 行（admin），页面、交互和状态处理高度聚合，后续应拆分为功能组件/状态单元。
- 测试目前主要覆盖 admin/order/review 模型和会话事件；没有发现 Books、Cart、Orders、Reviews controller 的行为测试。
- `BooksState.copyWith` 对 `minPrice` 与 `maxPrice` 使用 `value ?? oldValue`，没有对应的清空标志；清除价格筛选时可能保留旧值。
- `AppConfig` 默认 API 地址为 `http://localhost:8080`；Android 模拟器、真机和 Web 的后端地址应通过环境或构建配置注入。
- `TokenStorage` 每次操作都调用 `SharedPreferences.getInstance()`；可在应用生命周期内缓存实例，并为存储失败补充边界测试。
- `OrdersController.refreshLoadedOrders` 会按已加载页逐页串行请求；当用户加载多页后刷新，延迟会线性增长。
