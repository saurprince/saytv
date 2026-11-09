# Notes for the app reviewers (paste into App Store Connect "Notes" and Play Console "App access")

**What the app is.** SayTV is a remote control for TVs and streaming boxes that run Android TV or Google TV. It talks to the user's own TV over their home Wi-Fi, using the TV's built-in remote service (the same one Google's own remote apps use). It has no accounts, no server and no sign-in.

**How to see it work.** The app needs such a TV on the same Wi-Fi network, so a full test needs one. A short video of the app controlling a real TV is attached / linked here: `TODO: add the video link or upload it in App Store Connect (App Review Information > Attachment)`.

**Without a TV.** On first launch the app shows "Find your TV". If no TV is reachable it says so and offers Retry. Everything else (Edit apps, adding and removing apps, About) works without a TV.

**Steps with a TV**
1. Open the app. Tap "Search my network" (iPhone shows the Local Network permission prompt: allow it) or type the TV's address, then Connect.
2. The TV shows "Device pairing request" with a six-character code. Type it in the app and tap Pair.
3. The remote screen shows "Connected". Try: type `volume 30` in the command box, or tap an app button (for example YouTube), or the Home button.
4. Microphone button: iOS asks for Microphone and Speech Recognition permission. Spoken commands such as "open YouTube" or "volume 30" are matched on the phone. The speech-to-text itself is done by Apple's (iPhone) or Google's (Android) speech recognition.

**Permissions and why**
- Microphone and Speech Recognition: spoken commands (only while the mic button is tapped).
- Local Network (iPhone): to find the TV and send it commands. Bonjour service used: `_androidtvremote2._tcp`.
- Network (Android): the same.

**Data.** The app collects no data and sends nothing to the publisher. It stores a pairing key in the phone's secure storage and the TV's local address on the phone. Privacy policy: https://saurprince.github.io/saytv/privacy-policy.html (source: `docs/privacy-policy.html`).

**Third-party names.** App names such as Netflix or YouTube appear only as text labels on buttons the user chooses; the app uses no logos and is not affiliated with those services, with Google, or with any TV maker (stated in the app's About screen and in the description).

**App Review contact**: the publisher's support contact (support@visswaverse.com; the phone number is on the publisher's website). Enter a named person and phone number in App Store Connect when submitting.
