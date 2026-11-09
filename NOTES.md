# Notes: controlling an Android TV over Wi-Fi (Android TV Remote v2)

Status: tested from a Windows PC against one Android 11 TV with 2 GB of RAM (2026-11-08), and from the Android app in an emulator against
the same TV (2026-11-09). Other TVs have not been tried: results below are about that one TV.
Do not publish anything from `pc-client/client/` (the pairing key), a TV's mDNS name or Bluetooth address, or any screenshot of a TV.

## What the TV offers
- TCP 6467: pairing (TLS, client certificate, 6-character hexadecimal code shown on the TV).
- TCP 6466: remote (TLS with the same client certificate). Messages are protobuf with a varint length prefix.
- Both belong to `com.google.android.tv.remote.service`, the service Google's own Google TV / Android TV Remote apps use.
- The Bluetooth remote, the IR remote and this Wi-Fi remote are separate paths. The TV does not answer on Wi-Fi in standby (power-on stays on IR).

## Test results (all on this TV, all from the PC client `pc-client/atvremote.py` and `pc-client/tv_tests.py`)
| Need | Result |
|---|---|
| Pair with the on-screen code | worked |
| Read state (model, volume 0-100, muted, screen on) | worked |
| Keep one connection open | worked: 150 s, 29 pings answered, commands accepted after the idle |
| Live volume updates | the TV pushes the new level 0.07 to 0.45 s after a change |
| Set the volume to an exact number | worked: send the needed number of presses back to back (60 ms apart), 14 presses in 2.4 s, 18 in 2.7 s, landed exactly (62 and 30, back to 48) |
| Audio mute (key 164) | worked: level reads 0 and muted=true; second press restores it |
| D-pad arrows, OK, Back, Menu, Home | each key left the TV's virtual remote as the matching Linux key (kernel evidence via `getevent`) |
| Media keys: play/pause, play, pause, stop, next, previous, rewind, fast-forward | each left the virtual remote correctly; effect on a real player not tested (nothing was played) |
| Channel up/down | left the virtual remote correctly |
| Settings key (176) | emitted as `KEY_OPTION`; did NOT open the Settings app |
| Input keys: TV_INPUT 178, HDMI_1..4 (243-246) | NOT injectable: no kernel event at all |
| HDMI input by link (`content://android.media.tv/passthrough/...`) | no: opens Android's "Open with" chooser (same from adb) |
| `intent:` link | no: the TV drops the connection |
| Source picker | opens from adb: `am start -n com.android.tv/.SelectInputActivity`; it lists ATV, ANTENNA, CABLE, HDMI GAME, HDMI2, HDMI3, AV, Zee 5, and arrow keys + OK over the remote could pick one |
| Open an app by link `market://launch?id=<package>` | worked for 11 of 12 installed apps (2.4 to 9.5 s until the app was in front); the launcher `com.gathin.tvhome` handles `market://launch` itself |
| Jio on-demand app (`com.jio.media.stb.ondemand`) | failed: it has no launchable screen; keep only launchable apps in the list |
| Wake from the clock screensaver | HOME works (goes to the launcher); the WAKEUP key (224) does nothing |
| Find the TV: mDNS `_androidtvremote2._tcp` | the TV announces it (service on port 6466, TXT carries its Bluetooth address); it answered a direct query but not my multicast query on this PC (Windows network profile "Public" may be why) |
| Find the TV: scan the subnet for port 6466 | worked: 2.5 s, found only the TV |

## Apps tested (package, all launch with `market://launch?id=<package>`)
Netflix `com.netflix.ninja`; Prime Video `com.amazon.amazonvideo.livingroom`; Apple TV `com.apple.atve.androidtv.appletv`;
YouTube `com.google.android.youtube.tv`; JioHotstar `in.startv.hotstar`; SonyLIV `com.sonyliv`; ZEE5 `com.graymatrix.did`;
JioTV `com.jio.jioplay.tv`; TVF Play `com.tvf.tvfplay.tv`; Spotify `com.spotify.tv.android`; MX Player `com.mxtech.videoplayer.television`.

## Things that went wrong, and the fixes
- **A key sent right after connecting is dropped.** The TV creates a virtual input device per client and its vendor key layer registers it about
  0.15 s later (log: `KCR-KeyConverter ... not found keycode!`). Wait about 1.5 s after the handshake, and keep one connection open.
