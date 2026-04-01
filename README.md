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
- Logout currently relies on local secure-storage sign-out. The mobile client is ready for optional backend token invalidation when a dedicated logout endpoint is exposed.

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

## Logout semantics

- Current production behavior is intentional local sign-out: the stored token is removed from device secure storage and the app returns to the login screen immediately.
- The auth repository also supports optional backend logout invalidation when a dedicated endpoint is configured later.
- If backend invalidation is unavailable or fails, local sign-out still completes so the operator is not left in a broken logout state.

## Next implementation steps

- Expand purchase-order workflow coverage with more mutation paths
- Add integration-style coverage around create/edit/send flows

## CI

GitHub Actions runs `flutter analyze` and `flutter test` automatically on pushes to `main` and on pull requests via [.github/workflows/flutter-ci.yml](C:/Users/avrca/Documents/Projects/mozart-mobile/.github/workflows/flutter-ci.yml).
