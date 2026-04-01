# Ordino

<p align="center">
  <img src="assets/branding/app_mark.png" alt="Ordino app mark" width="180">
</p>

Mobile purchase, mailbox, and dashboard client for the Mozart backend, now branded as `Ordino`.

## Overview

- Flutter app for Android and iOS
- Native app identity: `hr.finestar.ordino`
- Token-based authentication against the existing Django API
- Dashboard, mailbox, and purchase-order workflows
- Secure session persistence with `flutter_secure_storage`
- CI on `push` to `main` and `pull_request`

## Project Structure

- `lib/src/data` API clients, DTOs, repositories
- `lib/src/domain` app models and business entities
- `lib/src/presentation` screens, controllers, app shell
- `test/widget_test.dart` widget and flow coverage

## Backend Contract

- `POST /api/token/` login
- `GET /api/me/` current user
- Mailbox endpoints under `/api/mailbox/messages/`
- Purchase-order endpoints under `/api/purchase-orders/`

Default API base URL:

```bash
https://mozart.sibenik1983.hr
```

Override it when needed:

```bash
flutter run --dart-define=MOZART_API_BASE_URL=https://your-backend.example.com
```

## Run

```bash
flutter pub get
flutter run
```

## Verification

```bash
flutter analyze
flutter test
```

## Notes

- Logout clears the locally stored token immediately and can optionally call a backend logout endpoint when configured.
- Android 12+ splash behavior is still constrained by the platform splash API masking rules.

## CI

GitHub Actions workflow:

- `.github/workflows/flutter-ci.yml`
