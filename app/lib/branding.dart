/// The name people see. One place to change it; the Android label (res/values/strings.xml) and the iOS display name
/// (ios/Runner/Info.plist) have to match, and `scripts/make-store-graphics.py` reads it for the store images.
const String appName = 'SayTV';

/// Must equal the part of `version:` in pubspec.yaml before the + (test/branding_test.dart checks).
const String appVersion = '1.0.0';

/// Where people write for help. Taken from the publisher's website.
const String supportEmail = 'support@visswaverse.com';

/// The hosted privacy policy (GitHub Pages, source `docs/privacy-policy.html`). Both stores require it to be linked in the app too.
const String privacyPolicyUrl = 'https://saurprince.github.io/saytv/privacy-policy.html';
