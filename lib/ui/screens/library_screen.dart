import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../navigation.dart';
import '../widgets/layout.dart';
import 'albums_screen.dart';
import 'artists_screen.dart';
import 'playlists_screen.dart';

/// Phone-only: albums, artists and playlists as tabs under one destination.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pad = pagePadding(context);
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 3,
      initialIndex: context.read<NavController>().libraryTab,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(pad, 24, pad, 8),
                child: Text('Library', style: theme.textTheme.headlineMedium),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: pad - 12),
                child: const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(text: 'Albums'),
                    Tab(text: 'Artists'),
                    Tab(text: 'Playlists'),
                  ],
                ),
              ),
              const Expanded(
                child: TabBarView(
                  children: [
                    AlbumsScreen(showTitle: false),
                    ArtistsScreen(showTitle: false),
                    PlaylistsScreen(showTitle: false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
