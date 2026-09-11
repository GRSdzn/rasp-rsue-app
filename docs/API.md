# RSUE API notes

Inspected on 2026-09-11 from `https://rasp-api.rsue.ru/api/schema/?format=json` and live responses.

## Endpoints

- `GET /api/v1/schedule/search/` — all searchable groups and teachers. Items contain only `id` and `name`; the response does not identify the entity kind.
- `GET /api/v1/schedule/list/` — groups nested by faculty and course. Used to classify search items as groups.
- `GET /api/v1/schedule/lessons/{query}/` — schedule for a group or teacher. `query` is the URL-encoded display name. The response exposes `kind`, `instance`, and `weeks`.

IDs are never shown. The current endpoint addresses schedules by name; the app still persists the supplied numeric id as the stable catalogue identifier.

## Schedule response

`weeks[]` contains `id`, `name`, `current`, `parity`, and `days[]`. A day has `date`, `name`, and eight or fewer `pairs[]`. Empty pair slots have an empty `lessons` array and are not rendered.

A lesson contains:

- `subject`
- `teacher { id, name }`
- `group`
- `kind { id, name }`
- `subgroup { id, name }`
- `audience`

## Observed inconsistencies

- OpenAPI declares `Day.date` as `format: date`, while the live API returns `dd.MM.yyyy` (for example `07.09.2026`). The parser accepts that format plus ISO-8601.
- The search payload cannot classify groups vs teachers. Classification is enriched from `/schedule/list/`; bundled first-launch data uses a conservative group-code heuristic until the first successful sync.
- The service is sometimes slow to establish a TLS connection. Timeouts are treated as ordinary offline conditions and cached content remains usable.
- The served chain includes a self-signed certificate. The mobile client accepts the invalid chain only for `rasp-api.rsue.ru:443` and only when the leaf certificate SHA-256 fingerprint matches the audited value from 2026-09-11. Certificate rotation requires updating this pin; all other invalid certificates are rejected.
- Responses can contain a valid week whose every pair has no lessons.

No undocumented endpoint or field is used.
