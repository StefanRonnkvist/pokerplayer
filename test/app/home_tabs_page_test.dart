import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playpoker/app/home_tabs_page.dart';
import 'package:playpoker/features/five_card/five_card_page.dart';
import 'package:playpoker/features/five_card/persistence/five_card_state_store.dart';
import 'package:playpoker/features/stud/stud_page.dart';

void main() {
  testWidgets('tab labels fill wide space and scroll in limited space', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    tester.view.physicalSize = const Size(1200, 800);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeTabsPage(
          selectedCardBackIndex: 0,
          onCardBackSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    var tabBar = tester.widget<TabBar>(
      find.byKey(const ValueKey('home-tab-bar')),
    );
    expect(tabBar.isScrollable, isFalse);
    expect(tabBar.tabAlignment, TabAlignment.fill);

    tester.view.physicalSize = const Size(360, 800);
    await tester.pumpAndSettle();

    tabBar = tester.widget<TabBar>(find.byKey(const ValueKey('home-tab-bar')));
    expect(tabBar.isScrollable, isTrue);
    expect(tabBar.tabAlignment, TabAlignment.start);
  });

  testWidgets('settings button opens game configuration fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeTabsPage(
          selectedCardBackIndex: 0,
          onCardBackSelected: (_) {},
          fiveCardStateStore: _MemoryFiveCardStateStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Number of players (2-5)'), findsOneWidget);
    expect(find.text('Initial bank amount'), findsOneWidget);
    expect(find.text('Ante'), findsOneWidget);
    expect(find.text('Maximum cards to draw (1-5)'), findsOneWidget);
    expect(find.text('Teach Mode'), findsOneWidget);
    expect(find.text('On'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);

    final playerField = tester.widget<TextFormField>(
      find.byKey(const ValueKey('number-of-players-field')),
    );
    final bankField = tester.widget<TextFormField>(
      find.byKey(const ValueKey('initial-bank-amount-field')),
    );
    final anteField = tester.widget<TextFormField>(
      find.byKey(const ValueKey('ante-amount-field')),
    );
    final maxDrawField = tester.widget<TextFormField>(
      find.byKey(const ValueKey('max-cards-to-draw-field')),
    );
    expect(playerField.initialValue, '5');
    expect(bankField.initialValue, '1000');
    expect(anteField.initialValue, '2');
    expect(maxDrawField.initialValue, '5');
    var teachModeSelector = tester.widget<SegmentedButton<bool>>(
      find.byKey(const ValueKey('teach-mode-selector')),
    );
    expect(teachModeSelector.selected, {false});

    await tester.tap(find.text('On'));
    await tester.pump();
    teachModeSelector = tester.widget<SegmentedButton<bool>>(
      find.byKey(const ValueKey('teach-mode-selector')),
    );
    expect(teachModeSelector.selected, {true});

    await tester.enterText(
      find.byKey(const ValueKey('number-of-players-field')),
      '6',
    );
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Enter a number from 2 to 5'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('number-of-players-field')),
      '5',
    );
    await tester.enterText(
      find.byKey(const ValueKey('max-cards-to-draw-field')),
      '6',
    );
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Enter a number from 1 to 5'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('max-cards-to-draw-field')),
      '5',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Five Card'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<FiveCardPage>(find.byType(FiveCardPage)).teachMode,
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();

    teachModeSelector = tester.widget<SegmentedButton<bool>>(
      find.byKey(const ValueKey('teach-mode-selector')),
    );
    expect(teachModeSelector.selected, {true});
  });

  testWidgets('player count setting updates the five card table', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeTabsPage(
          selectedCardBackIndex: 0,
          onCardBackSelected: (_) {},
          fiveCardStateStore: _MemoryFiveCardStateStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('number-of-players-field')),
      '3',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Five Card'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('player-1-cards')), findsOneWidget);
    expect(find.byKey(const ValueKey('player-3-cards')), findsOneWidget);
    expect(find.byKey(const ValueKey('player-4-cards')), findsNothing);
  });

  testWidgets('Draw tab uses the configured maximum draw count', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeTabsPage(
          selectedCardBackIndex: 0,
          onCardBackSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('max-cards-to-draw-field')),
      '2',
    );
    await tester.enterText(
      find.byKey(const ValueKey('number-of-players-field')),
      '3',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Draw'), findsOneWidget);
    await tester.tap(find.text('Draw'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('draw-page')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('draw-deal-button')));
    await tester.pumpAndSettle();
    expect(find.text('Select up to 2 cards'), findsOneWidget);
    expect(find.byKey(const ValueKey('draw-player-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('draw-player-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('draw-player-4')), findsNothing);
  });

  testWidgets('Stud tab uses the configured player count', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeTabsPage(
          selectedCardBackIndex: 0,
          onCardBackSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('number-of-players-field')),
      '3',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stud'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('stud-page')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('stud-deal-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('stud-player-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('stud-player-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('stud-player-4')), findsNothing);
  });

  testWidgets('Stud7 tab opens a Stud table', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeTabsPage(
          selectedCardBackIndex: 0,
          onCardBackSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stud7'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('stud-page')), findsOneWidget);
    expect(tester.widget<StudPage>(find.byType(StudPage)).cardCount, 7);
  });

  testWidgets("Hold'em tab opens a configured Texas Hold'em table", (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeTabsPage(
          selectedCardBackIndex: 0,
          onCardBackSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Hold'em"));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('holdem-page')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('holdem-community-cards')),
      findsOneWidget,
    );
  });
}

class _MemoryFiveCardStateStore implements FiveCardStateStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> remove() async => value = null;

  @override
  Future<void> write(String value) async => this.value = value;
}
