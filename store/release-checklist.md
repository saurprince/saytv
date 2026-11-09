# SayTV release checklist

Legend: **[done]** finished and checked here. **[you]** needs you (an account, a legal declaration, a device). **[say go]** I can do it in the signed-in browser once you say go; I will not create records, accept terms, upload or submit without that.

## Done on 2026-11-09
- Public repository https://github.com/saurprince/saytv (Apache-2.0), one clean commit, no personal paths or keys in it.
- GitHub Pages (from `docs/`): privacy policy https://saurprince.github.io/saytv/privacy-policy.html and support page https://saurprince.github.io/saytv/ (both answer 200).
- Apple Developer Program License Agreement accepted by the Account Holder.
- The TV's sleep timer is back to the original 30 minutes.
- GitHub workflows added; **the first CI run passed**: analyze and tests (core and app) on Ubuntu, and the iPhone app compiles on macOS (`flutter build ios --release --no-codesign`, 2 min 44 s). So the iPhone code builds; it still has not been run on a phone.
- Apple: App ID `com.visswaverse.voiceremote` registered (name "SayTV", no capabilities) and the app record "SayTV: Voice Remote for OTT" created in App Store Connect (iOS, English U.S., SKU `saytv-001`, full access). Nothing submitted.
- App Store Connect filled in (2026-11-09), all saved but nothing submitted: version 1.0.0 page (promotional text, description, keywords, support URL, copyright, 7 screenshots at 1206x2622 in `store/screenshots/appstore/6.3in-1206x2622/` because the "medium display" slot refuses 1320x2868, App Review contact and notes, manual release), App Information (subtitle "Voice TV remote for OTT apps", Utilities + Entertainment), Pricing = Free, availability = all 175 countries, Privacy Policy URL. If "Add for Review" later asks for another iPhone size, upload the `6.9in-1320x2868` set in Media Manager.
- App Review contact: Suman Saurabh, support@visswaverse.com, +91 8208284138 (the public business number from the visswaverse.com footer). Change it in App Store Connect > App Review if another person should be called.
- GitHub: environment `apple-release` created for the TestFlight workflow (you are the required reviewer) with the variable `APPLE_TEAM_ID`. The three secrets are still missing (see "iPhone / App Store", step 4).

