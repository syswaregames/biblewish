# Submitting BibleWish 2.0 to the App Store

Everything the repository can do is done. This is the rest, in order. Steps marked **you** need your Apple or hosting
login; nothing here needs a password pasted anywhere but those sites.

Version **2.0 (build 3)**, bundle id `Sysware.BibleWish`, widget `Sysware.BibleWish.Widget`, team `3FG6EV356S`, iPhone and iPad, iOS 17.5 or later.

## What is already done

- [x] Version 2.0 (3) on the app **and** the widget (they must match); export compliance declared (`ITSAppUsesNonExemptEncryption = NO`: only standard HTTPS)
- [x] An unsigned Release **archive** builds with no errors; the archive has the widget, both privacy manifests (`PrivacyInfo.xcprivacy`) and the app icon; no Debug-only code, test hooks or local-server exceptions are in it
- [x] App icon: 1024 × 1024 with no transparency (Apple rejects an alpha channel)
- [x] Capabilities in the project: App Groups (`group.Sysware.BibleWish`, app and widget), Push Notifications (`aps-environment`)
- [x] Account deletion and data export are in the app (Settings → Account), as Apple requires (5.1.1(v))
- [x] User-generated content (Guideline 1.2): Report on every request and reply, Block on every member (even anonymous ones), community guidelines where people post, a moderator who is emailed each report and can remove content, contact address on the site
- [x] Push notifications working, with Apple's sandbox and production keys on the server
- [x] Privacy policy page updated for the app and live; review sign-in live and tested (step 3)
- [x] 9 iPhone (6.3" and 6.9" sets) and 6 iPad screenshots at Apple's sizes, opaque PNGs, in `AppStore/Screenshots/` (git-ignored)
- [x] 336 automated checks pass (`SelfTest`, Debug build)

## Step by step

### 1. Apple Developer account **(you)**: developer.apple.com → Certificates, Identifiers & Profiles

1. **Identifiers → `Sysware.BibleWish`**: tick **Push Notifications** and **App Groups** (select `group.Sysware.BibleWish`; create the group first under Identifiers → App Groups if it is missing). Save.
2. **Identifiers → `Sysware.BibleWish.Widget`**: tick **App Groups**, select the same group. Save.
3. Nothing else: signing is automatic (Xcode makes the profiles). The APNs keys are already on the server.

### 2. App Store Connect: the app record **(you)**: appstoreconnect.apple.com → Apps

If BibleWish is already listed, open it and skip to "version". Otherwise **+ → New App**: Platforms iOS; Name `BibleWish`; Primary language English (U.S.); Bundle ID `Sysware.BibleWish`; SKU anything unique (`biblewish`); User access Full.

### 3. Website: privacy page and the review login (done)

