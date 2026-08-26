# Category Hierarchy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the bookstore category system visibly enforce and present a two-level parent-child hierarchy across the Spring backend and Flutter client.

**Architecture:** The existing `category.parent_id` schema stays unchanged. Backend services add two-level validation, a tree response, and parent-category search expansion; Flutter models preserve hierarchy data, the admin page renders a tree, and the customer search page derives cascading selectors from the flat category list.

**Tech Stack:** Spring Boot, Spring Data JPA, JUnit 5 + Mockito, Flutter, Riverpod, flutter_test.

**Spec:** `docs/superpowers/specs/2026-08-26-category-hierarchy-design.md`

## Global Constraints

- Keep the `category` and `book_category` database tables unchanged.
- Permit only level-1 and level-2 categories.
- Preserve existing flat category endpoints for compatibility.
- Do not include local `.m2/`, `.runtime-temp/`, `target/`, or Flutter build outputs in commits.
- Add a focused failing test before each production behavior change.

---

### Task 1: Backend category hierarchy contract and validation

**Files:**
- Modify: `src/main/java/com/example/demo/vo/CategoryVo.java`
- Modify: `src/main/java/com/example/demo/service/CategoryService.java`
- Modify: `src/main/java/com/example/demo/controller/CategoryController.java`
- Modify: `src/main/java/com/example/demo/controller/AdminCategoryController.java`
- Test: `src/test/java/com/example/demo/service/CategoryHierarchyServiceTests.java`

- [ ] Write tests for two-level validation and root/child tree construction.
- [ ] Run the focused test to observe RED compilation/behavior failures.
- [ ] Add recursive `children` to the category response and build sorted trees.
- [ ] Add public and admin tree endpoints.
- [ ] Reject third-level parent choices and moving a category that has children under another parent.
- [ ] Run focused backend tests.

### Task 2: Parent-category book filtering

**Files:**
- Modify: `src/main/java/com/example/demo/repository/CategoryRepository.java`
- Modify: `src/main/java/com/example/demo/service/BookService.java`
- Test: `src/test/java/com/example/demo/service/BookCategoryFilterTests.java`

- [ ] Write a failing test for resolving a selected parent category to itself plus direct children.
- [ ] Run the focused test to observe RED.
- [ ] Implement category-ID expansion and use it in the book search category predicate.
- [ ] Run focused backend tests.

### Task 3: Flutter category hierarchy models and parsing

**Files:**
- Modify: `lib/data/models/book/category.dart`
- Modify: `lib/features/admin/data/admin_models.dart`
- Create: `lib/data/models/book/category_hierarchy.dart`
- Test: `test/category_hierarchy_test.dart`
- Test: `test/admin_models_test.dart`

- [ ] Write failing tests for parent ID parsing, tree child parsing, roots, and child lookup.
- [ ] Run the focused Flutter test to observe RED.
- [ ] Implement model fields and pure hierarchy helper.
- [ ] Run focused Flutter tests.

### Task 4: Flutter management tree and customer cascading filters

**Files:**
- Modify: `lib/features/admin/data/admin_repository.dart`
- Modify: `lib/features/admin/presentation/admin_catalog_pages.dart`
- Modify: `lib/features/books/presentation/search_results_page.dart`
- Test: `test/category_hierarchy_test.dart`

- [ ] Write/extend unit tests for the selector helper behavior.
- [ ] Add the tree endpoint repository method and render expandable nested admin category items.
- [ ] Restrict parent choices in the management dialog to root categories.
- [ ] Render primary/secondary category dropdowns from `CategoryHierarchy`.
- [ ] Run formatter and focused tests.

### Task 5: Verification and documentation

**Files:**
- Modify: `README.md` if endpoint or usage documentation needs updating.

- [ ] Run backend focused tests and the applicable Maven suite command.
- [ ] Run Flutter focused tests, `flutter analyze`, and format checks.
- [ ] Record known environment limitations separately from code failures.
- [ ] Review the diff against the design and commit the feature.
