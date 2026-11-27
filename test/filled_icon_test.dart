import 'package:flutter_test/flutter_test.dart';
import 'package:jewelcase/ui/widgets/filled_icon.dart';
import 'package:material_ui/material_ui.dart';

void expectBounds(Path path, Rect expected) {
  final b = path.getBounds();
  for (final (actual, want) in [
    (b.left, expected.left),
    (b.top, expected.top),
    (b.right, expected.right),
    (b.bottom, expected.bottom),
  ]) {
    expect(actual, closeTo(want, 0.05));
  }
}

void main() {
  test('parses absolute and relative lines, H/V and implicit line-tos', () {
    expectBounds(parseSvgPath('M1 2 4 2v3H1z'), const Rect.fromLTRB(1, 2, 4, 5));
    expectBounds(parseSvgPath('m1 2 3 0 0 3-3 0z'), const Rect.fromLTRB(1, 2, 4, 5));
  });

  test('reads compact numbers and packed arc flags', () {
    // ".5.5" is two numbers; "011" is two flags then the number 1.
    expectBounds(parseSvgPath('M0 0h.5.5'), const Rect.fromLTRB(0, 0, 1, 0));
    expectBounds(parseSvgPath('M0 0a1 1 0 011 1'), const Rect.fromLTRB(0, 0, 1, 1));
  });

  test('mirrors the previous control point for S', () {
    final s = parseSvgPath('M0 0C0 2 2 2 2 0S4-2 4 0');
    final c = parseSvgPath('M0 0C0 2 2 2 2 0C2-2 4-2 4 0');
    expectBounds(s, c.getBounds());
  });

  test('every filled icon parses and fits the 24px grid', () {
    for (final icon in [
      FilledIcons.star,
      FilledIcons.play,
      FilledIcons.pause,
      FilledIcons.skipBack,
      FilledIcons.skipForward,
    ]) {
      final b = icon.path.getBounds();
      expect(const Rect.fromLTRB(0, 0, 24, 24).contains(b.topLeft) && b.right <= 24 && b.bottom <= 24, isTrue);
    }
    expectBounds(FilledIcons.pause.path, const Rect.fromLTRB(5, 3, 19, 21));
  });

  test('rejects malformed data', () {
    expect(() => parseSvgPath('1 2'), throwsFormatException);
    expect(() => parseSvgPath('M0 0a1 1 0 2 1 1 1'), throwsFormatException);
    expect(() => parseSvgPath('M0 0X'), throwsFormatException);
  });
}