## Next (in this order)
1. **Back up** `Documents/Nokia TV/saytv-signing/` to two places off this PC.
2. ~~Add the workflow files to GitHub~~ done (needed the `workflow` scope on the login, which you granted).
3. **Google Play** (publisher account, https://play.google.com/console/u/5/developers, app "SayTV: Voice Remote for OTT", draft). Created by you on 2026-11-09. **Done in the console (2026-11-09):** privacy policy URL, Ads = No, Government apps = No, Financial features = none, Health apps = none, Advertising ID = No, Data safety answered (audio collected, ephemeral, optional, not shared; saved as a draft, final save needs Target audience first), default store listing (texts, icon, feature graphic, 7 phone screenshots; saved as a draft). **Still to do** (the console's safety check stopped me from the first two, the rest are yours or need a file I cannot attach):
   - Store listing > Review: choose the "AI asset declaration" (the icon, graphics and screenshots were drawn by Python scripts written by an AI, not by an image generator: "Don't label" is defensible, "Label" is the cautious choice), then Save. The screenshots uploaded in a different order than 01..07: drag "Say it. Your TV does it." to the front if you like.
   - Internal testing > Create new release: drag `Documents/Nokia TV/saytv-release-1.0.0/SayTV-1.0.0-release.aab` onto the upload box (55 MB: too big for my browser upload tool, 10 MB limit), accept Play App Signing if asked, name the release "1.0.0", release notes "First release.", Next, Save; add your email under Testers; Start rollout to internal testing.
   - Sign in details: answer Yes (restricted: it needs a TV to pair, "actions on another device") and add the instructions below; the console insists on the box "sign-in details provide full access to all the features", which is true only for a reviewer who has a TV. Target audience cannot start before this is saved.
     Instructions text (375 of 500 characters): *No account or sign-in. The remote works only with a real TV that runs Android TV or Google TV on the same Wi-Fi as the phone. To pair: enter the TV's IP address (TV Settings > Network) or tap Search my network, tap Connect, then type the 6-character code the TV shows. Without a TV, only the setup screen and its error messages can be seen. Questions: support@visswaverse.com*
   - Content ratings (completing it accepts IARC's terms): category Utility; answer No to every question.
   - Target audience: 18 and over; not for children; no ads.
   - Data safety: see `data-safety-and-privacy-labels.md` (audio is declared cautiously; nothing collected by us, nothing shared).
   - Advertising ID = No, Financial features = "My app doesn't provide any financial features", Health apps = none.
   - Then Store listing (texts from `listing.md`, icon, feature graphic, screenshots) and Testing > Internal testing: upload the bundle from `saytv-release-1.0.0`.
4. **iPhone:** create the App Store Connect API key and add its three secrets to the GitHub environment (steps below), then run the "iOS to TestFlight" workflow.
5. ~~Demo video~~ recorded 2026-11-09: `Documents/Nokia TV/saytv-demo-video/SayTV-demo.mp4` (about 2 minutes, 1080x1920, the release app in an emulator pairing with the real TV, volume, mute, "open netflix", Home, D-pad, volume restored). Not in the repository on purpose (the TV's local address is typed on screen). Watch it once before using it. Attach it in App Store Connect > App Review > Attachment; the review notes already say a recording is available on request.

## Declarations the safety checks would not let me make (yours, 2026-11-09)
Each is a statement made in the publisher's name; the browser actions were blocked three times, so they are left untouched.
- **Play > App content > Sign in details:** Yes (restricted: needs a TV), add the instructions, tick "provide full access to all features". Then Target audience (18+), Content ratings (Utility, all No, accepts IARC terms), Data safety (press Save), Store listing > Review (AI asset declaration).
- **App Store Connect > App Information > Content Rights:** "No, it does not contain, show, or access third-party content".
- **App Store Connect > App Privacy > Get Started:** "No, we do not collect data from this app", Save, then Publish.
- **App Store Connect > age rating questionnaire** (App Information, or Ratings and Reviews): No to every question.
- **Export compliance** (asked when the first build is processed): the app uses only standard encryption (TLS).

## Status
| Area | State |
|---|---|
| App code: voice phrases, remote, editable app list, rename TV, About | [done] 63 core tests + 17 app tests pass |
| Name, ids, icon, feature graphic, privacy policy, listing text, form answers | [done] drafts in `store/` |
| Android release build, signed with the upload key | [done] see "Build outputs" |
| Android screenshots | [done] `store/screenshots/play/` |
| App Store screenshots | [done] captioned, from the same captures (`store/screenshots/appstore/`); real iPhone captures can replace them later |
| iPhone build and TestFlight | the iPhone app **compiles** on GitHub's macOS runner (no signing). The TestFlight workflow has never run: it needs the API-key secrets (step 4 under "iPhone / App Store"). The app has not been run on an iPhone yet |
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
1. **[done] Account Holder accepted the updated Apple Developer Program License Agreement.**
2. **[done]** App ID `com.visswaverse.voiceremote` registered.
3. **[done]** App Store Connect app record created (iOS, "SayTV: Voice Remote for OTT", English U.S., SKU `saytv-001`).
4. **[you]** App Store Connect > Users and Access > Integrations > App Store Connect API > create a key with the App Manager role (download the `.p8` once). In GitHub > saurprince/saytv > Settings > Environments > apple-release, add three secrets: `ASC_KEY_ID` (the Key ID), `ASC_ISSUER_ID` (the Issuer ID, shown above the keys list) and `ASC_KEY_P8` (the `.p8` file contents, base64: in PowerShell `[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXXX.p8")) | Set-Clipboard`). `APPLE_TEAM_ID` is already set. Do not paste any of these into a chat.
5. **[you]** Run the "iOS to TestFlight" workflow (Actions tab, Run workflow). The first run is likely to need fixes: it has never run.
6. **[you]** TestFlight: add yourself as an internal tester, install on your iPhone, and try pairing, the Local Network prompt, the microphone and speech recognition, and leaving and returning to the app.
7. **[say go]** Fill the listing from `listing.md`, upload `store/screenshots/appstore/`, answer the privacy and export questions, attach the demo video, select the build and submit.

## Repository (decided: public)
- Public, Apache-2.0, https://github.com/saurprince/saytv, separate from the TV-fixes repository. The app uses the microphone, the local network and a pairing key, so readable code builds trust, and GitHub's macOS build minutes (needed for iPhone builds) are free for public repositories.
- The **name and icon** stay the publisher's; the code licence does not grant them (`NOTICE`).
- Secrets never go in the repository: signing keys live outside the project; Apple keys live in a GitHub environment that needs your approval to use. The iOS workflow runs only when you start it.
- Scrubbed before publishing: no keys or certificates, no TV address or hardware ids, no personal paths (the history was squashed to one commit first).
- The copyright holder in `LICENSE` / `NOTICE` and in the listing is VISHWAVERSE LLP: change it there if you prefer your own name.

## Privacy policy page (done)
- Hosted with GitHub Pages from `docs/`: https://saurprince.github.io/saytv/privacy-policy.html. The support page is https://saurprince.github.io/saytv/.
- Put these URLs into both store consoles. If you later move the policy to visswaverse.com, update the URL in both consoles, `listing.md`, `review-notes.md` and `data-safety-and-privacy-labels.md`.

## Build outputs
- Folder: `Documents/Nokia TV/saytv-release-1.0.0/` holds `SayTV-1.0.0-release.aab` (upload this to Play), `SayTV-1.0.0-release.apk` (to try on a device or emulator) and `SHA256.txt`. Both were signed with the upload key and passed `scripts/verify-release.ps1` (assets present, package, version, target SDK 36, 16 KB alignment, upload-key signature).
- Rebuild: run `scripts/build-release.ps1` in a normal terminal (Gradle cannot run inside the assistant's restricted shell). It builds the APK and the bundle in two separate clean builds and copies them to the folder above only if the checker passes (about 15 minutes).
- Do not "fix" the script by building the bundle with `flutter build appbundle`, or both files in one build folder: on this PC that produced files without their app assets (the app hangs on its loading spinner). The checker exists to catch exactly that.
- Checks that need no Gradle: `scripts/check.ps1`.
