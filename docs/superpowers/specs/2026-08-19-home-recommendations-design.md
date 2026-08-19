# Homepage Recommendations Design

## Goal

Show each customer a small, explainable list of in-stock books on the storefront, ranked from existing completed purchases and published ratings, while returning reliable popular-book results for customers without enough history.

## Scope

The backend will expose `GET /api/recommendations/home?limit=12` for an authenticated customer. It returns a `RecommendationHomeVo` containing a source (`PERSONALIZED` or `POPULAR`) and up to 12 `RecommendationBookVo` items. Each item includes the existing book-card fields and a short reason. The client will make the books page the home surface and add a compact "为你推荐" section above the normal catalog.

Only `ON_SALE` books with positive stock may be returned. Books present in the customer's completed orders are excluded. The client keeps the existing searchable catalog below the recommendation section.

## Ranking

The ranking has three deterministic components, evaluated in the backend:

1. Category affinity: each completed purchase contributes 3 points to every category of that book; a review contributes an extra 0-4 points according to its rating.
2. Co-purchase affinity: for every book bought by the current customer, every other item in the same completed order contributes 2 points. This is item-based collaborative filtering over real co-purchase behaviour, without a new event table.
3. Popularity fallback: completed-order sales count sorts candidates with no personal score. Ties use average published rating, then most recently created book, then id.

For a customer with positive category or co-purchase scores, personalized candidates sort by the combined score, popularity, rating, recency, and id. For a customer without history, the response source is `POPULAR`, and the reason is "热门畅销". A personalized item says either "与你喜欢的分类相似" or "与已购图书常被一起购买" based on its dominant score.

## Caching And Invalidation

`RecommendationService` will cache a completed response per user for 15 minutes in process memory. Cache entries must be removed when an order transitions from `SHIPPED` to `COMPLETED`, and when that user creates or changes a review. A size bound prevents unbounded memory use. Cache misses and failures remain local to the recommendation request; the standard catalog endpoint stays independent.

## Frontend Behavior

`RecommendationRepository` retrieves and parses the home response. A Riverpod controller exposes loading, data, error, and `refresh`. The section renders existing book-card affordances, handles loading with the shared commerce loading state, renders a retry action on failure, and omits itself if no eligible books exist. Pull-to-refresh refreshes both recommendations and catalog data. The controller preserves the last successful list while a background refresh is in flight.

## Error Handling And Tests

The API rejects limits outside 1-20 with the project's existing `BusinessException` convention. The service returns a valid empty response rather than throwing when the catalog has no eligible books. Backend unit tests cover exclusion, personalized ranking, popular fallback, and invalidation. Flutter tests cover JSON parsing, retryable error state, and rendering a reason from the returned item.

## Constraints

- No database migration or third-party recommender engine is introduced.
- Ranking uses only completed orders and published reviews.
- Existing untracked frontend `.tmp_tool/` content remains untouched.
- Frontend verification uses the no-space mapped path when Flutter dependency tooling requires it.
