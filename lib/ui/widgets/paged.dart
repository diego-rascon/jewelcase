import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../state/paged_list.dart';

/// Asks [list] for its next page as the user nears the end of [child], a
/// scroll view.
class LoadMoreOnScroll extends StatelessWidget {
  const LoadMoreOnScroll({super.key, required this.list, required this.child});

  final PagedList<Object?> list;
  final Widget child;

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollNotification>(
    onNotification: (n) {
      if (n.metrics.extentAfter < 800) unawaited(list.loadMore());
      return false;
    },
    child: child,
  );
}

/// The sliver after a [PagedList]'s items: a spinner while a page loads, or a
/// retry button when loading more failed.
class PagedFooter extends StatelessWidget {
  const PagedFooter({super.key, required this.list, this.loading});

  final PagedList<Object?> list;

  /// Shown instead of the plain spinner while a page loads.
  final Widget? loading;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: list.isLoading
            ? loading ?? const CircularProgressIndicator()
            : list.error != null && list.items.isNotEmpty
            ? FilledButton.tonal(onPressed: list.retry, child: const Text('Couldn’t load more · Retry'))
            : null,
      ),
    ),
  );
}
