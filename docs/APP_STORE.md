# App Store listing — draft

Draft copy for the next release. Edit freely; limits are Apple's (name 30, subtitle 30, promotional text 170, keywords 100, description 4000, what's new 4000 characters).

## Name and subtitle

- **Name:** BibleWish
- **Subtitle:** A daily verse and quiet reading *(29)*

## Promotional text *(≤170; can change without a new build)*

Read the Bible without distraction. A verse for every day, reading plans, notes and maps, free for everyone: no ads, no accounts, no subscriptions.

## Description

BibleWish is a free Bible app made as a gift. There are no ads, no subscriptions and no accounts. Everything stays on your device.

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
• Save favorite verses and highlight in five colors
• Write notes with tags (Insight, Question, Prayer, Sermon, Promise), light formatting, and verse references that open the passage
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

Answer **Data Not Collected**. The app does not collect or send any data. Notifications are scheduled locally, and the widget only shares the chosen translation with the app on the device. If Phase 4 (accounts and sync) is ever added, this changes: update the label and `PRIVACY.md` first.

## Notes for App Review

- No account is needed; everything works offline.
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

- [ ] Register the App Group and the widget's App ID (see `WIDGET.md`) and archive with signing
- [ ] Bump the version/build for **both** the app and the widget (they must match)
- [ ] Try the flows the automated checks couldn't: start a plan, tick chapters, save and edit a note, long-press a verse, turn on the reminder, add the widget
- [ ] Check iPad if iPad stays enabled (the layouts haven't been looked at)
- [ ] VoiceOver walkthrough on a device
