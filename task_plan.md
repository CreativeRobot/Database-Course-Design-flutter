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
