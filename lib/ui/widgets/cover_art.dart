import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../api/subsonic_client.dart';
import '../../state/session.dart';

/// Album/artist/playlist artwork with a soft generated placeholder.
class CoverArt extends StatelessWidget {
  const CoverArt({
    super.key,
    required this.id,
    this.size,
    this.radius = 8,
    this.circle = false,
    this.icon = LucideIcons.disc3,
    this.seed,
  });

  /// Subsonic `coverArt` id, may be null.
  final String? id;

  /// Pixel size to request from the server. Defaults to the laid-out size
  /// times the device pixel ratio; either way it is snapped to
  /// [SubsonicClient.coverSizes].
  final int? size;
  final double radius;
  final bool circle;
  final IconData icon;

  /// Used to pick the placeholder gradient when there is no art.
  final String? seed;

  @override
  Widget build(BuildContext context) {
    final client = context.select<SessionController, SubsonicClient?>((s) => s.isSignedIn ? s.client : null);
    final placeholder = _Placeholder(seed: seed ?? id ?? '', icon: icon);
    Widget child = placeholder;
    if (id != null && client != null) {
      child = LayoutBuilder(
        builder: (context, c) {
          final pixels = size ?? (c.maxWidth.isFinite ? c.maxWidth * MediaQuery.devicePixelRatioOf(context) : 400);
          return CachedNetworkImage(
            imageUrl: client.coverUrl(id!, size: pixels),
            cacheKey: client.coverCacheKey(id!, pixels),
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 200),
            fadeOutDuration: Duration.zero,
            placeholder: (_, _) => placeholder,
            errorWidget: (_, _, _) => placeholder,
          );
        },
      );
    }
    return AspectRatio(
      aspectRatio: 1,
      child: circle ? ClipOval(child: child) : ClipRRect(borderRadius: BorderRadius.circular(radius), child: child),
    );
  }
}

/// Image provider for the same artwork, for color extraction & backgrounds.
ImageProvider? coverProvider(BuildContext context, String? id, {int size = 400}) {
  final session = context.read<SessionController>();
  if (id == null || !session.isSignedIn) return null;
  return CachedNetworkImageProvider(
    session.client.coverUrl(id, size: size),
    cacheKey: session.client.coverCacheKey(id, size),
  );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.seed, required this.icon});

  final String seed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final hue = (seed.hashCode % 360).abs().toDouble();
    final a = HSLColor.fromAHSL(1, hue, 0.45, 0.32).toColor();
    final b = HSLColor.fromAHSL(1, (hue + 40) % 360, 0.5, 0.18).toColor();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [a, b], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: LayoutBuilder(
        builder: (context, c) => Center(
          child: Icon(icon, size: c.maxWidth * 0.36, color: Colors.white.withValues(alpha: 0.55)),
        ),
      ),
    );
  }
}