- **Launching an app while the screensaver is showing starts it behind the screensaver.** Send HOME first, then the link.
- **`MUTE` (91) is the microphone mute key.** Audio mute is `VOLUME_MUTE` (164).
- **Netflix blocks screenshots** (the capture comes back empty).

## The Android app, end to end (test emulator -> real TV, 2026-11-09)
Debug build installed in a throwaway Android 14 emulator on the PC, talking to the real TV over the home Wi-Fi:
- **Pairing:** typed the TV's address, the TV showed "Device pairing request" with a 6-character code, typed it into the app, status went to "Connected".
- **Typed commands:** `volume 40` -> the TV's music stream read 40 and the app's slider followed; `volume 48` restored it; `open netflix` -> Netflix had focus.
- **Mute button:** tap -> muted (stream reads 0), second tap -> unmuted at the previous level (40).
- **App chip and Home:** YouTube chip -> YouTube had focus; Home button -> the home screen (`com.gathin.tvhome`) had focus.
- **D-pad:** Right moved the highlight on the home screen from Netflix to Prime Video; Left was tapped to move it back.
- **Remembered pairing:** force-stopping and relaunching the app reconnected by itself, no new pairing.
- Before any key was sent the foreground app and media sessions were checked; nothing was playing, and the media Play key was not pressed
  (a paused music session exists, and Play would have started it).
- The emulator is NAT-ed, so "Search my network" (subnet scan and mDNS) could not be checked there; it needs a real phone on the Wi-Fi.

### Release build, same night (signed release APK and bundle, `com.visswaverse.voiceremote`)
- Paired again with the release build and repeated: typed command `open netflix` -> Netflix in front; Home button -> home screen; the app-list editor
  (add, suggestions, edit, remove with undo); naming the TV ("Connected to Living room"); dark theme.
- **The TV in standby:** it went to standby on its own twice during the session (it is set to sleep after 30 minutes). In standby every port was closed:
  6466 and 6467 (remote), 5555 (adb) and ping all failed, so no Wi-Fi remote can wake it. The app handled it as designed: while pairing it showed
  "Could not reach the TV ... Connection timed out"; when already paired it showed "The TV is not reachable. It may be off: switch it on with its own
  remote" with a Retry button, and the buttons stayed visible. Whether the app reconnects by itself when a paired TV comes back (it retries
  every 2, 4, 8, then 15 seconds) was not observed tonight: still to check.
- The TV's sleep timer is `settings secure sleep_timeout` (30 minutes by default). Raising it to 6 hours did NOT stop the TV going to standby about
  30 minutes later, so another setting (probably the TV maker's own auto-standby) is what turns it off; not yet found.
- Two build faults found and fixed (see `scripts/build-release.ps1`): a second Flutter asset step in the same build folder leaves the asset folder empty
  (the app then hangs on its loading spinner), and `flutter build appbundle` fails here. `scripts/verify-release.ps1` checks the finished files.
- The app also now starts, and shows the pairing screen, when stored data cannot be read (before, it hung on the spinner).

## Not tested yet
- The standby key (POWER 26 / SLEEP 223): what it does, and whether the TV still answers on Wi-Fi afterwards (needs you at the TV with the IR remote).
- Text entry, long key presses, and how the connection behaves when the TV is switched off at the wall or Wi-Fi drops mid-session.
- On a real phone: speech recognition, "Search my network", the media-key row, and the app being sent to the background and back.
- The iPhone app in any form (needs macOS and the publisher's Apple Developer account), Siri/Assistant shortcuts, local-network permission on iPhone, an Android Bluetooth fallback.

## Message layouts used (from the open-source androidtvremote2 project, Apache-2.0)
Pairing: protocol_version 2, status 200; request (10) -> ack (11); options (20) hex x 6, role input; configuration (30) -> ack (31);
secret (40) = SHA-256(client modulus, client exponent, server modulus, server exponent, last 4 hex characters of the code as 2 bytes),
first byte must equal the first 2 hex characters of the code; ack (41).
Remote: TV sends configure (1) with features; reply with features & 611; set_active (2) echo; start (40); ping (8) -> response (9);
key inject (10) = {key code, direction 3}; app link (90); volume info (50) = {max 6, level 7, muted 8}.
