# Phase 4 — website changes the app relies on

The iOS app syncs through the website's existing API. Three small additions were made in the website repo (`BibleWish_Website`) and are **deployed to production (2026-11-22)**.

| File | Change |
|---|---|
| `db/migrations/022_highlight_colors.sql` | adds `highlights.colors` (JSON text, `''` = all default) |
| `api/highlights.php` | `GET` also returns `colors`; `PUT`/merge accept optional `colors`. `highlights` keeps its shape, and a `PUT` without `colors` (the website) keeps the saved colors |
| `api/reading.php` | `POST ?action=import { chapters }`: adds chapters read before signing in to Bible progress only (no read events, so streaks and the leaderboard are untouched); invalid entries are skipped; capped at 1,189 |
| `api/plans.php` | `POST ?action=import { plan_id, started_on, progress }`: keeps the real start date and tick times (a normal `start` only accepts a date within two days of today, and `check` counts as reading today) |

`api/account.php` was **not** deployed: production's copy has song-related lines that the repo doesn't have (it deletes unpublished songs when an account is deleted and includes songs in the export), so replacing it would have removed them. The only thing lost is highlight colors in the data export.

## Production is ahead of the website repo

Production has migrations `017_songs` to `021_make_room_lyrics` applied, but the repo (and GitHub) stops at `016`, so the songs work lives somewhere else (another machine or branch). Before anyone runs `deploy.sh --all` from a clone that lacks it, reconcile that, or older files would overwrite newer ones. This deploy was done by comparing production's copies of each file with the version the change was built on, and uploading only files that matched. The three website commits (`63ce1dc`, `d1095a8`, `09949c8`) are local and not pushed.

## Deploying from macOS

`scripts/deploy.sh` and `scripts/migrate.sh` needed small fixes for macOS's bash 3.2 (empty arrays under `set -u`, a variable followed by `…`); those are committed. `deploy.sh` still uses `wait -n`, which needs bash 4.3 or newer: `brew install bash`, then run it with `/opt/homebrew/bin/bash scripts/deploy.sh`.

## If a server doesn't have these yet (for example a local copy)

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
