import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

/// Lucide icons that can be drawn filled. Lucide ships outlines only, so each
/// icon here pairs its outline glyph with its SVG path data copied from
/// lucide.dev (a `<rect>` rewritten as a path). The path is painted filled and
/// stroked at Lucide's 2px width, so it keeps the outline's size and rounded
/// corners. To add one, add an entry here.
abstract final class FilledIcons {
  static const star = FilledIconData(
    LucideIcons.star,
    'M11.525 2.295a.53.53 0 0 1 .95 0l2.31 4.679a2.123 2.123 0 0 0 1.595 1.16l5.166.756'
    'a.53.53 0 0 1 .294.904l-3.736 3.638a2.123 2.123 0 0 0-.611 1.878l.882 5.14a.53.53 0 0 1-.771.56'
    'l-4.618-2.428a2.122 2.122 0 0 0-1.973 0L6.396 21.01a.53.53 0 0 1-.77-.56l.881-5.139'
    'a2.122 2.122 0 0 0-.611-1.879L2.16 9.795a.53.53 0 0 1 .294-.906l5.165-.755a2.122 2.122 0 0 0 1.597-1.16z',
  );
  static const play = FilledIconData(
    LucideIcons.play,
    'M5 5a2 2 0 0 1 3.008-1.728l11.997 6.998a2 2 0 0 1 .003 3.458l-12 7A2 2 0 0 1 5 19z',
  );
  static const pause = FilledIconData(
    LucideIcons.pause,
    'M6 3h3a1 1 0 0 1 1 1v16a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1z'
    'M15 3h3a1 1 0 0 1 1 1v16a1 1 0 0 1-1 1h-3a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1z',
  );
  static const skipBack = FilledIconData(
    LucideIcons.skipBack,
    'M17.971 4.285A2 2 0 0 1 21 6v12a2 2 0 0 1-3.029 1.715l-9.997-5.998a2 2 0 0 1-.003-3.432zM3 20V4',
  );
  static const skipForward = FilledIconData(
    LucideIcons.skipForward,
    'M21 4v16M6.029 4.285A2 2 0 0 0 3 6v12a2 2 0 0 0 3.029 1.715l9.997-5.998a2 2 0 0 0 .003-3.432z',
  );
}

/// A Lucide [outline] glyph and its SVG path data on Lucide's 24×24 grid,
/// parsed once on first use.
class FilledIconData {
  const FilledIconData(this.outline, this.pathData);

  final IconData outline;
  final String pathData;

  static final _paths = <String, Path>{};

  Path get path => _paths[pathData] ??= parseSvgPath(pathData);
}

/// Draws a [FilledIconData] filled, or as its plain outline glyph when
/// [filled] is false (for a toggle such as the favorite star). Like [Icon],
/// it takes its size, color and opacity from the ambient [IconTheme], so it
/// works inside an [IconButton].
class FilledIcon extends StatelessWidget {
  const FilledIcon(this.icon, {super.key, this.filled = true, this.size, this.color});

  final FilledIconData icon;
  final bool filled;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (!filled) return Icon(icon.outline, size: size, color: color);
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? 24;
    var c = color ?? theme.color ?? const Color(0xFFFFFFFF);
    final opacity = theme.opacity ?? 1;
    if (opacity != 1) c = c.withValues(alpha: c.a * opacity);
    return CustomPaint(size: Size.square(s), painter: _FilledIconPainter(icon.path, c));
  }
}

class _FilledIconPainter extends CustomPainter {
  const _FilledIconPainter(this.path, this.color);

  final Path path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final paint = Paint()..color = color;
    canvas.drawPath(path, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_FilledIconPainter old) => old.path != path || old.color != color;
}

/// Parses SVG path data (a `<path>`'s `d` attribute): every command, absolute
/// and relative, including compact forms such as `.5.5` or packed arc flags.
Path parseSvgPath(String data) {
  final s = _PathScanner(data);
  final path = Path();
  var cmd = '';
  var cur = Offset.zero;
  var start = Offset.zero;
  Offset? cubicCtrl; // last control point, mirrored by S
  Offset? quadCtrl; // last control point, mirrored by T

  while (s.skipSeparators()) {
    if (s.atCommand) {
      cmd = s.read();
    } else if (cmd.isEmpty) {
      throw FormatException('Expected a path command', data, s.i);
    }
    final rel = cmd == cmd.toLowerCase();
    final from = cur;
    Offset point() {
      final p = Offset(s.number(), s.number());
      return rel ? from + p : p;
    }

    Offset? nextCubic;
    Offset? nextQuad;
    switch (cmd.toUpperCase()) {
      case 'M':
        cur = start = point();
        path.moveTo(cur.dx, cur.dy);
        cmd = rel ? 'l' : 'L'; // further coordinate pairs are line-tos
      case 'L':
        cur = point();
        path.lineTo(cur.dx, cur.dy);
      case 'H':
        final x = s.number();
        cur = Offset(rel ? from.dx + x : x, from.dy);
        path.lineTo(cur.dx, cur.dy);
      case 'V':
        final y = s.number();
        cur = Offset(from.dx, rel ? from.dy + y : y);
        path.lineTo(cur.dx, cur.dy);
      case 'C' || 'S':
        final c1 = cmd.toUpperCase() == 'C' ? point() : from * 2 - (cubicCtrl ?? from);
        final c2 = point();
        cur = point();
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, cur.dx, cur.dy);
        nextCubic = c2;
      case 'Q' || 'T':
        final c = cmd.toUpperCase() == 'Q' ? point() : from * 2 - (quadCtrl ?? from);
        cur = point();
        path.quadraticBezierTo(c.dx, c.dy, cur.dx, cur.dy);
        nextQuad = c;
      case 'A':
        final radius = Radius.elliptical(s.number(), s.number());
        final rotation = s.number();
        final largeArc = s.flag();
        final clockwise = s.flag();
        cur = point();
        path.arcToPoint(cur, radius: radius, rotation: rotation, largeArc: largeArc, clockwise: clockwise);
      case 'Z':
        path.close();
        cur = start;
        cmd = ''; // a command must follow
      default:
        throw FormatException('Unknown path command "$cmd"', data, s.i - 1);
    }
    cubicCtrl = nextCubic;
    quadCtrl = nextQuad;
  }
  return path;
}

class _PathScanner {
  _PathScanner(this.data);

  final String data;
  int i = 0;

  static final _number = RegExp(r'[-+]?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?');
  static final _command = RegExp('[MmLlHhVvCcSsQqTtAaZz]');

  /// Skips whitespace and commas; false at the end of the data.
  bool skipSeparators() {
    while (i < data.length && ' ,\t\r\n'.contains(data[i])) {
      i++;
    }
    return i < data.length;
  }

  bool get atCommand => _command.matchAsPrefix(data, i) != null;

  String read() => data[i++];

  double number() {
    skipSeparators();
    final m = _number.matchAsPrefix(data, i) ?? (throw FormatException('Expected a number', data, i));
    i = m.end;
    return double.parse(m[0]!);
  }

  /// An arc flag: a single 0 or 1, which may run into the next number.
  bool flag() {
    skipSeparators();
    final c = i < data.length ? data[i] : '';
    if (c != '0' && c != '1') throw FormatException('Expected an arc flag', data, i);
    i++;
    return c == '1';
  }
}
