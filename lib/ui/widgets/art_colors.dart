import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:material_ui/material_ui.dart';

import 'cover_art.dart';

/// The colors a cover lends the UI around it.
@immutable
class ArtPalette {
  const ArtPalette({this.accent, required this.glow});

  /// From a quantized cover ([QuantizerResult.colorToCount]).
  factory ArtPalette.fromPopulation(Map<int, int> population) {
    final accent = pickAccent(population);
    return ArtPalette(
      accent: accent == null ? null : schemeForAccent(accent),
      glow: accent == null ? neutralGlow(population) : accentGlow(accent),
    );
  }

  /// A dark scheme around the art's accent color, or `null` for art with no
  /// real color, which keeps the app's neutral (white) accents.
  final ColorScheme? accent;

  /// The light the art casts behind it: its accent, or for colorless art the
  /// average color of its lit parts ([neutralGlow]). Transparent for dark
  /// colorless art.
  final Color glow;
}

/// Extracts an [ArtPalette] from album art (cached), for the Now Playing
/// backdrop and the album and playlist page headers. The rest of the app
/// stays neutral.
class ArtColors {
  /// Insertion-ordered, oldest first.
  static final _cache = <String, ArtPalette>{};

  static ArtPalette? cached(String? coverId) => coverId == null ? null : _cache[coverId];

  static Future<ArtPalette?> resolve(BuildContext context, String? coverId) async {
    if (coverId == null) return null;
    final hit = _cache[coverId];
    if (hit != null) return hit;
    final provider = coverProvider(context, coverId, size: 150);
    if (provider == null) return null;
    try {
      final pixels = await _argbPixels(provider);
      final quantized = await QuantizerCelebi().quantize(pixels, 128);
      final palette = ArtPalette.fromPopulation(quantized.colorToCount);
      _cache[coverId] = palette;
      if (_cache.length > 64) _cache.remove(_cache.keys.first);
      return palette;
    } catch (_) {
      // Not cached: the art may load next time.
      return null;
    }
  }

  /// The image's pixels as ARGB ints.
  static Future<List<int>> _argbPixels(ImageProvider provider) async {
    final done = Completer<ui.Image>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        if (!done.isCompleted) done.complete(info.image);
      },
      onError: (e, st) {
        stream.removeListener(listener);
        if (!done.isCompleted) done.completeError(e, st);
      },
    );
    stream.addListener(listener);
    final image = await done.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        stream.removeListener(listener);
        throw TimeoutException('Cover art took too long to load');
      },
    );
    final bytes = await image.toByteData();
    if (bytes == null) throw StateError('Cover art has no pixel data');
    final rgba = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    return [
      for (var i = 0; i + 3 < rgba.length; i += 4)
        (rgba[i + 3] << 24) | (rgba[i] << 16) | (rgba[i + 1] << 8) | rgba[i + 2],
    ];
  }
}

/// The art's accent: its most prominent real color, from a quantized
/// [population] (ARGB color → pixel count). `null` when the art has none.
///
/// Material's own scoring ([ColorScheme.fromImageProvider]) weighs every
/// color by how much of the image it covers, so a large near-black or
/// near-white area with a faint tint from compression noise outranks a
/// smaller, truly colorful one: a black cover with gold in it comes out pink.
/// So near-black, near-white and grayish colors are dropped first, and art
/// that's (almost) all of those has no accent and keeps the neutral look.
int? pickAccent(Map<int, int> population) {
  var total = 0;
  var colorfulTotal = 0;
  final colorful = <int, int>{};
  for (final MapEntry(key: argb, value: count) in population.entries) {
    total += count;
    final hct = Hct.fromInt(argb);
    if (hct.tone < _minTone || hct.tone > _maxTone || hct.chroma < _minChroma) continue;
    colorful[argb] = count;
    colorfulTotal += count;
  }
  if (total == 0 || colorfulTotal / total < _minColorfulShare) return null;
  final best = Score.score(colorful, desired: 1, fallbackColorARGB: 0).first;
  return best == 0 ? null : best;
}

const _minTone = 10.0;
const _maxTone = 90.0;
const _minChroma = 16.0;

/// How much of the art must be colorful for it to have an accent.
const _minColorfulShare = 0.01;

/// The lowest chroma an accent is shown with, so a muted one still reads as
/// a color next to the neutral UI.
const _minAccentChroma = 32.0;

/// Colorless art glows with the average color of its lit parts (tone at
/// least [_litTone]), faint tint and all: a white cover glows white, a sepia
/// one warm beige. Lifted to [_minGlowTone] so it shows against the dark
/// page. Transparent when under [_minLitShare] of the art is lit.
Color neutralGlow(Map<int, int> population) {
  var total = 0;
  var lit = 0;
  var r = 0.0, g = 0.0, b = 0.0;
  for (final MapEntry(key: argb, value: count) in population.entries) {
    total += count;
    if (Hct.fromInt(argb).tone < _litTone) continue;
    lit += count;
    r += (argb >> 16 & 0xFF) * count;
    g += (argb >> 8 & 0xFF) * count;
    b += (argb & 0xFF) * count;
  }
  if (total == 0 || lit / total < _minLitShare) return const Color(0x00000000);
  final average = Color.fromARGB(255, (r / lit).round(), (g / lit).round(), (b / lit).round());
  final hct = Hct.fromInt(average.toARGB32());
  return hct.tone >= _minGlowTone ? average : Color(Hct.from(hct.hue, hct.chroma, _minGlowTone).toInt());
}

const _litTone = 20.0;
const _minLitShare = 0.15;

/// The accent, lifted to at least [_minGlowTone] so a dark one still shows
/// against the dark page.
Color accentGlow(int accent) {
  final hct = Hct.fromInt(accent);
  return Color(Hct.from(hct.hue, math.max(hct.chroma, _minAccentChroma), math.max(hct.tone, _minGlowTone)).toInt());
}

const _minGlowTone = 40.0;

/// A dark scheme that keeps [accent]'s hue and (at least [_minAccentChroma])
/// its chroma, rather than exaggerating it as the vibrant variant does.
ColorScheme schemeForAccent(int accent) {
  final hct = Hct.fromInt(accent);
  final seed = Hct.from(hct.hue, math.max(hct.chroma, _minAccentChroma), hct.tone);
  return ColorScheme.fromSeed(
    seedColor: Color(seed.toInt()),
    brightness: Brightness.dark,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
}

/// Rebuilds with the art-derived scheme once it is ready, animating changes.
class ArtTinted extends StatefulWidget {
  const ArtTinted({super.key, required this.coverId, required this.builder});

  final String? coverId;
  final Widget Function(BuildContext context, ArtPalette? palette) builder;

  @override
  State<ArtTinted> createState() => _ArtTintedState();
}

class _ArtTintedState extends State<ArtTinted> {
  ArtPalette? _palette;

  @override
  void initState() {
    super.initState();
    _palette = ArtColors.cached(widget.coverId);
    unawaited(_resolve());
  }

  @override
  void didUpdateWidget(ArtTinted old) {
    super.didUpdateWidget(old);
    if (old.coverId != widget.coverId) unawaited(_resolve());
  }

  // The previous palette stays up until the new one is ready, so the colors
  // change once. A cover without usable art falls back to the neutral look.
  Future<void> _resolve() async {
    final id = widget.coverId;
    final palette = await ArtColors.resolve(context, id);
    if (mounted && id == widget.coverId && palette != _palette) setState(() => _palette = palette);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _palette);
}
