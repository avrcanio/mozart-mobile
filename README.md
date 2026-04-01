# Mozart Mobile

Flutter MVP scaffold for issue `#1`, based on the migration brief from the existing web frontend to a mobile-first client over the same Django API.

## Scope implemented

- Flutter project bootstrap for Android and iOS
- Layered app structure:
  - `lib/src/data`
  - `lib/src/domain`
  - `lib/src/presentation`
- Token-auth oriented login shell
- Dashboard, mailbox, and purchase orders MVP screens
- Purchase order split-view detail layout on wide screens
- Warm visual theme that matches the issue direction better than a default Material seed app

## Current backend contract assumptions

- `POST /api/token/` for login
- `GET /api/me/` for current user details
- Existing mailbox and purchase order endpoints remain the source of truth

The app now performs real token-based auth and backend requests, with secure device storage for session persistence.

## Run

```bash
flutter run
```

Default API base URL: `https://mozart.sibenik1983.hr`

Override the API base URL when needed:

```bash
flutter run --dart-define=MOZART_API_BASE_URL=https://your-backend.example.com
```

## Next implementation steps

- Expand purchase-order workflow coverage with more mutation paths
- Add integration-style coverage around create/edit/send flows
- Confirm logout semantics for token invalidation vs local sign-out

## CI

GitHub Actions runs `flutter analyze` and `flutter test` automatically on pushes to `main` and on pull requests via [.github/workflows/flutter-ci.yml](C:/Users/avrca/Documents/Projects/mozart-mobile/.github/workflows/flutter-ci.yml).
