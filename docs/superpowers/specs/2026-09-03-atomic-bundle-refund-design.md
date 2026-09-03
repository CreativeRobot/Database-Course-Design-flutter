# 组合包原子退款与整包审核设计规格

**日期：** 2026-09-03  
**状态：** 业务方案已由用户确认，待规格复核  
**涉及项目：** Flutter 客户端 `flutter_application_bookstore`、Spring Boot 后端 `../demo`

## 1. 目标

在现有单品退款机制之外，增加以 `OrderBundleApplication` 为业务边界的整包退款。用户只能对下单时实际参与组合优惠的全部成员和数量发起一次共同申请，全部成员共享退款类型、原因、审核状态和审核结果。创建申请与审核通过都必须在后端事务内全成或全败。

组合覆盖数量只能通过整包退款处理；同一订单项中超出组合覆盖的数量仍可使用普通单品退款。例如订单包含 `A×2、B×1`，组合包覆盖 `A×1+B×1`，则 `A×1+B×1` 必须整包退款，额外的 `A×1` 可以单独退款。

## 2. 范围

### 2.1 本期包含

- 新增整包退款主表和明细表。
- 用户创建、查询整包退款申请。
- 管理员查询、整包通过或整包拒绝申请。
- 服务端从订单组合快照派生成员、数量和金额，客户端不得提交这些可信数据。
- 待审核申请占用对应退款资格；拒绝后释放；通过后永久消费。
- 退货退款整包恢复库存并写库存流水；仅退款不恢复库存。
- 普通退款仅允许使用非组合覆盖数量。
- 修复现有退款订单项归属校验、数量重复扣减、前端可退款数量与按钮判断问题。
- 为历史订单提供保守兼容策略。

### 2.2 本期不包含

- 部分批准组合成员。
- 用户修改组合成员或退款数量。
- 一个组合申请混用“仅退款”和“退货退款”。
- 审核后撤销、反审核或退款退回。
- 接入微信、支付宝等外部支付渠道。
- 将全部单品退款迁移成统一通用售后主从模型。

## 3. 方案与边界

采用独立聚合：

```text
BundleRefundRequest
└── BundleRefundRequestItem
```

现有 `RefundRequest` 继续表示普通单品退款。整包退款通过 `bundle_application_id` 关联下单时生成的 `OrderBundleApplication`，不直接信任当前组合包定义。组合包后续改名、改价、换成员或停用均不影响历史退款。

明细不持有独立审核状态。主申请为 `PENDING`、`APPROVED` 或 `REJECTED`，其全部明细共同继承该状态，避免部分成员成功。

## 4. 业务规则

### 4.1 整包退款资格

申请必须同时满足：

1. 订单存在且属于当前用户。
2. 订单已经支付，且不是待支付或已取消状态。
3. `OrderBundleApplication` 存在并属于该订单。
4. 组合应用包含至少一个有效快照明细。
5. 尚无已通过的整包退款。
6. 尚无另一条待审核整包退款。
7. 所有快照明细均关联该订单的 `OrderItem`。
8. 历史单品售后未造成新旧算法冲突。

服务端锁定组合应用后再检查第 5、6 项。并发重复创建时只能产生一条待审核申请；重复网络请求可以返回已有待审核申请。

### 4.2 组合覆盖与普通数量

对每个订单项定义：

```text
bundleCoveredQuantity = 同订单所有 OrderBundleApplicationItem.quantity 之和
standaloneQuantity = OrderItem.quantity - bundleCoveredQuantity
standaloneRefundableQuantity
  = standaloneQuantity
  - 已通过普通退款数量
  - 待审核普通退款数量
```

组合应用之间当前不复用同一图书，因此通常一个订单项只被一个组合应用覆盖。计算仍采用求和方式，避免把该假设写死。

`OrderItem.refundedQuantity` 继续保存所有已通过退款数量的合计，用于订单总体展示，但不再单独承担普通退款资格计算。普通退款资格必须按普通退款记录单独计算。

### 4.3 状态转换

```text
PENDING -> APPROVED
PENDING -> REJECTED
```

