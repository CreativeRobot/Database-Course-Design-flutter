# 图书组合包设计规格

**日期：** 2026-09-02  
**状态：** 已由用户确认  
**涉及项目：** Flutter 客户端 `flutter_application_bookstore`、Spring Boot 后端 `../demo`

## 1. 目标

新增由管理员维护的图书组合包。一个组合包由 2～10 本不同图书组成，并配置一个低于成员图书当前售价合计的固定组合价。普通用户可以在图书详情页看到相关组合包并整套加入购物车；购物车根据已选商品自动寻找互不重叠且总优惠最大的组合方案；创建订单时由后端重新计算、分摊并保存组合优惠与历史快照。

本功能复用现有图书 `salePrice` 作为单独购买价格，复用现有订单 `discountAmount` 作为组合优惠总额，不改变当前单本图书折扣机制。

## 2. 范围

### 2.1 本期包含

- 管理员创建、查询、编辑、启用和停用组合包。
- 每个组合包包含 2～10 本不同图书，每本固定 1 份。
- 管理员直接填写组合包总价。
- 商品详情页按条件展示包含当前图书的有效组合包。
- 用户可将一个组合包整套、原子地加入购物车。
- 购物车返回所有完整匹配的组合包和自动选中的最优组合方案。
- 同一本图书的一份商品不能同时参与两个组合包。
- 同一个组合包在一张订单中最多应用一次。
- 后端在订单事务中重新计算组合优惠。
- 订单保存组合包应用快照和订单项优惠分摊。
- 退款基于订单项实际支付金额，避免组合优惠订单超额退款。
- 普通用户和管理员订单详情展示历史组合包快照。

### 2.2 本期不包含

- 同一个组合包在一张订单中重复应用多次。
- 组合包成员自定义数量，例如同一本书配置 2 本。
- 用户手动选择使用哪个组合包。
- 优惠券、会员折扣、满减、限时活动和组合包叠加顺序配置。
- 组合包时间窗口、用户限购、库存预留或独立组合包库存。
- 组合包封面上传；第一版使用成员图书封面进行展示。

## 3. 业务规则

### 3.1 管理规则

1. 组合包名称不能为空，最大长度 100。
2. 说明可为空，最大长度 500。
3. 每个组合包必须包含 2～10 本不同图书。
4. 组合包价格必须大于等于 0，保留两位小数。
5. 创建、编辑或启用时，组合价必须严格小于成员图书当前 `salePrice` 合计。
6. 成员图书必须存在。
7. 组合包不物理删除，只允许停用，以保护历史引用和审计信息。
8. 图书后续降价可能使组合包价格不再优惠。此时组合包保留为 ACTIVE，但运行时视为“价格失效”，不参与普通用户查询、购物车匹配或订单应用；管理员列表显示警告并允许调整价格。
9. 成员图书下架时，组合包仍保留，但不作为可购买组合包返回。

### 3.2 购买规则

1. 一个组合包消费每个成员图书 1 份。
2. 用户已选购物车中每个成员图书的数量均至少为 1 时，该组合包才完整匹配。
3. 同一个组合包每张订单最多应用一次。
4. 第一版按图书种类判断冲突：两个组合包只要共享同一个图书 ID 就不能同时应用，即使购物车中该图书数量大于 1。
5. 同种图书的额外数量以及未被组合包使用的商品按图书当前 `salePrice` 结算。
6. 多个候选组合包发生成员冲突时，选择总优惠最大的互不重叠组合集合。
7. 最大优惠相同时，按照应用组合包 ID 升序组成的序列进行字典序比较，选择字典序较小的方案，保证结果稳定。
8. 组合优惠不与其他订单级优惠叠加；当前系统没有其他生效的订单级优惠。
9. Flutter 只能展示后端计算结果，不能向创建订单接口提交组合包价格或优惠金额。

### 3.3 可见性和可用性

一个组合包只有同时满足以下条件时才对普通用户可见并可匹配：

- 状态为 ACTIVE；
- 包含目标图书；
- 全部成员图书为 ON_SALE；
- 全部成员图书库存至少为 1；
- 组合包价格严格低于成员当前 `salePrice` 合计。

详情接口没有符合条件的组合包时返回空数组，Flutter 完全隐藏组合包区域。

## 4. 数据模型

使用 Flyway 新增迁移 `V7__add_book_bundles.sql`。

