# Verse of the Day widget

A WidgetKit extension (`BibleWishWidget/`, target `BibleWishWidgetExtension`) with the same daily verse as the app and the website, in small, medium and large home-screen sizes and lock-screen rectangular and inline.

## How it works

- **Verses:** the widget carries its own copy of the website's verse files (`BibleWishWidget/Data/votd`, 216 KB: the reference list plus the text of every day in KJV, WEB, Biblia Livre and Hebrew). It never needs the app's Bible files or the network. `VerseLibrary.swift` picks the day (29 February has its own verse, as everywhere else).
- **Translation:** the app writes the reader's translation to the shared App Group (`SharedConfig.translationKey`) whenever it changes and asks WidgetKit to reload. If the group isn't available, the widget shows KJV.
- **Timeline:** one entry per day for the next week, each changing at midnight.
- **Look:** `Shared/VerseWidgetViews.swift` is plain SwiftUI, compiled into the app and the widget, so it can be rendered in the app for checking.

## One-time setup in your Apple Developer account

Automatic signing in Xcode normally does this for you when you build with team `3FG6EV356S`, but if it complains:

1. Register the **App Group** `group.Sysware.BibleWish`.
2. Register the App ID `Sysware.BibleWish.Widget` and enable the App Groups capability on it and on `Sysware.BibleWish`.
3. Build the `BibleWish` scheme; the widget is embedded in the app (PlugIns).

The widget and the app must share the same marketing version and build number (both targets read them from the project settings; change them together).

## Regenerating the data

```sh
python3 -I tools/build_votd.py        # also refreshes BibleWishWidget/Data/votd
```
