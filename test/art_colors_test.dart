import 'package:flutter_test/flutter_test.dart';
import 'package:jewelcase/ui/widgets/art_colors.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

void main() {
  group('pickAccent', () {
    test('picks a small colorful area over a large faintly tinted dark one', () {
      // A black cover whose compression noise leaves a pinkish tint, with
      // some gold in it.
      const tintedBlack = 0xFF1C1018;
      const gold = 0xFFC9A04A;
      const silver = 0xFFB8B8BC;
      final accent = pickAccent({tintedBlack: 7000, silver: 2000, gold: 1000});
      expect(accent, isNotNull);
      expect(Hct.fromInt(accent!).hue, closeTo(Hct.fromInt(gold).hue, 15));
    });

    test('picks a dim color on mostly black art', () {
      // A spotlit stage: a dark blue beam on black.
      const darkBlue = 0xFF14236B;
      final accent = pickAccent({0xFF01010A: 9850, darkBlue: 150});
      expect(accent, isNotNull);
      expect(Hct.fromInt(accent!).hue, closeTo(Hct.fromInt(darkBlue).hue, 15));
    });

    test('has no accent for black-and-white art', () {
      expect(pickAccent({0xFF000000: 6000, 0xFFFFFFFF: 3000, 0xFF808082: 1000}), isNull);
    });

    test('has no accent when the color is only a speck', () {
      expect(pickAccent({0xFF101010: 9950, 0xFFE03030: 50}), isNull);
    });

    test('has no accent for an empty image', () {
      expect(pickAccent({}), isNull);
    });
  });

  group('ArtPalette', () {
    test('colorful art glows its accent and tints the accents', () {
      final palette = ArtPalette.fromPopulation({0xFF101010: 8000, 0xFFC9A04A: 2000});
      expect(palette.accent, isNotNull);
      expect(Hct.fromInt(palette.glow.toARGB32()).chroma, greaterThan(16));
    });

    test('white colorless art glows white, with neutral accents', () {
      final palette = ArtPalette.fromPopulation({0xFFF8F8F8: 9000, 0xFF101010: 1000});
      expect(palette.accent, isNull);
      final glow = palette.glow;
      expect(Hct.fromInt(glow.toARGB32()).tone, greaterThan(80));
      // A true gray.
      expect(glow.r, glow.g);
      expect(glow.g, glow.b);
    });

    test('sepia art glows its faint warm tint', () {
      // Beige and brown tones, too muted to be an accent.
      final palette = ArtPalette.fromPopulation({0xFF1C1C1C: 4000, 0xFF73715E: 3000, 0xFFD5D3BB: 3000});
      expect(palette.accent, isNull);
      final glow = Hct.fromInt(palette.glow.toARGB32());
      expect(glow.hue, closeTo(Hct.fromInt(0xFF73715E).hue, 20));
      expect(glow.chroma, greaterThan(5));
    });

    test('dark colorless art has no glow', () {
      final palette = ArtPalette.fromPopulation({0xFF050505: 9000, 0xFF909090: 1000});
      expect(palette.accent, isNull);
      expect(palette.glow.a, 0);
    });
  });

  test('schemeForAccent keeps the hue', () {
    const gold = 0xFFC9A04A;
    final scheme = schemeForAccent(gold);
    expect(Hct.fromInt(scheme.primary.toARGB32()).hue, closeTo(Hct.fromInt(gold).hue, 15));
  });
}
