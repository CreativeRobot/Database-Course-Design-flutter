# Task Plan: Authentication and Storefront Flow Updates

## Goal
Implement the requested captcha policy, personalized storefront, role-based post-login routing, shared branding, and checkout address refresh across the Flutter client and Spring backend.

## Phases
- [completed] Confirm requirements and map existing flows.
- [completed] Record the approved architecture specification.
- [completed] Create the implementation plan.
- [completed] Await execution-mode selection before production-code changes.
- [completed] Write failing backend and Flutter tests.
- [completed] Implement the agreed changes without overwriting existing work.
- [completed] Run focused verification and document known full-suite environment blockers.

## Constraints
- Preserve the user's existing uncommitted changes in both repositories.
- Login captcha becomes required beginning with the fourth consecutive attempt.
- Captcha lifetime is five minutes.
- Login attempts accumulate per device for a rolling 30-minute window, including successful attempts.
- Do not begin production-code edits until the user approves the design.

## Completion Notes

- Forgot-password recovery remains deferred as requested; its button stays visibly disabled.
- Login attempts are counted on the Flutter client per device in a rolling 30-minute window; captcha is shown from the fourth submission onward.
- Registration always requires captcha, and backend captcha records remain valid for five minutes.
- Customer and administrator destinations are role-aware; the storefront homepage now presents recommendations as its primary content.
- The shared `BookstoreBrand` mark is used across auth, storefront, cart, and admin surfaces.
- Returning from profile to checkout invalidates the address provider so newly saved addresses are available immediately.

## Errors Encountered
| Error | Resolution |
|---|---|
| `rg.exe` cannot run in the sandbox. | Use PowerShell file discovery and `Select-String` for read-only search. |
| Git object database is read-only to the sandbox. | The specification file is saved but cannot be committed from this session. |
| Escalated Git staging approval returned HTTP 503. | No Git write occurred; do not retry or bypass the rejected staging operation without fresh user direction. |
