# Phase 4 — Accounts and sync (plan)

Status: **proposal, nothing built** · 2026-11-22

Goal: sign in to biblewish.com from the app so favorites, notes, highlights, reading progress and plans follow the reader across the website and the app (and, if wanted, the prayer features).

## What the website already gives us (no backend work needed for tier A)

- **Auth:** `api/auth.php` — email → 6-digit code (`request-link`, `verify-code`). The app keeps the session cookie (30 days, `HttpOnly`, `Secure`) in `HTTPCookieStorage` and sends the `X-Requested-With: BibleWish` header that writes require (the `Origin` check only applies when an Origin is sent, and the app sends none).
- **Data:** `favorites.php`, `notes.php`, `highlights.php`, `reading.php`, `plans.php`, `prayers.php` (private list), `account.php` (profile, export, **delete account**), `badges.php`.
- **Terms:** `terms.html` exists; `privacy.html` exists.

## Mapping local data to the API

| In the app | API | Notes |
|---|---|---|
| Favorites (bookmarks) | `favorites.php` | needs translation id, canonical book index, chapter, verses, label, text; the app stores book *names*, so map names → canonical index (already done for badges) |
| Notes | `notes.php` | same tag ids; body is the same light Markdown; anchors = book index, chapter, verses |
| Highlights | `highlights.php` | **gap:** the API stores verses only, the app has 4 colors → a small migration to store the color, or map every color to the site's one |
| Chapters read | `reading.php` | the server stamps "today"; the app's older chapters have no dates, so history can't be back-dated without a small import endpoint |
| Plans | `plans.php` | start date + per-day/item progress: same model as the app's |
| Prayer list (private) | `prayers.php` | simple list; new UI needed |

## How sync should work

- **Offline first.** The device stays the source of truth; every change is queued and sent when online; the app works signed out exactly as it does now.
- **First sign-in merges** (union, like the website's own merge for highlights) so nothing is lost on either side; after that, last write wins per item using `updated_at`.
- **Signed out = today's behavior.** Sync is opt-in from Settings.

## Apple's rules this triggers

- **Account deletion in the app** (guideline 5.1.1(v)): the API exists, the UI doesn't. Required for any app with accounts.
- **Sign in with Apple is not required**: the app uses its own email sign-in, no third-party/social login.
- **Privacy label changes** from "Data Not Collected" to: Email Address, User ID, and User Content (notes, prayers), linked to the user, used for app functionality, not tracking. Update `PRIVACY.md`, `docs/APP_STORE.md` and the two `PrivacyInfo.xcprivacy` manifests (`NSPrivacyCollectedDataTypes`) **before** submitting.
- **Community prayers are user-generated content** (guideline 1.2). They need: terms acceptance before posting, a way to report (exists), a way to **block users (missing in the prayers API; only verse shares have `block`)**, filtering of objectionable content, and published contact details. This is the biggest review risk.

## Tiers

| Tier | Scope | Backend changes | Apple UGC rules |
|---|---|---|---|
| **A. Private sync** | Sign in; sync favorites, notes, highlights, reading, plans; account screen with export and delete | small: highlight color (optional), reading import (optional) | not triggered |
| **B. + Prayer list** | A + the private prayer list | none | not triggered |
| **C. + Community** | B + community prayers, reactions, replies, reporting | block users; terms-acceptance flag; review-ready moderation | **triggered** |

## Recommendation

Ship **tier A** first (it delivers what readers ask for: the same notes and progress everywhere), add **B** when wanted, and treat **C** as a separate release with the block/terms work done on the server first.

## Work breakdown for tier A

1. `APIClient` (URLSession, cookies, JSON, error mapping) and `AuthStore` (signed-in user, sign-in/out).
2. Sign-in screen (email → code), reachable from Settings; account screen (profile, export, delete with a typed confirmation).
3. A sync layer: per-type change queue, merge on first sign-in, retry with backoff, "Last synced" and a manual "Sync now".
4. Mapping code (names ↔ canonical book index) with tests.
5. Privacy: manifests, `PRIVACY.md`, App Privacy label, terms link in the sign-in screen.
6. Tests against the local Docker stack (`docker compose up -d`, Mailpit catches the sign-in code) before touching production.

## Decisions needed from the owner

1. Which tier to build.
2. Highlight colors: add a color column on the server, or map to a single color?
3. Whether to import existing on-device reading history (needs a small server import endpoint) or start server history from the day of first sync.
