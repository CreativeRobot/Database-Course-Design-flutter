# 组合包原子退款实施计划

> **执行要求：** 使用 TDD，逐项先写失败测试并确认失败原因，再写最小实现；后端与 Flutter 分仓提交。不得覆盖两个仓库中已有的用户改动，不得使用 `git add .`。

**日期：** 2026-09-03  
**设计规格：** `docs/superpowers/specs/2026-09-03-atomic-bundle-refund-design.md`  
**Flutter 仓库：** `D:/no game/Code/DatabaseHomework/BookStore_Flutter/flutter_application_bookstore`  
**后端仓库：** `D:/no game/Code/DatabaseHomework/demo`

## 目标

增加以 `OrderBundleApplication` 为边界的整包原子退款：一次申请包含组合快照中的全部成员和数量，共享退款类型、原因、状态及审核结果；审核通过时，退款数量、订单累计退款额、支付状态、库存与库存流水在同一个事务中全成或全败。组合覆盖之外的额外数量继续走普通单品退款。

## 实现边界与架构

### 后端职责划分

- `RefundAvailabilityService`：唯一负责组合覆盖量、普通可退量、组合可退资格和历史冲突判断；普通退款、整包退款和订单 VO 组装都复用它。
- `RefundService`：保留普通单品退款；修复订单项归属、数量重复扣减、组合数量隔离和金额计算。
- `BundleRefundService`：负责整包申请创建、用户/管理员查询、原子审核和 VO 转换。
- `BundleRefundRequest`：整包申请主聚合，持有唯一审核状态。
- `BundleRefundRequestItem`：服务端从订单组合快照生成的不可编辑退款明细。
- `OrderService` 与 `OrderQueryService`：只消费资格服务结果，不自行复制退款算法。

### 数据兼容规则

- V15 新增 `bundle_refund_request` 与 `bundle_refund_request_item`。
- V15 给 `refund_request` 增加 `bundle_aware BOOLEAN NOT NULL DEFAULT FALSE`。
- 历史普通退款自动为 `bundleAware=false`；上线后创建的普通退款设为 `true`。
- 组合成员若存在 `PENDING/APPROVED` 且 `bundleAware=false` 的历史普通退款，则整包退款不可用。
- 新的 `bundleAware=true` 普通退款只能消费组合外数量，可与整包退款先后共存。

### 金额规则

- 普通退款金额：`OrderItem.unitPrice × quantity`，只用于组合外数量；不再按整行 `paidSubtotal / quantity` 混合组合折扣。
- 整包明细金额：`salePrice × quantity - allocatedDiscount`。
- 明细合计必须精确等于 `OrderBundleApplication.bundlePrice`；按 id 顺序计算，最后一条吸收一分尾差。
- 审核累计使用锁定后的 `BookOrder.refundedAmount`，不能另查聚合和订单字段并行计算。

### 锁顺序

创建普通退款：`BookOrder -> OrderItem`。  
创建整包退款：`BookOrder -> OrderBundleApplication -> OrderItem(id asc)`。  
审核整包退款：`BundleRefundRequest -> BookOrder -> OrderBundleApplication -> OrderItem(id asc) -> Book(id asc，仅 RETURN_REFUND)`。

---

## Task 1：数据库迁移与整包退款持久化模型

**新增文件（后端）**

- `src/main/resources/db/migration/V15__add_atomic_bundle_refunds.sql`
- `src/main/java/com/example/demo/entity/BundleRefundRequest.java`
- `src/main/java/com/example/demo/entity/BundleRefundRequestItem.java`
- `src/main/java/com/example/demo/repository/BundleRefundRequestRepository.java`
- `src/main/java/com/example/demo/repository/BundleRefundRequestItemRepository.java`
- `src/test/java/com/example/demo/migration/AtomicBundleRefundMigrationTests.java`

**修改文件（后端）**

- `src/main/java/com/example/demo/entity/RefundRequest.java`

### Step 1.1 — RED：迁移结构测试

