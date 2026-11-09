# SayTV: a voice remote for Android TV and Google TV

A phone app (Android and iPhone, one Flutter code base) that controls a TV that runs Android TV or Google TV over Wi-Fi: open streaming apps,
set the volume, play and pause, move around the screen, and do all of it by speaking a fixed phrase ("open Netflix", "volume 30", "mute").
You choose which apps appear, and what you call them.

It talks to the TV's own remote service, the protocol Google's own remote apps use. It does **not** work with Fire TV, Roku, Samsung, LG or
Apple TV. It has no accounts, no servers, no ads and no analytics. Protocol notes and everything measured on a real TV: [`NOTES.md`](NOTES.md).

**Status: 1.0.0 candidate, not published.** What has and has not been tried is listed at the bottom.

## Layout
| Folder | What it is |
|---|---|
| `core/` | Pure Dart package `tv_remote_core`: the protocol (pairing, remote connection, keys), the spoken-phrase parser, the app list model, TV discovery. Unit tests, and a PC command-line tool (`bin/tvcli.dart`). |
| `app/` | The Flutter app: setup and pairing, the remote screen, microphone button, typed-command box, app-list editor. |
| `spec/` | `apps.json` (default apps and the names they answer to), `catalog.json` (suggested apps), `phrases.json` (what each spoken phrase must do). Tests read them; `app/assets/` holds exact copies. |
| `docs/` | The app's public web page and [privacy policy](https://saurprince.github.io/saytv/privacy-policy.html), served by GitHub Pages. |
| `store/` | Store listing text, answers for the store forms, release checklist, icon and screenshots. Start with [`store/release-checklist.md`](store/release-checklist.md). |
| `scripts/` | Windows helper scripts: checks, release build, upload-key creation, icon and screenshot generators (default paths follow the author's PC; environment variables in the script headers override them). |
| `pc-client/` | The first Python client used to prove the protocol on a TV, plus `tv_tests.py` (the TV test suite). |
| `.github/workflows/` | CI (analyze, test, iPhone build compiles) and a manual "iOS to TestFlight" job. |

## Building and testing on Windows
Flutter must live in a folder **without spaces** (a space in the path breaks Flutter's build-hook runner), and so should the project: a junction
does that without moving files (`mklink /J C:\dev\tvvoice "<path to this folder>"`).

```powershell
$env:PATH = "C:\dev\flutter\bin;C:\dev\flutter\bin\cache\dart-sdk\bin;" + $env:PATH
$env:PUB_CACHE = "C:\dev\pub-cache"
scripts\check.ps1              # core: analyze + 63 tests; app: analyze + 17 tests
scripts\build-release.ps1      # signed APK and app bundle (needs the upload key, see store/release-checklist.md)
```
Gradle needs Java's loopback networking, so run the build in a normal terminal, not in a restricted shell.

Try the shared code against a real TV from the PC (the TV shows a 6-character code when you pair):

```powershell
cd core
dart run bin/tvcli.dart scan
dart run bin/tvcli.dart pair   192.168.1.20
dart run bin/tvcli.dart say    192.168.1.20 "set volume to 30"
```

## iPhone builds
An iPhone app can only be built on macOS: here that is a GitHub Actions macOS runner (`.github/workflows/`). Signing uses the publisher's own
Apple Developer account through an App Store Connect API key kept in a GitHub environment; nothing secret is in this repository.
The iPhone cannot act as a Bluetooth remote, so the iPhone app is Wi-Fi only.

## What has been tried
- Core on a PC against a real TV: scan, pairing with a generated key, state, exact volume, mute, spoken phrases, opening apps.
- The signed Android release APK in an emulator against that TV: pairing with the on-screen code, typed commands, mute, app buttons, Home, D-pad,
  reconnecting after a restart, and the app-list editor.
- Not yet: speech recognition and "Search my network" on a real phone, the iPhone app running anywhere, TVs other than the test TV, standby.

## Licence
Apache-2.0 (see `LICENSE`, `NOTICE`). The name "SayTV" and its icon are the publisher's trademarks and are not covered by the code licence.
Protocol credit: message layouts follow the open-source `androidtvremote2` project (Apache-2.0).
