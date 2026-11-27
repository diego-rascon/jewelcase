import 'package:material_ui/material_ui.dart';

/// A thin, round-ended bar with no handle, for playback progress and volume.
///
/// With [onChangeEnd] it's interactive: it thickens on hover and while
/// dragged, and a click or horizontal drag sets it. The drag position is held
/// locally while scrubbing, so the bar doesn't jump back to a [value] that
/// hasn't caught up yet.
class ThinSlider extends StatefulWidget {
  const ThinSlider({
    super.key,
    required this.value,
    this.onChanged,
    this.onChangeEnd,
    this.color,
    this.thickness = 2,
    this.activeThickness = 4,
    this.hitHeight = 12,
  });

  /// From 0 to 1.
  final double value;

  /// Called as a drag moves, with the fraction under the pointer.
  final ValueChanged<double>? onChanged;

  /// Called with the chosen fraction on a click or at the end of a drag.
  /// Without it, the bar only shows [value].
  final ValueChanged<double>? onChangeEnd;

  /// Defaults to the theme's primary color; the track is a faint version of it.
  final Color? color;

  final double thickness;

  /// The thickness on hover and while dragged.
  final double activeThickness;

  /// The height of the area that takes clicks and drags, taller than the bar
  /// so it's easy to grab.
  final double hitHeight;

  @override
  State<ThinSlider> createState() => _ThinSliderState();
}

class _ThinSliderState extends State<ThinSlider> {
  bool _hover = false;

  /// The fraction under the pointer while dragging.
  double? _drag;

  void _move(double f) {
    setState(() => _drag = f);
    widget.onChanged?.call(f);
  }

  void _end() {
    final f = _drag;
    setState(() => _drag = null);
    if (f != null) widget.onChangeEnd?.call(f);
  }

  void _cancel() => setState(() => _drag = null);

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final value = (_drag ?? widget.value).clamp(0.0, 1.0);
    final active = _hover || _drag != null;

    final bar = TweenAnimationBuilder<double>(
      tween: Tween(end: active ? widget.activeThickness : widget.thickness),
      duration: const Duration(milliseconds: 120),
      builder: (context, height, _) => LinearProgressIndicator(
        value: value,
        minHeight: height,
        borderRadius: BorderRadius.circular(height / 2),
        color: color,
        backgroundColor: color.withValues(alpha: 0.15),
      ),
    );
    final onChangeEnd = widget.onChangeEnd;
    if (onChangeEnd == null) return bar;

    return Semantics(
      slider: true,
      value: '${(value * 100).round()}%',
      onIncrease: () => onChangeEnd((value + 0.05).clamp(0.0, 1.0)),
      onDecrease: () => onChangeEnd((value - 0.05).clamp(0.0, 1.0)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double fraction(Offset local) => (local.dx / constraints.maxWidth).clamp(0.0, 1.0);
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => onChangeEnd(fraction(d.localPosition)),
              onHorizontalDragStart: (d) => _move(fraction(d.localPosition)),
              onHorizontalDragUpdate: (d) => _move(fraction(d.localPosition)),
              onHorizontalDragEnd: (_) => _end(),
              onHorizontalDragCancel: _cancel,
              child: SizedBox(
                height: widget.hitHeight,
                child: Center(child: bar),
              ),
            ),
          );
        },
      ),
    );
  }
}
