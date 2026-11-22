# App Store listing — draft

Draft copy for the next release. Edit freely; limits are Apple's (name 30, subtitle 30, promotional text 170, keywords 100, description 4000, what's new 4000 characters).

## Name and subtitle

- **Name:** BibleWish
- **Subtitle:** Daily verse & quiet reading *(27)*

## Promotional text *(≤170; can change without a new build)*

Read the Bible without distraction. A verse for every day, reading plans, notes and maps, free for everyone: no ads, no subscriptions, no account needed.

## Description

BibleWish is a free Bible app made as a gift. There are no ads and no subscriptions, and you never need an account: everything works on your device. If you like, sign in with just your email to keep your notes, progress and prayers in step with biblewish.com.

READ
• A book-style reader: a serif page, a gold frame and an illuminated first letter
• The words of Jesus in red, only the words he spoke, not the whole verse
• Focus mode, reading time, adjustable text, and Dark, Sepia and Light themes
• King James Version, World English Bible, Biblia Livre (Portuguese) and a Hebrew Bible

EVERY DAY
• A verse of the day on your Home screen, with the same verses as biblewish.com
• An optional daily reminder, at the time you choose
• A Home Screen and Lock Screen widget

STAY ON TRACK
• Reading plans: the Bible in a year, the New Testament in 90 days, the Gospels, Psalms and Proverbs
• Progress through every book, and streaks that encourage rather than shame
• Achievements that celebrate faithfulness. Nothing is ranked or compared

STUDY
• Save favorite verses and highlight in four colors
• Write notes with tags (Insight, Question, Prayer, Sermon, Promise), light formatting, and verse references that open the passage
• A private prayer list, with a place to write down how a prayer was answered
• Cross-references for every verse
• Places named in each chapter, and the journeys of Abraham, the Exodus, Jesus and Paul on a map

"Freely you have received; freely give." (Matthew 10:8)

BibleWish is open source. The code, the plans and the privacy policy are on GitHub.

## Keywords *(≤100, comma separated, no spaces)*

bible,verse of the day,scripture,devotional,reading plan,KJV,study,notes,widget,biblia,christian

## What's New (this release)

A new look, matching biblewish.com: warm Dark, Sepia and Light themes and a book-style reader.

• New Home: verse of the day, today's reading, and where you left off
• Reading plans with progress and streaks
• Study: notes with tags and formatting, cross-references, places and journey maps
• Achievements
• Words of Jesus in red, word by word
• Daily verse reminder and a Verse of the Day widget
• Larger text, VoiceOver actions in the reader, and better contrast

## Categories, rating, links

- **Primary category:** Books (the project already sets `public.app-category.books`). Reference or Lifestyle are alternatives.
- **Age rating:** answer the questionnaire honestly; the app has no user-generated content shared with others, no web access of its own, no purchases and no ads, so it should be 4+.
- **Support / marketing URL:** https://biblewish.com
- **Privacy policy URL:** the policy in this repository (`PRIVACY.md`), or a page on biblewish.com that says the same.

## App Privacy ("nutrition label")

Without signing in the app collects nothing, but the label describes the app as shipped, and signing in is a feature, so declare what it collects. All of it is **linked to the user**, used for **App Functionality** only, **not used for tracking**:

- **Contact Info → Email Address** (sign-in code, account identity)
- **Identifiers → User ID** (the account number)
- **User Content → Other User Content** (notes, highlights, favorites, private prayers)
- **Usage Data → Product Interaction** (reading progress and plan progress, i.e. saved place)

Sending a verse ("Send to someone") also transmits what the sender types, including an optional recipient email address, to biblewish.com; it is user content that the sender chooses to send, covered by the same declarations (consider whether the recipient's email address needs to be called out under Contact Info in App Store Connect). This matches `NSPrivacyCollectedDataTypes` in `BibleWish/PrivacyInfo.xcprivacy`; keep the two in step. Confirm the categories yourself in App Store Connect: they are the closest fit I could find, not legal advice. Notifications are scheduled locally and the widget only shares the chosen translation with the app on the device.

## Notes for App Review

- No account is needed; everything works offline. Signing in is optional (Settings → Account): it asks for an email, then a 6-digit code we send. For review, create an account with any address you can read. Account deletion and data export are in Settings → Account → Account.
- The daily verse reminder is off by default. Turn it on in Settings → Daily Verse (it asks for notification permission).
- The Verse of the Day widget is added from the Home Screen or Lock Screen widget gallery.
- The Bible maps use Apple Maps and need a network connection to draw the map tiles; everything else works offline.

## Screenshots to take

Use the largest iPhone size Apple asks for, in the warm Dark theme, plus one Sepia. Suggested order:

1. Reader (Matthew 5 with red letters and the gold frame)
2. Home (hero, verse of the day, today's reading)
3. Reading plans (a started plan with a streak)
4. A note with tags and a verse link
5. Journey map (Paul's first journey)
6. Achievements
7. Widget on a Home Screen (medium)

## Before submitting

- [x] Website changes for sync are deployed (see `docs/PHASE4_SERVER.md`); verified file-by-file, but the authenticated endpoints were only tested locally, not yet from a phone against production
- [ ] Push notifications: turn on the Push Notifications capability for the App ID, create the APNs key and give it to the server as described in the website repo's `docs/PUSH.md`, then try Settings → Notifications → Send me a test notification on a real iPhone (a TestFlight build too: it uses Apple's production service, Xcode builds the sandbox). The push token is declared as **Device ID** (linked to the user, app functionality, not tracking) in `PrivacyInfo.xcprivacy`; add it in App Store Connect too
- [ ] Update the App Privacy answers in App Store Connect as above (the Community adds user content that other people can see: prayers, encouragement, display name, optional country and photo)
- [ ] User-generated content (Guideline 1.2): the app has a Report on every request and reply, Block on every member (even anonymous ones), community guidelines shown where you post and in the Community settings, and a moderator who is emailed each report and can remove content. Confirm in App Store Connect's review notes how to reach the moderator (the support address in the listing) and that reports are answered within a day

- [x] Release build for a real device compiles with no errors; privacy manifests (`PrivacyInfo.xcprivacy`) added for the app and the widget (UserDefaults only, no data collected)
- [ ] Register the App Group and the widget's App ID (see `WIDGET.md`) and archive with signing
- [ ] Bump the version/build for **both** the app and the widget (they must match)
- [ ] Try the flows the automated checks couldn't: start a plan, tick chapters, save and edit a note, long-press a verse, turn on the reminder, add the widget
- [x] iPad: checked on an 11-inch iPad Pro simulator (portrait). Content is capped to a readable width and centered, and the Bible grid uses more columns. Landscape, split view and the 13-inch size haven't been looked at
- [ ] VoiceOver walkthrough on a device
