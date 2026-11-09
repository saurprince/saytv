import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tv_remote_core/tv_remote_core.dart';

/// What the app remembers. The identity (the pairing key) goes into the platform's secure storage, never into plain preferences.
class Store {
  static const _secure = FlutterSecureStorage();

  Future<Identity?> loadIdentity() async {
    final s = await _secure.read(key: 'identity');
    return s == null ? null : Identity.fromJson(jsonDecode(s) as Map<String, dynamic>);
  }

  Future<void> saveIdentity(Identity id) => _secure.write(key: 'identity', value: jsonEncode(id.toJson()));

  Future<String?> loadHost() async => (await SharedPreferences.getInstance()).getString('host');

  Future<void> saveHost(String host) async => (await SharedPreferences.getInstance()).setString('host', host);

  /// The fingerprint of the TV's certificate, saved when pairing succeeded. Public information, so plain preferences are fine.
  /// null for a pairing made before pins existed: the app then saves the TV's fingerprint on the next successful connection.
  Future<String?> loadTvPin() async => (await SharedPreferences.getInstance()).getString('tvPin');

  Future<void> saveTvPin(String? pin) async {
    final prefs = await SharedPreferences.getInstance();
    if (pin == null) {
      await prefs.remove('tvPin');
    } else {
      await prefs.setString('tvPin', pin);
    }
  }

  /// The name the user gave the TV ("Living room"); null if they did not.
  Future<String?> loadTvName() async => (await SharedPreferences.getInstance()).getString('tvName');

  Future<void> saveTvName(String? name) async {
    final prefs = await SharedPreferences.getInstance();
    if (name == null || name.trim().isEmpty) {
      await prefs.remove('tvName');
    } else {
      await prefs.setString('tvName', name.trim());
    }
  }

  /// Forget the TV and the pairing (the TV keeps its side until its remote service data is cleared). The app list stays.
  Future<void> forget() async {
    await _secure.delete(key: 'identity');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('host');
    await prefs.remove('tvName');
    await prefs.remove('tvPin');
  }

  // ---- apps ----
  static List<AppEntry> _parse(String text) =>
      [for (final a in (jsonDecode(text)['apps'] as List)) AppEntry.fromJson(a as Map<String, dynamic>)];

  /// The list the app ships with (assets/apps.json, a copy of spec/apps.json).
  Future<List<AppEntry>> loadDefaultApps() async => _parse(await rootBundle.loadString('assets/apps.json'));

  /// Suggested apps for one-tap adding (assets/catalog.json, a copy of spec/catalog.json).
  Future<List<AppEntry>> loadCatalog() async => _parse(await rootBundle.loadString('assets/catalog.json'));

  /// The user's list; the shipped defaults until they change it. An empty list is a valid choice and is kept.
  Future<List<AppEntry>> loadApps() async {
    final text = (await SharedPreferences.getInstance()).getString('apps');
    if (text != null) {
      try {
        return _parse(text);
      } catch (_) {
        // A damaged saved list must not stop the app from starting: fall back to the defaults below.
      }
    }
    return loadDefaultApps();
  }

  Future<void> saveApps(List<AppEntry> apps) async => (await SharedPreferences.getInstance())
      .setString('apps', jsonEncode({'apps': [for (final a in apps) a.toJson()]}));

  /// Back to the shipped list.
  Future<void> resetApps() async => (await SharedPreferences.getInstance()).remove('apps');
}
