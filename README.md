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

This scaffold currently uses in-memory sample data so the mobile structure can be reviewed before wiring real API and persistent token storage.

## Run

```bash
flutter run
```

Optional API base URL:

```bash
flutter run --dart-define=MOZART_API_BASE_URL=https://your-backend.example.com
```

## Next implementation steps

- Replace in-memory auth storage with secure device storage
- Implement real HTTP DTOs and mappers for dashboard, mailbox, and purchase orders
- Confirm logout semantics for token invalidation vs local sign-out
- Add forms and mutations for purchase order create/edit flows