- 同方向重复审核为幂等读取：已通过再次通过、已拒绝再次拒绝，直接返回当前结果。
- 终态后提交相反结果返回 `409 Conflict`。
- 已通过申请禁止重新申请。
- 已拒绝申请允许重新申请。

## 5. 数据模型

使用新的 Flyway 迁移，不修改已经应用的历史迁移。

### 5.1 `bundle_refund_request`

| 字段 | 类型 | 约束 | 含义 |
|---|---|---|---|
| id | BIGINT | PK, AUTO_INCREMENT | 主键 |
| refund_no | VARCHAR(40) | NOT NULL, UNIQUE | 整包退款编号 |
| order_id | BIGINT | NOT NULL, FK | 订单 |
| bundle_application_id | BIGINT | NOT NULL, FK | 订单组合应用快照 |
| user_id | BIGINT | NOT NULL, FK | 申请用户 |
| type | VARCHAR(20) | NOT NULL | REFUND_ONLY / RETURN_REFUND |
| status | VARCHAR(20) | NOT NULL | PENDING / APPROVED / REJECTED |
| amount | DECIMAL(10,2) | NOT NULL | 整包退款总额 |
| reason | VARCHAR(500) | NOT NULL | 申请原因 |
| reviewer_id | BIGINT | NULL, FK | 审核人 |
| review_remark | VARCHAR(500) | NULL | 审核备注 |
| reviewed_time | DATETIME(6) | NULL | 审核时间 |
| create_time | DATETIME(6) | NOT NULL | 创建时间 |
| update_time | DATETIME(6) | NOT NULL | 更新时间 |

索引：

- `uk_bundle_refund_no(refund_no)`。
- `idx_bundle_refund_order(order_id)`。
- `idx_bundle_refund_application_status(bundle_application_id, status)`。
- `idx_bundle_refund_status_create(status, create_time)`。

不使用 `(bundle_application_id, status)` 唯一约束，因为同一组合应用允许存在多条已拒绝历史记录。创建服务通过组合应用悲观锁保证活动申请唯一。

### 5.2 `bundle_refund_request_item`

| 字段 | 类型 | 约束 | 含义 |
|---|---|---|---|
| id | BIGINT | PK, AUTO_INCREMENT | 主键 |
| bundle_refund_request_id | BIGINT | NOT NULL, FK | 所属主申请 |
| application_item_id | BIGINT | NOT NULL, FK | 订单组合成员快照 |
| order_item_id | BIGINT | NOT NULL, FK | 订单明细 |
| book_id | BIGINT | NOT NULL | 图书 ID 快照 |
| book_title | VARCHAR(200) | NOT NULL | 书名快照 |
| quantity | INT | NOT NULL, > 0 | 组合覆盖数量 |
| sale_price | DECIMAL(10,2) | NOT NULL | 下单销售价快照 |
| allocated_discount | DECIMAL(10,2) | NOT NULL | 组合优惠分摊 |
| refund_amount | DECIMAL(10,2) | NOT NULL | 本成员退款金额 |

约束和索引：

- 同一主申请中 `application_item_id` 唯一。
- `bundle_refund_request_id` 建普通索引。
- 主申请删除时不级联物理删除；退款审计数据不提供删除操作。

## 6. 金额计算

所有金额由服务端使用订单快照计算：

```text
memberRefundAmount
  = applicationItem.salePrice × applicationItem.quantity
  - applicationItem.allocatedDiscount
```

主申请金额原则上等于：

```text
OrderBundleApplication.bundlePrice
```

创建申请时验证：

```text
所有成员 refundAmount 之和 == bundlePrice
regularAmount - discountAmount == bundlePrice
```

若历史快照存在一分钱的分摊尾差，前 `n-1` 个成员按快照金额计算，最后一个成员使用 `bundlePrice - 前面金额之和`，强制保证主从金额严格一致。成员金额不得为负数，主申请金额不得导致订单累计退款超过 `BookOrder.payableAmount`。

## 7. 后端组件

### 7.1 `BundleRefundService`

负责：

- 创建整包退款；
- 整包审核；
- 用户和管理员查询；
- DTO/VO 转换；
- 组合退款编号生成。

### 7.2 `RefundAvailabilityService`

作为普通退款与组合退款共享的领域组件，负责：

