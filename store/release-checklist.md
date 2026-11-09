# SayTV release checklist

Legend: **[done]** finished and checked here. **[you]** needs you (an account, a legal declaration, a device). **[say go]** I can do it in the signed-in browser once you say go; I will not create records, accept terms, upload or submit without that.

## First thing tomorrow (about 15 minutes of yours)
1. **Back up** `Documents/Nokia TV/saytv-signing/` to two places off this PC.
2. **Apple Account Holder: accept the updated Developer Program License Agreement** in App Store Connect (nothing for iPhone can move before this).
3. **Decide public or private** for the code (recommendation: public, Apache-2.0; the licence files are already in the project). The project is committed locally
   (one commit, no remote). Putting it on GitHub was refused by this session's safety check, so it is not uploaded. To upload it privately, run in the project folder:
   `gh repo create saurprince/saytv --private --source . --remote origin --push`
   Pushing starts the CI: the first time the iPhone app is compiled anywhere (it may need fixes). To make it public later: `gh repo edit saurprince/saytv --visibility public --accept-visibility-change-consequences`.
4. **Tell me "go"** for the Play Console and App Store Connect steps marked [say go] below. I will stop at each legal declaration for you to tick.
5. Optional: record a 30-second video of the app controlling your TV (needed for App Review, see `review-notes.md`).

## Status
| Area | State |
|---|---|
| App code: voice phrases, remote, editable app list, rename TV, About | [done] 63 core tests + 17 app tests pass |
| Name, ids, icon, feature graphic, privacy policy, listing text, form answers | [done] drafts in `store/` |
| Android release build, signed with the upload key | [done] see "Build outputs" |
| Android screenshots | [done] `store/screenshots/play/` |
| App Store screenshots | [done] captioned, from the same captures (`store/screenshots/appstore/`); real iPhone captures can replace them later |
| iPhone build and TestFlight | workflows written, **never run**: the code is not on GitHub yet (see "First thing tomorrow") and TestFlight also needs the Apple steps below. The iPhone app has not been compiled or run anywhere yet |
| Real-phone testing (speech, "Search my network") | [you] first on your iPhone through TestFlight |

## Decisions that are yours
1. **Name.** Working name SayTV; store title "SayTV: Voice Remote for OTT". Changing the display name later is cheap (`app/lib/branding.dart`, `res/values/strings.xml`, `ios/Runner/Info.plist`, then `python scripts/make-store-graphics.py`). The app id is not: `com.visswaverse.voiceremote` is permanent once published on either store.
2. **Public or private repository, and the licence** (see "Repository" below).
3. **Where the privacy policy lives** (see "Privacy policy page").
4. **Target audience 18+** and the **data-safety reading** (`data-safety-and-privacy-labels.md`).
5. **Encryption export declaration** for Apple: yours to make (`data-safety-and-privacy-labels.md`).
6. **Copyright line**: the listing uses "2026 VISHWAVERSE LLP".

## Android / Google Play
1. **[you] Back up the signing folder** `Documents/Nokia TV/saytv-signing/` (the upload key, its random password file and `key.properties`) in two places that are not this PC. Never commit or share it. If it is lost, Google can reset the upload key, but only through a support request.
2. **[say go]** Play Console > Create app (App, Free, English). Accept the declarations: that is a legal step, so you will be asked.
3. **[say go]** App content: privacy policy URL, ads = No, app access = all functionality available without login (add the review notes), Data safety, content rating, target audience (18+), news/government/financial/health = No.
4. **[say go]** Store listing: text from `listing.md`, icon `store/art/play-icon-512.png`, feature graphic `store/art/play-feature-1024x500.png`, phone screenshots from `store/screenshots/play/`.
5. **[say go]** Testing > Internal testing: upload `app-release.aab`, add your email as a tester, open the test link on a phone. (You have no Android phone: the same build can be installed on an emulator.)
6. **[you or say go]** Production: create the release from the tested bundle, choose countries, send for review. Organization accounts have no tester waiting period.
7. The Play Console banner "Declare your trader status by 1 February 2027" is an account-level EU declaration: yours.
8. Every later upload needs a higher build number (`version: 1.0.0+N` in `app/pubspec.yaml`).

