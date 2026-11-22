# Phase 4 — website changes the app relies on

The iOS app syncs through the website's existing API. Three small additions were made in the website repo (`BibleWish_Website`), **tested against the local Docker stack but not committed or deployed**: that is the owner's call (the website repo's `CLAUDE.md` describes deploying: commit, then `bash scripts/deploy.sh`, which also applies pending migrations).

| File | Change |
|---|---|
| `db/migrations/017_highlight_colors.sql` | adds `highlights.colors` (JSON text, `''` = all default) |
| `api/highlights.php` | `GET` also returns `colors`; `PUT`/merge accept optional `colors`. `highlights` keeps its shape, and a `PUT` without `colors` (the website) keeps the saved colors |
| `api/reading.php` | `POST ?action=import { chapters }`: adds chapters read before signing in to Bible progress only (no read events, so streaks and the leaderboard are untouched); invalid entries are skipped; capped at 1,189 |
| `api/plans.php` | `POST ?action=import { plan_id, started_on, progress }`: keeps the real start date and tick times (a normal `start` only accepts a date within two days of today, and `check` counts as reading today) |
| `api/account.php` | the data export includes highlight colors |

## If the server isn't updated yet

The app still works and nothing on the device is lost. Highlight colors stay on the device (a server without `colors` just omits them). An older server refuses the two import endpoints; the app keeps those plans and highlights, merges them with whatever the server has, and tries the upload again on every sync until the endpoints are live. A plan or the highlights are only overwritten or removed by the server once it has acknowledged them (the self-test simulates a refusing server).

## Local testing

```sh
# website repo
cp config.example.php config.local.php   # dev values from docker-compose.yml (git-ignored)
docker compose up -d                     # site :8088, Mailpit :8025
# app repo, simulator build
SIMCTL_CHILD_BW_SELFTEST=1 SIMCTL_CHILD_BW_API_BASE=http://localhost:8088 \
  xcrun simctl launch --console <device> Sysware.BibleWish
```

`BibleWish/Sync/SelfTest.swift` (Debug builds only) signs in with throwaway accounts through Mailpit and checks both directions of every data type, offline retries and switching accounts (117 checks). The local server rate-limits sign-ins (30 verifications per hour per IP); clear it between runs with `DELETE FROM rate_limits`.
