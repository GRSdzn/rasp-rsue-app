# Architecture

RSUE Schedule is an offline-first Flutter application. The dependency flow is:

`presentation -> domain -> repository -> remote API / Drift database`

## Modules

- `app/` — application shell, semantic theme, navigation and dependency wiring.
- `core/` — HTTP client, Drift database and shared primitives.
- `features/entities/` — group/teacher catalogue, local bootstrap and favorites.
- `features/schedule/` — schedule models, parsing, repository, sharing and UI.
- `features/settings/` — persisted appearance and first-day-of-week preferences.

Riverpod owns application state and constructor-level dependency injection. Repositories expose cached values first and synchronize in the background. UI code does not parse API payloads or access SQLite.

## Offline-first contract

1. The bundled `api-search-list.json` seeds the catalogue on the first launch.
2. Drift is the source of truth for the catalogue, favorites, schedules and sync metadata.
3. A refresh stores successful remote responses transactionally and merges newly
   received weeks with already cached weeks for the same entity.
4. Network failures never clear cached values.
5. Schedule JSON is cached by stable entity key so future API changes remain isolated in the data mapper.

## Current database

- `entities`: stable API id (also used as the internal cache key), display name
  and group/teacher kind. The id is never rendered.
- `favorites`: entity key and creation time.
- `schedule_cache`: raw validated schedule JSON and synchronization time.
- `app_settings`: key/value preferences and synchronization metadata.

Schema version is 1. The project uses Drift's runtime typed-query API so it has
no generated source step. Future schema changes must include a Drift migration.
