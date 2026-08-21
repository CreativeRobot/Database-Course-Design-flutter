# Homepage Recommendations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build explainable, cached home recommendations from completed purchases, reviews, catalog categories, and co-purchase signals.

**Architecture:** The Spring application owns all scoring and exclusion rules behind one authenticated endpoint. Flutter keeps the recommendation request in a focused Riverpod repository/controller and renders it above the existing browse catalogue without replacing search or filtering.

**Tech Stack:** Spring Boot, Spring Data JPA, JUnit 5, Flutter, Riverpod, Dio, flutter_test.

**Spec:** `docs/superpowers/specs/2026-08-19-home-recommendations-design.md`

## Global Constraints

- Return only `ON_SALE`, in-stock, not-completed-purchased books.
- Bound `limit` to 1-20 and cache a user's response for 15 minutes.
- Invalidate on completed order, review creation, and review update.
- Keep all ranking deterministic and explainable.
- Preserve the existing books catalog and untracked frontend `.tmp_tool/` directory.

---

### Task 1: Backend Recommendation Contract And Queries

**Files:**
- Create: `demo/src/main/java/com/example/demo/vo/RecommendationBookVo.java`
- Create: `demo/src/main/java/com/example/demo/vo/RecommendationHomeVo.java`
- Modify: `demo/src/main/java/com/example/demo/repository/BookRepository.java`
- Modify: `demo/src/main/java/com/example/demo/repository/OrderItemRepository.java`
- Modify: `demo/src/main/java/com/example/demo/repository/BookReviewRepository.java`
- Test: `demo/src/test/java/com/example/demo/service/RecommendationServiceTests.java`

**Interfaces:**
- Produces `RecommendationHomeVo(String source, List<RecommendationBookVo> books)`.
- Produces repository methods that return completed purchases, category preferences, co-purchase candidates, and eligible books.

- [ ] Write repository/service tests that require completed-order-only data, purchased-book exclusion, and eligible catalog filtering.
- [ ] Run the new tests and confirm they fail because recommendation contracts and queries do not exist.
- [ ] Add projection records, DTOs, and minimal repository queries that supply those test fixtures.
- [ ] Run the focused tests until they pass.

### Task 2: Backend Ranking, Cache, And API

**Files:**
- Create: `demo/src/main/java/com/example/demo/service/RecommendationService.java`
- Create: `demo/src/main/java/com/example/demo/controller/RecommendationController.java`
- Modify: `demo/src/main/java/com/example/demo/service/OrderService.java`
- Modify: `demo/src/main/java/com/example/demo/service/ReviewService.java`
- Test: `demo/src/test/java/com/example/demo/service/RecommendationServiceTests.java`

**Interfaces:**
- Consumes the Task 1 repository projections.
- Produces `RecommendationHomeVo getHomeRecommendations(Long userId, int limit)` and `void invalidate(Long userId)`.

- [ ] Write failing tests for category/co-purchase ranking, popular fallback, score reasons, 15-minute cache reuse, and invalidation.
- [ ] Run the tests and confirm each failure is caused by missing ranking/cache behavior.
- [ ] Implement the smallest deterministic ranking and bounded per-user cache to satisfy the tests.
- [ ] Add the authenticated `GET /api/recommendations/home` controller, validate `limit`, and invoke invalidation from completion/review write flows.
- [ ] Run the focused backend test class and existing affected service tests.

### Task 3: Flutter Data And State Layer

**Files:**
- Create: `BookStore_Flutter/flutter_application_bookstore/lib/features/recommendations/data/recommendation_models.dart`
- Create: `BookStore_Flutter/flutter_application_bookstore/lib/features/recommendations/data/recommendation_repository.dart`
- Create: `BookStore_Flutter/flutter_application_bookstore/lib/features/recommendations/presentation/recommendation_controller.dart`
- Modify: `BookStore_Flutter/flutter_application_bookstore/lib/core/constants/api_paths.dart`
- Test: `BookStore_Flutter/flutter_application_bookstore/test/recommendation_models_test.dart`

**Interfaces:**
- Produces `RecommendationHome`, `RecommendationBook`, `RecommendationRepository.fetchHome({int limit = 12})`, and a controller with `load()` and `refresh()`.

- [ ] Write failing Flutter tests for parsing source, item reason, and numeric fields from the API payload.
- [ ] Run the model test and confirm it fails because the recommendation types do not exist.
- [ ] Implement models, endpoint path, repository parsing, and controller state while retaining the latest data on refresh.
- [ ] Run the focused Flutter model/controller tests until they pass.

### Task 4: Flutter Homepage Presentation

**Files:**
- Create: `BookStore_Flutter/flutter_application_bookstore/lib/features/recommendations/presentation/recommendation_section.dart`
- Modify: `BookStore_Flutter/flutter_application_bookstore/lib/features/books/presentation/books_page.dart`
- Test: `BookStore_Flutter/flutter_application_bookstore/test/recommendation_section_test.dart`

**Interfaces:**
- Consumes the Task 3 controller and `RecommendationHome`.
- Produces a reusable `RecommendationSection` with loading, error/retry, empty, and populated states.

- [ ] Write a failing widget test that verifies a recommendation reason and retry action are visible.
- [ ] Run the widget test and confirm it fails because the section does not exist.
- [ ] Render the compact section above the existing catalog, keep book navigation/card interactions, and connect page refresh to recommendations.
- [ ] Run focused widget tests, then `dart format` on changed Dart files.

### Task 5: Verification

**Files:**
- Modify only files introduced or changed by Tasks 1-4.

- [ ] Run `git diff --check` in both repositories.
- [ ] Run Maven focused tests if the local wrapper starts; otherwise record the exact startup failure.
- [ ] Map a no-space drive if needed, run `flutter analyze`, and run all Flutter tests.
- [ ] Review every changed file and confirm the frontend and backend still point to their intended `recommend` branches.