### 4.1 `book_bundle`

| 字段 | 类型 | 约束 | 含义 |
|---|---|---|---|
| id | BIGINT | PK, AUTO_INCREMENT | 组合包 ID |
| name | VARCHAR(100) | NOT NULL | 名称 |
| description | VARCHAR(500) | NULL | 说明 |
| bundle_price | DECIMAL(10,2) | NOT NULL, >= 0 | 固定组合价 |
| status | VARCHAR(20) | NOT NULL | ACTIVE / INACTIVE |
| create_time | DATETIME(6) | NOT NULL | 创建时间 |
| update_time | DATETIME(6) | NOT NULL | 更新时间 |

索引：

- `idx_book_bundle_status_id(status, id)`。

### 4.2 `book_bundle_item`

| 字段 | 类型 | 约束 | 含义 |
|---|---|---|---|
| id | BIGINT | PK, AUTO_INCREMENT | 主键 |
| bundle_id | BIGINT | FK -> book_bundle.id | 组合包 |
| book_id | BIGINT | FK -> book.id | 成员图书 |
| display_order | INT | NOT NULL, > 0 | 展示顺序 |

约束和索引：

- `UNIQUE(bundle_id, book_id)`，禁止重复成员。
- `UNIQUE(bundle_id, display_order)`，保证展示顺序唯一。
- `idx_bundle_item_book_bundle(book_id, bundle_id)`，支持按图书查询组合包。
- 组合包和图书均使用 `ON DELETE RESTRICT`。

### 4.3 `order_bundle_application`

| 字段 | 类型 | 约束 | 含义 |
|---|---|---|---|
| id | BIGINT | PK, AUTO_INCREMENT | 应用记录 ID |
| order_id | BIGINT | FK -> book_order.id | 所属订单 |
| bundle_id | BIGINT | NULL, FK -> book_bundle.id | 原组合包 ID |
| bundle_name | VARCHAR(100) | NOT NULL | 名称快照 |
| regular_amount | DECIMAL(10,2) | NOT NULL, >= 0 | 成员普通售价合计快照 |
| bundle_price | DECIMAL(10,2) | NOT NULL, >= 0 | 组合价快照 |
| discount_amount | DECIMAL(10,2) | NOT NULL, >= 0 | 优惠快照 |

约束：

- `discount_amount = regular_amount - bundle_price`。
- `bundle_price < regular_amount`。
- `UNIQUE(order_id, bundle_id)`，落实同一组合包每张订单最多一次。
- 历史记录保存名称和金额快照；即使未来允许清理组合包，`bundle_id` 也可置空，快照仍完整。

### 4.4 `order_bundle_application_item`

| 字段 | 类型 | 约束 | 含义 |
|---|---|---|---|
| id | BIGINT | PK, AUTO_INCREMENT | 主键 |
| application_id | BIGINT | FK -> order_bundle_application.id | 组合包应用记录 |
| order_item_id | BIGINT | FK -> order_item.id | 对应订单项 |
| book_id | BIGINT | NOT NULL | 图书 ID 快照 |
| book_title | VARCHAR(200) | NOT NULL | 书名快照 |
| allocated_discount | DECIMAL(10,2) | NOT NULL, >= 0 | 此成员分摊的优惠 |

约束：

- `UNIQUE(application_id, order_item_id)`。
- `UNIQUE(order_item_id)`，第一版中一个订单项最多属于一个已应用组合包。

### 4.5 修改 `order_item`

新增：

| 字段 | 类型 | 默认值 | 含义 |
|---|---|---|---|
| discount_amount | DECIMAL(10,2) | 0.00 | 此订单项分摊的组合优惠 |
| paid_subtotal | DECIMAL(10,2) | 与 subtotal 相同 | 此订单项实际支付金额 |

数据库约束：

```text
0 <= discount_amount <= subtotal
paid_subtotal = subtotal - discount_amount
paid_subtotal >= 0
```

迁移现有数据时：

```text
discount_amount = 0.00
paid_subtotal = subtotal
```

### 4.6 订单金额不变量

创建和更新订单相关数据时必须满足：

```text
book_order.total_amount = SUM(order_item.subtotal)
book_order.discount_amount = SUM(order_item.discount_amount)
book_order.payable_amount = total_amount - discount_amount + shipping_fee
SUM(order_bundle_application.discount_amount) = book_order.discount_amount
SUM(order_bundle_application_item.allocated_discount)
  = SUM(order_bundle_application.discount_amount)
```

