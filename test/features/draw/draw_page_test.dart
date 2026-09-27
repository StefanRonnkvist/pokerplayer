import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playpoker/features/draw/draw_page.dart';
import 'package:playpoker/shared/cards/card_back.dart';
import 'package:playpoker/shared/cards/playing_card_face.dart';

void main() {
  Widget buildPage({
    int playerCount = 2,
    int maxCardsToDraw = 5,
    int initialBankAmount = 1000,
    int anteAmount = 2,
    bool teachMode = false,
    bool automateComputerPlayers = true,
  }) => MaterialApp(
    home: Scaffold(
      body: DrawPage(
        cardBack: cardBackDesigns.first,
        patternIndex: 0,
        playerCount: playerCount,
        maxCardsToDraw: maxCardsToDraw,
        initialBankAmount: initialBankAmount,
        anteAmount: anteAmount,
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

      await tester.pumpWidget(buildPage(playerCount: 5));
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
      find.byKey(const ValueKey('draw-deal-button')),
    );
    expect(
      dealButton.style?.backgroundColor?.resolve({}),
      const Color(0xFFD8B75B),
    );
    expect(
      dealButton.style?.foregroundColor?.resolve({}),
      const Color(0xFF211A05),
    );

    await tester.tap(find.byKey(const ValueKey('draw-deal-button')));
    await tester.pumpAndSettle();

    final shuffleButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('draw-shuffle-button')),
    );
    expect(
      shuffleButton.style?.backgroundColor?.resolve({}),
      const Color(0xFF8F1D24),
    );
    expect(shuffleButton.style?.foregroundColor?.resolve({}), Colors.white);

    await tester.tap(find.byKey(const ValueKey('draw-shuffle-button')));
    await tester.pumpAndSettle();
    expect(find.text('Deal'), findsOneWidget);
    expect(find.byKey(const ValueKey('draw-shuffle-button')), findsNothing);
  });

  testWidgets('Teach Mode shows a recommended bet for the user', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPage(teachMode: true, automateComputerPlayers: false),
    );
    await tester.tap(find.byKey(const ValueKey('draw-deal-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('draw-player-1-recommended-bet')),
      findsOneWidget,
    );
    expect(find.textContaining('Recommended bet: \$'), findsOneWidget);
  });

  testWidgets('reactivates a player when an opponent bets after a check', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPage(
        playerCount: 2,
        initialBankAmount: 100,
        anteAmount: 2,
        automateComputerPlayers: false,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('draw-deal-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('draw-player-1-check')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('draw-player-2-bet')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('draw-player-2-bet-amount')),
      '10',
    );
    await tester.tap(find.byKey(const ValueKey('draw-player-2-bet-submit')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('draw-player-1-call')),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      find.byKey(const ValueKey('draw-player-1-call-available')),
      findsOneWidget,
    );
    final checkButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('draw-player-1-check')),
    );
    expect(checkButton.style?.backgroundColor?.resolve({}), Colors.transparent);
  });

  testWidgets('draws no more than the configured maximum', (tester) async {
    await tester.pumpWidget(buildPage(maxCardsToDraw: 2));

    await tester.tap(find.byKey(const ValueKey('draw-deal-button')));
    await tester.pumpAndSettle();

    expect(find.byType(PlayingCardFace), findsNWidgets(5));
    expect(findCardBacks(), findsNWidgets(5));
    expect(find.text('PLAYER 2 - COMPUTER'), findsOneWidget);
    expect(find.text('Select up to 2 cards'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('draw-player-1-bet-available')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('draw-player-1-fold-available')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('draw-player-1-raise-available')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('draw-player-1-call-available')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('draw-player-1-check')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('draw-player-1-check-available')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('draw-card-0')));
    await tester.tap(find.byKey(const ValueKey('draw-card-1')));
    await tester.tap(find.byKey(const ValueKey('draw-card-2')));
    await tester.pumpAndSettle();

    expect(find.text('Draw 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('draw-selected-button')));
    await tester.pumpAndSettle();

    expect(find.byType(PlayingCardFace), findsNWidgets(10));
    expect(findCardBacks(), findsNothing);
    expect(
      find.textContaining(
        RegExp(
          '^(High Card|One Pair|Two Pair|Three of a Kind|Straight|Flush|Full House|Four of a Kind|Straight Flush)( - WINNER)?\$',
        ),
      ),
      findsNWidgets(2),
    );
    expect(find.text('New Hand'), findsOneWidget);
  });

  testWidgets('stands pat without replacing cards', (tester) async {
    await tester.pumpWidget(buildPage(playerCount: 3));
    await tester.tap(find.byKey(const ValueKey('draw-deal-button')));
    await tester.pumpAndSettle();

    final cardsBefore = tester
        .widgetList<PlayingCardFace>(find.byType(PlayingCardFace))
        .map((view) => view.card)
        .toList();
    await tester.tap(find.byKey(const ValueKey('stand-pat-button')));
    await tester.pumpAndSettle();
    final cardsAfter = tester
        .widgetList<PlayingCardFace>(find.byType(PlayingCardFace))
        .map((view) => view.card)
        .toList();

    expect(cardsAfter.take(5), cardsBefore);
    expect(cardsAfter, hasLength(15));
    expect(find.textContaining('COMPUTER'), findsNWidgets(2));
    expect(find.text('New Hand'), findsOneWidget);
  });

  testWidgets('moves Draw bets and calls to the pot and awards the winner', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPage(
        playerCount: 3,
        initialBankAmount: 100,
        anteAmount: 2,
        automateComputerPlayers: false,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('draw-deal-button')));
    await tester.pumpAndSettle();

    for (var player = 1; player <= 3; player++) {
      for (final label in [
        'Player $player chip bank, 98 dollars',
        'Player $player table wager, 2 dollars',
      ]) {
        expect(
          find.byWidgetPredicate(
            (widget) => widget is Semantics && widget.properties.label == label,
          ),
          findsOneWidget,
        );
      }
      for (final action in ['bet', 'raise', 'call', 'fold']) {
        expect(
          find.byKey(ValueKey('draw-player-$player-$action')),
          findsOneWidget,
        );
      }
    }

    await tester.tap(find.byKey(const ValueKey('draw-player-1-bet')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('draw-player-1-bet-amount')),
      '10',
    );
    await tester.tap(find.byKey(const ValueKey('draw-player-1-bet-submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('draw-player-2-call')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('draw-player-3-raise')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('draw-player-3-raise-amount')),
      '20',
    );
    await tester.tap(find.byKey(const ValueKey('draw-player-3-raise-submit')));
    await tester.pumpAndSettle();

    expect(find.text(r'Player 1: Call $10 or Fold'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('draw-player-1-call')));
    await tester.pumpAndSettle();
    expect(find.text(r'Player 2: Call $10 or Fold'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('draw-player-2-fold')));
    await tester.pumpAndSettle();

    expect(find.text('Select up to 5 cards'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stand-pat-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('payout-message')), findsOneWidget);
    expect(find.textContaining(r'wins $56'), findsOneWidget);
    expect(find.byType(PlayingCardFace), findsNWidgets(10));
    expect(findCardBacks(), findsNWidgets(5));
    expect(find.byKey(const ValueKey('player-1-table-wager')), findsNothing);
    expect(find.byKey(const ValueKey('player-2-table-wager')), findsNothing);
    expect(find.byKey(const ValueKey('player-3-table-wager')), findsNothing);
  });

  testWidgets('computer players respond before the user draws', (tester) async {
    await tester.pumpWidget(
      buildPage(playerCount: 2, initialBankAmount: 100, anteAmount: 2),
    );
    await tester.tap(find.byKey(const ValueKey('draw-deal-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('draw-player-1-bet')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('draw-player-1-bet-amount')),
      '10',
    );
    await tester.tap(find.byKey(const ValueKey('draw-player-1-bet-submit')));
    await tester.pumpAndSettle();

    final selectedComputerActions = ['bet', 'raise', 'call', 'fold'].where((
      action,
    ) {
      final button = tester.widget<OutlinedButton>(
        find.byKey(ValueKey('draw-player-2-$action')),
      );
      return button.style?.backgroundColor?.resolve({}) == Colors.amberAccent;
    });
    expect(selectedComputerActions, hasLength(1));

    if (find
        .byKey(const ValueKey('raise-response-prompt'))
        .evaluate()
        .isNotEmpty) {
      await tester.tap(find.byKey(const ValueKey('draw-player-1-call')));
      await tester.pumpAndSettle();
    }

    expect(find.text('Select up to 5 cards'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('stand-pat-button')),
          )
          .onPressed,
      isNotNull,
    );
  });
}
