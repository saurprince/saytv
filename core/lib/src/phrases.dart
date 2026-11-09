/// Turns a spoken phrase (as text from speech recognition) into one TV action. The phrases are fixed on purpose:
/// predictable, offline and free. The same cases are checked in spec/phrases.json.

sealed class VoiceAction {
  const VoiceAction();
  Map<String, Object?> toJson();
}

class OpenApp extends VoiceAction {
  const OpenApp(this.id);
  final String id;
  @override
  Map<String, Object?> toJson() => {'type': 'app', 'id': id};
}

class VolumeDelta extends VoiceAction {
  const VolumeDelta(this.delta);
  final int delta;
  @override
  Map<String, Object?> toJson() => {'type': 'volume_delta', 'delta': delta};
}

class VolumeSet extends VoiceAction {
  const VolumeSet(this.level);
  final int level;
  @override
  Map<String, Object?> toJson() => {'type': 'volume_set', 'level': level};
}

class MuteAction extends VoiceAction {
  const MuteAction(this.on);
  final bool on;
  @override
  Map<String, Object?> toJson() => {'type': 'mute', 'on': on};
}

class PressKey extends VoiceAction {
  const PressKey(this.key);
  final String key;
  @override
  Map<String, Object?> toJson() => {'type': 'key', 'key': key};
}

class Unknown extends VoiceAction {
  const Unknown();
  @override
  Map<String, Object?> toJson() => {'type': 'unknown'};
}

/// One app the user can open by name. [say] lists the names it answers to.
class AppEntry {
  const AppEntry({required this.id, required this.name, required this.package, required this.say});
  final String id;
  final String name;
  final String package;
  final List<String> say;

  static AppEntry fromJson(Map<String, dynamic> j) => AppEntry(
        id: j['id'] as String,
        name: j['name'] as String,
        package: j['package'] as String,
        say: (j['say'] as List).cast<String>(),
      );

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'package': package, 'say': say};

  /// The names an app answers to: its own name first, then [extra], without empties or duplicates.
  /// A name with no Latin letters or digits (for example Devanagari) cannot be matched against speech recognition output, so it is left out.
  static List<String> buildSay(String name, Iterable<String> extra) {
    final out = <String>[];
    final seen = <String>{};
    for (final s in [name, ...extra]) {
      final t = s.trim();
      final key = normalize(t);
      if (key.isNotEmpty && seen.add(key)) out.add(t);
    }
    return out;
  }

  /// An app the user adds by hand. [takenIds] are the ids already in use, so the new id is unique.
  factory AppEntry.custom({
    required String name,
    required String package,
    Iterable<String> extraSay = const [],
    Iterable<String> takenIds = const [],
  }) {
    final n = name.trim();
    final pkg = package.trim();
    var base = normalize(n).replaceAll(' ', '');
    if (base.isEmpty) base = pkg.split('.').last.toLowerCase();
    final taken = takenIds.toSet();
    var id = base;
    for (var i = 2; taken.contains(id); i++) {
      id = '$base$i';
    }
    return AppEntry(id: id, name: n, package: pkg, say: buildSay(n, extraSay));
  }

  AppEntry copyWith({String? name, String? package, List<String>? say}) =>
      AppEntry(id: id, name: name ?? this.name, package: package ?? this.package, say: say ?? this.say);
}

/// An Android application id such as com.netflix.ninja: two or more dot-separated parts, each starting with a letter.
bool isValidPackage(String s) => RegExp(r'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$').hasMatch(s);

/// The app in [apps] that already answers to [spoken], other than the one with id [exceptId]; null if none.
AppEntry? appUsingName(Iterable<AppEntry> apps, String spoken, {String? exceptId}) {
  final key = normalize(spoken);
  if (key.isEmpty) return null;
  for (final a in apps) {
    if (a.id == exceptId) continue;
    if (a.say.any((s) => normalize(s) == key)) return a;
  }
  return null;
}

class PhraseParser {
  PhraseParser(this.apps, {this.volumeStep = 5}) {
    for (final a in apps) {
      for (final s in a.say) {
        final key = normalize(s);
        if (key.isNotEmpty) _alias[key] = a.id;
      }
    }
    _aliasesLongestFirst = _alias.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
  }

  /// True if saying [spoken] already means a TV command (pause, home, mute, volume ...), so an app must not be named that.
  static bool isReserved(String spoken) {
    final t = normalize(spoken);
    return _keyPhrases.containsKey(t) || const {'mute', 'unmute', 'silence', 'standby', 'sleep', 'shutdown', 'volume', 'open', 'launch', 'start'}.contains(t);
  }

  final List<AppEntry> apps;
  final int volumeStep;
  final Map<String, String> _alias = {};
  late final List<String> _aliasesLongestFirst;