## iPhone / App Store
1. **[you] Account Holder: accept the updated Apple Developer Program License Agreement** (App Store Connect shows the banner; new apps cannot be submitted until it is accepted).
2. **[say go]** developer.apple.com > Identifiers: register `com.visswaverse.voiceremote` (no special capabilities needed).
3. **[say go]** App Store Connect > Apps > New App: iOS, name, English, that bundle id, SKU `saytv-001`.
4. **[you]** App Store Connect > Users and Access > Integrations > API: create a key with the App Manager role (download the `.p8` once). Put its Key ID, Issuer ID and the `.p8` contents (base64) into the GitHub environment as described at the top of `.github/workflows/ios-testflight.yml`. Do not paste them into a chat.
5. **[you]** Run the "iOS to TestFlight" workflow (Actions tab, Run workflow). The first run is likely to need fixes: it has never run.
6. **[you]** TestFlight: add yourself as an internal tester, install on your iPhone, and try pairing, the Local Network prompt, the microphone and speech recognition, and leaving and returning to the app.
7. **[say go]** Fill the listing from `listing.md`, upload `store/screenshots/appstore/`, answer the privacy and export questions, attach the demo video, select the build and submit.

## Repository (decision)
- **Recommendation: public, Apache-2.0, in a new repository separate from the TV-fixes one.** Reasons: the app uses the microphone, the local network and a pairing key, so readable code builds trust; GitHub's macOS build minutes (needed for iPhone builds) are free for public repositories but limited on private ones; nothing in it is proprietary. The reference protocol project (androidtvremote2) is Apache-2.0 too.
- Keep the **name and icon** as the publisher's trademarks (say so in the README); the code licence does not grant those.
- Secrets never go in the repository: signing keys live outside the project; Apple keys live in a GitHub environment that needs your approval to use. The iOS workflow runs only when you start it.
- **Before it goes public** (I will do this and show you the result): scrub `NOTES.md` and `pc-client/` of anything tied to your TV (model and device names, addresses, hardware ids, Wi-Fi names), check no key or certificate file is present, add `LICENSE` and a README note.
- Choose the owner (your personal GitHub account, like the TV-fixes repository, or an organization) and the copyright holder in the LICENSE (you or VISHWAVERSE LLP).

## Privacy policy page
The stores need a public URL. Your website was not changed. Options:
- **A. A page on visswaverse.com** that you add yourself (paste the body of `store/privacy-policy.html`): for example `https://visswaverse.com/saytv-privacy`. Best for trust: same company domain.
- **B. GitHub Pages** from a public repository: `https://<owner>.github.io/<repo>/privacy-policy.html`. No change to your website.
- Either way, put the final URL into: both store consoles, `review-notes.md`, and (optionally) the About screen.

## Build outputs
- Folder: `Documents/Nokia TV/saytv-release-1.0.0/` holds `SayTV-1.0.0-release.aab` (upload this to Play), `SayTV-1.0.0-release.apk` (to try on a device or emulator) and `SHA256.txt`. Both were signed with the upload key and passed `scripts/verify-release.ps1` (assets present, package, version, target SDK 36, 16 KB alignment, upload-key signature).
- Rebuild: run `scripts/build-release.ps1` in a normal terminal (Gradle cannot run inside the assistant's restricted shell). It builds the APK and the bundle in two separate clean builds and copies them to the folder above only if the checker passes (about 15 minutes).
- Do not "fix" the script by building the bundle with `flutter build appbundle`, or both files in one build folder: on this PC that produced files without their app assets (the app hangs on its loading spinner). The checker exists to catch exactly that.
- Checks that need no Gradle: `scripts/check.ps1`.
