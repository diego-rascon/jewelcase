import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/models.dart';
import '../../audio/player_controller.dart';
import '../../state/favorites.dart';
import '../actions.dart';
import '../format.dart';
import '../theme.dart';
import 'cover_art.dart';

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({super.key, required this.id, required this.kind, this.size = 22, this.color});

  final String id;
  final FavoriteKind kind;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isFav = context.select<FavoritesController, bool>((f) => f.isFavorite(id));
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
      iconSize: size,
      onPressed: () => guarded(context, () => context.read<FavoritesController>().toggle(id, kind)),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
        child: Icon(
          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          key: ValueKey(isFav),
          color: isFav ? scheme.primary : color,
        ),
      ),
    );
  }
}

/// One row in a track list. Shows the track number (or artwork), title,
/// artist, and on wide screens the album and duration columns.
class SongTile extends StatefulWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.number,
    this.showCover = true,
    this.showAlbum = true,
    this.showArtist = true,
    this.extraActions = const [],
  });

  final Song song;
  final VoidCallback onTap;
  final int? number;
  final bool showCover;
  final bool showAlbum;
  final bool showArtist;
  final List<MenuAction> extraActions;

  @override
  State<SongTile> createState() => _SongTileState();
}

class _SongTileState extends State<SongTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final wide = isWide(context);
    final isCurrent = context.select<PlayerController, bool>((p) => p.current?.id == song.id);
    final isFav = context.select<FavoritesController, bool>((f) => f.isFavorite(song.id));
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    List<MenuAction> actions() => songActions(context, song, extra: widget.extraActions);

    Widget leading;
    if (widget.showCover) {
      leading = SizedBox(
        width: 44,
        child: Stack(
          children: [
            CoverArt(id: song.coverArt, seed: song.albumId, radius: 6),
            if (isCurrent)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                  child: Icon(Icons.graphic_eq_rounded, color: scheme.primary),
                ),
              ),
          ],
        ),
      );
    } else {
      leading = SizedBox(
        width: 32,
        child: Center(
          child: isCurrent
              ? Icon(Icons.graphic_eq_rounded, color: scheme.primary, size: 20)
              : _hover
              ? const Icon(Icons.play_arrow_rounded, size: 20)
              : Text('${widget.number ?? song.track ?? ''}', style: muted),
        ),
      );
    }

    return ContextMenuRegion(
      actions: actions,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Material(
          color: _hover ? scheme.onSurface.withValues(alpha: 0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  leading,
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: isCurrent ? scheme.primary : null,
                          ),
                        ),
                        if (widget.showArtist && song.artist != null)
                          Text(song.artist!, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
                      ],
                    ),
                  ),
                  if (wide && widget.showAlbum && song.album != null) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: Text(song.album!, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
                    ),
                  ],
                  if (wide)
                    Opacity(
                      opacity: _hover || isFav ? 1 : 0,
                      child: FavoriteButton(id: song.id, kind: FavoriteKind.song, size: 18),
                    ),
                  if (wide)
                    SizedBox(
                      width: 52,
                      child: Text(formatDuration(song.duration), style: muted, textAlign: TextAlign.right),
                    ),
                  MoreButton(actions: actions),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
