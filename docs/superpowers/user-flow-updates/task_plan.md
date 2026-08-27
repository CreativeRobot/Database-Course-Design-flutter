# Task Plan: Authentication and Storefront Flow Updates

## Goal
Implement the requested captcha policy, personalized storefront, role-based post-login routing, shared branding, and checkout address refresh across the Flutter client and Spring backend.

## Phases
- [completed] Confirm requirements and map existing flows.
- [completed] Record the approved architecture specification.
- [completed] Create the implementation plan.
- [in_progress] Await execution-mode selection before production-code changes.
- [pending] Write failing backend and Flutter tests.
- [pending] Implement the agreed changes without overwriting existing work.
- [pending] Run focused and full verification.

## Constraints
- Preserve the user's existing uncommitted changes in both repositories.
- Login captcha becomes required beginning with the fourth consecutive attempt.
- Captcha lifetime is five minutes.
- Login attempts accumulate per device for a rolling 30-minute window, including successful attempts.
- Do not begin production-code edits until the user approves the design.

## Errors Encountered
| Error | Resolution |
|---|---|
| `rg.exe` cannot run in the sandbox. | Use PowerShell file discovery and `Select-String` for read-only search. |
| Git object database is read-only to the sandbox. | The specification file is saved but cannot be committed from this session. |
| Escalated Git staging approval returned HTTP 503. | No Git write occurred; do not retry or bypass the rejected staging operation without fresh user direction. |
