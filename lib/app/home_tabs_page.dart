import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../features/draw/draw_page.dart';
import '../features/five_card/five_card_page.dart';
import '../features/five_card/persistence/five_card_state_store.dart';
import '../features/card_backs/card_back_selector.dart';
import '../features/help/help_page.dart';
import '../features/holdem/holdem_page.dart';
import '../features/information/information_page.dart';
import '../features/stud/stud_page.dart';
import '../shared/card_table_surface.dart';
import '../shared/cards/card_back.dart';

/// Hosts all game variants and distributes shared table settings to each tab.
class HomeTabsPage extends StatefulWidget {
  const HomeTabsPage({
    required this.selectedCardBackIndex,
    required this.onCardBackSelected,
    this.fiveCardStateStore,
    super.key,
  });

  static const _tabLabels = [
    'Card Backs',
    'Five Card',
    'Draw',
    'Stud',
    'Stud7',
    "Hold'em",
    'Information',
    'Help',
  ];

  final int selectedCardBackIndex;
  final ValueChanged<int> onCardBackSelected;
  final FiveCardStateStore? fiveCardStateStore;

  @override
  State<HomeTabsPage> createState() => _HomeTabsPageState();
}

class _HomeTabsPageState extends State<HomeTabsPage> {
  static const _defaultNumberOfPlayers = 5;
  static const _defaultInitialBankAmount = 1000;
  static const _defaultAnteAmount = 2;

  int _numberOfPlayers = _defaultNumberOfPlayers;
  int _initialBankAmount = _defaultInitialBankAmount;
  int _anteAmount = _defaultAnteAmount;
  int _maxCardsToDraw = 5;
  bool _teachMode = false;
  int _fundsResetToken = 0;

