import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../state/session.dart';
import '../actions.dart';
import '../format.dart';
import '../widgets/async_view.dart';
import '../widgets/cover_art.dart';
import '../widgets/layout.dart';

/// Alphabetical artist list with a quick A–Z jump strip.
class ArtistsScreen extends StatelessWidget {
  const ArtistsScreen({super.key, this.showTitle = true});

  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: AsyncView<List<Artist>>(
          deps: [session.libraryId],
          load: () => session.client.getArtists(musicFolderId: session.libraryId),
          builder: (context, artists, reload) => artists.isEmpty
              ? const EmptyState(icon: Icons.person_outline_rounded, title: 'No artists found')
              : _ArtistList(artists: artists, showTitle: showTitle),
        ),
      ),
    );
  }
}

class _ArtistList extends StatefulWidget {
  const _ArtistList({required this.artists, required this.showTitle});

  final List<Artist> artists;
  final bool showTitle;

  @override
  State<_ArtistList> createState() => _ArtistListState();
}

class _ArtistListState extends State<_ArtistList> {
  static const _rowHeight = 68.0;
  final _scroll = ScrollController();
  late List<Artist> _sorted;
  late Map<String, int> _letterIndex;

  @override
  void initState() {
    super.initState();
    _index();
  }

  @override
  void didUpdateWidget(_ArtistList old) {
    super.didUpdateWidget(old);
    if (old.artists != widget.artists) _index();
  }

  static String _letter(String name) {
    final c = name.trim().isEmpty ? '#' : name.trim()[0].toUpperCase();
    return RegExp('[A-Z]').hasMatch(c) ? c : '#';
  }

  void _index() {
    _sorted = [...widget.artists]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _letterIndex = {};
    for (final (i, a) in _sorted.indexed) {
      _letterIndex.putIfAbsent(_letter(a.name), () => i);
    }
  }

  void _jump(String letter) {
    final i = _letterIndex[letter];
    if (i == null) return;
    _scroll.jumpTo((i * _rowHeight).clamp(0, _scroll.position.maxScrollExtent));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pad = pagePadding(context);
    return Row(
      children: [
        Expanded(
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              if (widget.showTitle)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(pad, 24, pad, 16),
                  sliver: SliverToBoxAdapter(child: Text('Artists', style: theme.textTheme.headlineMedium)),
                ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(pad - 10, 8, pad - 10, 32),
                sliver: SliverFixedExtentList.builder(
                  itemExtent: _rowHeight,
                  itemCount: _sorted.length,
                  itemBuilder: (context, i) => _ArtistRow(artist: _sorted[i]),
                ),
              ),
            ],
          ),
        ),
        _LetterStrip(letters: _letterIndex.keys.toList()..sort(), onLetter: _jump),
      ],
    );
  }
}

class _ArtistRow extends StatelessWidget {
  const _ArtistRow({required this.artist});

  final Artist artist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ContextMenuRegion(
      actions: () => artistActions(context, artist),
      child: ListTile(
        onTap: () => openArtist(context, artist.id),
        leading: SizedBox(
          width: 48,
          child: CoverArt(id: artist.coverArt, seed: artist.id, circle: true, icon: Icons.person_rounded),
        ),
        title: Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
        subtitle: artist.albumCount > 0 ? Text(plural(artist.albumCount, 'album')) : null,
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

/// Vertical A–Z strip; tap or drag to jump.
class _LetterStrip extends StatelessWidget {
  const _LetterStrip({required this.letters, required this.onLetter});

  final List<String> letters;
  final ValueChanged<String> onLetter;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700);
    return LayoutBuilder(
      builder: (context, c) {
        void hit(double dy) {
          if (letters.isEmpty) return;
          final i = (dy / c.maxHeight * letters.length).floor().clamp(0, letters.length - 1);
          onLetter(letters[i]);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => hit(d.localPosition.dy),
          onVerticalDragUpdate: (d) => hit(d.localPosition.dy),
          child: SizedBox(
            width: 28,
            // Equal-height cells so the drag position maps directly to a letter.
            child: Column(
              children: [
                for (final l in letters)
                  Expanded(
                    child: Center(child: Text(l, style: style)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
