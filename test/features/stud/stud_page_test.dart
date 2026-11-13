import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playpoker/features/stud/stud_page.dart';
import 'package:playpoker/shared/cards/card_back.dart';
import 'package:playpoker/shared/cards/playing_card_face.dart';

void main() {
  Widget buildPage({
    int playerCount = 2,
    int cardCount = 5,
    bool teachMode = false,
    bool automateComputerPlayers = false,
  }) => MaterialApp(
    home: Scaffold(
      body: StudPage(
        cardBack: cardBackDesigns.first,
        patternIndex: 0,
        playerCount: playerCount,
        initialBankAmount: 100,
        anteAmount: 2,
        cardCount: cardCount,
        teachMode: teachMode,
        automateComputerPlayers: automateComputerPlayers,
      ),
    ),
  );

  Finder findCardBacks() => find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter is CardBackPainter,
  );

  for (final cardCount in [5, 7]) {
    for (final viewport in <(String, Size)>[
      ('phone', const Size(390, 844)),
      ('tablet', const Size(800, 1180)),
      ('desktop', const Size(1440, 900)),
    ]) {
      testWidgets('Stud$cardCount uses the ${viewport.$1} game layout', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = viewport.$2;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          buildPage(playerCount: 5, cardCount: cardCount),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(ValueKey('game-layout-${viewport.$1}')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final cardCount in [5, 7]) {
    testWidgets('Stud$cardCount matches Five Card deck controls', (
      tester,
    ) async {
      await tester.pumpWidget(buildPage(cardCount: cardCount));

      final dealButton = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('stud-deal-button')),
      );
      expect(
        dealButton.style?.backgroundColor?.resolve({}),
        const Color(0xFFD8B75B),
      );
      expect(
        dealButton.style?.foregroundColor?.resolve({}),
        const Color(0xFF211A05),
      );

      await tester.tap(find.byKey(const ValueKey('stud-deal-button')));
      await tester.pumpAndSettle();

      final shuffleButton = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('stud-shuffle-button')),
      );
      expect(
        shuffleButton.style?.backgroundColor?.resolve({}),
        const Color(0xFF8F1D24),
      );
      expect(shuffleButton.style?.foregroundColor?.resolve({}), Colors.white);

      await tester.tap(find.byKey(const ValueKey('stud-shuffle-button')));
      await tester.pumpAndSettle();
      expect(find.text('Deal First Card'), findsOneWidget);
      expect(find.byKey(const ValueKey('stud-shuffle-button')), findsNothing);
    });
  }

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
    await tester.tap(find.byKey(const ValueKey('stud-deal-button')));
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
    await tester.tap(find.byKey(const ValueKey('stud-deal-button')));
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
    final checkButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('stud-player-1-check')),
    );
    expect(checkButton.style?.backgroundColor?.resolve({}), Colors.transparent);
  });

  testWidgets('deals down up up up down with betting after every card', (
    tester,
  ) async {
    await tester.pumpWidget(buildPage());

    await tester.tap(find.byKey(const ValueKey('stud-deal-button')));
    await tester.pumpAndSettle();
    expect(findCardBacks(), findsNWidgets(2));
    expect(find.byType(PlayingCardFace), findsNothing);
    expect(find.text('Betting round 1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('stud-player-1-bet-available')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('stud-player-1-fold-available')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('stud-player-1-raise-available')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('stud-player-1-call-available')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('stud-player-1-check')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('stud-player-1-check-available')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('stud-deal-button')),
          )
          .onPressed,
      isNull,
    );

    await completeBettingRound(tester);
    expect(find.text('Betting complete'), findsOneWidget);

    for (var card = 2; card <= 5; card++) {
      await tester.tap(find.byKey(const ValueKey('stud-deal-button')));
      await tester.pumpAndSettle();

      final exposedPerPlayer = card.clamp(1, 4) - 1;
      expect(find.byType(PlayingCardFace), findsNWidgets(exposedPerPlayer * 2));
      expect(findCardBacks(), findsNWidgets(card == 5 ? 4 : 2));
      expect(find.text('Betting round $card'), findsOneWidget);

      if (card == 5) {
        final fan = find.byKey(const ValueKey('stud-player-1-card-fan'));
        final positionedCards = tester
            .widgetList<Positioned>(
              find.descendant(of: fan, matching: find.byType(Positioned)),
            )
            .where(
              (positioned) =>
                  positioned.top == null &&
                  positioned.right == null &&
                  positioned.bottom == null,
            )
            .toList();
        expect(positionedCards, hasLength(5));
        for (var index = 1; index < positionedCards.length; index++) {
          expect(
            positionedCards[index].left! - positionedCards[index - 1].left!,
            lessThan(58),
          );
        }
      }

      await completeBettingRound(tester);
    }

    expect(find.byType(PlayingCardFace), findsNWidgets(10));
    expect(findCardBacks(), findsNothing);
    expect(find.byKey(const ValueKey('payout-message')), findsOneWidget);
    expect(find.text('New Hand'), findsOneWidget);
  });

  testWidgets('awards an early pot when every opponent folds', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.tap(find.byKey(const ValueKey('stud-deal-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('stud-player-1-bet')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('stud-player-1-bet-amount')),
      '5',
    );
    await tester.tap(find.byKey(const ValueKey('stud-player-1-bet-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stud-player-2-fold')));
    await tester.pumpAndSettle();

    expect(find.text(r'Player 1 wins $9'), findsOneWidget);
    expect(find.text('New Hand'), findsOneWidget);
  });

  testWidgets('user can reveal the first and last cards by tapping them', (
    tester,
  ) async {
    await tester.pumpWidget(buildPage());
    await tester.tap(find.byKey(const ValueKey('stud-deal-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('stud-player-1-card-0')));
    await tester.pump();
    expect(find.byType(PlayingCardFace), findsOneWidget);
    expect(findCardBacks(), findsOneWidget);

    await completeBettingRound(tester);
    for (var card = 2; card <= 5; card++) {
      await tester.tap(find.byKey(const ValueKey('stud-deal-button')));
      await tester.pumpAndSettle();
      if (card < 5) {
        await completeBettingRound(tester);
      }
    }

    expect(find.byType(PlayingCardFace), findsNWidgets(7));
    expect(findCardBacks(), findsNWidgets(3));
    await tester.tap(find.byKey(const ValueKey('stud-player-1-card-4')));
    await tester.pump();
    expect(find.byType(PlayingCardFace), findsNWidgets(8));
    expect(findCardBacks(), findsNWidgets(2));
  });

  testWidgets('Stud7 deals seven cards with betting after every card', (
    tester,
  ) async {
    await tester.pumpWidget(buildPage(cardCount: 7));

    for (var card = 1; card <= 7; card++) {
      await tester.tap(find.byKey(const ValueKey('stud-deal-button')));
      await tester.pumpAndSettle();
      expect(find.text('$card OF 7 CARDS'), findsNWidgets(2));
      expect(find.text('Betting round $card'), findsOneWidget);

      if (card == 7) {
        expect(
          find.byKey(const ValueKey('stud-player-1-card-6')),
          findsOneWidget,
        );
        expect(find.byType(PlayingCardFace), findsNWidgets(10));
        expect(findCardBacks(), findsNWidgets(4));
        await tester.tap(find.byKey(const ValueKey('stud-player-1-card-6')));
        await tester.pump();
        expect(find.byType(PlayingCardFace), findsNWidgets(11));
        expect(findCardBacks(), findsNWidgets(3));
      }

      await completeBettingRound(tester);
    }

    expect(find.byType(PlayingCardFace), findsNWidgets(14));
    expect(find.text('New Hand'), findsOneWidget);
  });

  testWidgets('computers finish Stud games after the user folds', (
    tester,
  ) async {
    for (final cardCount in [5, 7]) {
      await tester.pumpWidget(
        buildPage(
          playerCount: 3,
          cardCount: cardCount,
          automateComputerPlayers: true,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('stud-deal-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('stud-player-1-fold')));
      for (var street = 1; street <= cardCount; street++) {
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('payout-message')), findsOneWidget);
      expect(find.text('New Hand'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('stud-player-1-fold-available')),
        findsNothing,
      );
    }
  });
}
