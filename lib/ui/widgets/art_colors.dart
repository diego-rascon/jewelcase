import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'cover_art.dart';

/// Extracts a color scheme from album art (cached), for the Now Playing
/// backdrop. The rest of the app stays neutral.
class ArtColors {
  static final _cache = <String, ColorScheme>{}; // insertion-ordered: oldest first

  static ColorScheme? cached(String? coverId) => coverId == null ? null : _cache[coverId];

  static Future<ColorScheme?> resolve(BuildContext context, String? coverId) async {
    if (coverId == null) return null;
    final hit = _cache[coverId];
    if (hit != null) return hit;
    final provider = coverProvider(context, coverId, size: 150);
    if (provider == null) return null;
    try {
      final scheme = await ColorScheme.fromImageProvider(
        provider: provider,
        brightness: Brightness.dark,
        dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
      );
      _cache[coverId] = scheme;
      if (_cache.length > 64) _cache.remove(_cache.keys.first);
      return scheme;
    } catch (_) {
      return null;
    }
  }
}

/// Rebuilds with the art-derived scheme once it is ready, animating changes.
class ArtTinted extends StatefulWidget {
  const ArtTinted({super.key, required this.coverId, required this.builder});

  final String? coverId;
  final Widget Function(BuildContext context, ColorScheme? scheme) builder;

  @override
  State<ArtTinted> createState() => _ArtTintedState();
}

class _ArtTintedState extends State<ArtTinted> {
  ColorScheme? _scheme;

  @override
  void initState() {
    super.initState();
    _scheme = ArtColors.cached(widget.coverId);
    unawaited(_resolve());
  }

  @override
  void didUpdateWidget(ArtTinted old) {
    super.didUpdateWidget(old);
    if (old.coverId != widget.coverId) unawaited(_resolve());
  }

  // The previous scheme stays up until the new one is ready, so the colors
  // change once. A cover without usable art falls back to the neutral look.
  Future<void> _resolve() async {
    final id = widget.coverId;
    final scheme = await ArtColors.resolve(context, id);
    if (mounted && id == widget.coverId && scheme != _scheme) setState(() => _scheme = scheme);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _scheme);
}
