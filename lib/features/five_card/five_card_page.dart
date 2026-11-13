import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:playing_cards/playing_cards.dart';

import '../../app/shared/game_layout.dart';
import '../../app/shared/widgets/betting_actions.dart';
import '../../app/shared/widgets/game_deck_button_styles.dart';
import '../../shared/cards/card_back.dart';
import '../../shared/cards/playing_card_face.dart';
import '../../shared/computer_win_celebration.dart';
import 'five_card_state.dart';
import 'models/poker_hand.dart';
import 'persistence/five_card_state_store.dart';
import 'strategy/computer_strategy.dart';
import 'widgets/chip_stacks.dart';
import 'widgets/table_wagers.dart';

class FiveCardPage extends StatefulWidget {
  const FiveCardPage({
    required this.cardBack,
    required this.patternIndex,
    this.playerCount = 5,
    this.initialBankAmount = 1000,
    this.anteAmount = 2,
    this.teachMode = false,
    this.automateComputerPlayers = true,
    this.stateStore,
    super.key,
  }) : assert(playerCount >= 2 && playerCount <= 5),
       assert(initialBankAmount > 0),
       assert(anteAmount > 0 && anteAmount <= initialBankAmount);

  final CardBackDesign cardBack;
  final int patternIndex;
  final int playerCount;
  final int initialBankAmount;
  final int anteAmount;
  final bool teachMode;
  final bool automateComputerPlayers;
  final FiveCardStateStore? stateStore;

  @override
  State<FiveCardPage> createState() => _FiveCardPageState();
}

class _FiveCardPageState extends State<FiveCardPage> {
  static const _controlsHeight = 40.0;
  static const _dealDelay = Duration(milliseconds: 80);

  static const _spacing = 12.0;

  final _standardDeck = standardFiftyTwoCardDeck();
  late final FiveCardStateStore _stateStore;
  Future<void> _pendingSave = Future.value();
  List<PlayingCard>? dealtCards;
  final playerHands = <int, List<PlayingCard>>{};
  final playerActions = <int, String>{};
  final playerBalances = <int, int>{};
  final playerWagers = <int, int>{};
  final playerBets = <int, int>{};
  final foldedPlayers = <int>{};
  final pendingRaiseResponders = <int>[];
  final pendingComputerPlayers = <int>[];
  final revealedPlayerNumbers = <int>{};
  String? payoutMessage;
  String? computerCelebration;
  final computerWinStreaks = <int, int>{};
  bool potAwarded = false;
  int nextCardIndex = 0;
  bool isDealing = false;
  bool isRestoring = true;
  bool computerTurnRunning = false;
  bool bettingRoundStarted = false;

  @override
  void initState() {
    super.initState();
    _stateStore = widget.stateStore ?? SharedPreferencesFiveCardStateStore();
    _restoreState();
  }

