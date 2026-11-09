import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tv_remote_core/tv_remote_core.dart';

import 'apps_screen.dart';
import 'branding.dart';
import 'controller.dart';
import 'voice.dart';

class RemoteScreen extends StatefulWidget {
  const RemoteScreen({super.key, required this.controller});
  final TvController controller;

  @override
  State<RemoteScreen> createState() => _RemoteScreenState();
}

class _RemoteScreenState extends State<RemoteScreen> {
  final _voice = VoiceInput();
  final _typed = TextEditingController();
  bool _listening = false;
  String? _partial;
  String? _voiceError;
  double? _dragVolume;

  TvController get c => widget.controller;

  @override
  void dispose() {
    _voice.stop();
    _typed.dispose();
    super.dispose();
  }

  void _tap(int key) {
    HapticFeedback.selectionClick();
    c.key(key);
  }

  Future<void> _mic() async {
    if (_listening) {
      await _voice.stop();
      return;
    }
    setState(() {
      _voiceError = null;
      _partial = null;
    });
    final ok = await _voice.init(
      onStatus: (s) {
        if (!mounted) return;
        if (s == 'done' || s == 'notListening') setState(() => _listening = false);
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _listening = false;
          _voiceError = 'Could not hear you ($e).';
        });
      },
    );
    if (!ok) {
      if (!mounted) return;
      setState(() => _voiceError = 'Speech recognition is not available or not allowed. You can still type a command below.');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _listening = true);
    await _voice.listen(
      onPartial: (t) => setState(() => _partial = t),
      onFinal: (t) async {
        if (!mounted) return;
        setState(() {
          _listening = false;
          _partial = null;
        });
        await c.say(t);
      },
    );
  }

  Future<void> _confirmPower() async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Put the TV in standby?'),
        content: const Text('To switch it on again you will need the TV\'s own remote (infrared).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Standby')),
        ],
      ),
    );
    if (go == true) c.key(Keys.power);
  }

  void _editApps() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AppsScreen(controller: c)));

  void _about() => showAboutDialog(
        context: context,
        applicationName: appName,
        applicationVersion: appVersion,
        children: const [
          SizedBox(height: 16),
          Text(
            'Controls TVs that run Android TV or Google TV, over your home Wi-Fi. '
            'An independent app: not affiliated with Google or with any TV or streaming brand. App names are trademarks of their owners.',
          ),
          SizedBox(height: 8),
          SelectableText('Support: $supportEmail'),
          SizedBox(height: 4),
          SelectableText('Privacy policy: $privacyPolicyUrl'),
        ],
      );

  Future<void> _renameTv() async {
    final field = TextEditingController(text: c.tvName ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Name this TV'),
        content: TextField(
          controller: field,
          autofocus: true,
          maxLength: 30,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Living room'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, field.text), child: const Text('Save')),
        ],
      ),
    );
    field.dispose();
    if (name != null) await c.renameTv(name);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final tv = c.tv;
        return Scaffold(
          appBar: AppBar(
            title: const Text(appName),
            actions: [
              IconButton(tooltip: 'Standby', onPressed: _confirmPower, icon: const Icon(Icons.power_settings_new)),
              PopupMenuButton<String>(
                onSelected: (v) {
                  switch (v) {
                    case 'apps':
                      _editApps();
                    case 'rename':
                      _renameTv();
                    case 'about':
                      _about();
                    case 'forget':
                      c.forget();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'apps', child: Text('Edit apps')),
                  PopupMenuItem(value: 'rename', child: Text('Name this TV')),
                  PopupMenuItem(value: 'about', child: Text('About')),
                  PopupMenuItem(value: 'forget', child: Text('Forget this TV')),
                ],
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _status(context),
                const SizedBox(height: 12),
                _voiceCard(context),
                const SizedBox(height: 12),
                _volumeCard(context, tv),
                const SizedBox(height: 12),
                _dpad(context),
                const SizedBox(height: 12),
                _media(context),
                const SizedBox(height: 12),
                _apps(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _status(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, text) = switch (c.link) {
      Link.connected => (Colors.green, 'Connected to ${c.displayName}'),
      Link.connecting => (Colors.orange, 'Connecting...'),
      Link.unreachable => (scheme.error, 'The TV is not reachable. It may be off: switch it on with its own remote.'),
      Link.idle => (Colors.grey, 'Not connected'),
    };
    return Row(children: [
      Icon(Icons.circle, size: 12, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(text)),
      if (c.link == Link.unreachable || c.link == Link.idle) TextButton(onPressed: c.connect, child: const Text('Retry')),
    ]);
  }

  Widget _voiceCard(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            IconButton.filled(
              iconSize: 32,
              onPressed: _mic,
              icon: Icon(_listening ? Icons.hearing : Icons.mic),
              tooltip: 'Speak a command',
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _listening
                      ? (_partial == null || _partial!.isEmpty ? 'Listening...' : _partial!)
                      : (c.lastHeard == null ? 'Tap the mic and say a command' : '"${c.lastHeard}"'),
                  style: theme.textTheme.titleMedium,
                ),
                if (!_listening && c.lastResult != null) Text(c.lastResult!, style: theme.textTheme.bodyMedium),
                if (c.lastHeard == null && !_listening)
                  Text('For example: open Netflix, volume 30, pause, mute', style: theme.textTheme.bodySmall),
              ]),
            ),
          ]),
          if (_voiceError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_voiceError!, style: TextStyle(color: theme.colorScheme.error)),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _typed,
            textInputAction: TextInputAction.send,
            decoration: const InputDecoration(
              hintText: 'Or type a command',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (t) {
              if (t.trim().isEmpty) return;
              c.say(t.trim());
              _typed.clear();
            },
          ),
        ]),
      ),
    );
  }

  Widget _volumeCard(BuildContext context, TvState tv) {
    final max = tv.volumeMax.toDouble();
    final shown = (_dragVolume ?? (tv.muted ? 0 : tv.volume.toDouble())).clamp(0, max).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(children: [
          IconButton(
            tooltip: tv.muted ? 'Unmute' : 'Mute',
            onPressed: c.toggleMute,
            icon: Icon(tv.muted ? Icons.volume_off : Icons.volume_up),
          ),
          IconButton(onPressed: () => c.volumeBy(-1), icon: const Icon(Icons.remove)),
          Expanded(
            child: Slider(
              value: shown,
              max: max,
              divisions: tv.volumeMax,
              label: shown.round().toString(),
              onChanged: (v) => setState(() => _dragVolume = v),
              onChangeEnd: (v) async {
                await c.setVolume(v.round());
                if (mounted) setState(() => _dragVolume = null);
              },
            ),
          ),
          IconButton(onPressed: () => c.volumeBy(1), icon: const Icon(Icons.add)),
          SizedBox(width: 36, child: Text(tv.muted ? 'mute' : '${tv.volume}', textAlign: TextAlign.center)),
        ]),
      ),
    );
  }

  Widget _dpad(BuildContext context) {
    Widget b(IconData i, int key, {String? tip, bool big = false}) => IconButton.filledTonal(
          iconSize: big ? 36 : 28,
          tooltip: tip,
          onPressed: () => _tap(key),
          icon: Icon(i),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          b(Icons.keyboard_arrow_up, Keys.up, tip: 'Up'),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            b(Icons.keyboard_arrow_left, Keys.left, tip: 'Left'),
            const SizedBox(width: 8),
            b(Icons.circle_outlined, Keys.center, tip: 'OK', big: true),
            const SizedBox(width: 8),
            b(Icons.keyboard_arrow_right, Keys.right, tip: 'Right'),
          ]),
          b(Icons.keyboard_arrow_down, Keys.down, tip: 'Down'),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            TextButton.icon(onPressed: () => _tap(Keys.back), icon: const Icon(Icons.arrow_back), label: const Text('Back')),
            TextButton.icon(onPressed: () => _tap(Keys.home), icon: const Icon(Icons.home_outlined), label: const Text('Home')),
            TextButton.icon(onPressed: () => _tap(Keys.menu), icon: const Icon(Icons.menu), label: const Text('Menu')),
          ]),
        ]),
      ),
    );
  }

  Widget _media(BuildContext context) {
    Widget b(IconData i, int key, String tip) =>
        IconButton(iconSize: 28, tooltip: tip, onPressed: () => _tap(key), icon: Icon(i));
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          b(Icons.skip_previous, Keys.previous, 'Previous'),
          b(Icons.fast_rewind, Keys.rewind, 'Rewind'),
          b(Icons.play_arrow, Keys.playPause, 'Play or pause'),
          b(Icons.fast_forward, Keys.fastForward, 'Fast forward'),
          b(Icons.skip_next, Keys.next, 'Next'),
        ]),
      ),
    );
  }

  Widget _apps(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final app in c.apps)
            ActionChip(
              label: Text(app.name),
              onPressed: () {
                HapticFeedback.selectionClick();
                c.openApp(app);
              },
            ),
          ActionChip(
            avatar: const Icon(Icons.edit_outlined, size: 18),
            label: Text(c.apps.isEmpty ? 'Add apps' : 'Edit'),
            onPressed: _editApps,
          ),
        ]),
      ),
    );
  }
}
