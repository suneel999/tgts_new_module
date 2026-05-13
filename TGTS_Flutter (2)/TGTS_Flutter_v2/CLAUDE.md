# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Install dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# Run on specific device
flutter run -d <device-id>

# Run a single test file
flutter test test/path/to/test_file.dart

# Run all tests
flutter test

# Static analysis
flutter analyze

# Build release APK
flutter build apk --release

# Build release iOS
flutter build ios --release
```

## Architecture

This is the Flutter frontend for the **Telangana Congress Communication App** — a member/party-facing mobile app with OTP login, bilingual content (English + Telugu), role-gated content, and an admin panel.

### State management

Two global `ChangeNotifier` providers mounted at the root in `main.dart`:

- **`AuthService`** (`lib/services/auth_service.dart`) — authentication state, current user, JWT access token, membership status. Persisted to `SharedPreferences`. All screens that need auth data read from this.
- **`LanguageService`** (`lib/services/language_service.dart`) — current language (`Language.en` or `Language.te`), persisted to `SharedPreferences`.

### Navigation

`GoRouter` is configured in `main.dart` with a `redirect` guard that enforces:
1. Unauthenticated → `/login`
2. Authenticated but no membership → `/membership`
3. Has membership but visiting `/membership` → `/home`

The main authenticated shell is `MainNavigationScreen`, a `PageView` with 6 tabs (Home, Media, Events, Documents, MyActivity, Profile) driven by `MobileNavBar`.

### API layer

- **`ApiConfig`** (`lib/config/api_config.dart`) — toggle `useProduction = true/false` to switch between production (`https://api.tgtccon2025.com/api`) and local URLs. Change this flag when developing locally.
- **`ApiService`** (`lib/services/api_service.dart`) — singleton HTTP client. All requests go through `makeRequest()`. Response parsing/error wrapping is done in `_handleResponse()`.

### Data models (`lib/models/index.dart`)

All models live in a single file. Key models:
- `User` — merged user + member data. Presence of `fullName` and `status` fields signals an active membership (not a separate boolean field).
- `NewsItem`, `Event`, `MediaItem`, `Document` — content models. Multilingual fields are stored as `Map<String, String>` keyed by `"en"` / `"te"`.
- `Language`, `UserRole` (`public` | `cadre` | `admin`) — enums used throughout.

### Access level filtering

`AccessLevelFilterMixin` (`lib/mixins/access_level_filter_mixin.dart`) is mixed into content screens. Access is hierarchical: `admin` sees all, `cadre` sees public + cadre, `public` sees only public. Items store their required access level as a single-item list (e.g. `['cadre']`). The mixin's `applyFilters()` handles both role-gating and the active filter chip selection.

### Theme and colors

`AppTheme` (`lib/utils/app_theme.dart`) defines a Material 3 theme. `AppColors` (`lib/utils/app_colors.dart`) defines the palette — Indian flag-inspired: sky blue primary (`#19aaed`), green secondary (`#138808`), navy accent (`#000080`). Always use `AppColors` constants; do not hardcode hex values in widgets.

### Key conventions

- All API responses return `Map<String, dynamic>` with a `success` bool and either `data` or `message`.
- Bilingual content is accessed via `.getName(lang)` on ref models or by indexing `map[lang.name]` on `Map<String, String>` title/description fields.
- The `SplashScreen` calls `AuthService.initialize()` and `AuthService.checkMembershipStatus()` before routing — don't assume auth state is ready until after splash.
