import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

/// Loads data with [load] and re-runs it whenever [deps] change (e.g. the
/// selected library). Renders loading and error states consistently.
class AsyncView<T> extends StatefulWidget {
  const AsyncView({super.key, required this.load, required this.builder, this.deps = const [], this.frame});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, Future<void> Function() reload) builder;
  final List<Object?> deps;

  /// Wraps the loading and error states, e.g. to give them an app bar.
  final Widget Function(Widget child)? frame;

  /// For pushed detail pages: loading/error states get a back button.
  static Widget page(Widget child) => Scaffold(backgroundColor: Colors.transparent, appBar: AppBar(), body: child);

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> _future = widget.load();

  @override
  void didUpdateWidget(covariant AsyncView<T> old) {
    super.didUpdateWidget(old);
    if (!_listEquals(old.deps, widget.deps)) _future = widget.load();
  }

  Future<void> _reload() async {
    final f = widget.load();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {
      // Surfaced by the FutureBuilder.
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _future,
    builder: (context, snap) {
      final frame = widget.frame ?? (w) => w;
      // Keep showing stale data during a reload (pull-to-refresh).
      final waiting = snap.connectionState != ConnectionState.done;
      if (waiting && !snap.hasData) {
        return frame(const Center(child: CircularProgressIndicator()));
      }
      if (snap.hasError) return frame(ErrorState(message: '${snap.error}', onRetry: _reload));
      return widget.builder(context, snap.data as T, _reload);
    },
  );

  static bool _listEquals(List<Object?> a, List<Object?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
    icon: LucideIcons.cloudOff,
    title: 'Something went wrong',
    message: message,
    action: onRetry == null ? null : FilledButton.tonal(onPressed: onRetry, child: const Text('Try again')),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
