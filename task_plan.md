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
