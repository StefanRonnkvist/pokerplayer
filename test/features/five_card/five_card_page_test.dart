import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playpoker/features/five_card/five_card_page.dart';
import 'package:playpoker/features/five_card/five_card_state.dart';
import 'package:playpoker/features/five_card/persistence/five_card_state_store.dart';
import 'package:playpoker/shared/cards/card_back.dart';
import 'package:playpoker/shared/cards/playing_card_face.dart';

void main() {
  Widget buildPage(
    FiveCardStateStore stateStore, {
    int initialBankAmount = 1000,
    int anteAmount = 2,
    int playerCount = 5,
    bool teachMode = false,
    bool automateComputerPlayers = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: FiveCardPage(
          cardBack: cardBackDesigns.first,
          patternIndex: 0,
          playerCount: playerCount,
          initialBankAmount: initialBankAmount,
          anteAmount: anteAmount,
          teachMode: teachMode,
          automateComputerPlayers: automateComputerPlayers,
          stateStore: stateStore,
        ),
      ),
    );
  }

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

      await tester.pumpWidget(
        buildPage(_MemoryFiveCardStateStore(), playerCount: 5),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(ValueKey('game-layout-${viewport.$1}')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Teach Mode shows a recommended bet for the user', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPage(_MemoryFiveCardStateStore(), playerCount: 2, teachMode: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deal'));
    await tester.pumpAndSettle();

    final recommendation = find.byKey(
      const ValueKey('player-1-recommended-bet'),
    );
    expect(recommendation, findsOneWidget);
    expect(find.textContaining('Recommended bet: \$'), findsOneWidget);
    expect(
      tester.getTopLeft(recommendation).dy,
      greaterThan(
        tester.getBottomLeft(find.byKey(const ValueKey('player-1-check'))).dy,
      ),
    );
  });

  testWidgets('normal mode does not show a recommended bet', (tester) async {
    await tester.pumpWidget(
      buildPage(_MemoryFiveCardStateStore(), playerCount: 2),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deal'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('player-1-recommended-bet')),
      findsNothing,
    );
  });

  testWidgets('uses high-contrast colors for deal and shuffle controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPage(_MemoryFiveCardStateStore(), playerCount: 2),
    );
    await tester.pumpAndSettle();

    final dealButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('five-card-deal-button')),
    );
    expect(
      dealButton.style?.backgroundColor?.resolve({}),
      const Color(0xFFD8B75B),
    );
    expect(
      dealButton.style?.foregroundColor?.resolve({}),
      const Color(0xFF211A05),
    );

    await tester.tap(find.byKey(const ValueKey('five-card-deal-button')));
    await tester.pumpAndSettle();

    final shuffleButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('five-card-shuffle-button')),
    );
    expect(
      shuffleButton.style?.backgroundColor?.resolve({}),
      const Color(0xFF8F1D24),
    );
    expect(shuffleButton.style?.foregroundColor?.resolve({}), Colors.white);
  });

  testWidgets('moves every player ante to the table when dealing', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPage(
        _MemoryFiveCardStateStore(),
        initialBankAmount: 20,
        anteAmount: 2,
        playerCount: 2,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Deal'));
    await tester.pump();

    final firstTableWager = find.byKey(const ValueKey('player-1-table-wager'));
    final startingY = tester.getTopLeft(firstTableWager).dy;
    await tester.pump(const Duration(milliseconds: 225));
    final midwayY = tester.getTopLeft(firstTableWager).dy;
    await tester.pump(const Duration(milliseconds: 225));
    final endingY = tester.getTopLeft(firstTableWager).dy;

    expect(startingY, greaterThan(midwayY));
    expect(midwayY, greaterThan(endingY));
    await tester.pumpAndSettle();

    expect(find.text('x18'), findsNWidgets(2));
    expect(find.text('x2'), findsNWidgets(2));
    for (var player = 1; player <= 2; player++) {
      expect(
        find.byKey(ValueKey('player-$player-table-wager')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('player-$player-table-chip-1')),
        findsOneWidget,
      );
    }
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('player-1-bet')))
          .onPressed,
      isNotNull,
    );
    expect(
      find.byKey(const ValueKey('player-1-bet-available')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('player-1-fold-available')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('player-1-raise-available')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('player-1-call-available')), findsNothing);
    expect(find.byKey(const ValueKey('player-1-check')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('player-1-check-available')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Icon>(find.byKey(const ValueKey('player-1-bet-available')))
          .color,
      Colors.amberAccent,
    );

    await tester.tap(find.byKey(const ValueKey('player-1-check')));
    await tester.pumpAndSettle();

    final checkButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('player-1-check')),
    );
    expect(checkButton.style?.backgroundColor?.resolve({}), Colors.amberAccent);
    expect(find.text('Check - Player 1'), findsNothing);
  });

  testWidgets('reactivates a player when an opponent bets after a check', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPage(
        _MemoryFiveCardStateStore(),
        initialBankAmount: 100,
        anteAmount: 2,
        playerCount: 2,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Deal'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('player-1-check')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('player-2-bet')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('player-2-bet-amount')),
      '10',
    );
    await tester.tap(find.byKey(const ValueKey('player-2-bet-submit')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('player-1-call')))
          .onPressed,
      isNotNull,
    );
    expect(
      find.byKey(const ValueKey('player-1-call-available')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('player-1-fold-available')),
      findsOneWidget,
    );
    final checkButton = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('player-1-check')),
    );
    expect(checkButton.style?.backgroundColor?.resolve({}), Colors.transparent);
  });

  testWidgets('restores hands, bets, folds, and balances', (tester) async {
    final store = _MemoryFiveCardStateStore();
    await tester.pumpWidget(
      buildPage(store, initialBankAmount: 100, anteAmount: 2, playerCount: 2),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Deal'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('player-1-bet')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('player-1-bet-amount')),
      '10',
    );
    await tester.tap(find.byKey(const ValueKey('player-1-bet-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('player-2-fold')));
    await tester.pumpAndSettle();

    final savedState = FiveCardState.decode(store.value!);
    expect(savedState.playerCardIndexes.values, everyElement(hasLength(5)));
    expect(savedState.playerBalances, {1: 88, 2: 98});
    expect(savedState.playerWagers, {1: 12, 2: 2});
    expect(savedState.playerBets, {1: 10, 2: 0});
    expect(savedState.playerActions, {1: 'Bet', 2: 'Fold'});
    expect(savedState.foldedPlayers, {2});

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      buildPage(store, initialBankAmount: 100, anteAmount: 2, playerCount: 2),
    );
    await tester.pumpAndSettle();

    for (final label in [
      'Player 1 chip bank, 88 dollars',
      'Player 2 chip bank, 98 dollars',
      'Player 1 table wager, 12 dollars',
      'Player 2 table wager, 2 dollars',
    ]) {
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.label == label,
        ),
        findsOneWidget,
      );
    }
    expect(findCardBacks(), findsNWidgets(10));
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('player-2-fold')))
          .style
          ?.backgroundColor
          ?.resolve({}),
      Colors.amberAccent,
    );
  });

  testWidgets('shows each player bank as exact denomination stacks', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPage(_MemoryFiveCardStateStore(), initialBankAmount: 136),
    );
    await tester.pumpAndSettle();

    for (var player = 1; player <= 5; player++) {
      expect(find.byKey(ValueKey('player-$player-chip-bank')), findsOneWidget);
      for (final value in [10, 5, 1]) {
        expect(
          find.byKey(ValueKey('player-$player-chip-$value')),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(ValueKey('player-$player-chip-10-image-0')),
        findsOneWidget,
      );
    }
    expect(find.text('x13'), findsNWidgets(5));
  });

  testWidgets('reveals poker hand rankings and the winning player', (
    tester,
  ) async {
    final state = FiveCardState(
      deckCardIndexes: List.generate(52, (index) => index),
      playerCardIndexes: const {
        1: [8, 9, 10, 11, 12],
        2: [0, 13, 26, 39, 1],
        3: [2, 15, 28, 3, 16],
        4: [14, 17, 20, 23, 25],
        5: [41, 29, 4, 5, 6],
      },
      nextCardIndex: 25,
      handsRevealed: true,
    );

    await tester.pumpWidget(
      buildPage(_MemoryFiveCardStateStore(state.encode())),
    );
    await tester.pumpAndSettle();

    final handLabels = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .whereType<String>()
        .where(
          (text) =>
              text.contains('WINNER') ||
              const {
                'High Card',
                'One Pair',
                'Two Pair',
                'Three of a Kind',
                'Straight',
                'Flush',
                'Full House',
                'Four of a Kind',
                'Straight Flush',
              }.contains(text),
        )
        .toList();
    expect(handLabels, [
      'Straight Flush - WINNER',
      'Four of a Kind',
      'Full House',
      'Flush',
      'Straight',
    ]);
    expect(find.byType(PlayingCardFace), findsNWidgets(25));
    expect(find.text('Hit'), findsNothing);
    expect(find.text('Stand'), findsNothing);
  });

  testWidgets('awards all table wagers to the winning hand', (tester) async {
    final state = FiveCardState(
      deckCardIndexes: List.generate(52, (index) => index),
      playerCardIndexes: const {
        1: [8, 9, 10, 11, 12],
        2: [0, 13, 26, 39, 1],
        3: [2, 15, 28, 3, 16],
        4: [14, 17, 20, 23, 25],
        5: [41, 29, 4, 5, 6],
      },
      nextCardIndex: 25,
      handsRevealed: false,
    );

    await tester.pumpWidget(
      buildPage(_MemoryFiveCardStateStore(state.encode())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('player-2-bet')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('player-2-bet-amount')),
      '100',
    );
    await tester.tap(find.byKey(const ValueKey('player-2-bet-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('player-1-call')));
    await tester.pump();

    for (var player = 1; player <= 5; player++) {
      await tester.tap(find.byKey(ValueKey('player-$player-cards')));
      await tester.pump();
    }

    expect(find.text(r'Player 1 wins $200'), findsOneWidget);
    expect(find.text('x11'), findsOneWidget);
    expect(find.text('x18'), findsOneWidget);
    expect(find.byKey(const ValueKey('player-1-chip-100')), findsOneWidget);
    expect(find.byKey(const ValueKey('player-2-chip-50')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('player-1-table-wager')), findsNothing);
    expect(find.byKey(const ValueKey('player-2-table-wager')), findsNothing);
  });

  testWidgets('computer raises a user bet with strong winning odds', (
    tester,
  ) async {
    final state = FiveCardState(
      deckCardIndexes: List.generate(52, (index) => index),
      playerCardIndexes: const {
        1: [2, 15, 28, 3, 16],
        2: [0, 13, 26, 39, 1],
        3: [7, 20, 33, 46, 2],
        4: [14, 17, 20, 23, 25],
        5: [41, 29, 4, 5, 6],
      },
      nextCardIndex: 25,
      handsRevealed: false,
    );
    final stateStore = _MemoryFiveCardStateStore(state.encode());

    await tester.pumpWidget(
      buildPage(stateStore, automateComputerPlayers: true),
    );
    await tester.pumpAndSettle();

    expect(find.text('PLAYER 1 - YOU'), findsOneWidget);
    expect(find.text('PLAYER 2 - COMPUTER'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('player-2-bet')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('player-1-bet')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('player-1-bet-amount')),
      '100',
    );
    await tester.tap(find.byKey(const ValueKey('player-1-bet-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('player-2-table-wager')), findsOneWidget);
    final savedState = FiveCardState.decode(stateStore.value!);
    expect(savedState.playerActions[2], 'Raise');
    expect(savedState.playerBets[2], greaterThan(100));
    expect(savedState.playerBalances[2], inInclusiveRange(0, 899));
    expect(find.byKey(const ValueKey('raise-response-prompt')), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('player-1-call')))
          .onPressed,
      isNotNull,
    );
    final playerTwoRaise = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('player-2-raise')),
    );
    expect(
      playerTwoRaise.style?.backgroundColor?.resolve({}),
      Colors.amberAccent,
    );
  });

  testWidgets('reveals all remaining hands after every player calls', (
    tester,
  ) async {
    final state = FiveCardState(
      deckCardIndexes: List.generate(52, (index) => index),
      playerCardIndexes: const {
        1: [8, 9, 10, 11, 12],
        2: [0, 13, 2, 16, 30],
      },
      nextCardIndex: 10,
      handsRevealed: false,
    );

    await tester.pumpWidget(
      buildPage(
        _MemoryFiveCardStateStore(state.encode()),
        playerCount: 2,
        automateComputerPlayers: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('player-2-cards')));
    await tester.pump();
    expect(find.byType(PlayingCardFace), findsNothing);
    expect(findCardBacks(), findsNWidgets(10));

    await tester.tap(find.byKey(const ValueKey('player-1-bet')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('player-1-bet-amount')),
      '100',
    );
    await tester.tap(find.byKey(const ValueKey('player-1-bet-submit')));
    await tester.pumpAndSettle();

    expect(find.byType(PlayingCardFace), findsNWidgets(10));
    expect(findCardBacks(), findsNothing);
    expect(find.text('One Pair'), findsOneWidget);
    expect(find.text(r'Player 1 wins $200'), findsOneWidget);
  });

  testWidgets('keeps a folded computer hand face down at showdown', (
    tester,
  ) async {
    final state = FiveCardState(
      deckCardIndexes: List.generate(52, (index) => index),
      playerCardIndexes: const {
        1: [8, 9, 10, 11, 12],
        2: [0, 14, 28, 42, 5],
      },
      nextCardIndex: 10,
      handsRevealed: false,
    );

    await tester.pumpWidget(
      buildPage(
        _MemoryFiveCardStateStore(state.encode()),
        playerCount: 2,
        automateComputerPlayers: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('player-1-bet')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('player-1-bet-amount')),
      '100',
    );
    await tester.tap(find.byKey(const ValueKey('player-1-bet-submit')));
    await tester.pumpAndSettle();

    expect(find.byType(PlayingCardFace), findsNWidgets(5));
    expect(findCardBacks(), findsNWidgets(5));
    expect(find.text('FACE DOWN'), findsOneWidget);
    expect(find.text(r'Player 1 wins $100'), findsOneWidget);
  });

  testWidgets('reveals only the clicked player hand', (tester) async {
    final stateStore = _MemoryFiveCardStateStore();
    await tester.pumpWidget(buildPage(stateStore));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Deal'));
    await tester.pump();
    expect(findCardBacks(), findsOneWidget);

    for (var card = 1; card < 25; card++) {
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.pumpAndSettle();

    expect(findCardBacks(), findsNWidgets(25));
    expect(find.text('Reveal'), findsNothing);
    expect(find.text('FACE DOWN'), findsNWidgets(5));

    await tester.tap(find.byKey(const ValueKey('player-3-cards')));
    await tester.pumpAndSettle();
    expect(find.byType(PlayingCardFace), findsNWidgets(5));
    expect(findCardBacks(), findsNWidgets(20));
    expect(find.text('FACE DOWN'), findsNWidgets(4));

    final saved = FiveCardState.decode((await stateStore.read())!);
    expect(saved.playerCardIndexes.values, everyElement(hasLength(5)));
    expect(saved.nextCardIndex, 25);
    expect(saved.handsRevealed, isFalse);
    expect(saved.revealedPlayerNumbers, {3});
  });

  testWidgets('moves bet, call, and raise chips to the table and folds', (
    tester,
  ) async {
    final state = FiveCardState(
      deckCardIndexes: List.generate(52, (index) => index),
      playerCardIndexes: const {
        1: [0, 1, 2, 3, 4],
        2: [5, 6, 7, 8, 9],
        3: [10, 11, 12, 13, 14],
        4: [15, 16, 17, 18, 19],
        5: [20, 21, 22, 23, 24],
      },
      nextCardIndex: 25,
      handsRevealed: false,
    );

    await tester.pumpWidget(
      buildPage(_MemoryFiveCardStateStore(state.encode())),
    );
    await tester.pumpAndSettle();

    for (final action in ['Bet', 'Raise', 'Call', 'Fold']) {
      expect(find.text(action), findsNWidgets(5));
    }

    await tester.tap(find.byKey(const ValueKey('player-1-bet')));
    await tester.pumpAndSettle();
    expect(find.text('Bet - Player 1'), findsOneWidget);
    final betText = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('player-1-bet-amount')),
        matching: find.byType(EditableText),
      ),
    );
    expect(betText.style.color, isNot(Colors.white));
    expect(betText.style.color?.a, 1);
    await tester.enterText(
      find.byKey(const ValueKey('player-1-bet-amount')),
      '1001',
    );
    await tester.tap(find.byKey(const ValueKey('player-1-bet-submit')));
    await tester.pump();
    expect(find.text(r'Amount exceeds the $1000 bank'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('player-1-bet-amount')),
      '125',
    );
    await tester.tap(find.byKey(const ValueKey('player-1-bet-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('player-1-table-wager')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('player-1-table-chip-10')),
      findsOneWidget,
    );
    expect(find.text('x12'), findsOneWidget);
    expect(find.text('x17'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('player-2-call')));
    await tester.pump();
    expect(find.byKey(const ValueKey('player-2-table-wager')), findsOneWidget);
    expect(find.text('x12'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('player-3-raise')));
    await tester.pumpAndSettle();
    expect(find.text('Raise - Player 3'), findsOneWidget);
    expect(find.text(r'Includes $125 to call'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('player-3-raise-amount')),
      '200',
    );
    await tester.tap(find.byKey(const ValueKey('player-3-raise-submit')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('player-3-table-chip-20')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('raise-response-prompt')), findsNothing);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('player-1-call')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('player-2-call')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('player-4-fold')))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const ValueKey('player-4-call')));
    await tester.pump();
    expect(find.byKey(const ValueKey('raise-response-prompt')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('player-5-fold')));
    await tester.pump();
    expect(find.text(r'Player 1: Call $75 or Fold'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('player-1-call')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('player-1-table-chip-20')),
      findsOneWidget,
    );
    expect(find.text(r'Player 2: Call $75 or Fold'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('player-2-fold')));
    await tester.pump();
    expect(find.byKey(const ValueKey('raise-response-prompt')), findsNothing);
    final playerTwoFold = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('player-2-fold')),
    );
    final playerTwoRaise = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('player-2-raise')),
    );
    expect(
      playerTwoFold.style?.backgroundColor?.resolve({}),
      Colors.amberAccent,
    );
    expect(playerTwoRaise.onPressed, isNull);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('player-4-fold')))
          .onPressed,
      isNull,
    );
  });
}

class _MemoryFiveCardStateStore implements FiveCardStateStore {
  _MemoryFiveCardStateStore([this.value]);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> remove() async => value = null;

  @override
  Future<void> write(String value) async => this.value = value;
}