  static const _keyPhrases = <String, String>{
    'pause': 'PAUSE',
    'resume': 'PLAY',
    'continue': 'PLAY',
    'play': 'PLAY',
    'stop': 'STOP',
    'next': 'NEXT',
    'skip': 'NEXT',
    'previous': 'PREVIOUS',
    'rewind': 'REWIND',
    'fast forward': 'FAST_FORWARD',
    'forward': 'FAST_FORWARD',
    'back': 'BACK',
    'go back': 'BACK',
    'return': 'BACK',
    'home': 'HOME',
    'go home': 'HOME',
    'up': 'UP',
    'down': 'DOWN',
    'left': 'LEFT',
    'right': 'RIGHT',
    'select': 'CENTER',
    'ok': 'CENTER',
    'okay': 'CENTER',
    'enter': 'CENTER',
    'confirm': 'CENTER',
    'menu': 'MENU',
  };

  VoiceAction parse(String raw) {
    final t = normalize(raw);
    if (t.isEmpty) return const Unknown();

    if (RegExp(r'^(unmute|un mute|sound on|volume on|restore sound)( tv)?$').hasMatch(t)) return const MuteAction(false);
    if (RegExp(r'^(mute|sound off|silence)( tv)?$').hasMatch(t)) return const MuteAction(true);
    if (RegExp(r'^(turn off|switch off|power off|shut down|shutdown|standby|go to standby|sleep)( tv| television)?$').hasMatch(t)) {
      return const PressKey('POWER');
    }

    if (t.contains('volume') || RegExp(r'\b(louder|quieter|softer)\b').hasMatch(t)) {
      final v = _volume(t);
      if (v != null) return v;
    }

    final app = _app(t);
    if (app != null) return app;

    final key = _keyPhrases[t];
    if (key != null) return PressKey(key);
    return const Unknown();
  }

  VoiceAction? _volume(String t) {
    if (RegExp(r'\b(max|maximum|full)\b').hasMatch(t)) return const VolumeSet(100);
    final by = RegExp(r'\bby (\d{1,3})\b').firstMatch(t);
    final step = by != null ? int.parse(by.group(1)!) : volumeStep;
    final up = RegExp(r'\b(up|increase|raise|higher|louder)\b').hasMatch(t);
    final down = RegExp(r'\b(down|decrease|lower|reduce|quieter|softer)\b').hasMatch(t);
    if (up && !down) return VolumeDelta(step);
    if (down && !up) return VolumeDelta(-step);
    final set = RegExp(r'^(?:set |change )?volume (?:to |at )?(\d{1,3})(?: percent)?$').firstMatch(t);
    if (set != null) return VolumeSet(int.parse(set.group(1)!).clamp(0, 100));
    return null;
  }

  VoiceAction? _app(String t) {
    final stripped = t.replaceFirst(RegExp(r'^(open|launch|start|go to|play|show|switch to|put on|run) '), '');
    if (stripped == t && t == 'open') return null;
    for (final alias in _aliasesLongestFirst) {
      if (stripped == alias) return OpenApp(_alias[alias]!);
    }
    return null;
  }
}

const _small = {
  'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6, 'seven': 7, 'eight': 8, 'nine': 9,
  'ten': 10, 'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14, 'fifteen': 15, 'sixteen': 16,
  'seventeen': 17, 'eighteen': 18, 'nineteen': 19,
};
const _tens = {'twenty': 20, 'thirty': 30, 'forty': 40, 'fifty': 50, 'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90};

/// Lower-case, no punctuation, filler words dropped, spelled-out numbers turned into digits.
String normalize(String raw) {
  var t = raw.toLowerCase().replaceAll(RegExp(r"[^a-z0-9% ]"), ' ').replaceAll('%', ' percent ');
  // Dropped words. "to", "tv" and "a" stay: rules such as "go to hotstar", "turn off tv" and "apple tv" use them.
  const filler = {'the', 'please', 'television', 'hey', 'can', 'you', 'could', 'my'};
  final words = t.split(RegExp(r'\s+')).where((w) => w.isNotEmpty && !filler.contains(w)).toList();
  final out = <String>[];
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    if (_tens.containsKey(w)) {
      var n = _tens[w]!;
      if (i + 1 < words.length && _small.containsKey(words[i + 1]) && _small[words[i + 1]]! < 10) {
        n += _small[words[++i]]!;
      }
      out.add('$n');
    } else if (w == 'hundred' && out.isNotEmpty && out.last == '1') {
      out[out.length - 1] = '100';
    } else if (_small.containsKey(w)) {
      out.add('${_small[w]}');
    } else {
      out.add(w);
    }
  }
  return out.join(' ');
}
