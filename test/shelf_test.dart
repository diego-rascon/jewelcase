import 'package:flutter_test/flutter_test.dart';
import 'package:jewelcase/ui/widgets/layout.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('snapOffset rounds to the nearest item and stays in range', () {
    expect(snapOffset(170, 188, 0, 2000), 188);
    expect(snapOffset(80, 188, 0, 2000), 0);
    expect(snapOffset(-50, 188, 0, 2000), 0);
    // The end of the list is reachable though it isn't on a multiple.
    expect(snapOffset(1990, 188, 0, 1900), 1900);
  });

  for (final height in [230.0, null]) {
    testWidgets('a ${height == null ? 'content-sized' : 'fixed-height'} shelf settles on an item', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                Shelf(
                  title: 'Albums',
                  height: height,
                  itemCount: 20,
                  itemBuilder: (context, i) => SizedBox(height: 200, child: Text('$i')),
                ),
              ],
            ),
          ),
        ),
      );
      final scrollable = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.right);
      double offset() => tester.state<ScrollableState>(scrollable).position.pixels;
      const extent = 170 + 18.0;

      await tester.fling(find.text('0'), const Offset(-300, 0), 1500);
      await tester.pumpAndSettle();
      expect(offset(), greaterThan(extent));
      expect(offset() % extent, moreOrLessEquals(0, epsilon: 0.5));

      // A slow drag that stops partway still lands on an item.
      await tester.drag(scrollable, const Offset(-70, 0));
      await tester.pumpAndSettle();
      expect(offset() % extent, moreOrLessEquals(0, epsilon: 0.5));
    });
  }
}
