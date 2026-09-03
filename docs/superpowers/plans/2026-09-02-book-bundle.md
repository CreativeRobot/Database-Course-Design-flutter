# Book Bundle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Each task follows TDD: write a failing test, verify the expected failure, implement the minimum behavior, verify the test passes, then run the relevant regression suite.

**Goal:** Add administrator-managed fixed-price book bundles, expose eligible bundles on book details and carts, and make the backend authoritative for optimal bundle pricing, order snapshots, and refund-safe payment allocation.

**Architecture:** Keep single-book sale pricing unchanged and introduce a backend bundle domain with `BookBundle`/`BookBundleItem` persistence, a pure `BundlePricingService`, and transactional management/cart/order integrations. The frontend consumes backend-calculated candidates and applications, adds a dedicated admin bundle page, and renders bundle information in book detail, cart/checkout, and order detail without submitting client prices or bundle IDs to order creation.

**Tech Stack:** Spring Boot 4.1, Java 21, Spring Data JPA, Flyway/MySQL, JUnit/Mockito; Flutter/Dart 3.12, Riverpod, Dio, Flutter widget tests.

**Spec:** `D:\no game\Code\DatabaseHomework\BookStore_Flutter\flutter_application_bookstore\docs\superpowers\specs\2026-09-02-book-bundle-design.md`

## Global Constraints

- Bundle contains 2–10 distinct books, one copy of each.
- Bundle price is a fixed amount strictly below the current sum of member `salePrice` values when created, edited, or enabled.
- Only ACTIVE, on-sale, in-stock, currently cheaper bundles are visible and matchable to customers.
- A bundle applies at most once per order; extra quantities remain at normal sale price.
- Bundles conflict by book ID, even when cart quantity is greater than one.
- Candidate selection maximizes total savings globally; ties use ascending bundle-ID sequence lexicographic order.
- Backend recomputes price inside the order transaction; clients never submit trusted bundle IDs/prices/discounts.
- Historical order bundle and payment snapshots are immutable; refund totals use actual paid subtotals and cent-safe proportional allocation.
- Only add Flyway `V7__add_book_bundles.sql`; never edit V1–V6.
- Existing unrelated user modifications must remain untouched. Stage feature files explicitly; never use `git add .`.

---

### Task 1: Establish backend schema and persistence model

**Files:**
- Create: `D:\no game\Code\DatabaseHomework\demo\src\main\resources\db\migration\V7__add_book_bundles.sql`
- Create: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\entity\BookBundle.java`
- Create: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\entity\BookBundleItem.java`
- Create: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\entity\OrderBundleApplication.java`
- Create: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\entity\OrderBundleApplicationItem.java`
- Modify: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\entity\OrderItem.java`
- Modify: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\entity\BookOrder.java` only if needed for explicit bundle relationships
- Create: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\repository\BookBundleRepository.java`
- Create: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\repository\BookBundleItemRepository.java`
- Create: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\repository\OrderBundleApplicationRepository.java`
- Create: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\repository\OrderBundleApplicationItemRepository.java`
- Test: `D:\no game\Code\DatabaseHomework\demo\src\test\java\com\example\demo\FlywayMigrationResourceTests.java` or a new bundle migration validation test

**Interfaces:**
- Persist `BookBundle.status` as `ACTIVE`/`INACTIVE` and include an optimistic `version` field for admin edits.
- `BookBundleItem` points to one `Book`; enforce uniqueness per bundle/book.
- Order application/item rows contain immutable bundle/member snapshots, applied discount, and the relation to `BookOrder`/`OrderItem`.
- `OrderItem` gains `discountAmount` and `paidSubtotal` with safe zero defaults for old rows.

