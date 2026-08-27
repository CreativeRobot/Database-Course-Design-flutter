# Progress

## 2026-08-27

- Classified the requested work as an architectural, cross-application change.
- Inspected existing captcha service and authentication contracts.
- Confirmed the user-selected login threshold and five-minute captcha lifetime.
- Confirmed that the visible password-recovery control is currently inert and that no reset contract exists.
- Password recovery was explicitly deferred by the user.
- Mapped the homepage recommendation placement, shared commerce header, role-bearing client session, and checkout address provider.
- User approved a rolling 30-minute, per-device login-attempt counter that also counts successful sign-ins.
- User approved the complete design. Wrote the architecture specification and will self-review it before requesting the mandatory specification review gate.
- Self-review passed: no placeholders, contradictions, out-of-scope work, or whitespace errors found.
- Git staging was blocked by `.git/objects` permissions; no commit was created and no existing worktree changes were altered.
- Wrote the task-by-task TDD implementation plan and will self-review it before offering the execution handoff.
- Plan self-review passed: Tasks 1-4 cover every specification requirement; task interfaces use consistent names and the plan contains no placeholders or whitespace errors.
- Inline execution setup found the frontend checkout is a normal `main` branch, not a linked worktree. No production or test code has been changed.
- The combined repository probe used the frontend working directory for the backend Git commands and therefore did not produce a valid backend isolation result; do not reuse that command form.
- The requested baseline commit could not start because elevated Git staging approval was rejected with an approval-service HTTP 503. No files were staged or committed.

## Implementation complete

- Backend captcha cache lifetime is now 300 seconds; login accepts an omitted captcha pair for the first three attempts and validates a complete pair thereafter, while registration remains captcha-required.
- Flutter login attempt policy persists timestamps in `SharedPreferences`, prunes entries at 30 minutes, counts successful and failed submissions, and reveals captcha on the fourth submission.
- Role-aware navigation sends `ADMIN` sessions to `/admin` and customer sessions to `/books`; admin/customer route guards were updated accordingly.
- The `/books` homepage now loads recommendation content instead of the general catalog, with responsive recommendation cards.
- `BookstoreBrand` centralizes the cart-style mark across auth, admin, storefront, and commerce headers.
- Checkout address management returns through `/profile`, invalidates `checkoutAddressesProvider`, and removes the obsolete explanatory sentence.
- Verification: backend focused Maven tests passed (12/12); frontend focused Flutter tests passed (25/25); `flutter analyze` reports only pre-existing project diagnostics, including the existing `showAdminActionError` test error.
