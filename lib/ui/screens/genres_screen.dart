import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../state/session.dart';
import '../widgets/async_view.dart';
import '../widgets/layout.dart';
import '../widgets/media_cards.dart';

/// Every genre in the selected library, as cards that open the genre's
/// albums. The genres are counted from the album list (see [genresOf]), so
/// each card's count matches its page.
class GenresScreen extends StatelessWidget {
  const GenresScreen({super.key, this.showTitle = true});

  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final theme = Theme.of(context);
    final pad = pagePadding(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: AsyncView<List<Genre>>(
          deps: [session.libraryId],
          load: () async => genresOf(await session.client.getAllAlbums(musicFolderId: session.libraryId)),
          builder: (context, genres, reload) => RefreshIndicator(
            onRefresh: reload,
            child: CustomScrollView(
              slivers: [
                if (showTitle)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, 24, pad, 20),
                    sliver: SliverToBoxAdapter(child: Text('Genres', style: theme.textTheme.headlineMedium)),
                  )
                else
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                if (genres.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(icon: LucideIcons.tags, title: 'No genres found'),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, 0, pad, 32),
                    sliver: SliverLayoutBuilder(
                      builder: (context, c) => SliverGrid.builder(
                        gridDelegate: cardGrid(c.crossAxisExtent),
                        itemCount: genres.length,
                        itemBuilder: (context, i) => GenreCard(genre: genres[i]),
                      ),
                    ),
                  ),
                const BottomInset(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
