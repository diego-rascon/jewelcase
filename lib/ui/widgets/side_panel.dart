import 'package:material_ui/material_ui.dart';

/// A panel along the right edge that slides in and out while [open] changes.
///
/// Its slot widens while the panel keeps its [width], so the contents don't
/// relayout on every frame. [child] is only built while open or sliding out.
class SidePanel extends StatefulWidget {
  const SidePanel({super.key, required this.open, required this.width, required this.child});

  static const duration = Duration(milliseconds: 300);

  final bool open;
  final double width;
  final Widget child;

  @override
  State<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<SidePanel> {
  /// Keeps [SidePanel.child] built while it slides out.
  bool _closing = false;

  @override
  void didUpdateWidget(SidePanel old) {
    super.didUpdateWidget(old);
    if (old.open && !widget.open) _closing = true;
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: AnimatedAlign(
      alignment: Alignment.centerLeft,
      widthFactor: widget.open ? 1 : 0,
      duration: SidePanel.duration,
      curve: Curves.easeOutCubic,
      onEnd: () {
        if (_closing) setState(() => _closing = false);
      },
      child: SizedBox(
        width: widget.width,
        height: double.infinity,
        child: widget.open || _closing ? widget.child : null,
      ),
    ),
  );
}