  @override
  void didUpdateWidget(FiveCardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playerCount != oldWidget.playerCount) {
      setState(() {
        dealtCards = null;
        playerHands.clear();
        playerActions.clear();
        _resetPlayerMoney();
        revealedPlayerNumbers.clear();
        nextCardIndex = 0;
        isDealing = false;
      });
      _removeInvalidState();
    } else if (widget.initialBankAmount != oldWidget.initialBankAmount ||
        widget.anteAmount != oldWidget.anteAmount) {
      setState(_resetPlayerMoney);
      _schedulePersistence();
    }
  }

  /// Restores a compatible snapshot and resumes any queued computer turns.
  ///
  /// Corrupt data and saves for a different player count are removed. Storage
  /// failures are deliberately non-fatal so the page can start a fresh game.
  Future<void> _restoreState() async {
    FiveCardState? savedState;
    try {
      final encoded = await _stateStore.read();
      if (encoded != null) {
        savedState = FiveCardState.decode(encoded);
      }
    } on FormatException {
      await _removeInvalidState();
    } on Exception {
      // Start a new game when storage is temporarily unavailable.
    }

    if (!mounted) {
      return;
    }

    final state =
        savedState != null &&
            (savedState.playerCount == null ||
                savedState.playerCount == widget.playerCount) &&
            savedState.playerCardIndexes.keys.every(
              (player) => player <= widget.playerCount,
            )
        ? savedState
        : null;
    if (savedState != null && state == null) {
      await _removeInvalidState();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _resetPlayerMoney();
      if (state != null) {
        dealtCards = state.deckCardIndexes
            ?.map((index) => _standardDeck[index])
            .toList();
        playerHands
          ..clear()
          ..addEntries(
            state.playerCardIndexes.entries.map(
              (entry) => MapEntry(
                entry.key,
                entry.value.map((index) => _standardDeck[index]).toList(),
              ),
            ),
          );
        nextCardIndex = state.nextCardIndex;
        revealedPlayerNumbers
          ..clear()
          ..addAll(state.revealedPlayerNumbers);
        playerBalances.addAll(state.playerBalances);
        playerWagers.addAll(state.playerWagers);
        playerBets.addAll(state.playerBets);
        playerActions.addAll(state.playerActions);
        foldedPlayers.addAll(state.foldedPlayers);
        pendingRaiseResponders.addAll(state.pendingRaiseResponders);
        pendingComputerPlayers.addAll(state.pendingComputerPlayers);
        payoutMessage = state.payoutMessage;
        potAwarded = state.potAwarded;
        bettingRoundStarted = state.bettingRoundStarted;
      }
      isRestoring = false;
    });
    if (state != null && widget.automateComputerPlayers) {
      _runComputerTurns();
    }
  }

  void _resetPlayerMoney() {
    playerBalances
      ..clear()
      ..addEntries(
        List.generate(
          widget.playerCount,
          (index) => MapEntry(index + 1, widget.initialBankAmount),
        ),
      );
    _resetBettingRound();
  }

  void _resetBettingRound() {
    playerWagers.clear();
    playerBets.clear();
    foldedPlayers.clear();
    pendingRaiseResponders.clear();
    pendingComputerPlayers.clear();
    payoutMessage = null;
    computerCelebration = null;
    potAwarded = false;
    computerTurnRunning = false;
    bettingRoundStarted = false;
  }

  Future<void> _removeInvalidState() async {
    try {
      await _stateStore.remove();
    } on Exception {
      // A storage failure should not prevent starting a new game.
    }
  }

  void _schedulePersistence() {
    if (isRestoring) {
      return;
    }

    final encoded = _createSavedState().encode();
    _pendingSave = _pendingSave.then((_) => _saveState(encoded));
  }

  Future<void> _saveState(String encoded) async {
    try {
      await _stateStore.write(encoded);
    } on Exception {
      // Keep the game usable when persistence is temporarily unavailable.
    }
  }

  FiveCardState _createSavedState() {
    return FiveCardState(
      deckCardIndexes: dealtCards?.map(_cardIndex).toList(),
      playerCardIndexes: playerHands.map(
        (player, cards) => MapEntry(player, cards.map(_cardIndex).toList()),
      ),
      nextCardIndex: nextCardIndex,
      handsRevealed: revealedPlayerNumbers.length == widget.playerCount,
      revealedPlayerNumbers: revealedPlayerNumbers,
      playerCount: widget.playerCount,
      playerBalances: playerBalances,
      playerWagers: playerWagers,
      playerBets: playerBets,
      playerActions: playerActions,
      foldedPlayers: foldedPlayers,
      pendingRaiseResponders: pendingRaiseResponders,
      pendingComputerPlayers: pendingComputerPlayers,
      payoutMessage: payoutMessage,
      potAwarded: potAwarded,
      bettingRoundStarted: bettingRoundStarted,
    );
  }

  int _cardIndex(PlayingCard card) {
    return _standardDeck.indexWhere(
      (candidate) =>
          candidate.suit == card.suit && candidate.value == card.value,
    );
  }

  /// Deals five cards round-robin after posting each player's ante.
  ///
  /// The current deck is reused until it lacks enough cards for another hand,
  /// preserving the persisted deck position across page restarts.
  Future<void> deal() async {
    if (isDealing) {
      return;
    }

    FocusScope.of(context).unfocus();
    final cards = dealtCards ?? _shuffledDeck();

    final cardsPerDeal = widget.playerCount * 5;
    if (cards.length - nextCardIndex < cardsPerDeal) {
      return;
    }

    setState(() {
      if (dealtCards == null) {
        dealtCards = cards;
        nextCardIndex = 0;
      }
      isDealing = true;
      playerHands
        ..clear()
        ..addEntries(
          List.generate(
            widget.playerCount,
            (index) => MapEntry(index + 1, <PlayingCard>[]),
          ),
        );
      playerActions.clear();
      _resetBettingRound();
      _postAntes();
      revealedPlayerNumbers.clear();
    });

    for (var round = 0; round < 5; round++) {
      for (var player = 1; player <= widget.playerCount; player++) {
        if (!mounted) {
          return;
        }
        setState(() {
          playerHands[player]!.add(cards[nextCardIndex++]);
        });
        await Future<void>.delayed(_dealDelay);
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      isDealing = false;
    });
    _schedulePersistence();
  }

  void _postAntes() {
    for (var player = 1; player <= widget.playerCount; player++) {
      playerBalances[player] = _playerBalance(player) - widget.anteAmount;
      playerWagers[player] = widget.anteAmount;
      playerBets[player] = 0;
    }
  }

  /// Reveals a completed, active hand and attempts to settle the pot.
  void revealHand(int player) {
    if (isDealing ||
        foldedPlayers.contains(player) ||
        playerHands[player]?.length != 5) {
      return;
    }
    setState(() {
      revealedPlayerNumbers.add(player);
      _awardPotIfReady();
    });
    _schedulePersistence();
  }

  /// Awards the pot once every non-folded hand has been revealed.
  ///
  /// Tied players split the pot evenly; indivisible remainder chips are given
  /// in ascending player order to keep payout deterministic.
  void _awardPotIfReady() {
    if (potAwarded || !_allActiveHandsRevealed) {
      return;
    }
    final pot = playerWagers.values.fold(0, (total, wager) => total + wager);
    if (pot == 0) {
      return;
    }

    final evaluatedHands = _evaluatedHands;
    final winningPower = evaluatedHands.values.reduce(
      (best, hand) => hand.compareTo(best) > 0 ? hand : best,
    );
    final winners =
        evaluatedHands.entries
            .where((entry) => entry.value == winningPower)
            .map((entry) => entry.key)
            .toList()
          ..sort();
    final share = pot ~/ winners.length;
    var remainder = pot % winners.length;
    for (final winner in winners) {
      final extraChip = remainder > 0 ? 1 : 0;
      playerBalances[winner] = _playerBalance(winner) + share + extraChip;
      remainder -= extraChip;
    }
    playerWagers.clear();
    playerBets.clear();
    pendingRaiseResponders.clear();
    potAwarded = true;
    payoutMessage = winners.length == 1
        ? 'Player ${winners.single} wins \$$pot'
        : 'Players ${winners.join(' & ')} split \$$pot';
    computerCelebration = recordComputerHandWinners(
      computerWinStreaks,
      winners,
      computersEnabled: widget.automateComputerPlayers,
      playerCount: widget.playerCount,
    );
  }

  /// Validates and dispatches a player's action for the current betting turn.
  ///
  /// Before every player acts once, each player gets one action. Afterwards,
  /// only the head of the raise-response queue may call or fold.
  Future<void> selectAction(int player, String action) async {
    if (isDealing ||
        playerHands[player]?.length != 5 ||
        foldedPlayers.contains(player) ||
        (!_firstBettingTurnComplete && playerActions.containsKey(player)) ||
        (_firstBettingTurnComplete && _activeRaiseResponder == null) ||
        (_activeRaiseResponder != null && _activeRaiseResponder != player) ||
        (_activeRaiseResponder != null &&
            action != 'Call' &&
            action != 'Fold')) {
      return;
    }
    switch (action) {
      case 'Bet':
        await _showWagerDialog(player, action, minimumAmount: 1);
      case 'Raise':
        final callAmount = math.max(0, _highestWager - _playerBet(player));
        await _showWagerDialog(
          player,
          action,
          minimumAmount: _highestWager + 1,
          callAmount: callAmount,
        );
      case 'Call':
        final callAmount = math.max(0, _highestWager - _playerBet(player));
        if (callAmount == 0) {
          return;
        }
        if (callAmount > _playerBalance(player)) {
          await _showInsufficientFundsDialog(player, callAmount);
          return;
        }
        _commitWager(player, callAmount, action);
      case 'Check':
        if (_highestWager != _playerBet(player)) {
          return;
        }
        _commitWager(player, 0, action);
      case 'Fold':
        setState(() {
          foldedPlayers.add(player);
          playerActions[player] = action;
          _completeRaiseResponse(player);
        });
        _continueAfterUserAction(player);
        _schedulePersistence();
    }
  }

  Future<void> _showInsufficientFundsDialog(int player, int callAmount) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Not enough funds to call'),
        content: Text(
          'Player $player needs $callAmount to call, but has '
          '\$${_playerBalance(player)} available.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('insufficient-funds-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const ValueKey('insufficient-funds-add-bank'),
            onPressed: () => Navigator.of(dialogContext).pop('add-bank'),
            child: Text('Add ${widget.initialBankAmount} bank'),
          ),
          FilledButton(
            key: const ValueKey('insufficient-funds-offer-call'),
            onPressed: () => Navigator.of(dialogContext).pop('offer-call'),
            child: Text('Add funds to call ($callAmount)'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) {
      return;
    }
    setState(() {
      playerBalances[player] =
          _playerBalance(player) +
          (choice == 'add-bank' ? widget.initialBankAmount : callAmount);
    });
    if (choice == 'offer-call') {
      _commitWager(player, callAmount, 'Call');
    }
    _schedulePersistence();
  }

  int get _highestWager => playerBets.values.fold(0, math.max);

  bool get _firstBettingTurnComplete =>
      playerHands.isNotEmpty &&
      playerHands.keys.every(playerActions.containsKey);

  int? get _activeRaiseResponder =>
      _firstBettingTurnComplete ? pendingRaiseResponders.firstOrNull : null;

  int _playerBalance(int player) =>
      playerBalances[player] ?? widget.initialBankAmount;

  int _playerWager(int player) => playerWagers[player] ?? 0;

  int _playerBet(int player) => playerBets[player] ?? 0;

  Future<void> _showWagerDialog(
    int player,
    String action, {
    required int minimumAmount,
    int callAmount = 0,
  }) async {
    final formKey = GlobalKey<FormState>();
    var amountText = '';
    final balance = _playerBalance(player);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final baseTheme = Theme.of(dialogContext);
        final dialogColors = ColorScheme.fromSeed(
          seedColor: const Color(0xFF8F1D24),
          brightness: Brightness.light,
        );
        return Theme(
          data: baseTheme.copyWith(
            colorScheme: dialogColors,
            scaffoldBackgroundColor: dialogColors.surface,
            textTheme: baseTheme.textTheme.apply(
              bodyColor: dialogColors.onSurface,
              displayColor: dialogColors.onSurface,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: dialogColors.surface,
              titleTextStyle: baseTheme.textTheme.headlineSmall?.copyWith(
                color: dialogColors.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: dialogColors.surfaceContainerHighest,
              labelStyle: TextStyle(color: dialogColors.onSurfaceVariant),
              floatingLabelStyle: TextStyle(color: dialogColors.primary),
              helperStyle: TextStyle(color: dialogColors.onSurfaceVariant),
              prefixStyle: TextStyle(color: dialogColors.onSurface),
              border: const OutlineInputBorder(),
            ),
          ),
          child: AlertDialog(
            title: Text('$action - Player $player'),
            content: Form(
              key: formKey,
              child: TextFormField(
                key: ValueKey('player-$player-${action.toLowerCase()}-amount'),
                autofocus: true,
                style: TextStyle(
                  color: dialogColors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
                cursorColor: dialogColors.primary,
                decoration: InputDecoration(
                  labelText: action == 'Raise'
                      ? 'Total amount to add'
                      : 'Amount',
                  prefixText: r'$',
                  helperText: action == 'Raise' && callAmount > 0
                      ? 'Includes \$$callAmount to call'
                      : 'Available: \$$balance',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) => amountText = value,
                validator: (value) {
                  final amount = int.tryParse(value ?? '');
                  if (amount == null || amount < minimumAmount) {
                    return action == 'Raise'
                        ? 'Enter at least \$$minimumAmount'
                        : 'Enter an amount greater than 0';
                  }
                  if (amount > balance) {
                    return 'Amount exceeds the \$$balance bank';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submitWagerDialog(
                  dialogContext,
                  formKey,
                  player,
                  action,
                  amountText,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: ValueKey('player-$player-${action.toLowerCase()}-submit'),
                onPressed: () => _submitWagerDialog(
                  dialogContext,
                  formKey,
                  player,
                  action,
                  amountText,
                ),
                child: const Text('Submit'),
              ),
            ],
          ),
        );
      },
    );
  }

  double? _teachModeRecommendation(int player) {
    if (!widget.teachMode || player != 1 || playerHands[player]?.length != 5) {
      return null;
    }
    final callAmount = math.max(0, _highestWager - _playerBet(player));
    final cost = math.max(1, callAmount).toDouble();
    final pot =
        playerWagers.values.fold(0, (total, wager) => total + wager) + cost;
    return calculatePokerBet(
      p: _estimatedWinningOdds(player),
      cost: cost,
      pot: pot,
      maxBet: _playerBalance(player).toDouble(),
    );
  }

  void _submitWagerDialog(
    BuildContext dialogContext,
    GlobalKey<FormState> formKey,
    int player,
    String action,
    String amountText,
  ) {
    if (!formKey.currentState!.validate()) {
      return;
    }
    _commitWager(player, int.parse(amountText), action);
    Navigator.of(dialogContext).pop();
  }

  /// Commits chips and rebuilds the response queue after a bet or raise.
  ///
  /// [amount] is the additional amount removed from the player's balance, not
  /// the player's total wager for the hand.
  void _commitWager(int player, int amount, String action) {
    setState(() {
      playerBalances[player] = _playerBalance(player) - amount;
      playerWagers[player] = _playerWager(player) + amount;
      playerBets[player] = _playerBet(player) + amount;
      playerActions[player] = action;
      if (action == 'Bet' || action == 'Raise') {
        pendingRaiseResponders
          ..clear()
          ..addAll(
            _playersAfter(player).where(
              (candidate) =>
                  !foldedPlayers.contains(candidate) &&
                  playerActions.containsKey(candidate) &&
                  _playerBet(candidate) < _highestWager,
            ),
          );
      } else if (action == 'Call') {
        _completeRaiseResponse(player);
      }
    });
    _continueAfterUserAction(player);
    _schedulePersistence();
  }

  /// Starts or resumes automated turns after player one's action.
  void _continueAfterUserAction(int player) {
    if (!widget.automateComputerPlayers || player != 1 || potAwarded) {
      return;
    }
    if (!bettingRoundStarted) {
      bettingRoundStarted = true;
      pendingComputerPlayers.addAll(
        List.generate(widget.playerCount - 1, (index) => index + 2),
      );
    }
    _runComputerTurns();
  }

  /// Drains queued computer actions until input from player one is required.
  ///
  /// Raise responses take priority over first-turn decisions so every active
  /// player's bet catches up before the round can settle.
  void _runComputerTurns() {
    if (computerTurnRunning || !mounted) {
      return;
    }
    computerTurnRunning = true;
    while (mounted && !potAwarded) {
      final responder = _activeRaiseResponder;
      if (responder == 1) {
        break;
      }
      if (responder != null) {
        _performComputerResponse(responder);
        continue;
      }
      if (pendingComputerPlayers.isEmpty) {
        break;
      }
      final player = pendingComputerPlayers.removeAt(0);
      if (!foldedPlayers.contains(player)) {
        _performComputerDecision(player);
      }
    }
    computerTurnRunning = false;
    _finishBettingIfSettled();
  }

  /// Reveals active hands when all turns are complete and bets are matched.
  void _finishBettingIfSettled() {
    if (!widget.automateComputerPlayers ||
        !bettingRoundStarted ||
        potAwarded ||
        pendingComputerPlayers.isNotEmpty ||
        _activeRaiseResponder != null ||
        !_activePlayers.every(
          (player) => _playerBet(player) == _highestWager,
        )) {
      return;
    }
    setState(() {
      revealedPlayerNumbers
        ..clear()
        ..addAll(_activePlayers);
      _awardPotIfReady();
    });
    _schedulePersistence();
  }

  void _performComputerDecision(int player) {
    final decision = chooseComputerDecision(
      balance: _playerBalance(player),
      currentBet: _playerBet(player),
      highestBet: _highestWager,
      pot: playerWagers.values.fold(0, (total, wager) => total + wager),
      winningOdds: _estimatedWinningOdds(player),
    );
    _applyComputerDecision(player, decision);
  }

  void _performComputerResponse(int player) {
    final callAmount = _highestWager - _playerBet(player);
    final decision = chooseComputerResponse(
      balance: _playerBalance(player),
      callAmount: callAmount,
      pot: playerWagers.values.fold(0, (total, wager) => total + wager),
      winningOdds: _estimatedWinningOdds(player),
    );
    _applyComputerDecision(player, decision);
  }

  void _applyComputerDecision(int player, ComputerDecision decision) {
    switch (decision.action) {
      case ComputerAction.bet:
        _commitWager(player, decision.amount, 'Bet');
      case ComputerAction.call:
        _commitWager(player, decision.amount, 'Call');
      case ComputerAction.raise:
        _commitWager(player, decision.amount, 'Raise');
      case ComputerAction.fold:
        _foldComputer(player);
    }
  }

  void _foldComputer(int player) {
    setState(() {
      foldedPlayers.add(player);
      playerActions[player] = 'Fold';
      _completeRaiseResponse(player);
    });
    _schedulePersistence();
  }

  double _estimatedWinningOdds(int player) {
    final hand = evaluatePokerHand(playerHands[player]!);
    return estimateWinningOdds(hand, _activePlayers.length - 1);
  }

  Iterable<int> _playersAfter(int player) sync* {
    for (var offset = 1; offset < widget.playerCount; offset++) {
      yield (player - 1 + offset) % widget.playerCount + 1;
    }
  }

  void _completeRaiseResponse(int player) {
    if (_activeRaiseResponder == player) {
      pendingRaiseResponders.removeAt(0);
    }
  }

  void shuffle() {
    FocusScope.of(context).unfocus();
    setState(() {
      dealtCards = _shuffledDeck();
      playerHands.clear();
      playerActions.clear();
      _resetPlayerMoney();
      revealedPlayerNumbers.clear();
      nextCardIndex = 0;
    });
    _schedulePersistence();
  }

  List<PlayingCard> _shuffledDeck() {
    final cards = standardFiftyTwoCardDeck();
    cards.shuffle();
    return cards;
  }

  bool get _hasCardsForRound =>
      dealtCards == null ||
      dealtCards!.length - nextCardIndex >= widget.playerCount * 5;

  bool get _hasCompleteHands =>
      playerHands.length == widget.playerCount &&
      playerHands.values.every((hand) => hand.length == 5);

  Iterable<int> get _activePlayers =>
      playerHands.keys.where((player) => !foldedPlayers.contains(player));

  bool get _allActiveHandsRevealed =>
      _hasCompleteHands &&
      _activePlayers.isNotEmpty &&
      _activePlayers.every(revealedPlayerNumbers.contains);

  Map<int, PokerHand> get _evaluatedHands => {
    for (final entry in playerHands.entries)
      if (!foldedPlayers.contains(entry.key) &&
          revealedPlayerNumbers.contains(entry.key))
        entry.key: evaluatePokerHand(entry.value),
  };

  @override
  Widget build(BuildContext context) {
    if (isRestoring) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = GameLayoutSpec.resolve(
            constraints.maxWidth,
            widget.playerCount,
            height: constraints.maxHeight,
          );
          final contentWidth = constraints.maxWidth - layout.padding * 2;
          final playerWidth = layout.itemWidth(contentWidth);
          final playerHeight = playerWidth * 274 / 176;
          final evaluatedHands = _evaluatedHands;
          final allHandsRevealed = _allActiveHandsRevealed;
          final winningPower = !allHandsRevealed
              ? null
              : evaluatedHands.values.reduce(
                  (best, hand) => hand.compareTo(best) > 0 ? hand : best,
                );
          final hasHand = playerHands.values.any((hand) => hand.isNotEmpty);

          return GameLayoutMarker(
            layoutClass: layout.layoutClass,
            child: Padding(
              padding: EdgeInsets.all(layout.padding),
              child: Column(
                children: [
                  SizedBox(
                    height: _controlsHeight,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton(
                          key: const ValueKey('five-card-deal-button'),
                          onPressed:
                              !isDealing &&
                                  (!hasHand || allHandsRevealed) &&
                                  _hasCardsForRound
                              ? deal
                              : null,
                          style: GameDeckButtonStyles.deal(),
                          child: Text(hasHand ? 'New Deal' : 'Deal'),
                        ),
                        if (dealtCards != null) ...[
                          const SizedBox(width: 10),
                          OutlinedButton(
                            key: const ValueKey('five-card-shuffle-button'),
                            onPressed: shuffle,
                            style: GameDeckButtonStyles.shuffle(),
                            child: const Text('Shuffle'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: _spacing),
                  SizedBox(
                    height: computerCelebration == null ? 72 : 104,
                    child: TableWagers(
                      playerCount: widget.playerCount,
                      wagers: playerWagers,
                      activeResponder: _activeRaiseResponder,
                      callAmount: _activeRaiseResponder == null
                          ? 0
                          : _highestWager - _playerBet(_activeRaiseResponder!),
                      payoutMessage: payoutMessage,
                      celebrationMessage: computerCelebration,
                    ),
                  ),
                  const SizedBox(height: _spacing),
                  Expanded(
                    child: ZoomableGameDisplay(
                      child: SingleChildScrollView(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: layout.spacing,
                          runSpacing: layout.spacing,
                          children: [
                            for (
                              var player = 1;
                              player <= widget.playerCount;
                              player++
                            )
                              SizedBox(
                                width: playerWidth,
                                height: playerHeight,
                                child: _PlayerSpot(
                                  playerNumber: player,
                                  isUser:
                                      player == 1 ||
                                      !widget.automateComputerPlayers,
                                  cards:
                                      playerHands[player] ??
                                      const <PlayingCard>[],
                                  cardBack: widget.cardBack,
                                  patternIndex: widget.patternIndex,
                                  handRevealed: revealedPlayerNumbers.contains(
                                    player,
                                  ),
                                  evaluatedHand: evaluatedHands[player],
                                  isWinner:
                                      evaluatedHands[player] == winningPower,
                                  selectedAction: playerActions[player],
                                  bankAmount: _playerBalance(player),
                                  folded: foldedPlayers.contains(player),
                                  isActiveResponder: _firstBettingTurnComplete
                                      ? _activeRaiseResponder == player
                                      : !playerActions.containsKey(player),
                                  bettingClosed: allHandsRevealed,
                                  canBet:
                                      _activeRaiseResponder == null &&
                                      _highestWager == 0,
                                  canRaise:
                                      _activeRaiseResponder == null &&
                                      _highestWager > 0 &&
                                      _playerBalance(player) >
                                          _highestWager - _playerBet(player),
                                  canCall: _highestWager > _playerBet(player),
                                  canCheck: _highestWager == _playerBet(player),
                                  recommendedBet: _teachModeRecommendation(
                                    player,
                                  ),
                                  onCardsTapped: () => revealHand(player),
                                  onActionSelected: (action) =>
                                      selectAction(player, action),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlayerSpot extends StatelessWidget {
  const _PlayerSpot({
    required this.playerNumber,
    required this.isUser,
    required this.cards,
    required this.cardBack,
    required this.patternIndex,
    required this.handRevealed,
    required this.evaluatedHand,
    required this.isWinner,
    required this.selectedAction,
    required this.bankAmount,
    required this.folded,
    required this.isActiveResponder,
    required this.bettingClosed,
    required this.canBet,
    required this.canRaise,
    required this.canCall,
    required this.canCheck,
    required this.recommendedBet,
    required this.onCardsTapped,
    required this.onActionSelected,
  });

  final int playerNumber;
  final bool isUser;
  final List<PlayingCard> cards;
  final CardBackDesign cardBack;
  final int patternIndex;
  final bool handRevealed;
  final PokerHand? evaluatedHand;
  final bool isWinner;
  final String? selectedAction;
  final int bankAmount;
  final bool folded;
  final bool isActiveResponder;
  final bool bettingClosed;
  final bool canBet;
  final bool canRaise;
  final bool canCall;
  final bool canCheck;
  final double? recommendedBet;
  final VoidCallback onCardsTapped;
  final ValueChanged<String> onActionSelected;

  @override
  Widget build(BuildContext context) {
    final handLabel = evaluatedHand == null
        ? cards.isEmpty
              ? 'WAITING'
              : 'FACE DOWN'
        : '${evaluatedHand!.label}${isWinner ? ' - WINNER' : ''}';

    return Semantics(
      label: 'Player $playerNumber, $handLabel',
      child: _ScaledSpot(
        designWidth: 176,
        designHeight: 274,
        child: Column(
          children: [
            _SpotLabel(
              isUser
                  ? 'PLAYER $playerNumber - YOU'
                  : 'PLAYER $playerNumber - COMPUTER',
            ),
            const SizedBox(height: 4),
            Text(
              handLabel,
              style: TextStyle(
                color: isWinner ? Colors.amberAccent : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 4),
            Semantics(
              button: isUser && cards.length == 5 && !handRevealed,
              label: handRevealed
                  ? 'Player $playerNumber cards revealed'
                  : 'Reveal Player $playerNumber cards',
              child: GestureDetector(
                key: ValueKey('player-$playerNumber-cards'),
                behavior: HitTestBehavior.opaque,
                onTap: isUser && cards.length == 5 && !handRevealed
                    ? onCardsTapped
                    : null,
                child: _FannedCards(
                  cards: cards,
                  cardBack: cardBack,
                  patternIndex: patternIndex,
                  faceUp: handRevealed,
                ),
              ),
            ),
            const SizedBox(height: 5),
            ChipStacks(playerNumber: playerNumber, amount: bankAmount),
            const SizedBox(height: 3),
            _PlayerActions(
              playerNumber: playerNumber,
              enabled:
                  cards.length == 5 &&
                  isUser &&
                  !folded &&
                  isActiveResponder &&
                  !bettingClosed,
              canBet: canBet,
              canRaise: canRaise,
              canCall: canCall,
              canCheck: canCheck,
              recommendedBet: recommendedBet,
              selectedAction: selectedAction,
              onSelected: onActionSelected,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerActions extends StatelessWidget {
  const _PlayerActions({
    required this.playerNumber,
    required this.enabled,
    required this.canBet,
    required this.canRaise,
    required this.canCall,
    required this.canCheck,
    required this.recommendedBet,
    required this.selectedAction,
    required this.onSelected,
  });

  final int playerNumber;
  final bool enabled;
  final bool canBet;
  final bool canRaise;
  final bool canCall;
  final bool canCheck;
  final double? recommendedBet;
  final String? selectedAction;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return BettingActions(
      keyPrefix: 'player-$playerNumber',
      enabled: enabled,
      canBet: canBet,
      canRaise: canRaise,
      canCall: canCall,
      canCheck: canCheck,
      recommendedBet: recommendedBet,
      selectedAction: selectedAction,
      onSelected: onSelected,
    );
  }
}

class _FannedCards extends StatelessWidget {
  const _FannedCards({
    required this.cards,
    required this.cardBack,
    required this.patternIndex,
    required this.faceUp,
  });

  static const _width = 166.0;
  static const _height = 90.0;
  static const _cardWidth = 64.0;

  final List<PlayingCard> cards;
  final CardBackDesign cardBack;
  final int patternIndex;
  final bool faceUp;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const SizedBox(
        width: _width,
        height: _height,
        child: Center(child: _CardOutline()),
      );
    }

    final offset = cards.length == 1
        ? 0.0
        : math.min(28.0, (_width - _cardWidth) / (cards.length - 1));
    final handWidth = _cardWidth + offset * (cards.length - 1);
    final start = (_width - handWidth) / 2;
    final center = (cards.length - 1) / 2;

    return SizedBox(
      width: _width,
      height: _height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < cards.length; index++)
            Positioned(
              left: start + offset * index,
              child: Transform.rotate(
                angle: (index - center) * 0.045,
                alignment: Alignment.bottomCenter,
                child: _CardOutline(
                  card: cards[index],
                  cardBack: cardBack,
                  patternIndex: patternIndex,
                  faceUp: faceUp,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScaledSpot extends StatelessWidget {
  const _ScaledSpot({
    required this.designWidth,
    required this.designHeight,
    required this.child,
  });

  final double designWidth;
  final double designHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(width: designWidth, height: designHeight, child: child),
      ),
    );
  }
}

class _SpotLabel extends StatelessWidget {
  const _SpotLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 18,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _CardOutline extends StatelessWidget {
  const _CardOutline({
    this.card,
    this.cardBack,
    this.patternIndex = 0,
    this.faceUp = false,
  });

  final PlayingCard? card;
  final CardBackDesign? cardBack;
  final int patternIndex;
  final bool faceUp;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 90,
      decoration: BoxDecoration(
        color: card != null ? Colors.white : null,
        border: Border.all(color: Colors.white70, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: card == null
          ? null
          : ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: faceUp
                  ? PlayingCardFace(card: card!)
                  : CustomPaint(
                      painter: CardBackPainter(
                        color: cardBack!.color,
                        accent: cardBack!.accent,
                        patternIndex: patternIndex,
                      ),
                    ),
            ),
    );
  }
}
