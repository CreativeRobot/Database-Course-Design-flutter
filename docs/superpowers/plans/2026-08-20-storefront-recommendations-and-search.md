# Storefront Recommendations And Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show authenticated customers explainable homepage recommendations and move storefront searching into a state-isolated, filterable results page.

**Architecture:** `RecommendationRepository` and `RecommendationController` own the authenticated recommendation request and its cached-on-screen state. `SearchResultsController` owns a separate paginated book-query state for `SearchResultsPage`; it reuses `BookRepository`, while a shared catalog grid lets the storefront and search page render the same book-card affordances without sharing controller state.

**Tech Stack:** Flutter 3.12, Dart, Riverpod `StateNotifier`, GoRouter, Dio, flutter_test, cached_network_image.

**Spec:** `docs/superpowers/specs/2026-08-20-storefront-recommendations-and-search-design.md`

## Global Constraints

- Reuse Riverpod, GoRouter, `BookRepository`, `ApiClient`, shared commerce states, and existing card visual conventions.
- Do not modify the existing backend recommendation implementation.
- Do not alter or revert the worktree's existing uncommitted recommendation tests, planning files, or `.tmp_tool/` content.
- Flutter analysis and tests must run from the known no-space mapped checkout when the original path blocks native-assets tooling.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/core/constants/api_paths.dart` | Defines the recommendation endpoint path. |
| `lib/features/recommendations/data/recommendation_repository.dart` | Fetches and parses the recommendation response through `ApiClient`. |
| `lib/features/recommendations/presentation/recommendation_controller.dart` | Represents recommendation async state, errors, refresh, and provider wiring. |
| `lib/features/recommendations/presentation/recommendation_section.dart` | Renders recommendation cards, explanation text, and callbacks. |
| `lib/features/books/presentation/book_catalog_grid.dart` | Reusable public book-card grid for storefront and search results. |
| `lib/features/books/presentation/search_results_controller.dart` | Owns search query, filters, pagination, options, and retry behavior. |
| `lib/features/books/presentation/search_results_page.dart` | Renders the independent search route and connects controls to its controller. |
| `lib/features/books/presentation/books_page.dart` | Redirects homepage search, hosts recommendations, and uses the shared grid. |
| `lib/app/router/app_router.dart` | Adds the `/search` route and query handoff. |

### Task 1: Recommendation Data And State

**Files:**
- Modify: `lib/core/constants/api_paths.dart`
- Create: `lib/features/recommendations/data/recommendation_repository.dart`
- Create: `lib/features/recommendations/presentation/recommendation_controller.dart`
- Modify: `test/recommendation_controller_test.dart`
- Create: `test/recommendation_repository_test.dart`

**Interfaces:**
- Consumes: `ApiClient.get<T>()`, `RecommendationHome.fromJson`, `ApiException`.
- Produces: `RecommendationDataSource.fetchHome({int limit = 12})`, `RecommendationRepository`, `RecommendationController`, `RecommendationState`, and `recommendationControllerProvider`.

- [ ] **Step 1: Write failing repository and controller tests**

```dart
test('requests the recommendation endpoint with its limit', () async {
  final result = await repository.fetchHome(limit: 12);
  expect(result.books, hasLength(1));
  expect(client.lastPath, '/api/recommendations/home');
  expect(client.lastQuery, {'limit': 12});
});

test('keeps recommendations when refresh fails', () async {
  await controller.load();
  await controller.refresh();
  expect(controller.state.home, isNotNull);
  expect(controller.state.status, RecommendationStatus.failure);
});
```

- [ ] **Step 2: Run the focused test to confirm it fails**

Run: `flutter test test/recommendation_controller_test.dart test/recommendation_repository_test.dart`

Expected: compilation failure because the repository and controller imports do not yet exist.

- [ ] **Step 3: Implement the endpoint, repository, and state notifier**

```dart
abstract interface class RecommendationDataSource {
  Future<RecommendationHome> fetchHome({int limit = 12});
}

