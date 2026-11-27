import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

/// Where a [Frosted] draws the sidebar's hairline edge.
enum FrostedEdge {
  none,

  /// All the way around, following its shape.
  around,

  /// Along its top only, as on the phone tab bar.
  top,
}

/// The frosted material of the floating player and the phone tab bar: what's
/// behind it blurred, under a slightly see-through fill in the sidebar's color
/// and edge.
///
/// Rounded by [borderRadius] (a rectangle when it is zero), or a circle when
/// it is null.
class Frosted extends StatelessWidget {
  const Frosted({super.key, this.borderRadius, this.edge = FrostedEdge.around, required this.child})
    : assert(borderRadius != null || edge != FrostedEdge.top, 'A circle has no top edge');

  final BorderRadius? borderRadius;
  final FrostedEdge edge;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final circle = borderRadius == null;
    final side = BorderSide(color: scheme.outlineVariant);
    final blurred = BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
      child: DecoratedBox(
        decoration: BoxDecoration(
          // The sidebar's color, so the chrome reads as one material, thin
          // enough for what's behind to show through.
          color: scheme.surfaceContainerLow.withValues(alpha: 0.7),
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          // The clip below already rounds the fill; a one-sided border can't
          // take a radius, so only the full outline needs it.
          borderRadius: edge == FrostedEdge.around ? borderRadius : null,
          border: switch (edge) {
            FrostedEdge.none => null,
            FrostedEdge.around => Border.fromBorderSide(side),
            FrostedEdge.top => Border(top: side),
          },
        ),
        child: child,
      ),
    );
    return circle ? ClipOval(child: blurred) : ClipRRect(borderRadius: borderRadius!, child: blurred);
  }
}