- [ ] **Step 1: Write failing migration/entity mapping tests** for the V7 file, required columns/checks/indexes, bundle status/version, and order-item payment columns.
- [ ] **Step 2: Run the focused tests** with `mvnw.cmd -Dtest=... test`; verify failure because V7/entities are absent.
- [ ] **Step 3: Add V7 schema** with four new tables, foreign keys, uniqueness/indexes, `order_item.discount_amount`, and `order_item.paid_subtotal`.
- [ ] **Step 4: Add JPA entities/repositories** with lazy relations and explicit table/column mappings.
- [ ] **Step 5: Run migration/resource and compile tests**; fix only mapping/schema issues exposed by the tests.
- [ ] **Step 6: Commit only backend schema/model files** after the focused suite passes.

---

### Task 2: Implement and test pure bundle pricing

**Files:**
- Create: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\service\BundlePricingService.java`
- Create: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\service\BundlePricingResult.java`
- Create: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\service\BundleCandidate.java`
- Create: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\service\BundleAllocation.java` or equivalent immutable result records
- Test: `D:\no game\Code\DatabaseHomework\demo\src\test\java\com\example\demo\service\BundlePricingServiceTests.java`

**Interfaces:**
- Expose a pure method accepting cart book quantities and validated bundle snapshots, returning regular subtotal, selected bundle IDs, candidate bundle details, total discount, payable total, and per-book discount allocations.
- Filter inactive, incomplete, non-cheaper, unavailable, and non-positive-savings bundles before matching.
- Use exact DFS/backtracking with branch-and-bound, not greedy selection.
- Use `BigDecimal` scale 2 and deterministic cent rounding; distribute each bundle's discount proportionally to member sale prices and put any remainder on a deterministic final member.

- [ ] **Step 1: Write failing unit tests** for one match, incomplete match, quantity > 1 only once, disjoint bundles, greedy-counterexample global optimum, tie-break, invalid bundle filtering, and cent-exact allocation/refund inputs.
- [ ] **Step 2: Run `mvnw.cmd -Dtest=BundlePricingServiceTests test`** and confirm the expected missing-class/API failures.
- [ ] **Step 3: Define immutable pricing input/output records** with no Spring or database dependencies.
- [ ] **Step 4: Implement candidate filtering and savings calculation.**
- [ ] **Step 5: Implement deterministic DFS/backtracking and branch-and-bound.**
- [ ] **Step 6: Implement proportional allocation and regular/discount/payable totals.**
- [ ] **Step 7: Run the focused unit suite and then all backend unit tests.**
- [ ] **Step 8: Commit the pricing domain implementation and tests.**

---

### Task 3: Build backend bundle management APIs

**Files:**
- Create: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\dto\CreateBookBundleDTO.java`
- Create: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\dto\UpdateBookBundleDTO.java`
- Create: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\dto\BookBundleStatusDTO.java`
- Create: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\vo\BookBundleVo.java`
- Create: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\vo\BookBundleItemVo.java`
- Create: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\service\BookBundleService.java`
- Create: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\controller\AdminBookBundleController.java`
- Test: `D:\no game\Code\DatabaseHomework\demo\src\test\java\com\example\demo\service\BookBundleServiceTests.java`
- Test: `D:\no game\Code\DatabaseHomework\demo\src\test\java\com\example\demo\controller\AdminBookBundleControllerTests.java`

**Interfaces:**
- `GET /api/admin/bundles`, `GET /api/admin/bundles/{id}`, `POST /api/admin/bundles`, `PUT /api/admin/bundles/{id}`, `PUT /api/admin/bundles/{id}/status`.
- DTOs carry name, description, bundle price, distinct `bookIds`, and version on update.
- Service validates name/description lengths, 2–10 members, existing books, money scale/range, current sale-price strict discount, and optimistic version.
- Create/update replace member rows atomically. Status changes use a write lock and revalidate the strict discount rule before enabling.
- Admin list includes current regular sum, savings, validity, and reason for invalid/temporarily unusable price or book state.

- [ ] **Step 1: Write failing service/controller validation tests** for all input rules, 404, 409 optimistic conflicts, create/update/status/list behavior.
- [ ] **Step 2: Run focused tests** and verify failure due to missing service/controller.
- [ ] **Step 3: Implement DTO validation and service-level validation**; avoid trusting only bean validation because book IDs and price comparisons are domain rules.
- [ ] **Step 4: Implement locked create/update/status operations** and member replacement.
- [ ] **Step 5: Implement admin response mapping with current price validity metadata.**
- [ ] **Step 6: Implement controller routes and follow existing `AdminInterceptor`/`Result` conventions.**
- [ ] **Step 7: Run focused web/service tests and backend regression tests.**
- [ ] **Step 8: Commit management API files and tests.**

---

### Task 4: Expose customer bundle detail and cart matching APIs

**Files:**
- Create: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\vo\CustomerBookBundleVo.java`
- Create: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\vo\CartBundleVo.java`
- Modify: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\repository\BookBundleRepository.java`
- Modify: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\service\BookBundleService.java`
- Modify: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\service\CartService.java`
- Modify: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\controller\BookController.java`
- Modify: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\controller\CartController.java`
- Modify: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\vo\CartVo.java`
- Modify: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\vo\CartItemVo.java`
- Test: `D:\no game\Code\DatabaseHomework\demo\src\test\java\com\example\demo\service\CartBundleMatchingTests.java`
- Test: `D:\no game\Code\DatabaseHomework\demo\src\test\java\com\example\demo\controller\CartBundleControllerTests.java`