Future<void> refresh() => load(force: true);
```

Add `ApiPaths.recommendationsHome`, parse only `response.data`, reject limits outside `1..20`, map `ApiException` to its message, and retain `state.home` when a refresh fails.

- [ ] **Step 4: Format and verify the data layer**

Run: `dart format lib/core/constants/api_paths.dart lib/features/recommendations test/recommendation_controller_test.dart test/recommendation_repository_test.dart`

Run: `flutter test test/recommendation_controller_test.dart test/recommendation_repository_test.dart test/recommendation_models_test.dart`

Expected: all recommendation data/controller tests pass.

- [ ] **Step 5: Commit the recommendation data layer**

```bash
git add lib/core/constants/api_paths.dart lib/features/recommendations/data/recommendation_repository.dart lib/features/recommendations/presentation/recommendation_controller.dart test/recommendation_controller_test.dart test/recommendation_repository_test.dart
git commit -m "feat: add homepage recommendation state"
```

### Task 2: Recommendation Section And Storefront Wiring

**Files:**
- Create: `lib/features/books/presentation/book_catalog_grid.dart`
- Create: `lib/features/recommendations/presentation/recommendation_section.dart`
- Modify: `lib/features/books/presentation/books_page.dart`
- Modify: `test/recommendation_section_test.dart`
- Create: `test/books_page_search_navigation_test.dart`

**Interfaces:**
- Consumes: `RecommendationState`, `RecommendationHome`, `Book`, image base URL, and detail-route callback.
- Produces: `BookCatalogGrid`, `RecommendationBooks`, and homepage `onSearch` navigation.

- [ ] **Step 1: Extend widget tests for empty data and click behavior**

```dart
testWidgets('omits recommendation cards when no eligible books exist', (tester) async {
  await tester.pumpWidget(MaterialApp(home: RecommendationBooks(
    home: const RecommendationHome(source: 'POPULAR', books: []),
    baseUrl: 'http://localhost:8080', onBookTap: (_) {},
  )));
  expect(find.text('为你推荐'), findsNothing);
});
```

Also assert tapping a card invokes `onBookTap` with its id, and add a homepage widget test that submits `数据库` and observes `/search?keyword=数据库`.

- [ ] **Step 2: Run widget tests and confirm they fail**

Run: `flutter test test/recommendation_section_test.dart test/books_page_search_navigation_test.dart`

Expected: failure because the section and search-route behavior are absent.

- [ ] **Step 3: Extract the grid and wire recommendations into `BooksPage`**

```dart
class BookCatalogGrid extends StatelessWidget {
  const BookCatalogGrid({required this.books, required this.baseUrl,
    required this.compact, required this.onBookTap, this.onLoadMore,
    this.loadingMore = false, super.key});
}
```

Move the existing private grid/card rendering to this public grid, retaining price, cover, stock, and pagination affordances. Add `RecommendationBooks`; observe its controller only for authenticated non-admin customers. Replace `_search()` with a trimmed-keyword `context.push('/search?keyword=${Uri.encodeQueryComponent(keyword)}')`; whitespace-only values do nothing.

- [ ] **Step 4: Format and verify presentation changes**

Run: `dart format lib/features/books/presentation lib/features/recommendations/presentation test/recommendation_section_test.dart test/books_page_search_navigation_test.dart`

Run: `flutter test test/recommendation_section_test.dart test/books_page_search_navigation_test.dart`

Expected: reason, empty omission, tap callback, and route submission tests pass.

- [ ] **Step 5: Commit homepage presentation changes**

```bash
git add lib/features/books/presentation/book_catalog_grid.dart lib/features/books/presentation/books_page.dart lib/features/recommendations/presentation/recommendation_section.dart test/recommendation_section_test.dart test/books_page_search_navigation_test.dart
git commit -m "feat: show homepage recommendations"
```

### Task 3: Independent Search Controller

**Files:**
- Create: `lib/features/books/presentation/search_results_controller.dart`
- Create: `test/search_results_controller_test.dart`

**Interfaces:**
- Consumes: `BookRepository.getBooks`, `getCategories`, `getAuthors`, `getPublishers`, `PageResponse<Book>`, and `ApiException`.
- Produces: `SearchResultsState`, `SearchResultsStatus`, and methods `loadInitial`, `submitKeyword`, `updateFilters`, `loadMore`, and `retry`.

- [ ] **Step 1: Write controller tests for filter reset, pagination, and errors**

```dart
await controller.loadInitial();
await controller.updateFilters(authorId: 4);
expect(repository.requests.last.page, 1);
expect(repository.requests.last.authorId, 4);

