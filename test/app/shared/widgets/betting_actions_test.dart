import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playpoker/app/shared/widgets/betting_actions.dart';

void main() {
  Widget buildActions(double width) => MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: BettingActions(
            keyPrefix: 'test',
            enabled: true,
            canBet: true,
            canRaise: true,
            canCall: true,
            canCheck: true,
            selectedAction: null,
            onSelected: (_) {},
          ),
        ),
      ),
    ),
  );

  testWidgets('wraps betting options into rows when width is limited', (
    tester,
  ) async {
    await tester.pumpWidget(buildActions(156));

    final firstRowY = tester
        .getTopLeft(find.byKey(const ValueKey('test-bet')))
        .dy;
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('test-call'))).dy,
      firstRowY,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('test-check'))).dy,
      greaterThan(firstRowY),
    );
  });

  testWidgets('keeps betting options in one row when width is sufficient', (
    tester,
  ) async {
    await tester.pumpWidget(buildActions(300));

    final firstActionY = tester
        .getTopLeft(find.byKey(const ValueKey('test-bet')))
        .dy;
    for (final action in ['raise', 'call', 'check', 'fold']) {
      expect(
        tester.getTopLeft(find.byKey(ValueKey('test-$action'))).dy,
        firstActionY,
      );
    }
  });
}