编写集成测试，启动 Flyway 后使用 JDBC 元数据断言：

- 两张新表存在；
- 主表包含退款号、订单、组合应用、用户、类型、状态、总额、原因、审核信息和时间字段；
- 明细表包含主申请、订单项、图书快照、数量、单价、优惠分摊和退款金额；
- `refund_request.bundle_aware` 存在且历史插入默认值为 false；
- 主表存在退款号唯一约束；
- 同一组合应用的活动/已通过申请不能依赖数据库部分索引实现，唯一性由锁与服务校验保证。

运行：

`mvn -Dtest=AtomicBundleRefundMigrationTests test`

预期：因 V15 和实体缺失而失败。

### Step 1.2 — GREEN：迁移与实体

- 新增 V15，所有金额列使用 `DECIMAL(10,2)`，外键对应现有表命名。
- 主实体映射 `RefundType`、`RefundStatus`，状态默认 `PENDING`。
- 子实体只关联主申请，不持有审核状态。
- `RefundRequest` 增加 `@Builder.Default private Boolean bundleAware = false`，列名 `bundle_aware`。
- repository 提供：
  - 主申请按 id 悲观锁查询并 fetch order/application/user；
  - 按用户分页；
  - 管理员按状态/类型分页；
  - 按组合应用查询 PENDING/APPROVED；
  - 明细按 request id / application id / order item id 稳定排序查询。

再次运行迁移测试并确认通过。

### Step 1.3 — 提交

后端精确暂存上述文件，提交：

`feat: add atomic bundle refund persistence`

---

## Task 2：共享退款资格服务与普通退款修复

**新增文件（后端）**

- `src/main/java/com/example/demo/service/RefundAvailabilityService.java`
- `src/main/java/com/example/demo/service/RefundAvailability.java`
- `src/main/java/com/example/demo/service/BundleRefundAvailability.java`
- `src/test/java/com/example/demo/service/RefundAvailabilityServiceTests.java`

**修改文件（后端）**

- `src/main/java/com/example/demo/service/RefundService.java`
- `src/main/java/com/example/demo/repository/RefundRequestRepository.java`
- `src/main/java/com/example/demo/repository/OrderBundleApplicationItemRepository.java`
- `src/main/java/com/example/demo/repository/OrderItemRepository.java`
- `src/test/java/com/example/demo/service/RefundServiceTests.java`

### Step 2.1 — RED：资格计算测试

先写以下最小行为测试：

1. `A×2+B×1`、组合覆盖 `A×1+B×1` 时，A 普通数量为 1，B 为 0。
2. 普通 `PENDING` 占用普通数量。
3. 普通 `APPROVED` 已反映在 `refundedQuantity` 时不会被重复扣减；资格以普通记录的批准数量独立计算。
4. `REJECTED` 不占用数量。
5. 历史 `bundleAware=false` 的 PENDING/APPROVED 记录命中组合成员时，组合资格返回明确冲突原因。
6. 新 `bundleAware=true` 普通退款只占用组合外数量，不阻止组合覆盖数量整包退款。
7. 组合已有 PENDING 时不可重复创建；已有 APPROVED 时永久不可再申请；REJECTED 后可重新申请。

运行 `RefundAvailabilityServiceTests`，确认因服务/查询缺失失败。

### Step 2.2 — RED：普通退款回归测试

在 `RefundServiceTests` 增加：

- 路径订单与订单项所属订单不一致时返回 404/409（按项目异常语义选定一种并保持控制器一致），且不保存申请；
- 普通退款数量不能侵占组合覆盖数量；
- 额外 A 的退款金额为完整 `unitPrice`，而非整行平均实付价；
- 新申请设置 `bundleAware=true`；
- 多次普通退款时 PENDING 与 APPROVED 数量计算正确；
- 最后一笔普通退款不会因历史双重扣减被错误拒绝。

运行目标测试，观察预期失败。

### Step 2.3 — GREEN：共享资格与普通退款

