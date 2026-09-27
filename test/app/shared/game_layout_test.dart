import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playpoker/app/shared/game_layout.dart';

void main() {
  test('phone layouts stack player hands in one column', () {
    final layout = GameLayoutSpec.resolve(390, 5, height: 844);

    expect(layout.layoutClass, GameLayoutClass.phone);
    expect(layout.columns, 1);
  });

  testWidgets('game display supports zoom controls', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(
            child: ZoomableGameDisplay(child: ColoredBox(color: Colors.green)),
          ),
        ),
      ),
    );

    TransformationController controller() => tester
        .widget<InteractiveViewer>(
          find.byKey(const ValueKey('game-display-zoom-view')),
        )
        .transformationController!;

    expect(controller().value.getMaxScaleOnAxis(), 1);

    await tester.tap(find.byKey(const ValueKey('game-display-zoom-in')));
    await tester.pump();
    expect(controller().value.getMaxScaleOnAxis(), 1.25);

    await tester.tap(find.byKey(const ValueKey('game-display-zoom-reset')));
    await tester.pump();
    expect(controller().value.getMaxScaleOnAxis(), 1);

    await tester.tap(find.byKey(const ValueKey('game-display-zoom-out')));
    await tester.pump();
    expect(controller().value.getMaxScaleOnAxis(), 0.75);
  });
}