**Interfaces:**
- `GET /api/books/{bookId}/bundles` returns empty list when no valid customer-visible bundle exists.
- `POST /api/cart/bundles/{bundleId}` atomically adds one copy of every member, validates current availability, and rolls back on failure.
- Extend cart responses with `regularAmount`, `bundleDiscountAmount`, `payableAmount`, `eligibleBundles`, and `appliedBundles`; selected cart only considers selected items.
- Mark each candidate as applied or conflicting according to the pricing result; no incomplete bundle is returned.

- [ ] **Step 1: Write failing service/controller tests** for visibility filters, atomic bundle add, rollback, selected cart quantities, candidate/applied response, and price/stock changes.
- [ ] **Step 2: Run focused tests and verify expected failures.**
- [ ] **Step 3: Add repository queries/snapshot conversion** that load member books and lock candidate bundle records in ascending ID order when required.
- [ ] **Step 4: Integrate `BundlePricingService` into cart reads and selected-cart calculations.**
- [ ] **Step 5: Implement transactional bundle add with existing cart quantity/update semantics.**
- [ ] **Step 6: Add book detail and cart controller endpoints.**
- [ ] **Step 7: Run service/controller and existing cart tests; fix serialization/default behavior.**
- [ ] **Step 8: Commit customer/cart backend files and tests.**

---

### Task 5: Make order creation authoritative and persist immutable bundle snapshots

**Files:**
- Modify: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\service\OrderService.java`
- Modify: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\service\OrderQueryService.java`
- Modify: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\vo\OrderVo.java`
- Modify: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\vo\OrderItemVo.java`
- Modify: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\repository\OrderItemRepository.java` if needed for fetch/mapping
- Test: `D:\no game\Code\DatabaseHomework\demo\src\test\java\com\example\demo\service\OrderServiceBundleTests.java`
- Test: `D:\no game\Code\DatabaseHomework\demo\src\test\java\com\example\demo\service\OrderQueryBundleTests.java`

**Interfaces:**
- Keep `CreateOrderDTO` unchanged. At transaction start, load selected cart rows and current books, lock books using the existing stock strategy, then load/lock candidate bundle main records in ascending ID order.
- Recompute valid candidates and the optimal non-overlapping application; ignore any client-supplied bundle data.
- Persist order-level total `discountAmount`, order-item `discountAmount`, and `paidSubtotal`; persist bundle/member snapshots in application tables.
- Order list/detail responses include bundle application snapshots and item regular/discount/paid subtotals.
- Existing no-bundle orders remain semantically unchanged with zero discount and paid subtotal equal to normal subtotal.

- [ ] **Step 1: Write failing order tests** for tampered client data, backend recomputation, stock/price changes, bundle snapshot immutability, item allocation, and no-bundle compatibility.
- [ ] **Step 2: Run focused order tests and verify failure.**
- [ ] **Step 3: Extract/prepare selected-cart pricing inputs** without changing the public create-order request.
- [ ] **Step 4: Integrate locked bundle snapshot loading and pricing into the existing transaction.**
- [ ] **Step 5: Persist order-level/item-level discount and paid subtotal.**
- [ ] **Step 6: Persist and map immutable bundle application/item snapshots.**
- [ ] **Step 7: Run all order and query tests, including existing pre-sale behavior.**
- [ ] **Step 8: Commit order integration files and tests.**

---

### Task 6: Make refunds use actual paid subtotals

**Files:**
- Modify: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\service\RefundService.java`
- Modify: `D:\no game\Code\DatabaseHomework\demo\src\main\java\com\example\demo\vo\RefundRequestVo.java` only if response fields are needed
- Test: `D:\no game\Code\DatabaseHomework\demo\src\test\java\com\example\demo\service\RefundServiceBundleTests.java`
- Modify existing: `D:\no game\Code\DatabaseHomework\demo\src\test\java\com\example\demo\service\RefundServiceTests.java` only to preserve/extend existing expectations

