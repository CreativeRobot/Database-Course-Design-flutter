# Storefront Recommendations And Search Design

## Goal

After a customer signs in, show an explainable, account-specific recommendation section on the storefront. Submitting the storefront search opens an independent search-results page whose filters, pagination, and errors do not change the storefront catalog or recommendation state.

## Scope

This design implements Flutter client behavior only. The existing backend recommendation contract is documented in `2026-08-19-home-recommendations-design.md` and in the backend interface document:

- `GET /api/recommendations/home?limit=12` requires the current customer token and returns `source` plus up to 12 book-shaped items with a `reason`.
- `GET /api/books` accepts the existing `keyword`, `categoryId`, `authorId`, `publisherId`, `minPrice`, `maxPrice`, `inStock`, `sortBy`, `direction`, `page`, and `size` query parameters.

No backend contract, database schema, ranking behavior, or third-party package changes are needed.

## User Experience

### Storefront

`BooksPage` remains the catalog home surface. After authentication has resolved to a non-admin customer, it requests the home recommendation endpoint with `limit=12` and renders the recommendation section above the normal catalog. Each recommendation shows the existing book-card information and the backend-provided reason. Tapping a card opens the existing book detail route.

The section is omitted when the endpoint returns no eligible books. Initial loading uses the shared commerce loading state. A first-load failure exposes a retry affordance without hiding the catalog. A later refresh keeps the prior successful cards visible and shows the retryable error inline. A storefront refresh loads the catalog and recommendations independently, so a recommendation error never prevents catalog use.

### Search Results

Submitting a non-empty storefront search query navigates to `/search?keyword=<encoded keyword>`. This is an in-app page, not a browser tab or operating-system window. The page has its own search field, result count, paginated grid, loading/empty/error states, and a back action to the storefront.

The results page owns a separate Riverpod controller. Its initial query comes from the route query parameter. It offers category, author, publisher, minimum price, maximum price, availability, and sorting controls. Changing a query or a filter always reloads page 1. Loading more preserves those selections and appends the next page. Returning to the storefront leaves the storefront catalog and recommendation data unchanged.

## Architecture

### Recommendation Data And State

`RecommendationRepository` wraps the authenticated `ApiClient` and parses `RecommendationHome`. `RecommendationController` owns `RecommendationState` with `initial`, `loading`, `success`, `refreshing`, and `failure` states, an optional last successful response, and a user-readable error message. The controller must reject invalid client limits before issuing a request and must preserve the last successful response on refresh failure.

`RecommendationBooks` is a focused presentation widget. It receives a parsed home response, base URL, and book-tap callback; it does not issue HTTP requests or own application state. `BooksPage` observes the controller only for authenticated customers and wires retry, refresh, image URLs, and detail navigation.

### Search Data And State

`BookRepository` remains the only owner of `/api/books` calls. A new `SearchResultsController` owns an immutable `SearchResultsState`, composed from the existing book records and filter-option models. It exposes `loadInitial`, `submitKeyword`, `updateFilters`, `loadMore`, and `retry`. The controller reads category, author, and publisher options through the existing repository methods; option-loading errors are shown without discarding already-loaded results.

The controller is scoped to `SearchResultsPage`, rather than sharing `BooksController`. Therefore the home catalog may retain its category and filter selection while the search page changes independently. Route state contains only the initial keyword; subsequent controls live in the page controller, avoiding route writes for every dropdown selection.

### Routing

`app_router.dart` adds a public `GoRoute` for `/search`. Its builder passes `state.uri.queryParameters['keyword']` to `SearchResultsPage`. The route is intentionally public because `/api/books` and all available search filters are public data. The page uses `context.pop()` when it has a navigator history entry, otherwise it goes to `/books`, so direct links remain usable.

## Error Handling

- Recommendation `401` continues to be handled centrally by `ApiClient`, which clears the session and routes the user through existing authentication behavior.
- Recommendation response format errors and transport errors use the existing friendly network messages. They remain local to the section.
- The search page displays an empty state for a successful empty page, and an error state with a retry action when the first result page fails.
- A load-more failure retains loaded cards and exposes an inline retry. Repeated load-more requests are ignored while a request is already in flight or no next page exists.
- A new keyword is trimmed. Whitespace-only submissions remain on the current page and do not issue a request.
- Price values are parsed only when valid, and the page prevents `minPrice > maxPrice` from reaching the API by showing a local validation message.

## Tests

- Model tests verify the recommendation response, source, reason, and invalid payload behavior.
- Repository/controller tests verify correct endpoint/query parameters, successful load, refresh failure preserving existing recommendations, and retry.
- Widget tests verify that the recommendation section renders the backend reason, is hidden for empty data, and opens the supplied book callback.
- Search-controller tests verify route-keyword initialization, filter replacement resets to page 1, load-more appends records, ignored duplicate loading, and error retention.
- Search-page widget tests verify navigation from the storefront search field, query display, filters, empty/error states, and back behavior.

## Constraints

- Reuse Riverpod, GoRouter, `BookRepository`, `ApiClient`, shared commerce states, and existing card visual conventions.
- Do not modify the existing backend recommendation implementation.
- Do not alter or revert the worktree's existing uncommitted recommendation tests, planning files, or `.tmp_tool/` content.
- Flutter analysis and tests must run from the known no-space mapped checkout when the original path blocks native-assets tooling.
