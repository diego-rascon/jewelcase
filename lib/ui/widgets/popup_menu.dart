import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:material_ui/material_ui.dart';

import '../actions.dart';
import '../theme.dart';

/// The global rect of [context]'s render box, to anchor a [showPopupMenu] to.
Rect globalRect(BuildContext context) {
  final box = context.findRenderObject()! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Shows [actions] in a popup next to [anchor] (global coordinates; a
/// zero-size rect for a pointer position) and returns the one picked.
///
/// It opens below the anchor, or above when there's more room there, and
/// grows out of the corner touching the anchor with a quick scale and fade.
/// Actions without an icon get an empty slot, so a select menu can mark the
/// current choice with a check and keep its labels aligned.
Future<MenuAction?> showPopupMenu(BuildContext context, Rect anchor, List<MenuAction> actions) {
  final navigator = Navigator.of(context);
  // The route is laid out in the navigator's overlay. Inside a section's
  // nested navigator that overlay doesn't start at the window origin (the
  // sidebar sits to its left), so the anchor has to be made local to it.
  final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
  return navigator.push(
    _PopupMenuRoute(
      anchor: anchor.shift(overlay.globalToLocal(Offset.zero)),
      actions: actions,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
    ),
  );
}

class _PopupMenuRoute extends PopupRoute<MenuAction> {
  _PopupMenuRoute({required this.anchor, required this.actions, required this.themes});

  final Rect anchor;
  final List<MenuAction> actions;
  final CapturedThemes themes;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss menu';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 150);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 100);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    // Clear of the window edges, and on desktop of the floating player bar,
    // which adds its footprint to the bottom padding.
    final margin = MediaQuery.paddingOf(context) + const EdgeInsets.all(8);
    return Flow(
      delegate: _PopupMenuLayout(
        anchor: anchor,
        margin: margin,
        animation: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic),
      ),
      children: [themes.wrap(_PopupMenuPanel(actions: actions))],
    );
  }

  // The panel animates itself in [_PopupMenuLayout], which knows where it
  // ended up.
  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

/// Places the panel next to the anchor, kept inside [margin], and paints it
/// scaled and faded by [animation] around the corner nearest the anchor.
class _PopupMenuLayout extends FlowDelegate {
  _PopupMenuLayout({required this.anchor, required this.margin, required this.animation}) : super(repaint: animation);

  final Rect anchor;
  final EdgeInsets margin;
  final Animation<double> animation;

  /// Space between a widget anchor and the panel.
  static const _gap = 4.0;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      BoxConstraints.loose(margin.deflateSize(constraints.biggest));

  @override
  void paintChildren(FlowPaintingContext context) {
    final size = context.getChildSize(0)!;
    final bounds = margin.deflateRect(Offset.zero & context.size);
    final gap = anchor.isEmpty ? 0.0 : _gap;

    final below =
        anchor.bottom + gap + size.height <= bounds.bottom || anchor.top - bounds.top < bounds.bottom - anchor.bottom;
    final rightward =
        anchor.left + size.width <= bounds.right || anchor.right - bounds.left < bounds.right - anchor.left;
    final x = (rightward ? anchor.left : anchor.right - size.width).clamp(bounds.left, bounds.right - size.width);
    final y = (below ? anchor.bottom + gap : anchor.top - gap - size.height).clamp(
      bounds.top,
      bounds.bottom - size.height,
    );

    // Scale by s around the corner facing the anchor: p ↦ origin + s·(p + (x, y) − origin).
    final origin = Offset(rightward ? x : x + size.width, below ? y : y + size.height);
    final t = animation.value;
    final s = 0.9 + 0.1 * t;
    final transform = Matrix4.diagonal3Values(s, s, 1)
      ..setTranslationRaw(origin.dx + s * (x - origin.dx), origin.dy + s * (y - origin.dy), 0);
    context.paintChild(0, transform: transform, opacity: t.clamp(0.0, 1.0));
  }

  @override
  bool shouldRelayout(_PopupMenuLayout old) => margin != old.margin;

  @override
  bool shouldRepaint(_PopupMenuLayout old) =>
      anchor != old.anchor || margin != old.margin || animation != old.animation;
}

class _PopupMenuPanel extends StatelessWidget {
  const _PopupMenuPanel({required this.actions});

  final List<MenuAction> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: 'Menu',
      // Arrow keys move between rows, as in a native menu. Escape closes the
      // route.
      child: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowDown): NextFocusIntent(),
          SingleActivator(LogicalKeyboardKey.arrowUp): PreviousFocusIntent(),
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Material(
            color: scheme.surfaceContainerHigh,
            elevation: 3,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: IntrinsicWidth(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final a in actions)
                      MenuItemButton(
                        leadingIcon: SizedBox.square(
                          dimension: IconSizes.medium,
                          child: a.icon == null ? null : Center(child: Icon(a.icon, size: IconSizes.small)),
                        ),
                        onPressed: () => Navigator.pop(context, a),
                        child: Text(a.label),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
