import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tv_voice_remote/branding.dart';

void main() {
  test('appVersion matches the version in pubspec.yaml', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    final version = line.substring('version:'.length).trim().split('+').first;
    expect(appVersion, version);
  });

  test('the privacy policy URL points at the page published from docs/', () {
    expect(privacyPolicyUrl, startsWith('https://'));
    expect(privacyPolicyUrl, endsWith('/privacy-policy.html'));
    expect(File('../docs/privacy-policy.html').existsSync(), isTrue);
  });

  test('the Android label and the iOS display name match appName', () {
    expect(File('android/app/src/main/res/values/strings.xml').readAsStringSync(), contains('>$appName<'));
    expect(File('ios/Runner/Info.plist').readAsStringSync(), contains('<string>$appName</string>'));
  });
}