**Interfaces:**
- For each order item, compute refund by cumulative proportional rounding:
  `before = roundCent(P * A / Q)`, `after = roundCent(P * (A + q) / Q)`, `refund = after - before`; `P` is paid subtotal, `Q` ordered quantity, `A` pending/approved refunded quantity.
- Reject quantities beyond refundable quantity and never refund more than actual item payment.
- Preserve current refund status, inventory-return, and payment-total behavior.

- [ ] **Step 1: Write failing tests** for bundle-discounted item, one-shot refund, split refunds with cent remainder, and non-bundle regression.
- [ ] **Step 2: Run focused refund tests and confirm current unit-price calculation fails the bundle cases.**
- [ ] **Step 3: Implement cumulative paid-subtotal allocation.**
- [ ] **Step 4: Run all refund tests and backend regression tests.**
- [ ] **Step 5: Commit refund changes and tests.**

---

### Task 7: Add Flutter data models and repository/API contracts

**Files:**
- Modify: `D:\no game\Code\DatabaseHomework\BookStore_Flutter\flutter_application_bookstore\lib\core\constants\api_paths.dart`
- Modify: `D:\no game\Code\DatabaseHomework\BookStore_Flutter\flutter_application_bookstore\lib\features\cart\data\cart_models.dart`
- Modify: `D:\no game\Code\DatabaseHomework\BookStore_Flutter\flutter_application_bookstore\lib\features\cart\data\cart_repository.dart`
- Modify: `D:\no game\Code\DatabaseHomework\BookStore_Flutter\flutter_application_bookstore\lib\data\models\book\book_detail.dart`
- Modify: `D:\no game\Code\DatabaseHomework\BookStore_Flutter\flutter_application_bookstore\lib\features\books\data\book_repository.dart`
- Modify: `D:\no game\Code\DatabaseHomework\BookStore_Flutter\flutter_application_bookstore\lib\features\orders\data\order_models.dart`
- Modify: `D:\no game\Code\DatabaseHomework\BookStore_Flutter\flutter_application_bookstore\lib\features\orders\data\order_repository.dart`
- Modify: `D:\no game\Code\DatabaseHomework\BookStore_Flutter\flutter_application_bookstore\lib\features\admin\data\admin_models.dart`
- Modify: `D:\no game\Code\DatabaseHomework\BookStore_Flutter\flutter_application_bookstore\lib\features\admin\data\admin_repository.dart`
- Test: `D:\no game\Code\DatabaseHomework\BookStore_Flutter\flutter_application_bookstore\test\book_bundle_models_test.dart`
- Test: `D:\no game\Code\DatabaseHomework\BookStore_Flutter\flutter_application_bookstore\test\book_bundle_api_paths_test.dart`

