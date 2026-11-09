import 'package:flutter/material.dart';
import 'package:tv_remote_core/tv_remote_core.dart';

import 'controller.dart';
import 'layout.dart';

/// Lets the user choose which apps appear as buttons and answer to "open NAME": add suggested or own apps, rename, reorder, remove.
class AppsScreen extends StatelessWidget {
  const AppsScreen({super.key, required this.controller});
  final TvController controller;

  TvController get c => controller;

  Future<void> _edit(BuildContext context, {AppEntry? existing}) async {
    final others = [for (final a in c.apps) if (a.id != existing?.id) a];
    final result = await showDialog<AppEntry>(
      context: context,
      builder: (_) => _AppDialog(existing: existing, others: others),
    );
    if (result == null) return;
    if (existing == null) {
      await c.addApp(result);
    } else {
      await c.setApps([for (final a in c.apps) a.id == existing.id ? result : a]);
    }
  }

  Future<void> _remove(BuildContext context, AppEntry app) async {
    final index = c.apps.indexWhere((a) => a.id == app.id);
    await c.setApps([for (final a in c.apps) if (a.id != app.id) a]);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Removed ${app.name}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            final list = [...c.apps];
            list.insert(index.clamp(0, list.length), app);
            c.setApps(list);
          },
        ),
      ));
  }

  Future<void> _confirmReset(BuildContext context) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore the original list?'),
        content: const Text('Your changes to the app list will be replaced by the apps the app came with.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
        ],
      ),
    );
    if (go == true) await c.resetApps();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final have = c.apps.map((a) => a.package).toSet();
        final suggestions = [for (final a in c.catalog) if (!have.contains(a.package)) a];
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Your apps'),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'reset') _confirmReset(context);
                },
                itemBuilder: (_) => const [PopupMenuItem(value: 'reset', child: Text('Restore the original list'))],
              ),
            ],
          ),
          body: SafeArea(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: EdgeInsets.fromLTRB(sidePadding(context, min: 8), 0, sidePadding(context, min: 8), 32),
              header: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  c.apps.isEmpty
                      ? 'No apps yet. Add some below.'
                      : 'These are the buttons on the remote. Say "open" and the name to open one by voice. Drag to change the order, tap to edit.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              footer: _footer(context, suggestions),
              itemCount: c.apps.length,
              onReorderItem: (from, to) {
                final list = [...c.apps];
                list.insert(to, list.removeAt(from));
                c.setApps(list);
              },
              itemBuilder: (context, i) {
                final app = c.apps[i];
                return ListTile(
                  key: ValueKey(app.id),
                  leading: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle)),
                  title: Text(app.name),
                  subtitle: Text(
                    app.say.isEmpty ? '${app.package}\nNo spoken name: button only' : '${app.package}\nSay: open ${app.say.first}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    tooltip: 'Remove ${app.name}',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _remove(context, app),
                  ),
                  onTap: () => _edit(context, existing: app),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _footer(BuildContext context, List<AppEntry> suggestions) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (suggestions.isNotEmpty) ...[
          Text('Suggestions', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final a in suggestions)
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: Text(a.name),
                onPressed: () => c.addApp(a),
              ),
          ]),
          const SizedBox(height: 16),
        ],
        FilledButton.tonalIcon(
          onPressed: () => _edit(context),
          icon: const Icon(Icons.add),
          label: const Text('Add your own app'),
        ),
        const SizedBox(height: 8),
        Text(
          'Any app installed on the TV can be added. You need its package name: it is the part after "id=" in the app\'s Play Store web address.',
          style: theme.textTheme.bodySmall,
        ),
      ]),
    );
  }
}

class _AppDialog extends StatefulWidget {
  const _AppDialog({required this.existing, required this.others});
  final AppEntry? existing;
  final List<AppEntry> others;

  @override
  State<_AppDialog> createState() => _AppDialogState();
}

class _AppDialogState extends State<_AppDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _package = TextEditingController(text: widget.existing?.package ?? '');
  late final TextEditingController _extra = TextEditingController(text: _initialExtra());
  String? _error;

  String _initialExtra() {
    final e = widget.existing;
    if (e == null) return '';
    return e.say.where((s) => normalize(s) != normalize(e.name)).join(', ');
  }

  @override
  void dispose() {
    _name.dispose();
    _package.dispose();
    _extra.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final pkg = _package.text.trim();
    final extra = _extra.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final say = AppEntry.buildSay(name, extra);
    String? err;
    if (name.isEmpty) {
      err = 'Give the app a name.';
    } else if (name.length > 24) {
      err = 'Keep the name to 24 characters or fewer.';
    } else if (!isValidPackage(pkg)) {
      err = 'That package name does not look right. It is the part after "id=" in the app\'s Play Store address, for example com.netflix.ninja.';
    } else if (widget.others.any((a) => a.package == pkg)) {
      err = '${widget.others.firstWhere((a) => a.package == pkg).name} already uses this package.';
    } else if (say.isEmpty) {
      err = 'Add a name you can say, in English letters, so "open ..." can find the app.';
    } else {
      for (final s in say) {
        if (PhraseParser.isReserved(s)) {
          err = '"$s" already means a TV command. Pick another name.';
          break;
        }
        final used = appUsingName(widget.others, s);
        if (used != null) {
          err = '"$s" already opens ${used.name}. Pick another name.';
          break;
        }
      }
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    final entry = widget.existing == null
        ? AppEntry.custom(name: name, package: pkg, extraSay: extra, takenIds: widget.others.map((a) => a.id))
        : widget.existing!.copyWith(name: name, package: pkg, say: say);
    Navigator.pop(context, entry);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return AlertDialog(
      title: Text(editing ? 'Edit app' : 'Add an app'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            key: const Key('app-name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name on the button'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('app-package'),
            controller: _package,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.none,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'Package name', hintText: 'com.example.app'),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('app-extra'),
            controller: _extra,
            decoration: const InputDecoration(
              labelText: 'Also answers to (optional)',
              helperText: 'Other names you might say, separated by commas',
              helperMaxLines: 2,
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
