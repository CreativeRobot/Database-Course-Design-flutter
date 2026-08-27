# Findings

- The Flutter project is `flutter_application_bookstore`, nested below the directory originally named by the user.
- The backend captcha is currently always required by `LoginDTO` and expires after 120 seconds.
- The registration page already loads and submits a captcha. The login page also currently loads and requires one unconditionally.
- The visible `忘记密码？` control has `onPressed: null`; neither application contains a password-reset endpoint or page.
- Login responses already include the user's role, and the client session model persists it.
- The client already has recommendation, administration, checkout, cart, and profile/address modules.
- Checkout navigates to the profile route with `push`, but does not invalidate or reload its address provider on return.
- The `BooksPage` renders personalized recommendations above the ordinary catalog. The catalog uses a separate controller and grid, so it can be replaced without changing the search route.
- The cart, checkout, order, review, and profile pages already share `CommerceHeader`; its `书间` book-icon mark is the requested shared identity. The books page currently uses another header.
- The recommendation endpoint is loaded only for authenticated non-admin users. Administrators already have a dedicated administration route.
- The frontend and backend each contain pre-existing uncommitted changes, including active planning files for unrelated work. This task uses this separate directory to avoid overwriting them.

## Confirmed Requirements

- Show a login captcha starting after three prior login attempts, independent of success or failure.
- Keep captcha mandatory for registration.
- Set captcha validity to five minutes.
- Password recovery is explicitly out of scope; the inert password-recovery control will not be enabled or redesigned in this change.
- Login attempts use a client-persisted, rolling 30-minute per-device counter. Attempts one through three have no captcha; every later attempt in that window requires one, including after successful sign-in.
