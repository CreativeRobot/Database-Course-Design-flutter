# flutter_application_bookstore

Flutter client for the BookStore API.

## API environments

The app reads its API address from compile-time `--dart-define` values.
`APP_ENV` accepts `development`, `staging`, or `production` and defaults to
`development`. `API_BASE_URL` must be supplied explicitly for every environment;
there is no `localhost` fallback so that Android builds do not accidentally call
the device itself.

### Android emulator

The Android emulator reaches the backend running on the host computer through
`10.0.2.2`:

```powershell
flutter run `
  --dart-define=APP_ENV=development `
  --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

### Android physical device

Use the computer's LAN address, and keep the phone and computer on the same
network. Replace `192.168.1.100` with the computer's actual LAN IP:

```powershell
flutter run `
  --dart-define=APP_ENV=development `
  --dart-define=API_BASE_URL=http://192.168.1.100:8080
```

The backend must listen on a reachable interface and the computer firewall must
allow port `8080` for local testing.

### Staging

```powershell
flutter run `
  --dart-define=APP_ENV=staging `
  --dart-define=API_BASE_URL=https://staging-api.example.com
```

### Production APK

Production API addresses must use HTTPS:

```powershell
flutter build apk --release `
  --dart-define=APP_ENV=production `
  --dart-define=API_BASE_URL=https://api.example.com
```

The production API URL should be a public HTTPS endpoint. Do not use
`localhost`, `10.0.2.2`, or a private LAN address for a user-facing release APK.

For staging and production, `API_BASE_URL` must be an absolute HTTP(S) URL;
production additionally requires the `https` scheme.