应用层必须维护所有跨表求和不变量；数据库继续维护单行金额公式。

## 5. 后端组件

### 5.1 实体和仓储

新增：

- `BookBundle`
- `BookBundleItem`
- `BookBundleStatus`
- `OrderBundleApplication`
- `OrderBundleApplicationItem`
- 对应 Repository

修改：

- `OrderItem` 增加 `discountAmount` 和 `paidSubtotal`。
- `BookOrder` 保留现有金额字段，不新增重复字段。

Repository 需要支持：

- 管理端分页查询组合包；
- 按组合包 ID 获取成员；
- 按图书 ID 查询有效候选组合包；
- 按一组已选图书 ID 查询可能完整匹配的组合包；
- 按订单查询应用快照。

### 5.2 `BundlePricingService`

建立独立、无 Web 状态的领域服务，负责：

1. 根据当前图书价格计算组合包普通合计和优惠。
2. 过滤停用、下架、缺货、成员不完整或价格失效的组合包。
3. 从已选商品数量构建候选组合包。
4. 选择总优惠最大的互不重叠组合集合。
5. 按成员售价比例分摊每个组合包优惠。
6. 处理分币尾差并返回确定性结果。

建议接口形态：

```java
BundlePricingResult calculate(
    Map<Long, SelectedBookPrice> selectedBooks,
    List<BundleCandidate> candidates
)
```

返回：

```text
regularAmount
bundleDiscountAmount
payableAmount
eligibleBundles
appliedBundles
itemDiscountsByBookId
```

该服务不读取数据库，便于使用纯单元测试覆盖组合算法。

### 5.3 最大优惠算法

1. 只保留完整匹配且优惠大于 0 的候选组合包。
2. 按优惠金额降序、组合包 ID 升序排序。
3. 使用深度优先搜索枚举“选或不选”。
4. 维护已经被组合占用的图书 ID 集合；任意共享图书 ID 的候选组合互斥，不根据购物车额外数量重复放行。
5. 使用剩余候选优惠和作为上界进行剪枝。
6. 比较方案时先比较总优惠，再使用组合包 ID 序列作为稳定次序。

第一版每个组合包最多应用一次，候选组合包通常较少，精确搜索能满足课程设计规模并严格符合“最大总优惠”规则。算法必须单独测试，不允许用不能保证全局最优的贪心算法替代。

### 5.4 优惠分摊

对于一个组合包：

```text
regularAmount = SUM(member.salePrice)
discount = regularAmount - bundlePrice
rawMemberDiscount = discount * member.salePrice / regularAmount
```

步骤：

1. 每个成员先向下截断到分。
2. 计算尚未分配的分币数量。
3. 按原始小数余数降序、成员售价降序、图书 ID 升序分配剩余分币。
4. 保证每个成员分摊不为负且不超过其售价。
5. 保证成员分摊之和精确等于组合优惠。

订单项购买多份时，组合包只消费其中一份，但分摊优惠记在该订单项的总 `discountAmount` 中；其他份数仍包含在普通 `subtotal` 中。

## 6. 后端接口

所有接口继续使用现有统一 `Result<T>` 响应格式和 JWT 权限规则。

### 6.1 管理员组合包接口

```http
GET /api/admin/bundles
GET /api/admin/bundles/{bundleId}
POST /api/admin/bundles
PUT /api/admin/bundles/{bundleId}
PUT /api/admin/bundles/{bundleId}/status
```

分页列表参数：

```text
keyword?
status?
page=1
size=20
```

创建请求：

```json
{
  "name": "Java Web 学习套装",
  "description": "适合 Java Web 初学者",
  "bundlePrice": 199.00,
  "bookIds": [1, 2, 3]
}
```

修改请求整体替换名称、说明、价格和成员列表，避免部分成员更新语义不清。

状态请求：

```json
{
  "status": "ACTIVE"
}
```

管理员响应包含：

- 基础字段；
- 按 `displayOrder` 排序的成员图书；
- 当前成员售价合计；
- 当前节省金额；
- `priceValid`；
- `customerAvailable`；
- 不可用原因。

### 6.2 普通用户组合包接口

```http
GET /api/books/{bookId}/bundles
```

仅返回普通用户当前可购买的组合包。响应包含：

