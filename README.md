# flutter_application_bookstore

Flutter client for the BookStore API.

## API environments

The app reads its API address from compile-time `--dart-define` values.
`APP_ENV` accepts `development`, `staging`, or `production` and defaults to
`development`. Only development can omit `API_BASE_URL`; it then uses
`http://localhost:8080`.

Run against a backend on this computer:

```powershell
flutter run
```

Run on an Android emulator (where the host machine is `10.0.2.2`):

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

Run against staging:

```powershell
flutter run --dart-define=APP_ENV=staging --dart-define=API_BASE_URL=https://staging-api.example.com
```

Run against production:

```powershell
flutter run --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://api.example.com
```

For staging and production, `API_BASE_URL` must be an absolute HTTP(S) URL.
