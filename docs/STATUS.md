# Project status

## Implemented

- Android and iOS Flutter targets.
- Feature-based architecture and centralized semantic design system.
- Documented, isolated RSUE API contract.
- Drift source of truth for catalogue, favorites, cached schedules and settings.
- Bundled API search snapshot for first-launch/offline discovery.
- Background catalogue and schedule refresh with cached-data fallback.
- Name search with separate Groups and Teachers modes.
- Favorites, daily/weekly schedule, week navigation and one-tap Today.
- Purposeful calendar/content/favorite/loading animations and haptics.
- Current, upcoming and completed lesson presentation.
- Native day/week share sheet with a prepared deep-link payload.
- Light, dark and system themes; week-start and notification extension settings.
- Responsive bottom navigation on phones and split navigation/sidebar on tablets.
- Automatic positioning near the current/upcoming lesson.
- Calm custom launch artwork in the semantic teal/lavender palette.
- Android compile/target SDK 36 and iOS/Android custom URL scheme registration.

## Known limitations

- RSUE search items have no entity-kind field. The application classifies them with the group catalogue when online and a local naming heuristic before that.
- Notifications are an extension point only; the public API has no notification or change-feed contract.
- Shared text includes an entity/date/mode deep-link payload and both mobile
  platforms register the custom scheme. In-app URI routing and universal/app-link
  hosting are intentionally the next extension.
- iOS source and configuration are present, but an iOS binary cannot be compiled
  on the current Windows host.

## Verification

- `dart analyze` — no issues.
- `flutter test --no-pub` — 3 tests passed.
- `flutter build apk --debug --no-pub` — successful.
- Debug artifact: `build/app/outputs/flutter-apk/app-debug.apk`.