```text
id
name
description
bundlePrice
regularAmount
discountAmount
members
```

成员包含：

```text
bookId
title
coverUrl
salePrice
```

### 6.3 整套加入购物车

```http
POST /api/cart/bundles/{bundleId}
```

行为：

- 验证组合包当前可用；
- 固定按每个成员 1 本加入；
- 已有购物车项时数量加 1，并设为选中；
- 统一校验图书状态、库存和单品 999 上限；
- 整个操作在一个事务内完成；
- 任一成员失败则全部回滚；
- 返回更新后的完整 `CartVo`。

### 6.4 扩展购物车响应

`CartVo` 增加：

```text
regularAmount
bundleDiscountAmount
payableAmount
eligibleBundles
appliedBundles
```

兼容策略：保留现有 `selectedAmount`，其语义继续为“选中商品未应用订单级优惠前的普通合计”，并令：

```text
regularAmount == selectedAmount
payableAmount = regularAmount - bundleDiscountAmount
```

组合包摘要增加：

```text
id
name
regularAmount
bundlePrice
discountAmount
memberBookIds
applied
conflictReason?
```

`eligibleBundles` 包含全部完整匹配项；`appliedBundles` 只包含最优方案。未应用但完整匹配的组合包可通过比较 ID 判断是发生冲突，而不是不可用。

### 6.5 创建订单

现有创建请求保持不变：

```json
{
  "addressId": 1,
  "remark": "请尽快发货"
}
```

订单创建事务顺序：

1. 查询并锁定用户已选购物车项。
2. 按固定书籍 ID 顺序锁定图书库存快照。
3. 校验状态、库存、预售规则和购买数量。
4. 查询当前候选组合包。
5. 使用锁定后的当前 `salePrice` 运行 `BundlePricingService`。
6. 扣减库存。
7. 保存 `book_order`，写入普通合计、组合优惠和应付金额。
8. 保存 `order_item`，写入普通单价、小计、分摊优惠和实际支付小计。
9. 保存 `order_bundle_application` 及成员快照。
10. 保存库存流水。
11. 删除本次已选购物车项。

客户端不提交组合包 ID。即使购物车页面已显示优惠，创建订单仍完全重新计算，防止价格过期和请求篡改。

## 7. 订单与退款

### 7.1 订单响应

`OrderVo` 增加：

```text
appliedBundles
```

`OrderItemVo` 增加：

```text
discountAmount
paidSubtotal
```

订单组合包快照包含：

```text
name
regularAmount
bundlePrice
discountAmount
members
```

普通用户订单详情和管理员订单详情读取快照，不读取当前组合包定义。

### 7.2 部分退款算法

退款不能继续简单使用 `unitPrice * quantity`。对于订单项总购买数量 `Q`、实际支付小计 `P`，设已经被 PENDING 或 APPROVED 退款申请占用的累计数量为 `A`，本次申请数量为 `q`：

```text
before = roundToCent(P * A / Q)
after  = roundToCent(P * (A + q) / Q)
refund = after - before
```

结果：

- 同一订单项所有分批退款金额之和精确等于 `paidSubtotal`；
- PENDING 申请也占用数量和金额，防止重复申请；
- 最后一批退款自动吸收分币尾差；
- 退款金额不依赖当前图书或组合包价格。

退款审核仍使用现有悲观锁和状态校验，并继续保证订单累计退款金额不超过 `payableAmount`。

## 8. Flutter 架构

### 8.1 数据层

新增组合包模型：

- `BookBundleSummary`
- `BookBundleMember`
- `CartBundleMatch`
- `OrderBundleSnapshot`

Repository：

- 普通图书 Repository 查询某本书的组合包。
- Cart Repository 增加整套加入组合包方法。
- Admin Repository 增加组合包 CRUD 和状态方法。
- 现有 Cart、Order 模型解析新增金额和快照字段。

所有新增响应字段在模型中提供安全默认值，以兼容后端分阶段启动和旧测试数据。

### 8.2 管理端

在 `AdminSection` 增加：

```text
bundles / 组合包管理
```

建立独立 `AdminBundlesPage`，不扩大现有图书编辑对话框职责。

列表展示：

- 名称；
- 成员；
- 当前普通合计；
- 组合价；
- 当前优惠；
- 状态；
- 价格有效性和不可用原因；
- 编辑、启用、停用操作。

编辑对话框：

