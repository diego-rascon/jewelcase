import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jewelcase/ui/actions.dart';
import 'package:jewelcase/ui/widgets/popup_menu.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<BuildContext> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    return context;
  }

  List<MenuAction> actions(List<String> picked) => [
    for (final label in ['One', 'Two']) MenuAction(label, LucideIcons.check, () => picked.add(label)),
  ];

  testWidgets('opens below an anchor near the top and returns the picked action', (tester) async {
    final context = await pumpApp(tester);
    const anchor = Rect.fromLTWH(100, 40, 40, 40);
    final picked = <String>[];
    final result = showPopupMenu(context, anchor, actions(picked));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('One')).dy, greaterThan(anchor.bottom));
    await tester.tap(find.text('Two'));
    await tester.pumpAndSettle();
    (await result)?.onSelected();
    expect(picked, ['Two']);
    expect(find.text('One'), findsNothing);
  });

  testWidgets('opens above an anchor near the bottom', (tester) async {
    final context = await pumpApp(tester);
    const anchor = Rect.fromLTWH(100, 540, 40, 40);
    unawaited(showPopupMenu(context, anchor, actions([])));
    await tester.pumpAndSettle();

    expect(tester.getBottomLeft(find.text('Two')).dy, lessThan(anchor.top));
  });

  testWidgets('a tap outside dismisses without picking', (tester) async {
    final context = await pumpApp(tester);
    final result = showPopupMenu(context, const Rect.fromLTWH(100, 40, 0, 0), actions([]));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(700, 500));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });
}