**Interfaces:**
- Add safe-default model parsers for `CustomerBookBundle`, `CartBundle`, `AdminBookBundle`, `CartPricing`, `OrderBundleApplication`, and item-level discount/paid fields.
- Add API path helpers for admin bundle CRUD/status, book bundles, and cart bundle add.
- Add repository methods returning typed models and preserve the existing `ApiClient`/`ApiResponse` conventions.

- [ ] **Step 1: Write failing Dart model/path/repository contract tests.**
- [ ] **Step 2: Run `flutter test test/book_bundle_models_test.dart test/book_bundle_api_paths_test.dart`** and verify missing symbols/failures.
- [ ] **Step 3: Implement model parsing with defaults for absent fields.**
- [ ] **Step 4: Implement API paths and repository calls.**
- [ ] **Step 5: Run focused Dart tests and existing data tests.**
- [ ] **Step 6: Commit frontend model/repository changes and tests.**

---

### Task 8: Add Flutter customer bundle UI and cart/checkout rendering

**Files:**
- Modify: `D:\no game\Code\DatabaseHomework\BookStore_Flutter\flutter_application_bookstore\lib\features\books\presentation\book_detail_page.dart`
- Modify/create controller/provider adjacent to the existing book detail architecture
- Modify: `D:\no game\Code\DatabaseHomework\BookStore_Flutter\flutter_application_bookstore\lib\features\cart\presentation\cart_controller.dart`
- Modify: `D:\no game\Code\DatabaseHomework\BookStore_Flutter\flutter_application_bookstore\lib\features\cart\presentation\cart_page.dart`
- Modify: `D:\no game\Code\DatabaseHomework\BookStore_Flutter\flutter_application_bookstore\lib\features\orders\presentation\checkout_page.dart`
- Test: `D:\no game\Code\DatabaseHomework\BookStore_Flutter\flutter_application_bookstore\test\book_bundle_detail_widget_test.dart`
- Test: `D:\no game\Code\DatabaseHomework\BookStore_Flutter\flutter_application_bookstore\test\book_bundle_cart_widget_test.dart`

**Interfaces:**
- Detail page renders no bundle title/container when API returns an empty list.
- When bundles exist, render member covers/titles, regular sum, bundle price, savings, and an atomic “整套加入购物车” action.
- Cart displays eligible candidates; applied bundle IDs show `已自动使用`, non-applied fully matched candidates show `存在更优组合`.
- Cart/checkout amounts show 商品合计, 组合优惠, 应付金额; hide the discount line when zero.
- Joining or API refresh updates cart state and shows existing app feedback/error patterns; bundle failure must not block core book detail rendering.

- [ ] **Step 1: Write failing widget/controller tests** for empty/non-empty detail state, bundle add, candidate labels, discount row visibility, and checkout refresh.
- [ ] **Step 2: Run focused Flutter tests and verify failures.**
- [ ] **Step 3: Implement detail bundle section and atomic add action.**
- [ ] **Step 4: Integrate cart state refresh and bundle labels/amounts.**
- [ ] **Step 5: Integrate checkout selected-cart response and order-result refresh.**
- [ ] **Step 6: Run focused widgets and existing cart/order tests.**
- [ ] **Step 7: Commit customer UI changes and tests.**

---

### Task 9: Add Flutter admin bundle management

**Files:**
- Modify: `D:\no game\Code\DatabaseHomework\BookStore_Flutter\flutter_application_bookstore\lib\features\admin\presentation\admin_page.dart`
- Create: `D:\no game\Code\DatabaseHomework\BookStore_Flutter\flutter_application_bookstore\lib\features\admin\presentation\admin_bundles_page.dart`
- Create/modify controller/provider as needed in `lib/features/admin/presentation/`
- Modify: `D:\no game\Code\DatabaseHomework\BookStore_Flutter\flutter_application_bookstore\lib\features\admin\data\admin_repository.dart`
- Test: `D:\no game\Code\DatabaseHomework\BookStore_Flutter\flutter_application_bookstore\test\admin_bundles_test.dart`