- 订单、订单项、组合应用归属校验；
- 普通可退款数量计算；
- 组合退款资格判断；
- PENDING 数量占用；
- 历史冲突识别；
- 累计退款金额上限校验。

现有 `RefundService` 改用该组件，避免两套逻辑各自计算数量。

### 7.3 Repository 锁接口

新增或扩展查询：

- 按 ID 悲观锁定 `OrderBundleApplication`。
- 按 application ID 查询并排序成员。
- 按 ID 集合升序锁定 `OrderItem`。
- 按 ID 集合升序锁定库存图书。
- 查询组合应用的 PENDING/APPROVED 退款。
- 分别汇总普通 PENDING、普通 APPROVED 和组合 APPROVED 数量/金额。

所有创建和审核流程统一锁顺序：

```text
BookOrder
-> OrderBundleApplication
-> OrderItem（ID 升序）
-> Book（ID 升序，仅退货退款）
```

## 8. 创建事务

接口：

```http
POST /api/orders/{orderId}/bundle-refunds
```

请求：

```json
{
  "bundleApplicationId": 123,
  "type": "RETURN_REFUND",
  "reason": "不需要了"
}
```

客户端不提交成员、数量、优惠或退款金额。

单个 `@Transactional` 流程：

1. 锁定订单并验证用户、支付状态。
2. 锁定组合应用并验证归属。
3. 检查已有 PENDING/APPROVED 整包退款。
4. 读取全部组合成员快照。
5. 按 ID 升序锁定关联订单项。
6. 验证成员、订单项、数量和历史售后兼容性。
7. 计算主申请及全部明细金额。
8. 保存主申请和全部明细。
9. 提交事务。

任何异常均回滚主申请和全部明细。

## 9. 审核事务

接口：

```http
PUT /api/admin/bundle-refunds/{refundId}/review
```

审核拒绝仅修改主申请状态和审核信息，不修改数量、库存、订单退款额或支付状态。

审核通过在单个 `@Transactional` 内：

1. 悲观锁定主申请并处理幂等语义。
2. 锁定订单、组合应用和全部订单项。
3. 重新校验状态、数量和累计退款金额。
4. 若为 `RETURN_REFUND`，按图书 ID 升序锁库存并恢复全部成员库存。
5. 每个成员写一条 `InventoryChangeType.REFUND_RETURN` 流水。
6. 每个 `OrderItem.refundedQuantity += item.quantity`。
7. `BookOrder.refundedAmount += request.amount`。
8. 写入审核人、审核时间、审核备注并将主申请设为 `APPROVED`。
9. 若累计退款等于订单实付金额，将最近的成功支付记录设为 `REFUNDED`。
10. 提交事务。

任一步失败均回滚所有更新，不能留下部分库存回补或部分退款数量。

## 10. API 与返回模型

### 10.1 用户接口

```text
POST /api/orders/{orderId}/bundle-refunds
GET  /api/orders/bundle-refunds
GET  /api/orders/bundle-refunds/{refundId}
```

### 10.2 管理员接口

```text
GET /api/admin/bundle-refunds
GET /api/admin/bundle-refunds/{refundId}
PUT /api/admin/bundle-refunds/{refundId}/review
```

列表支持 `status`、`type`、分页筛选。

### 10.3 返回结构

主 VO 包含订单、组合名称、退款类型、状态、总额、原因、审核信息及 `items`。每个 item 返回订单项、图书快照、数量和退款金额。响应使用 `kind: BUNDLE` 方便 Flutter 在统一售后列表中区分单品与组合。

订单详情中的组合快照增加后端计算字段：

- `bundleRefundStatus`；
- `bundleRefundable`；
- `bundleRefundUnavailableReason`；
- `bundleRefundAmount`。

订单项增加：

- `bundleCoveredQuantity`；
- `standaloneRefundableQuantity`。

Flutter 不自行推导资格。

## 11. Flutter 交互

### 11.1 用户订单详情

在现有组合包历史卡片中展示：

- 组合名称；
- 覆盖成员和数量；
- 组合实付；
- 整包退款状态；
- “申请整包退款”入口。

申请弹窗只允许选择共同退款类型和填写原因，成员、数量和预计金额只读。提交成功后刷新订单详情和退款列表。