- repository 分开提供普通 PENDING 数量、普通 APPROVED 数量、历史冲突查询，禁止继续使用 `sumApprovedOrPendingQuantity` 的混合语义。
- 资格服务按订单项聚合所有组合应用明细数量。
- `RefundService.createRequest` 先锁订单，再锁订单项并验证 `item.order.id == dto.orderId`。
- 可退数量由 `RefundAvailabilityService` 返回。
- 退款额按组合外完整 `unitPrice` 计算，保留 V6 以前无字段订单的兼容分支但不重新混合组合优惠。
- 新普通申请写入 `bundleAware=true`。
- 普通审核保持现有行为，但累计金额基于锁定订单的 `refundedAmount`；同向重复审核幂等，反向终态审核返回 409，与整包语义一致。

运行：

`mvn -Dtest=RefundAvailabilityServiceTests,RefundServiceTests,CustomerRefundControllerTests,RefundControllerTests test`

### Step 2.4 — 提交

后端精确暂存，提交：

`fix: isolate standalone refund quantities from bundles`

---

## Task 3：创建整包退款申请

**新增文件（后端）**

- `src/main/java/com/example/demo/dto/CreateBundleRefundRequestDTO.java`
- `src/main/java/com/example/demo/service/BundleRefundService.java`
- `src/main/java/com/example/demo/controller/BundleRefundController.java`
- `src/main/java/com/example/demo/vo/BundleRefundRequestVo.java`
- `src/main/java/com/example/demo/vo/BundleRefundRequestItemVo.java`
- `src/test/java/com/example/demo/service/BundleRefundServiceTests.java`
- `src/test/java/com/example/demo/controller/BundleRefundControllerTests.java`

**修改文件（后端）**

- `src/main/java/com/example/demo/repository/BookOrderRepository.java`
- `src/main/java/com/example/demo/repository/OrderBundleApplicationRepository.java`
- `src/main/java/com/example/demo/repository/OrderBundleApplicationItemRepository.java`
- `src/main/java/com/example/demo/repository/OrderItemRepository.java`

### Step 3.1 — RED：创建服务测试

覆盖：

- DTO 只接受 `bundleApplicationId/type/reason`，无成员、数量和金额字段；
- 服务端校验订单归属、已支付状态、组合应用属于该订单；
- 无快照明细、明细订单项不属于订单、非法数量或非法金额均拒绝；
- 自动生成全部子项；
- 每个子项金额按快照公式生成；
- 最后一项吸收尾差，子项合计精确等于组合价；
- 重复请求在已有 PENDING 时返回现有申请，不新增第二条；
- 历史冲突与已有 APPROVED 时返回 409；
- 原因 trim 后不能为空。

先运行并确认失败。

### Step 3.2 — GREEN：创建事务与 API

实现：

- `POST /api/orders/{orderId}/bundle-refunds`；
- 路径订单 id 由 controller 写入 DTO 或作为独立 service 参数；
- 锁顺序固定为订单、组合应用、升序订单项；
- 资格检查与主从保存位于一个 `@Transactional` 方法；
- 生成 `BREF + UUID` 唯一退款号；
- 返回包含 `kind=BUNDLE`、组合快照和全部明细的 VO。

运行服务与控制器目标测试。

### Step 3.3 — 提交

后端提交：

`feat: create atomic bundle refund requests`

---

## Task 4：整包原子审核

**新增文件（后端）**

- `src/main/java/com/example/demo/controller/AdminBundleRefundController.java`
- `src/test/java/com/example/demo/controller/AdminBundleRefundControllerTests.java`

**修改文件（后端）**

- `src/main/java/com/example/demo/service/BundleRefundService.java`
- `src/main/java/com/example/demo/repository/BookRepository.java`
- `src/test/java/com/example/demo/service/BundleRefundServiceTests.java`

### Step 4.1 — RED：审核行为测试

覆盖：