**Interfaces:**
- Add independent `AdminSection.bundles` navigation entry.
- List shows name, selected members, current regular sum, bundle price, savings, status, and invalidity/unavailability reason.
- Dialog/editor provides name, description, price, searchable book selector, member removal/reordering, client-side 2–10/distinct/price validation, and server-error display.
- Enable/disable calls status endpoint and respects optimistic version conflicts.

- [ ] **Step 1: Write failing model/form/navigation/widget tests.**
- [ ] **Step 2: Run focused Flutter tests and verify failures.**
- [ ] **Step 3: Implement admin navigation and page shell.**
- [ ] **Step 4: Implement list loading/error/status actions.**
- [ ] **Step 5: Implement editor validation and save/update flow.**
- [ ] **Step 6: Run focused admin tests plus existing admin navigation/model tests.**
- [ ] **Step 7: Commit admin UI changes and tests.**

---

### Task 10: Add Flutter order snapshot rendering and end-to-end verification

**Files:**
- Modify: `D:\no game\Code\DatabaseHomework\BookStore_Flutter\flutter_application_bookstore\lib\features\orders\presentation\order_detail_page.dart`
- Modify: `D:\no game\Code\DatabaseHomework\BookStore_Flutter\flutter_application_bookstore\lib\features\admin\presentation\admin_order_detail_page.dart` if present/needed
- Test: `D:\no game\Code\DatabaseHomework\BookStore_Flutter\flutter_application_bookstore\test\order_bundle_snapshot_widget_test.dart`
- Modify: `D:\no game\Code\DatabaseHomework\BookStore_Flutter\.planning\book-bundles\task_plan.md`
- Modify: `D:\no game\Code\DatabaseHomework\BookStore_Flutter\.planning\book-bundles\findings.md`
- Modify: `D:\no game\Code\DatabaseHomework\BookStore_Flutter\.planning\book-bundles\progress.md`

**Interfaces:**
- Order detail hides the bundle section when there is no historical application.
- When present, render immutable bundle name/price/member snapshot and each order item’s regular subtotal, allocated discount, and paid subtotal.
- Validate both repositories without staging unrelated existing work.

- [ ] **Step 1: Write failing order-detail widget tests.**
- [ ] **Step 2: Run focused test and verify failure.**
- [ ] **Step 3: Implement snapshot section and item amount labels.**
- [ ] **Step 4: Run full backend verification: `mvnw.cmd test`.**
- [ ] **Step 5: Run full Flutter verification: `flutter test`.**
- [ ] **Step 6: Run static analysis: `flutter analyze` and backend compile/package checks.**
- [ ] **Step 7: Update planning progress with exact test output and remaining caveats.**
- [ ] **Step 8: Review `git diff`/`git status` in both repos; stage only feature files.**
- [ ] **Step 9: Commit backend and frontend separately with focused messages.**

---

## Verification Matrix

- Backend unit: `mvnw.cmd -Dtest=BundlePricingServiceTests,BookBundleServiceTests,CartBundleMatchingTests,OrderServiceBundleTests,RefundServiceBundleTests test`
- Backend regression: `mvnw.cmd test`
- Flutter focused: `flutter test test/book_bundle_models_test.dart test/book_bundle_api_paths_test.dart test/book_bundle_detail_widget_test.dart test/book_bundle_cart_widget_test.dart test/admin_bundles_test.dart test/order_bundle_snapshot_widget_test.dart`
- Flutter regression: `flutter test`
- Flutter static: `flutter analyze`
- Backend package/compile: `mvnw.cmd -DskipTests compile`

## Commit Boundaries

- Backend commits contain only backend bundle schema/entities/services/controllers/tests.
- Frontend commits contain only Flutter bundle models/repositories/controllers/pages/tests.
- Existing unrelated changes listed by `git status` are never staged or reverted.
- Before claiming completion, use `superpowers:verification-before-completion` and report actual command results, not assumptions.
