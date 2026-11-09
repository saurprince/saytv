import 'dart:convert';
import 'dart:io';

import 'package:tv_remote_core/tv_remote_core.dart';

const usage = '''
tvcli: tests the shared TV code from a PC.
  dart run bin/tvcli.dart scan
  dart run bin/tvcli.dart mdns
  dart run bin/tvcli.dart pair   <ip> [code]       generates a new identity if none exists, then pairs (prompts for the code)
  dart run bin/tvcli.dart status <ip>
  dart run bin/tvcli.dart key    <ip> NAME [NAME...]
  dart run bin/tvcli.dart app    <ip> <package-or-link>
  dart run bin/tvcli.dart vol    <ip> <0-100>
  dart run bin/tvcli.dart mute   <ip> on|off
  dart run bin/tvcli.dart say    <ip> "open netflix"
Options before the command:  --identity <dir>   folder holding identity.json (default .identity)
                             --pem <dir>        use cert.pem + key.pem from that folder instead (e.g. the Python client's)
''';

Future<void> main(List<String> argv) async {
  final args = [...argv];
  String identityDir = '.identity';
  String? pemDir;
  while (args.isNotEmpty && args.first.startsWith('--')) {
    final opt = args.removeAt(0);
    if (opt == '--identity') identityDir = args.removeAt(0);
    if (opt == '--pem') pemDir = args.removeAt(0);
  }
  if (args.isEmpty) {
    stdout.write(usage);
    return;
  }
  final cmd = args.removeAt(0);

  Future<Identity> identity({bool create = false}) async {
    if (pemDir != null) {
      return Identity(
          certPem: File('$pemDir/cert.pem').readAsStringSync(), keyPem: File('$pemDir/key.pem').readAsStringSync());
    }
    final f = File('$identityDir/identity.json');
    if (f.existsSync()) return Identity.fromJson(jsonDecode(f.readAsStringSync()) as Map<String, dynamic>);
    if (!create) throw StateError('no identity in $identityDir: run "pair" first');
    stdout.writeln('generating a new RSA identity (a few seconds)...');
    final id = await Identity.generate();
    Directory(identityDir).createSync(recursive: true);
    f.writeAsStringSync(jsonEncode(id.toJson()));
    return id;
  }

  switch (cmd) {
    case 'scan':
      final sw = Stopwatch()..start();
      stdout.writeln('subnet scan: ${await scanSubnet()} in ${sw.elapsedMilliseconds} ms');
    case 'mdns':
      stdout.writeln('mDNS: ${await discoverMdns()}');
    case 'pair':
      final id = await identity(create: true);
      final p = await Pairing.begin(args[0], id, clientName: 'TV Voice Remote (test)');
      stdout.writeln('PAIRING STARTED - the TV shows a 6-character code.');
      stdout.flush();
      String code;
      if (args.length > 1 && args[1].startsWith('@')) {
        // "@path": wait for a file to appear with the code (lets a script read the code off the TV screen)
        final f = File(args[1].substring(1));
        final end = DateTime.now().add(const Duration(minutes: 3));
        while (!(f.existsSync() && f.readAsStringSync().trim().isNotEmpty)) {
          if (DateTime.now().isAfter(end)) throw StateError('no code within 3 minutes');
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        code = f.readAsStringSync().trim();
      } else {
        code = args.length > 1 ? args[1] : (stdin.readLineSync() ?? '');
      }
      await p.finish(code);
      stdout.writeln('PAIRED.');
    case 'status':
      final c = await RemoteConnection.connect(args[0], await identity());
      stdout.writeln(c.state);
      c.close();
    case 'key':
      final c = await RemoteConnection.connect(args[0], await identity());
      for (final name in args.skip(1)) {
        final code = Keys.byName[name.toUpperCase()] ?? int.parse(name);
        c.key(code);
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
      stdout.writeln('sent ${args.skip(1).join(' ')}; ${c.state}');
      c.close();
    case 'app':
      final c = await RemoteConnection.connect(args[0], await identity());
      args[1].contains(':') ? c.app(args[1]) : c.launchPackage(args[1]);
      await Future<void>.delayed(const Duration(seconds: 1));
      stdout.writeln('sent ${args[1]}');
      c.close();
    case 'vol':
      final c = await RemoteConnection.connect(args[0], await identity());
      final from = c.state.volume;
      final sw = Stopwatch()..start();
      final end = await c.setVolume(int.parse(args[1]));
      stdout.writeln('volume $from -> $end in ${sw.elapsedMilliseconds} ms');
      c.close();
    case 'mute':
      final c = await RemoteConnection.connect(args[0], await identity());
      await c.setMuted(args[1] == 'on');
      stdout.writeln('muted: ${c.state.muted}, volume ${c.state.volume}');
      c.close();
    case 'say':
      final apps = [
        for (final a in (jsonDecode(File('../spec/apps.json').readAsStringSync())['apps'] as List))
          AppEntry.fromJson(a as Map<String, dynamic>)
      ];
      final action = PhraseParser(apps).parse(args[1]);
      stdout.writeln('"${args[1]}" -> ${jsonEncode(action.toJson())}');
      final c = await RemoteConnection.connect(args[0], await identity());
      switch (action) {
        case OpenApp(:final id):
          await c.wake();
          c.launchPackage(apps.firstWhere((a) => a.id == id).package);
        case VolumeDelta(:final delta):
          await c.volumeBy(delta);
        case VolumeSet(:final level):
          await c.setVolume(level);
        case MuteAction(:final on):
          await c.setMuted(on);
        case PressKey(:final key):
          c.key(Keys.byName[key]!);
        case Unknown():
          stdout.writeln('not understood');
      }
      await Future<void>.delayed(const Duration(seconds: 1));
      stdout.writeln(c.state);
      c.close();
    default:
      stdout.write(usage);
  }
  exit(0);
}