- 拒绝只更新主申请审核信息，无数量、金额、库存副作用；
- `REFUND_ONLY` 通过：全部订单项退款数量、订单退款额、申请状态一次更新，不回库存；
- `RETURN_REFUND` 通过：按 book id 升序锁定并回补全部库存，逐明细写 `REFUND_RETURN` 流水；
- 任一库存更新/流水保存失败，整笔事务回滚；
- 任一明细会导致超数量或订单累计超额时，整包全部拒绝落库并返回 409；
- 完全退款后最新 SUCCESS payment 变为 REFUNDED；部分退款不改变支付状态；
- 已 APPROVED 再次批准、已 REJECTED 再次拒绝返回当前结果；终态反向操作返回 409；
- 审核操作只能整体批准或整体拒绝，不接受成员级结果。

### Step 4.2 — GREEN：审核事务

- 新增 `PUT /api/admin/bundle-refunds/{refundId}/review`，复用 `ReviewRefundDTO`。
- 锁主申请后按统一顺序锁订单、组合应用、订单项、图书。
- 批准时用主申请保存的 amount 和 child quantity，不重新读取当前组合定义或当前售价。
- 订单累计金额以锁定的 `order.refundedAmount` 为基准。
- 所有实体更新依赖同一 Spring 事务；不 catch 并吞掉运行时异常。

运行：

`mvn -Dtest=BundleRefundServiceTests,AdminBundleRefundControllerTests test`

### Step 4.3 — 提交

后端提交：

`feat: review bundle refunds atomically`

---

## Task 5：查询接口与订单退款资格字段

**修改/新增文件（后端）**

- `src/main/java/com/example/demo/controller/BundleRefundController.java`
- `src/main/java/com/example/demo/controller/AdminBundleRefundController.java`
- `src/main/java/com/example/demo/service/BundleRefundService.java`
- `src/main/java/com/example/demo/service/OrderService.java`
- `src/main/java/com/example/demo/service/OrderQueryService.java`
- `src/main/java/com/example/demo/vo/OrderItemVo.java`
- `src/main/java/com/example/demo/vo/OrderBundleApplicationVo.java`
- `src/main/java/com/example/demo/vo/BundleRefundRequestVo.java`
- `src/test/java/com/example/demo/service/OrderServiceTests.java`
- `src/test/java/com/example/demo/service/OrderQueryServiceTests.java`（若不存在则新建）
- `src/test/java/com/example/demo/controller/BundleRefundControllerTests.java`
- `src/test/java/com/example/demo/controller/AdminBundleRefundControllerTests.java`

### Step 5.1 — RED：查询契约测试

- 用户列表/详情只能看到自己的整包申请；管理员可按状态/类型分页。
- 用户路径：`GET /api/orders/bundle-refunds`、`GET /api/orders/bundle-refunds/{id}`。
- 管理员路径：`GET /api/admin/bundle-refunds`、`GET /api/admin/bundle-refunds/{id}`。
- 订单项 VO 返回 `bundleCoveredQuantity`、`standaloneRefundableQuantity`。
- 组合 VO 返回 `bundleRefundStatus`、`bundleRefundable`、`bundleRefundUnavailableReason`、`bundleRefundAmount`。
- 两个订单组装服务对同一订单返回完全一致的资格字段。

### Step 5.2 — GREEN：实现统一查询

- 查询 VO 的资格字段全部由 `RefundAvailabilityService` 计算。
- 组合退款金额从快照计算或已存在申请读取，但最终必须等于 bundlePrice。
- 不让 Flutter 根据本地退款列表猜测资格。
- 对没有组合、没有退款历史的旧订单返回稳定默认值（0/false/null），避免 JSON 缺字段导致客户端崩溃。

运行相关目标测试。

### Step 5.3 — 提交

后端提交：

`feat: expose bundle refund eligibility and history`

---

## Task 6：后端迁移、事务与全量验证

**可能修改文件（后端，仅在测试暴露问题时）**

- Task 1–5 中的实现和测试文件

### Step 6.1 — 目标测试

运行：

