# Answers for the store privacy forms

These follow what the app actually does (see `docs/privacy-policy.html`). Check each against the live form when you fill it in: the stores change their wording.

## What the app does with data (the facts the answers come from)
- No accounts, no servers of ours, no analytics, no crash-reporting SDK, no ads, no tracking, no third-party SDKs that send data.
- Stores on the phone only: a pairing key (secure storage), the TV's local address, an optional TV name, the user's app list.
- Talks only to the user's own TV over the local network (TLS).
- Microphone: only while the mic button is tapped, through the phone's own speech recognizer (Apple Speech on iPhone, Android SpeechRecognizer / Google on Android). The app gets text only. The OS service may send audio to Apple or Google.

## Google Play: Data safety form
| Question | Answer | Why |
|---|---|---|
| Does your app collect or share any of the required user data types? | **Yes, one: Audio, "Voice or sound recordings"** (see note) | The phone's speech service may send the user's voice off the device. Declaring it is the cautious reading. |
| Voice or sound recordings: collected / shared? | Collected: yes. Shared: no | The app itself never sends or stores the audio; the system recognizer does. It is not given to us or to third parties by the app |
| Processed ephemerally? | Yes | Nothing is kept by the app |
| Required or optional? | Optional | The app works with typing and buttons |
| Purpose | App functionality | |
| Is all of the user data encrypted in transit? | Yes | The system recognizer uses encrypted connections; the TV link is TLS |
| Can users request that data be deleted? | Not applicable: we hold no data. Link: the privacy policy | |
| Independent security review | No | |
| Any other data type (location, personal info, identifiers, app activity, diagnostics...) | No | |

Result on the live form (saved 2026-11-09): because the voice data is declared "processed ephemerally", Google leaves it off the public listing, so the Preview and the Play page show "No data collection declared" and "No data shared with third parties". The voice entry stays in the form. To show "Audio: voice or sound recordings, collected" on the listing instead, answer "No" to ephemeral processing.

Note: if you prefer the narrower reading ("the app collects nothing; the OS speech service is outside the app"), choose "No data collected". The policy text is accurate either way. If Google asks for a change after review, switch to the declaration above.

Other Play forms: **Content rating** (IARC questionnaire): no violence, no sexual content, no profanity, no controlled substances, no user interaction or sharing, no location sharing, no purchases. Expected rating: Everyone / 3+. **Ads**: no. **Government app**: no. **Financial features**: none. **Health features**: none. **News app**: no. **Data deletion**: not required (no accounts). **Advertising ID**: not used (declare "No"). Target API level: see `release-checklist.md`.

## Apple: App Privacy ("nutrition labels")
| Question | Answer |
|---|---|
| Do you or your third-party partners collect data from this app? | **No, we do not collect data from this app** |
| Tracking? | No |

Why: the app sends nothing to the publisher or to third-party partners. Apple's own Speech framework is part of iOS, not a third-party partner. Privacy policy URL: required: https://saurprince.github.io/saytv/privacy-policy.html (same page as above).

Other App Store Connect answers:
- **Export compliance** (encryption): the app uses standard encryption only (TLS, hashing, and a certificate it generates for logging in to the user's own TV). That normally means "uses encryption, exempt". This is a legal declaration by the Account Holder. It was first answered by hand in App Store Connect (standard encryption; France No, so France was removed from availability: saying Yes asks for French encryption paperwork). On 2026-11-09 the Account Holder asked for `ITSAppUsesNonExemptEncryption = false` to be set in `ios/Runner/Info.plist`, so Apple no longer asks per build. If the app's encryption ever changes (for example, its own non-standard cryptography), revisit this.
- **Content rights**: the app contains no third-party content. App names (Netflix, etc.) appear only as text labels on buttons the user chooses; no logos.
- **Advertising identifier (IDFA)**: not used.
- **Sign in with Apple**: not needed (no accounts).
- **Made for Kids**: no.
- **Privacy manifest**: the Flutter plugins used ship their own privacy manifests. The app adds none of its own.
