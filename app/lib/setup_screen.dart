import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tv_remote_core/tv_remote_core.dart';

import 'branding.dart';
import 'controller.dart';

/// First run: find the TV (scan or typed address), then pair with the code the TV shows.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.controller});
  final TvController controller;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _ip = TextEditingController();
  final _code = TextEditingController();
  List<FoundTv> _found = [];
  bool _searching = false;
  String? _busy; // a message while something is running
  String? _error;
  Pairing? _pairing;
  Identity? _identity;
  String? _host;

  @override
  void dispose() {
    _pairing?.cancel();
    _ip.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _searching = true;
      _error = null;
      _found = [];
    });
    final results = <String, FoundTv>{};
    for (final tv in await discoverMdns(timeout: const Duration(seconds: 3))) {
      results[tv.host] = tv;
    }
    for (final tv in await scanSubnet()) {
      results.putIfAbsent(tv.host, () => tv);
    }
    final searched = (await localPrefixes()).map((p) => '$p.*').join(', ');
    if (!mounted) return;
    setState(() {
      _found = results.values.toList();
      _searching = false;
      if (_found.isEmpty) {
        _error = 'No TV found'
            '${searched.isEmpty ? ' (this phone has no Wi-Fi address: is Wi-Fi on?)' : ' (looked at $searched)'}. '
            'Make sure the TV is on and on the same Wi-Fi, or type its address (TV Settings > Network).'
            '${Platform.isIOS ? ' On iPhone, also check Settings > SayTV > Local Network is on.' : ''}';
      }
    });
  }

  Future<void> _startPairing(String host) async {
    setState(() {
      _busy = 'Preparing a secure key (a few seconds the first time)...';
      _error = null;
    });
    try {
      _identity ??= await widget.controller.store.loadIdentity() ?? await Identity.generate();
      if (!mounted) return;
      setState(() => _busy = 'Contacting the TV...');
      _pairing = await Pairing.begin(host, _identity!, clientName: appName);
      _host = host;
      if (!mounted) return;
      setState(() => _busy = null);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = null;
        _error = 'Could not reach the TV at $host. Is it on, and is it an Android TV on this Wi-Fi? ($e)';
      });
    }
  }

  Future<void> _finish() async {
    setState(() {
      _busy = 'Pairing...';
      _error = null;
    });
    try {
      await _pairing!.finish(_code.text);
      await widget.controller.setPaired(_identity!, _host!, pin: _pairing!.tvFingerprint);
    } on PairingException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = null;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = null;
        _error = 'Pairing failed: $e';
      });
    }
  }

  void _cancelPairing() {
    _pairing?.cancel();
    setState(() {
      _pairing = null;
      _code.clear();
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Connect your TV')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_busy != null) ...[
              const SizedBox(height: 48),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
              Center(child: Text(_busy!, textAlign: TextAlign.center)),
            ] else if (_pairing != null) ...[
              Text('Enter the code shown on your TV', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('The TV shows "Device pairing request" with six letters or digits.'),
              const SizedBox(height: 16),
              TextField(
                controller: _code,
                autofocus: true,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F]')),
                  TextInputFormatter.withFunction((o, n) => n.copyWith(text: n.text.toUpperCase())),
                ],
                style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: 6),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                onSubmitted: (_) => _finish(),
              ),
              if (_error != null) _ErrorText(_error!),
              const SizedBox(height: 8),
              FilledButton(onPressed: _finish, child: const Text('Pair')),
              TextButton(onPressed: _cancelPairing, child: const Text('Cancel')),
            ] else ...[
              Text('Find your TV', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('Your phone and TV must be on the same Wi-Fi, with the TV switched on.'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _searching ? null : _search,
                icon: _searching
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.search),
                label: Text(_searching ? 'Searching...' : 'Search my network'),
              ),
              for (final tv in _found)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.tv),
                    title: Text(tv.name ?? 'Android TV'),
                    subtitle: Text(tv.host),
                    onTap: () => _startPairing(tv.host),
                  ),
                ),
              const SizedBox(height: 24),
              const Text('Or type the TV\'s address'),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _ip,
                    // The decimal pad has a dot key on iPhone; the plain number pad does not. Some regions show a comma instead, so turn it into a dot.
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      TextInputFormatter.withFunction((o, n) => n.copyWith(text: n.text.replaceAll(',', '.'))),
                    ],
                    decoration: const InputDecoration(hintText: '192.168.1.20', border: OutlineInputBorder()),
                    onSubmitted: (v) => v.trim().isEmpty ? null : _startPairing(v.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _ip.text.trim().isEmpty ? null : _startPairing(_ip.text.trim()),
                  child: const Text('Connect'),
                ),
              ]),
              if (_error != null) _ErrorText(_error!),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      );
}