  /// Edits game settings atomically after every field passes validation.
  ///
  /// Temporary values remain local to the dialog, so cancelling cannot mutate
  /// an active game configuration.
  Future<void> _showSettings() async {
    final formKey = GlobalKey<FormState>();
    var playerCountText = '$_numberOfPlayers';
    var bankAmountText = '$_initialBankAmount';
    var anteAmountText = '$_anteAmount';
    var maxCardsToDrawText = '$_maxCardsToDraw';
    var teachMode = _teachMode;
    var resetFunds = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Settings'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    key: const ValueKey('number-of-players-field'),
                    initialValue: playerCountText,
                    decoration: const InputDecoration(
                      labelText: 'Number of players (2-5)',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) => playerCountText = value,
                    validator: (value) {
                      final playerCount = int.tryParse(value ?? '');
                      if (playerCount == null ||
                          playerCount < 2 ||
                          playerCount > 5) {
                        return 'Enter a number from 2 to 5';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('initial-bank-amount-field'),
                    initialValue: bankAmountText,
                    decoration: const InputDecoration(
                      labelText: 'Initial bank amount',
                      prefixText: r'$',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) => bankAmountText = value,
                    validator: (value) {
                      final bankAmount = int.tryParse(value ?? '');
                      if (bankAmount == null || bankAmount <= 0) {
                        return 'Enter an amount greater than 0';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('ante-amount-field'),
                    initialValue: anteAmountText,
                    decoration: const InputDecoration(
                      labelText: 'Ante',
                      prefixText: r'$',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) => anteAmountText = value,
                    validator: (value) {
                      final anteAmount = int.tryParse(value ?? '');
                      if (anteAmount == null || anteAmount <= 0) {
                        return 'Enter an ante greater than 0';
                      }
                      final bankAmount = int.tryParse(bankAmountText);
                      if (bankAmount != null && anteAmount > bankAmount) {
                        return 'Ante cannot exceed the initial bank';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('max-cards-to-draw-field'),
                    initialValue: maxCardsToDrawText,
                    decoration: const InputDecoration(
                      labelText: 'Maximum cards to draw (1-5)',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) => maxCardsToDrawText = value,
                    validator: (value) {
                      final maxCards = int.tryParse(value ?? '');
                      if (maxCards == null || maxCards < 1 || maxCards > 5) {
                        return 'Enter a number from 1 to 5';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    key: const ValueKey('reset-funds-button'),
                    onPressed: () {
                      setDialogState(() {
                        bankAmountText = '$_defaultInitialBankAmount';
                        anteAmountText = '$_defaultAnteAmount';
                        resetFunds = true;
                      });
                    },
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset funds to defaults'),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Teach Mode'),
                      SegmentedButton<bool>(
                        key: const ValueKey('teach-mode-selector'),
                        segments: const [
                          ButtonSegment(value: true, label: Text('On')),
                          ButtonSegment(value: false, label: Text('Off')),
                        ],
                        selected: {teachMode},
                        onSelectionChanged: (selection) {
                          setDialogState(() => teachMode = selection.single);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                setState(() {
                  _numberOfPlayers = resetFunds
                      ? _defaultNumberOfPlayers
                      : int.parse(playerCountText);
                  _initialBankAmount = int.parse(bankAmountText);
                  _anteAmount = int.parse(anteAmountText);
                  _maxCardsToDraw = int.parse(maxCardsToDrawText);
                  _teachMode = teachMode;
                });
                if (resetFunds) {
                  _fundsResetToken++;
                  final resetStateStore =
                      widget.fiveCardStateStore ??
                      SharedPreferencesFiveCardStateStore();
                  resetStateStore.remove();
                  Navigator.of(dialogContext).pop();
                  return;
                }
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: HomeTabsPage._tabLabels.length,
      child: Scaffold(
        appBar: AppBar(
          foregroundColor: Colors.white,
          backgroundColor: const Color(0xFF8F1D24),
          flexibleSpace: const CustomPaint(
            painter: FeltTexturePainter(),
            child: SizedBox.expand(),
          ),
          title: const Text('Play Poker'),
          actions: [
            Builder(
              builder: (context) => IconButton(
                key: const ValueKey('settings-button'),
                tooltip: 'Settings',
                onPressed: _showSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kTextTabBarHeight),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isScrollable = !_tabsFit(context, constraints.maxWidth);
                return TabBar(
                  key: const ValueKey('home-tab-bar'),
                  isScrollable: isScrollable,
                  tabAlignment: isScrollable
                      ? TabAlignment.start
                      : TabAlignment.fill,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  indicatorColor: Colors.white,
                  tabs: [
                    for (final label in HomeTabsPage._tabLabels)
                      Tab(text: label),
                  ],
                );
              },
            ),
          ),
        ),
        body: TabBarView(
          children: [
            CardTableSurface(
              child: CardBackSelector(
                selectedIndex: widget.selectedCardBackIndex,
                onSelected: widget.onCardBackSelected,
              ),
            ),
            CardTableSurface(
              child: FiveCardPage(
                key: ValueKey('five-card-$_fundsResetToken'),
                cardBack: cardBackDesigns[widget.selectedCardBackIndex],
                patternIndex: widget.selectedCardBackIndex,
                playerCount: _numberOfPlayers,
                initialBankAmount: _initialBankAmount,
                anteAmount: _anteAmount,
                teachMode: _teachMode,
                stateStore: widget.fiveCardStateStore,
              ),
            ),
            DrawPage(
              key: ValueKey('draw-$_fundsResetToken'),
              cardBack: cardBackDesigns[widget.selectedCardBackIndex],
              patternIndex: widget.selectedCardBackIndex,
              playerCount: _numberOfPlayers,
              maxCardsToDraw: _maxCardsToDraw,
              initialBankAmount: _initialBankAmount,
              anteAmount: _anteAmount,
              teachMode: _teachMode,
            ),
            StudPage(
              key: ValueKey('stud-$_fundsResetToken'),
              cardBack: cardBackDesigns[widget.selectedCardBackIndex],
              patternIndex: widget.selectedCardBackIndex,
              playerCount: _numberOfPlayers,
              initialBankAmount: _initialBankAmount,
              anteAmount: _anteAmount,
              teachMode: _teachMode,
            ),
            StudPage(
              key: ValueKey('stud7-$_fundsResetToken'),
              cardBack: cardBackDesigns[widget.selectedCardBackIndex],
              patternIndex: widget.selectedCardBackIndex,
              playerCount: _numberOfPlayers,
              initialBankAmount: _initialBankAmount,
              anteAmount: _anteAmount,
              cardCount: 7,
              teachMode: _teachMode,
            ),
            HoldemPage(
              key: ValueKey('holdem-$_fundsResetToken'),
              cardBack: cardBackDesigns[widget.selectedCardBackIndex],
              patternIndex: widget.selectedCardBackIndex,
              playerCount: _numberOfPlayers,
              initialBankAmount: _initialBankAmount,
              anteAmount: _anteAmount,
              teachMode: _teachMode,
            ),
            const InformationPage(),
            const HelpPage(),
          ],
        ),
      ),
    );
  }

  bool _tabsFit(BuildContext context, double availableWidth) {
    final textStyle = Theme.of(context).tabBarTheme.labelStyle;
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    var requiredWidth = 0.0;
    for (final label in HomeTabsPage._tabLabels) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: textStyle),
        maxLines: 1,
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout();
      requiredWidth += math.max(kMinInteractiveDimension, painter.width + 32);
    }
    return requiredWidth <= availableWidth;
  }
}
