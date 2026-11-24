import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../state/session.dart';
import '../actions.dart';
import '../widgets/layout.dart';

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
                leading: const Icon(Icons.dns_rounded),
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
                  leading: Icon(Icons.library_music_rounded),
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
                leading: const Icon(Icons.image_outlined),
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
              icon: const Icon(Icons.logout_rounded),
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
  const LibraryPicker({super.key, this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final current = session.library;
    return PopupMenuButton<String?>(
      tooltip: 'Choose library',
      initialValue: session.libraryId,
      onSelected: session.selectLibrary,
      itemBuilder: (context) => [
        const PopupMenuItem(value: null, child: Text('All libraries')),
        for (final l in session.libraries) PopupMenuItem(value: l.id, child: Text(l.name)),
      ],
      child: ListTile(
        dense: dense,
        leading: const Icon(Icons.library_music_rounded),
        title: Text(current?.name ?? 'All libraries', maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: dense ? null : const Text('Tap to switch'),
        trailing: const Icon(Icons.unfold_more_rounded),
      ),
    );
  }
}