`mvn -Dtest=AtomicBundleRefundMigrationTests,RefundAvailabilityServiceTests,RefundServiceTests,BundleRefundServiceTests,CustomerRefundControllerTests,RefundControllerTests,BundleRefundControllerTests,AdminBundleRefundControllerTests,OrderServiceTests,OrderQueryServiceTests test`

### Step 6.2 — 全量测试

运行：`mvn test`。

若失败：

- 本功能失败按 systematic-debugging 流程修复；
- 既有无关失败记录具体测试名、错误和与本改动的关系，不篡改无关用户代码。

### Step 6.3 — 数据库约束复核

- 使用测试数据库执行 V1–V15 全迁移；
- 检查金额 scale、默认值、索引与外键；
- 检查服务锁顺序在创建/审核路径一致；
- 检查所有新增查询避免 N+1 或 LazyInitializationException。

不为“验证”额外提交无意义改动；如产生修复，提交：

`test: verify atomic bundle refund backend`

---

## Task 7：Flutter 模型、API、repository 与 provider

**修改文件（Flutter）**

- `lib/core/constants/api_paths.dart`
- `lib/features/refunds/data/refund_models.dart`
- `lib/features/refunds/data/refund_repository.dart`
- `lib/features/refunds/presentation/refunds_providers.dart`
- `lib/features/orders/data/order_models.dart`
- `lib/features/admin/data/admin_models.dart`
- `lib/features/admin/data/admin_repository.dart`
- `lib/features/admin/presentation/admin_providers.dart`
- `test/customer_refund_models_test.dart`
- `test/customer_refund_repository_contract_test.dart`
- `test/admin_refund_management_test.dart`

### Step 7.1 — RED：模型和请求契约

测试：

- `BundleRefundApplication` 只序列化 `bundleApplicationId/type/reason`；
- `BundleRefundRequest` 解析主状态、金额、组合信息、明细和 `kind=BUNDLE`；
- `OrderLine` 解析组合覆盖量和普通可退量；
- `OrderBundleApplication` 解析整包资格字段及不可用原因；
- 普通 `CustomerRefundRequest.isActive` 仅在 PENDING 为 true；
- 顾客和管理员 repository 命中新增 API 路径且使用正确 HTTP 方法；
- provider 在创建/审核后可被 invalidate 刷新。

先运行相关 Flutter 测试并确认因类型/API 缺失失败。

### Step 7.2 — GREEN：数据层

- 在已有文件上增量增加类型，不覆盖用户的库存/组合管理改动。
- 顾客 repository 增加 create/list/detail bundle refund。
- 管理员 repository 增加 list/detail/review bundle refund。
- 新 provider 与普通退款 provider 并存；不把两个分页资源强行合并到 repository 层。

运行目标测试。

### Step 7.3 — 提交

Flutter 精确暂存，提交：

`feat: add bundle refund client data layer`

---

## Task 8：Flutter 订单详情与整包申请 UI

**修改文件（Flutter）**

- `lib/features/orders/presentation/order_detail_page.dart`
- `lib/features/orders/presentation/order_bundle_history.dart`
- `test/customer_refund_application_test.dart`
- `test/customer_refund_navigation_test.dart`
- 新增 `test/customer_bundle_refund_application_test.dart`

### Step 8.1 — RED：用户交互测试

覆盖：

- 组合可退时显示“申请整包退款”；不可退时显示服务端原因；
- 弹窗只允许选共同类型和填写原因，成员、数量、预计金额只读；
- 提交 body 不包含成员、数量或金额；
- 提交中禁用重复点击；成功后刷新订单详情、普通退款列表和整包退款列表；
- 普通商品展示购买数量、组合覆盖数量、可单独退款数量；
- 普通退款选择器最大值为 `standaloneRefundableQuantity`；为 0 时不显示入口并提示去组合区域；
- APPROVED 普通申请不再永久遮挡额外数量的普通退款入口；只有 PENDING 展示处理中状态。

### Step 8.2 — GREEN：订单页实现