- **Done:** the updated privacy page is live (https://biblewish.com/privacy.html) and the review sign-in is configured on the server and tested on production (ask for a code, wrong code refused, right code signs in, not a moderator).
- **The demo credentials** are in `AppStore/review-login.txt` (private, not in git): a demo email and a six-digit code. You paste them into App Store Connect in step 7.6. In the app the reviewer enters that email, then the six digits in place of the emailed code.
- To change the code or turn it off, edit or delete the `review` line in `domains/biblewish.com/config.php` (details: the website repo's `docs/APP_REVIEW.md`).

### 4. Archive and upload **(you)**: Xcode

1. Open `BibleWish.xcodeproj`. Select the **BibleWish** scheme and **Any iOS Device (arm64)**.
2. **Signing & Capabilities** (both targets, BibleWish and BibleWishWidgetExtension): Team = your team, "Automatically manage signing" ticked. No red errors.
3. **Product → Archive.** When it finishes the Organizer opens: select the archive → **Distribute App → App Store Connect → Distribute** (accept the defaults: upload symbols, manage version numbers off).
4. The build appears in App Store Connect → TestFlight after a few minutes ("Processing"). No export-compliance question will be asked.

If Xcode complains about the push entitlement, check step 1.1. The `development` value in the entitlements file is correct: Xcode changes it to `production` for the App Store build.

### 5. Test the TestFlight build on your phone **(you)**

Install it from TestFlight (Internal Testing → add yourself). TestFlight builds use Apple's **production** push service, which is what your production key covers. Check:

- Open the app, sign in, Settings → Notifications → turn push on → **Send me a test notification** arrives
- Someone praying for your request, or a verse you send to another account, gives a notification; tapping it opens the right screen
- Community: post, pray, report, block, unblock (Settings → Account → Community)
- Add the widget; the Verse of the Day reminder; Settings → Account → export and (on a spare account) delete
- Switch the Bible version in the reader; search; Original words; Send to someone

### 6. App information **(you)**: App Store Connect → your app

- **App Information:** Category Primary **Books** (the project already says so); Secondary optional (Reference). Content rights: "Does your app contain, show or access third-party content?" → **Yes**, you have the rights: the Bible texts are public domain or openly licensed, and the Strong's dictionaries are CC BY-SA, credited in the app (Original words screen) and in `docs/CREDITS.md`.
- **Pricing and Availability:** Free; all countries.
- **App Privacy:** Privacy Policy URL `https://biblewish.com/privacy.html`; then answer the questionnaire exactly as in "Privacy answers" below.
- **Age Rating:** answer the questionnaire honestly (see "Age rating" below).

### 7. Version 2.0 page **(you)**: App Store Connect → iOS App → the 2.0 version

1. **Screenshots:** each device tab accepts only its own size, so use the matching folder in `AppStore/Screenshots/`:
   - tab **iPhone with Dynamic Island (medium display)** (6.1"/6.3", the one App Store Connect shows first): `iPhone-6.3in/` (1206 × 2622), files 1 to 9;
   - tab **iPad 13" display**: `iPad-13in/` (2064 × 2752), files 1 to 6;
   - `iPhone-6.9in/` (1320 × 2868) is for the 6.9" slot (View All Sizes in Media Manager); it is optional, because Apple scales the screenshots down.
   Uploading a size to the wrong tab gives "File dimensions are invalid".
2. **Promotional text, Description, Keywords, What's New:** paste from "Listing text" below.
3. **Support URL** `https://biblewish.com/about.html`; **Marketing URL** `https://biblewish.com`.
4. **Copyright:** `2026 Sysware` (or your name).
5. **Build:** choose the build you uploaded (2.0 (3)).
6. **App Review Information:** contact first name, last name, phone, email (`sysware@sysware.com.br`). **Sign-in required: yes**: user name and password from `AppStore/review-login.txt` (step 3). Paste the notes from "Notes for App Review".
7. **Version Release:** "Manually release this version" lets you pick the day once it is approved; "Automatically" releases right after approval.
8. **Add for Review → Submit for Review.**

Review usually takes about a day or two. You get an email at each step.

## Listing text

**Name** (30): `BibleWish` · **Subtitle** (30): `Read, pray and study freely` (27)

**Promotional text** (170, editable without a new build, 165 used):

> Read the Bible without distraction. A verse every day, reading plans, notes, search, a prayer community and an Original-words study. Free, no ads, no account needed.

**Keywords** (100, 97 used): `bible,verse of the day,scripture,devotional,reading plan,KJV,prayer,study,widget,biblia,christian`

**Description:**

```
BibleWish is a free Bible app made as a gift. There are no ads and no subscriptions, and you never need an account: everything works on your device. If you like, sign in with just your email to keep your notes, progress and prayers in step with biblewish.com and to join the community.

READ
• A book-style reader: a serif page, a gold frame and an illuminated first letter
• The words of Jesus in red, only the words he spoke
• Switch between King James, World English Bible, Biblia Livre (Portuguese) and a Hebrew Bible in one tap, staying on the same verse
• Tap a verse to select it, press and hold to select a passage, then save, write a note, make a picture, send it, copy or share
• Focus mode, reading time, adjustable text, and Dark, Sepia and Light themes

FIND
• Search every word, in any translation, in a moment: "quotes" for a phrase, love* for word starts, filter by book
• Choose a book the way biblewish.com does: ten colored sections, recent chapters, or just type John 3:16

STUDY
• Original words: each word of a verse with the Hebrew or Greek behind it and Strong's dictionary entry
• Cross-references for every verse, and the places named in each chapter on a map, with the journeys of Abraham, the Exodus, Jesus and Paul
• Notes with tags, light formatting and a toolbar; verse references open the passage
• Favorites, four highlight colors, and a private prayer list with a place to record how a prayer was answered

EVERY DAY
• A verse of the day on your Home screen, with the same verses as biblewish.com
• Reading plans: the Bible in a year, the New Testament in 90 days, the Gospels, Psalms and Proverbs, with progress and streaks that encourage rather than shame
• Optional notifications: your daily reading reminder, and a note when someone prays for you
• A Home Screen and Lock Screen widget

TOGETHER (optional, with a free account)
• Share a prayer request, pray for others, encourage them, and rejoice when a prayer is answered
• Send a verse to someone with a private link
• A friendly reading leaderboard you can turn off, and achievements that celebrate faithfulness
• Report anything inappropriate and block any member. Community guidelines: biblewish.com/terms.html

"Freely you have received; freely give." (Matthew 10:8)

BibleWish is open source. The code, the reading plans and the privacy policy are on GitHub. Privacy: biblewish.com/privacy.html
```

(2,391 of 4,000 characters)

**What's New in 2.0:**

```
A new BibleWish, matching biblewish.com.

• A new reader with select-and-act: save, note, picture, send, copy or share any verse
• Switch Bible versions from the reader, staying on the same verse
• Fast search in every translation, and a new way to choose a book
• Original words: the Hebrew and Greek behind every verse
• Community: share prayer requests, pray and encourage, with report and block
• Reading leaderboard, notifications and a weekly recap
• Sepia and Light themes, reading plans, notes with a formatting toolbar, and a Home Screen widget
• Larger text, VoiceOver support and better contrast
```

## Privacy answers (App Store Connect → App Privacy)

"Do you or your third-party partners collect data from this app?" → **Yes.** Nothing is used for tracking (answer **No** to "Data used to track you"), there are no third-party partners or SDKs. For each type below: **linked to the user: Yes · used for tracking: No · purpose: App Functionality**.

| Category → type | What it is |
|---|---|
| Contact Info → **Email Address** | the sign-in address; an optional recipient address when sending a verse |
| Contact Info → **Name** | the display name shown with prayers and on the leaderboard |
| Location → **Coarse Location** | only the country you choose in Settings → Account → Community, to show its flag (not your device's location) |
| User Content → **Other User Content** | notes, highlights, favorites, prayers, community posts and encouragement, messages sent with a verse |
| Identifiers → **User ID** | the account number |
| Identifiers → **Device ID** | this phone's push token, only if you turn on notifications |
| Usage Data → **Product Interaction** | reading progress and plans (chapters read), for sync and the leaderboard |

This matches `NSPrivacyCollectedDataTypes` in `BibleWish/PrivacyInfo.xcprivacy`, row for row; keep the two in step. The app never uploads a profile picture (it only shows ones added on the website), so there is no Photos row. Apple's categories are the closest fit I could find, not legal advice: if you are unsure about one, declaring it is the safe side.

## Age rating (App Store Connect → Age Rating)

Answer the questionnaire honestly. For this app: no violence, sexual content, profanity, horror, gambling, drugs or medical content **of its own**; no unrestricted web access; no purchases; no ads. Two things need thought:

- **The Bible text** has passages that describe violence and mature themes. Answer "Infrequent/Mild" where Apple asks about those themes, as other Bible apps do.
- **User-generated content:** the prayer wall shows posts from other people, so answer **Yes** to user-generated content and describe the safeguards (report, block, moderator, guidelines). Apple will raise the rating (expect 12+ or 13+).

## Notes for App Review (paste into "Notes")

```
BibleWish is a free Bible reader. No account is needed to read, search, study or use reading plans; everything works offline.

SIGNING IN (optional): Settings (the gear on the Home screen) → Account → Sign in. Use the demo account from the fields above: enter the email, then the six digits in place of the emailed code. (Normal users get the code by email; this demo account has a fixed code so you can test.) With the demo account you can test the Community tab, sync, "Send to someone", and Settings → Account → export my data / delete account.

COMMUNITY (user-generated content): Community tab → prayer wall. Every request and reply has a ⋯ menu with Report (four reasons) and Block this member; community guidelines are shown where you post and at the bottom of the wall; the moderator (sysware@sysware.com.br) is emailed every report and can remove content, and a post reported by three members is hidden until reviewed. Settings → Account → Community lists blocked members and can undo it. Anonymous posts hide the author from other members; blocking still works on them.

NOTIFICATIONS: push notifications are optional (Settings → Notifications). They tell you when someone prays for you or encourages you, and send your reading reminder and weekly recap. The daily-verse reminder (Settings → Daily Verse) is created on the device.

OTHER: The Verse of the Day widget is added from the widget gallery. The Bible maps use Apple Maps and need a connection; everything else works offline. The Bible texts are public domain or openly licensed (King James Version, World English Bible, Biblia Livre, Hebrew Bible). Original words uses Strong's dictionaries (CC BY-SA, credited on that screen). No tracking, no ads, no third-party SDKs.
```

## Guidelines this app is built to meet

| Guideline | How |
|---|---|
| 1.2 User-generated content | Report + block + guidelines + moderator contact + auto-hide after 3 reports |
| 2.1 Demo account | Fixed-code review account (`docs/APP_REVIEW.md` on the website repo) |
| 4.2 Minimum functionality | A full reader, search, plans, study tools, widget: not a website wrapper |
| 5.1.1 Data collection | Sign-in optional; policy URL; labels filled in; no tracking |
| 5.1.1(v) Account deletion | Settings → Account → Delete account (and export) |
| 5.1.2 / 4.8 | No third-party or social login, so Sign in with Apple is not required; email-code sign-in is the app's own |
| 3.1 Payments | None: free, no purchases |
| 2.5.4 Background / push | Push is optional and only for the events listed |

## After approval

- The version goes live (or waits for you, if you chose manual release). Watch App Store Connect → TestFlight → crashes, and reports at sysware@sysware.com.br.
- Keep the `review` line in `config.php` for future updates (each update is reviewed again) or delete it between releases.
- To change the listing text later without a new build: edit **Promotional text** any time; everything else needs a new version.
