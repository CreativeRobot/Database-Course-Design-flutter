# Authentication and Storefront Flow Updates Design

## Purpose

Apply the agreed login captcha behavior and simplify the customer storefront without changing the existing order, catalog search, or management APIs beyond the captcha contract.

## Scope

- Login captcha is hidden for the first three login submissions made by one device during a rolling 30-minute window.
- Starting with submission four, login requires a captcha. Successful and failed submissions both increment the counter. The counter naturally expires after 30 minutes without a submission.
- Registration always requires a captcha. Password recovery remains out of scope because it has no current frontend or backend implementation.
- Captchas expire after five minutes and remain single-use.
- A customer homepage contains recommendation content only. The ordinary catalog remains available through the existing search flow.
- Customer and administrator sessions land on different destinations after successful authentication.
- The cart page brand becomes the consistent left-side brand mark throughout the application.
- Checkout removes the specified explanatory subtitle and reloads addresses after returning from profile management.

## Architecture

### Captcha policy

The Flutter client owns the per-device interaction policy because the agreed scope is a local-device, rolling time window. A focused persisted helper stores the timestamped recent login submission count in SharedPreferences. It exposes the current `requiresCaptcha` state and records one submission only after client-side form validation has passed.

The login request contract changes so `captchaId` and `captchaCode` are optional as a pair. The backend skips captcha validation when both values are absent, validates and consumes the captcha when both are present, and rejects a partial pair. This supports the agreed user interface while retaining server-side image-code validation whenever a captcha is required by the client. Registration keeps its existing mandatory captcha fields and validation.

`CaptchaService` and its Caffeine cache configuration use 300 seconds. The value returned in `CaptchaVo` is also 300 seconds so the visual countdown and server expiration agree.

### Homepage and roles

`BooksPage` becomes the customer recommendation homepage. For an authenticated customer it requests the existing recommendation endpoint and gives its recommendation grid the main content area; it no longer loads or renders the ordinary catalog grid. The search route remains the catalog access path. For an unauthenticated visitor, the page provides a sign-in call to action instead of a non-recommended catalog.

Authentication already returns and persists `Role`. A small destination resolver maps `ADMIN` to `/admin` and every other role to `/books`. Login and registration both use that resolver; registration naturally resolves to `/books` because the backend creates customers. The route guard redirects an authenticated administrator away from the customer homepage to `/admin`.

### Shared branding

Extract the existing `CommerceHeader` brand portion (book icon and `书间` text) into a reusable widget in the commerce presentation module. Retain page-specific navigation, search, and actions while replacing each page header's left-side identity with this shared widget. This prevents turning the books or administration header into the cart navigation bar while making the visual mark identical.

### Checkout address refresh

Checkout awaits the profile route result for both the management and add-address actions. When that route is popped, it invalidates `checkoutAddressesProvider`, causing a fresh address query before the selection is rendered. The selected-address helper continues to select the newly created default address first, then the first available address. The checkout hero subtitle is removed exactly as requested.

## Error Handling

- A failed captcha fetch keeps the login form usable only while a captcha is not required. Once required, it shows the existing retryable captcha error state and prevents submission.
- A malformed partial captcha pair receives the existing invalid-captcha business error from the backend.
- Recommendation and address loading continue to use the existing retry/error surfaces.
- The client does not reset the login-attempt state on a successful login; it resets only by rolling-window expiration.

## Tests

- Backend `CaptchaServiceTests` verifies five-minute issue metadata and cache behavior, including single-use verification.
- Backend authentication tests verify a login can omit both captcha fields, accepts a valid full pair, and rejects a partial pair. Registration tests continue to require a full pair.
- Flutter unit tests cover rolling-window pruning, threshold behavior, successful-attempt counting, and the role destination resolver.
- Flutter widget tests cover the login captcha visibility threshold, full recommendation-only customer homepage states, and checkout address-provider invalidation after the profile route returns.

## Compatibility

- Existing login clients that always send a complete captcha pair continue to work.
- Existing registration and recommendation APIs retain their paths and response models.
- No schema migration, password reset endpoint, or new external dependency is introduced.