单品区域展示购买数量、组合覆盖数量和可单独退款数量。`standaloneRefundableQuantity == 0` 时隐藏或禁用单品入口，并提示到组合包区域申请。

只有 `PENDING` 申请占用按钮。`APPROVED` 通过数量影响剩余可退数量，但如果订单项仍有额外普通数量，单品按钮仍可出现。

### 11.2 管理员

管理员列表以一条整包申请呈现，不拆成多条书目记录。详情展示所有成员及金额，审核操作只有“整包通过”和“整包拒绝”。

若当前 Flutter 管理售后页面将单品申请和组合申请放在同一入口，使用 `kind` 区分卡片；接口仍保持两个后端资源，避免在数据库层强行联合分页。

## 12. 历史兼容

对功能上线前已经存在的组合订单：

- 若组合成员不存在任何 `PENDING` 或 `APPROVED` 单品退款，可使用新整包退款。
- 若任一组合成员已经存在旧单品售后，则该组合应用不允许发起整包退款，返回明确原因并继续使用原流程或人工处理。
- `REJECTED` 历史申请不构成冲突。

这样避免旧的订单行平均退款金额和新的组合快照金额混算。新流程生效后，普通退款服务始终预留组合覆盖数量。

## 13. 错误处理

- `400 Bad Request`：缺少类型、原因、组合无明细、快照金额非法。
- `403 Forbidden`：订单不属于当前用户。
- `404 Not Found`：订单、组合应用、退款申请或关联明细不存在。
- `409 Conflict`：申请状态冲突、已有活动/已通过整包退款、历史单品售后冲突、数量或累计金额被并发占用。

错误消息必须说明用户下一步能做什么，不能只返回“操作失败”。

## 14. 外部支付边界

当前系统只更新本地 `Payment` 状态，没有调用真实支付渠道，因此数据库事务可覆盖当前全部副作用。

未来接入外部支付时，不应在数据库事务中同步等待第三方退款。应增加 `REFUNDING`/`REFUND_FAILED` 状态和 Outbox/任务表，通过幂等支付请求完成最终一致性。本期不提前引入该状态机。

## 15. 测试策略

### 15.1 后端

- `A×2+B×1` 中仅 `A×1+B×1` 属于组合，额外 A 可单退。
- B 的普通可退款数量为 0。
- 创建申请自动生成全部明细且金额等于组合价。
- 客户端伪造成员、数量或金额无入口可提交。
- 组合应用与订单不匹配时拒绝。
- 订单项与订单不匹配时拒绝，覆盖当前所有权缺陷。
- 重复和并发创建只生成一个 PENDING 申请。
- 拒绝无库存、数量和金额副作用。
- 仅退款不回补库存。
- 退货退款回补全部库存并写全部流水。
- 人为制造中途库存失败，验证全部更新回滚。
- 重复同向审核幂等，反向审核返回 409。
- 普通 PENDING 占用数量，APPROVED 不被重复扣减。
- 累计金额不能超过订单实付，完全退款时支付状态为 REFUNDED。
- 分币尾差由最后一条明细吸收。
- 历史单品售后冲突时禁止整包退款。

### 15.2 Flutter

- 模型和接口路径解析。
- 组合可退时展示整包入口。
- 不可退时显示服务端原因。
- 申请弹窗成员和数量不可编辑。
- 组合申请成功后刷新页面。
- 单品数量选择器使用 `standaloneRefundableQuantity`。
- PENDING、APPROVED、REJECTED 状态下按钮行为正确。
- 管理员详情只提供一次整包审核操作。
- 审核中防止重复点击。

## 16. 实施与提交约束

- 后端和 Flutter 分仓实施、分仓验证、分仓提交。
- 两个仓库当前都有用户未提交修改；不得覆盖、回滚或使用 `git add .` 混入这些修改。
- 使用 TDD：先写失败测试，确认失败原因，再实现最小行为并回归。
- Flyway 只新增迁移文件，不修改已经应用的迁移。
- 单品和整包创建/审核必须共享一致的锁顺序。
- 完成前运行后端目标测试及全量测试、Flutter 目标测试、`flutter test` 和 `flutter analyze`，如全量验证受既有问题阻断需准确报告。


