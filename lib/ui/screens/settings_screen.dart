import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../state/session.dart';
import '../actions.dart';
import '../widgets/layout.dart';
import '../widgets/popup_menu.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final creds = session.credentials;
    final theme = Theme.of(context);
    final pad = pagePadding(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(pad - 8, 8, pad - 8, 8 + bottomInset(context)),
        children: [
          _Group(
            title: 'Server',
            children: [
              ListTile(
                leading: const Icon(LucideIcons.server),
                title: Text(creds?.baseUrl ?? ''),
                subtitle: Text('Signed in as ${creds?.username ?? ''}'),
              ),
            ],
          ),
          _Group(
            title: 'Library',
            children: [
              if (session.libraries.length < 2)
                const ListTile(
                  leading: Icon(LucideIcons.libraryBig),
                  title: Text('All music'),
                  subtitle: Text('Your server has a single library'),
                )
              else
                const LibraryPicker(),
            ],
          ),
          _Group(
            title: 'Storage',
            children: [
              ListTile(
                leading: const Icon(LucideIcons.image),
                title: const Text('Clear artwork cache'),
                onTap: () => guarded(context, () async {
                  await DefaultCacheManager().emptyCache();
                  PaintingBinding.instance.imageCache.clear();
                }, success: 'Artwork cache cleared'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () async {
                Navigator.of(context).popUntil((r) => r.isFirst);
                await session.signOut();
              },
              icon: const Icon(LucideIcons.logOut),
              label: const Text('Sign out'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(letterSpacing: 1.4, color: theme.colorScheme.primary),
            ),
          ),
          Material(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

/// Lets the user scope browsing to one Navidrome library (music folder).
class LibraryPicker extends StatelessWidget {
  const LibraryPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final current = session.library;
    return Builder(
      builder: (context) => ListTile(
        leading: const Icon(LucideIcons.libraryBig),
        title: Text(current?.name ?? 'All libraries', maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: const Text('Tap to switch'),
        trailing: const Icon(LucideIcons.chevronsUpDown),
        onTap: () => unawaited(_pick(context, session)),
      ),
    );
  }

  Future<void> _pick(BuildContext context, SessionController session) async {
    MenuAction choice(String? id, String label) => MenuAction(
      label,
      id == session.libraryId ? LucideIcons.check : null,
      () => unawaited(guarded(context, () => session.selectLibrary(id))),
    );
    final picked = await pickMenuAction(context, globalRect(context), [
      choice(null, 'All libraries'),
      for (final l in session.libraries) choice(l.id, l.name),
    ]);
    if (context.mounted) picked?.onSelected();
  }
}