- 名称、说明、组合价；
- 可搜索图书选择器；
- 已选成员支持移除和排序；
- 实时展示当前售价合计、组合价和节省金额；
- 前端先做友好校验，后端仍是最终校验者。

### 8.3 图书详情页

图书详情加载后查询相关组合包。非空时展示“搭配购买更优惠”区域，卡片包含：

- 组合包名称和说明；
- 成员封面与书名；
- 普通合计、组合价、节省金额；
- “整套加入购物车”按钮。

加入成功后刷新购物车状态并提示成功。接口失败时显示可重试错误，但不阻断图书详情主体。

返回空数组时不渲染标题、占位容器或“暂无组合包”。

### 8.4 购物车与结算页

购物车使用后端返回的 `eligibleBundles` 和 `appliedBundles`：

- 最优方案显示“已自动使用”；
- 完整匹配但未应用的重叠组合显示“存在更优组合”；
- 未完整匹配的组合不显示；
- 无组合优惠时隐藏优惠行。

金额区域：

```text
商品合计
组合优惠
应付金额
```

结算页重新请求 `/api/cart/selected`，显示最新计算结果。创建订单成功后使用订单响应更新最终金额，不复用客户端本地计算。

### 8.5 订单详情

普通用户和管理员订单详情增加“已使用组合包”区域，展示历史快照。没有组合包时隐藏整个区域。

订单项可展示：

```text
普通小计
组合优惠分摊
实际支付小计
```

退款入口使用后端返回的可退款结果，不在 Flutter 本地重新推导金额。

## 9. 错误处理和一致性

- 管理操作返回明确的 400/404/409 业务错误。
- 组合包在浏览后到加入购物车前失效时，加入接口返回当前不可用原因。
- 组合包在购物车预览后到下单前失效时，下单按最新有效方案重算，不因原组合不存在而失败；金额可能恢复为普通价。
- 下单仍以图书库存锁和事务为边界，组合计算不改变现有库存并发策略。
- 组合包定义变更不影响历史订单、退款和统计。
- 管理端更新成员时整体替换关联，必须在同一事务内完成。`BookBundle` 使用乐观版本字段防止管理端覆盖更新；订单计算按组合包 ID 顺序对候选组合包主记录加悲观读锁，管理端修改时加悲观写锁，保证组合价和成员列表作为一致快照参与结算。
- 推荐和搜索仍按图书自身 `salePrice` 工作，不将组合价作为单书搜索价格。

## 10. 测试策略

### 10.1 后端单元测试

`BundlePricingService` 使用纯对象测试：

- 单个完整组合正确应用。
- 缺少任一成员不匹配。
- 数量大于 1 时组合仍只应用一次。
- 两个不重叠组合同时应用。
- 重叠组合选择全局总优惠最大方案。
- 构造贪心算法会失败的案例，证明实现是全局最优。
- 总优惠相同时稳定选择较小 ID 序列。
- 无效价格和停用组合被过滤。
- 分摊和尾差精确到分。

### 10.2 后端服务与接口测试

- 管理员创建、编辑、启停及所有输入校验。
- 按图书查询只返回当前可购买组合。
- 整套加入购物车成功和事务回滚。
- 购物车金额、候选组合和最优方案响应。
- 订单创建时忽略客户端可伪造信息并重新计算。
- 订单金额、订单项分摊、组合应用快照一致。
- 图书价格、状态、库存变化后的重新计算。
- 并发创建订单时库存和金额一致。
- 部分退款、分批退款、尾差和退款上限。

### 10.3 Flutter 测试

- 新模型解析和旧响应兼容。
- 无组合包时详情区域不出现。
- 有组合包时展示成员、价格和优惠。
- 整套加入购物车交互。
- 购物车区分已应用和冲突组合。
- 无优惠时隐藏优惠行。
- 管理员表单成员数量、重复图书和价格校验。
- 结算和订单详情显示后端快照。

## 11. 实施边界与提交策略

- 使用 TDD：每个后端领域行为和 Flutter 模型/组件行为先写失败测试，再写生产代码。
- 后端和 Flutter 分别提交，避免跨仓库混合提交。
- 两个仓库当前都有用户未提交修改，所有暂存操作必须精确指定本功能文件，禁止使用 `git add .`。
- 不修改或覆盖与组合包无关的现有用户改动。
- 数据库迁移只新增 V7，不修改已经应用的 V1～V6。

