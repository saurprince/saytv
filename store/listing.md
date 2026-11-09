# Store listing text (SayTV)

Drafts for both stores. Every field below has its store limit in brackets; check the lengths with `python store/check-listing.py`.
Publisher details come from the VisswaVerse website (public footer): VISHWAVERSE LLP, Pune, Maharashtra, India; support@visswaverse.com.

## Shared
| Field | Value |
|---|---|
| App name / title [30] | SayTV: Voice Remote for OTT |
| Category | Play: Tools. App Store: Utilities (secondary: Entertainment) |
| Price | Free. No ads, no in-app purchases |
| Support email | support@visswaverse.com |
| Support URL (App Store needs one) | https://saurprince.github.io/saytv/ (the app's page on GitHub Pages: support email, privacy link, issue tracker; source `docs/index.html`) |
| Privacy policy URL | https://saurprince.github.io/saytv/privacy-policy.html (GitHub Pages; source `docs/privacy-policy.html`) |
| Copyright (App Store) | 2026 VISHWAVERSE LLP |
| Target audience (Play) | 18 and over, to match the publisher's own policy. The app collects nothing and is not aimed at children |
| What's new, first release [4000 / 4000] | First release. Say "open Netflix", "volume 30", "mute", "pause". Edit your app list. Works with TVs that run Android TV or Google TV. |

## Google Play
**Short description [80]**
Voice remote for Android TV and Google TV. Say it and your TV does it.

**Full description [4000]**
SayTV turns your phone into a voice remote for your TV. Tap the microphone and say what you want: "open Netflix", "volume 30", "mute", "pause", "go home". The TV does it.

SAY IT
- Open apps by name: "open YouTube", "launch Prime Video", "go to Hotstar"
- Set the volume exactly ("volume 40") or nudge it ("volume up", "quieter"), mute and unmute
- Control playback and menus: "pause", "resume", "next", "rewind", "back", "home", "select"
- Put the TV in standby: "turn off"
You can also type any command instead of speaking it.

THE FULL REMOTE, TOO
Direction pad, OK, Back, Home and Menu, playback keys, a volume slider and mute, and one-tap buttons for your apps.

YOUR APPS, YOUR WAY
Add the streaming and music apps you use, remove the ones you do not, rename them and put them in your order. Suggestions are one tap away, and any app installed on your TV can be added with its package name.

PRIVATE BY DESIGN
No account. No ads. No analytics. No tracking. SayTV talks to your TV directly over your home Wi-Fi with an encrypted connection and keeps its pairing key in your phone's secure storage. Your phone's own speech recognition turns your voice into text and may send the audio to Google, under Google's policies; SayTV never receives your audio.

GOOD TO KNOW
- Works with TVs and streaming boxes that run Android TV or Google TV. It does not work with Fire TV, Roku, Samsung, LG or Apple TV.
- Your phone and TV must be on the same Wi-Fi network. Pairing takes one six-character code shown on the TV.
- Spoken commands are fixed phrases, so they are quick and predictable. Phrases are in English.
- A TV in standby usually cannot be switched on over Wi-Fi. Use the TV's own remote for that.
- If an app button does nothing, check that the app is installed on the TV and that the package name in Edit apps is right.

SayTV is an independent app. It is not affiliated with or endorsed by Google or by any TV or streaming brand. Names of apps and companies are trademarks of their owners.

## App Store
**Subtitle [30]**
Voice TV remote for OTT apps

**Promotional text [170]**
Say "open Netflix" or "volume 30" and your TV does it. A private voice remote for TVs that run Android TV or Google TV.

**Description [4000]**
Use the Google Play description above, with "Google" replaced by "Apple" in the PRIVATE BY DESIGN paragraph ("...may send the audio to Apple, under Apple's policies...").

**Keywords [100, comma-separated, no spaces after commas, none of the words above repeated]**
tv remote,voice,remote control,smart tv,streaming,ott,volume,hands free,speak,television,clicker

(Brand names and other companies' trademarks are deliberately not used as keywords; Apple rejects that.)

**Age rating questionnaire**: answer "None" to every content question. No user-generated content, no web browsing, no gambling, no unrestricted web access.

**App Review notes**: see `review-notes.md`.

## Screenshots
- Play: `store/screenshots/play/*.png` (phone, 1080x1920) plus `store/art/play-feature-1024x500.png` and `store/art/play-icon-512.png`.
- App Store: `store/screenshots/appstore/*.png` (1290x2796 and 1320x2868, captioned). Real iPhone-simulator captures can replace them from the iOS CI job.