- `OrderBundleHistory` 接收申请回调与 loading 状态，但不自行请求网络。
- `order_detail_page.dart` 负责调用 repository、处理错误提示及刷新 provider。
- 所有资格和金额均直接显示服务端字段；UI 不复制资格公式。

运行：

`flutter test test/customer_refund_application_test.dart test/customer_refund_navigation_test.dart test/customer_bundle_refund_application_test.dart`

### Step 8.3 — 提交

Flutter 提交：

`feat: apply for whole bundle refunds`

---

## Task 9：Flutter 顾客历史与管理员整包审核 UI

**修改文件（Flutter）**

- `lib/features/refunds/presentation/customer_refunds_page.dart`
- `lib/features/admin/presentation/admin_orders_reviews_pages.dart`
- `lib/features/admin/presentation/admin_refunds_page.dart`
- `lib/features/admin/presentation/admin_providers.dart`
- `test/admin_refund_management_test.dart`
- 新增 `test/customer_bundle_refund_history_test.dart`
- 新增 `test/admin_bundle_refund_management_test.dart`

### Step 9.1 — RED：列表、详情与审核测试

- 顾客售后页能区分单品和整包卡片，整包只显示一条主申请并展开全部成员；
- 管理员整包列表一条申请一个操作单元，不拆成员；
- 详情显示共同类型、原因、总额、成员金额和审核备注；
- PENDING 才显示“整包通过/整包拒绝”；终态只读；
- 审核中两个按钮都禁用，防止重复点击；
- 审核完成后刷新管理员整包列表/详情和相关订单信息；
- 普通售后现有列表和审核行为保持不变。

### Step 9.2 — GREEN：实现页面

优先在现有售后入口中用 `kind` 区分卡片；如果现有分页结构无法无损合并，则使用同一页面的两个分区/Tab，各自保持后端分页，避免伪造跨资源全局排序。

运行目标测试。

### Step 9.3 — 提交

Flutter 提交：

`feat: review and display bundle refunds`

---

## Task 10：最终验证、文档与提交审计

**可能修改文件**

- `D:/no game/Code/DatabaseHomework/demo/接口文档.md`（该文件已有用户改动，只能增量追加并单独检查 diff）
- 两仓库本功能相关文件

### Step 10.1 — 后端验证

在后端仓库运行：

1. 全部本功能目标测试；
2. `mvn test`；
3. 如项目有打包约定，再运行 `mvn -DskipTests package`。

记录测试数、失败数和退出码。

### Step 10.2 — Flutter 验证

在 Flutter 仓库运行：

1. 退款相关目标测试；
2. `flutter test`；
3. `flutter analyze`。

记录测试数、分析错误/警告及退出码。

### Step 10.3 — 规格逐条核对

逐项核对设计规格第 4–15 节，尤其确认：

- 创建与审核原子性；
- 服务端派生成员/数量/金额；
- 组合覆盖与额外数量隔离；
- 历史兼容 marker；
- 拒绝释放资格；
- 同向审核幂等、反向 409；
- 退货退款全部回库并记录流水；
- 一分尾差；
- 两个订单 VO 组装路径一致；
- Flutter 不本地推导资格。

### Step 10.4 — Git 审计

两个仓库分别执行：

- `git status --short`
- `git diff --check`
- `git diff --stat`
- 检查每个已有脏文件，确认只包含本功能的增量和用户原改动；
- 禁止提交 `.planning/`、`.runtime-temp/`、`uploads/posts/` 和无关库存管理文件。

如接口文档已增量更新，单独精确暂存并提交：

`docs: document atomic bundle refund APIs`

## 完成定义

只有在以下全部满足时才能声明完成：

- V15 可从空库成功迁移；
- 后端目标测试与全量测试有新鲜通过证据；
- Flutter 目标测试、全量测试和 analyze 有新鲜通过证据；
- 原子审核回滚场景被自动化测试覆盖；
- 普通退款的历史缺陷均有回归测试；
- 两仓库 diff 已审计且未混入无关用户改动；
- 最终回复明确列出修改文件、提交、验证命令和任何仍存在的外部限制。