await controller.loadMore();
expect(controller.state.books, hasLength(2));
```

Add a test that `updateFilters(minPrice: 100, maxPrice: 10)` sets a local validation error with no repository request and a test that a load-more error retains current cards.

- [ ] **Step 2: Run the controller test to confirm it fails**

Run: `flutter test test/search_results_controller_test.dart`

Expected: compilation failure because the controller does not exist.

- [ ] **Step 3: Implement controller isolation from `BooksController`**

```dart
Future<void> updateFilters({int? categoryId, int? authorId,
  int? publisherId, double? minPrice, double? maxPrice,
  bool? inStock, String? sortBy});
```

Reuse only repository calls and friendly-message conventions from `BooksController`. Queries and valid filter changes replace records with page 1. `loadMore` appends only when not loading and `hasMore` is true. Fetch the three option lists on initialization, retaining results when an option request fails.

- [ ] **Step 4: Format and verify controller tests**

Run: `dart format lib/features/books/presentation/search_results_controller.dart test/search_results_controller_test.dart`

Run: `flutter test test/search_results_controller_test.dart`

Expected: all search state-transition tests pass.

- [ ] **Step 5: Commit independent search state**

```bash
git add lib/features/books/presentation/search_results_controller.dart test/search_results_controller_test.dart
git commit -m "feat: add isolated search results state"
```

### Task 4: Search Page And Routing

**Files:**
- Create: `lib/features/books/presentation/search_results_page.dart`
- Modify: `lib/app/router/app_router.dart`
- Create: `test/search_results_page_test.dart`

**Interfaces:**
- Consumes: `SearchResultsController`, `BookCatalogGrid`, GoRouter query parameters, and book-detail routes.
- Produces: `SearchResultsPage({required String initialKeyword})` and `/search` route.

- [ ] **Step 1: Write route and page widget tests**

```dart
testWidgets('uses the route keyword for the first search', (tester) async {
  await tester.pumpWidget(makeRouterApp('/search?keyword=算法'));
  expect(find.textContaining('算法'), findsWidgets);
});

testWidgets('shows filters and navigates to selected book details', (tester) async {
  await tester.tap(find.text('全部作者'));
  expect(find.text('只看有库存'), findsOneWidget);
});
```

Include empty first-page, retryable first-page failure, and direct-link back-to-storefront behavior.

- [ ] **Step 2: Run page tests to confirm the route/page are missing**

Run: `flutter test test/search_results_page_test.dart`

Expected: compilation failure because `SearchResultsPage` and `/search` are absent.

- [ ] **Step 3: Implement the route and independent results UI**

```dart
GoRoute(
  path: '/search',
  builder: (context, state) => SearchResultsPage(
    initialKeyword: state.uri.queryParameters['keyword'] ?? '',
  ),
),
```

Build the search field, count, dropdowns, price inputs, stock chip, sort control, shared grid, first-page loading/empty/error states, inline load-more retry, and detail navigation. Use `context.pop()` when possible and `context.go('/books')` for direct-link fallback.

- [ ] **Step 4: Format and verify page tests**

Run: `dart format lib/app/router/app_router.dart lib/features/books/presentation/search_results_page.dart test/search_results_page_test.dart`

Run: `flutter test test/search_results_page_test.dart`

Expected: route handoff, filters, first-page states, and back behavior pass.

- [ ] **Step 5: Commit the search page**

```bash
git add lib/app/router/app_router.dart lib/features/books/presentation/search_results_page.dart test/search_results_page_test.dart
git commit -m "feat: add filterable search results page"
```

### Task 5: Final Verification

**Files:**
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Interfaces:**
- Consumes: the focused tests from Tasks 1-4 and Flutter SDK from the no-space mapped checkout.
- Produces: recorded verification evidence and a scoped final-diff review.

- [ ] **Step 1: Run the feature suite**

Run: `flutter test test/recommendation_models_test.dart test/recommendation_repository_test.dart test/recommendation_controller_test.dart test/recommendation_section_test.dart test/books_page_search_navigation_test.dart test/search_results_controller_test.dart test/search_results_page_test.dart`

Expected: all relevant feature tests pass.

- [ ] **Step 2: Run static and whitespace checks**

Run: `flutter analyze`

Run: `git diff --check`

Expected: no new analyzer errors and no whitespace errors.

- [ ] **Step 3: Review changed-file scope**

Run: `git status --short` and `git diff --stat`

Expected: only intended feature files plus pre-existing user worktree files are present; no generated output is added.

- [ ] **Step 4: Record evidence and commit status updates**

```bash
git add task_plan.md findings.md progress.md
git commit -m "docs: record recommendation and search verification"
```
