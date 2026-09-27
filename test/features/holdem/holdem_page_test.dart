import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playpoker/features/holdem/holdem_page.dart';
import 'package:playpoker/shared/cards/card_back.dart';
import 'package:playpoker/shared/cards/playing_card_face.dart';

void main() {
  Widget buildPage({
    bool teachMode = false,
    bool automateComputerPlayers = false,
  }) => MaterialApp(
    home: Scaffold(
      body: HoldemPage(
        cardBack: cardBackDesigns.first,
        patternIndex: 0,
        playerCount: 2,
        initialBankAmount: 100,
        anteAmount: 2,
        teachMode: teachMode,
        automateComputerPlayers: automateComputerPlayers,
      ),
    ),
  );

  Finder findCardBacks() => find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is CardBackPainter,
  );

  for (final viewport in <(String, Size)>[
    ('phone', const Size(390, 844)),
    ('tablet', const Size(800, 1180)),
    ('desktop', const Size(1440, 900)),
  ]) {
    testWidgets('uses the ${viewport.$1} game layout', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = viewport.$2;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(
        find.byKey(ValueKey('game-layout-${viewport.$1}')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('matches Five Card deal and shuffle controls', (tester) async {
    await tester.pumpWidget(buildPage());

    final dealButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('holdem-deal-button')),
    );
    expect(
      dealButton.style?.backgroundColor?.resolve({}),
      const Color(0xFFD8B75B),
    );
    expect(
      dealButton.style?.foregroundColor?.resolve({}),
      const Color(0xFF211A05),
    );

    await tester.tap(find.byKey(const ValueKey('holdem-deal-button')));
    await tester.pumpAndSettle();

    final shuffleButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('holdem-shuffle-button')),
    );
    expect(
      shuffleButton.style?.backgroundColor?.resolve({}),
      const Color(0xFF8F1D24),
    );
    expect(shuffleButton.style?.foregroundColor?.resolve({}), Colors.white);

    await tester.tap(find.byKey(const ValueKey('holdem-shuffle-button')));
    await tester.pumpAndSettle();
    expect(find.text('Deal Hole Cards'), findsOneWidget);
    expect(find.byKey(const ValueKey('holdem-shuffle-button')), findsNothing);
  });

  Future<void> completeBettingRound(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('stud-player-1-bet')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('stud-player-1-bet-amount')),
      '1',
    );
    await tester.tap(find.byKey(const ValueKey('stud-player-1-bet-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stud-player-2-call')));
    await tester.pumpAndSettle();
  }

  testWidgets('Teach Mode shows a recommended bet for the user', (
    tester,
  ) async {
    await tester.pumpWidget(buildPage(teachMode: true));
    await tester.tap(find.byKey(const ValueKey('holdem-deal-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('stud-player-1-recommended-bet')),
      findsOneWidget,
    );
    expect(find.textContaining('Recommended bet: \$'), findsOneWidget);
  });

  testWidgets('reactivates a player when an opponent bets after a check', (
    tester,
  ) async {
    await tester.pumpWidget(buildPage());
    await tester.tap(find.byKey(const ValueKey('holdem-deal-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stud-player-1-check')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stud-player-2-bet')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('stud-player-2-bet-amount')),
      '10',
    );
    await tester.tap(find.byKey(const ValueKey('stud-player-2-bet-submit')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('stud-player-1-call')),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      find.byKey(const ValueKey('stud-player-1-call-available')),
      findsOneWidget,
    );
  });

  testWidgets('deals hole cards flop turn and river with betting rounds', (
    tester,
  ) async {
    await tester.pumpWidget(buildPage());

    await tester.tap(find.byKey(const ValueKey('holdem-deal-button')));
    await tester.pumpAndSettle();
    expect(find.text('Pre-flop betting'), findsOneWidget);
    expect(find.byType(PlayingCardFace), findsNWidgets(2));
    expect(findCardBacks(), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('stud-player-1-bet-available')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('stud-player-1-fold-available')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('stud-player-1-check')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('stud-player-1-check-available')),
      findsOneWidget,
    );

    await completeBettingRound(tester);
    expect(find.text('Deal Flop'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('holdem-deal-button')));
    await tester.pumpAndSettle();
    expect(find.text('Flop betting'), findsOneWidget);
    expect(find.byType(PlayingCardFace), findsNWidgets(5));

    await completeBettingRound(tester);
    expect(find.text('Deal Turn'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('holdem-deal-button')));
    await tester.pumpAndSettle();
    expect(find.text('Turn betting'), findsOneWidget);
    expect(find.byType(PlayingCardFace), findsNWidgets(6));

    await completeBettingRound(tester);
    expect(find.text('Deal River'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('holdem-deal-button')));
    await tester.pumpAndSettle();
    expect(find.text('River betting'), findsOneWidget);
    expect(find.byType(PlayingCardFace), findsNWidgets(7));
    expect(findCardBacks(), findsNWidgets(2));

    await completeBettingRound(tester);
    expect(find.byType(PlayingCardFace), findsNWidgets(9));
    expect(findCardBacks(), findsNothing);
    expect(find.byKey(const ValueKey('payout-message')), findsOneWidget);
    expect(find.text('New Hand'), findsOneWidget);
  });

  testWidgets('computers finish Holdem after the user folds', (tester) async {
    await tester.pumpWidget(buildPage(automateComputerPlayers: true));
    await tester.tap(find.byKey(const ValueKey('holdem-deal-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('stud-player-1-fold')));
    for (var street = 0; street < 4; street++) {
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('payout-message')), findsOneWidget);
    expect(find.text('New Hand'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('stud-player-1-fold-available')),
      findsNothing,
    );
  });
}
