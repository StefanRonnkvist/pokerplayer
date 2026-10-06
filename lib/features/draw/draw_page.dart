import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:playing_cards/playing_cards.dart';

import '../../app/shared/game_layout.dart';
import '../../app/shared/widgets/betting_actions.dart';
import '../../app/shared/widgets/game_deck_button_styles.dart';
import '../../shared/cards/card_back.dart';
import '../../shared/cards/playing_card_face.dart';
import '../five_card/models/poker_hand.dart';
import '../five_card/strategy/computer_strategy.dart';
import '../five_card/widgets/chip_stacks.dart';
import '../five_card/widgets/table_wagers.dart';

class DrawPage extends StatefulWidget {
  const DrawPage({
    required this.cardBack,
    required this.patternIndex,
    this.playerCount = 5,
    this.maxCardsToDraw = 5,
    this.initialBankAmount = 1000,
    this.anteAmount = 2,
    this.teachMode = false,
    this.automateComputerPlayers = true,
    super.key,
  }) : assert(playerCount >= 2 && playerCount <= 5),
       assert(maxCardsToDraw >= 1 && maxCardsToDraw <= 5),
       assert(initialBankAmount > 0),
       assert(anteAmount > 0 && anteAmount <= initialBankAmount);

  final CardBackDesign cardBack;
  final int patternIndex;
  final int playerCount;
  final int maxCardsToDraw;
  final int initialBankAmount;
  final int anteAmount;
  final bool teachMode;
  final bool automateComputerPlayers;

  @override
  State<DrawPage> createState() => _DrawPageState();
}

class _DrawPageState extends State<DrawPage> {
  final selectedCardIndexes = <int>{};
  final playerBalances = <int, int>{};
  final playerWagers = <int, int>{};
  final playerBets = <int, int>{};
  final playerActions = <int, String>{};
  final foldedPlayers = <int>{};
  final pendingRaiseResponders = <int>[];
  final pendingComputerPlayers = <int>[];
  List<PlayingCard> deck = const [];
  final playerHands = <int, List<PlayingCard>>{};
  int nextCardIndex = 0;
  bool drawComplete = false;
  bool bettingRoundStarted = false;
  bool bettingSettled = false;
  bool computerTurnRunning = false;
  String? payoutMessage;

  @override
  void initState() {
    super.initState();
    _resetPlayerBalances();
  }

  @override
  void didUpdateWidget(DrawPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playerCount != oldWidget.playerCount) {
      _resetPlayerBalances();
      playerHands.clear();
      selectedCardIndexes.clear();
      deck = const [];
      nextCardIndex = 0;
      drawComplete = false;
      return;
    }
    if (widget.initialBankAmount != oldWidget.initialBankAmount) {
      _resetPlayerBalances();
    }
    if (widget.maxCardsToDraw < oldWidget.maxCardsToDraw &&
        selectedCardIndexes.length > widget.maxCardsToDraw) {
      final retainedIndexes = selectedCardIndexes.toList()..sort();
      selectedCardIndexes
        ..clear()
        ..addAll(retainedIndexes.take(widget.maxCardsToDraw));
    }
  }

  void _resetPlayerBalances() {
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
    playerActions.clear();
    foldedPlayers.clear();
    pendingRaiseResponders.clear();
    pendingComputerPlayers.clear();
    payoutMessage = null;
    bettingRoundStarted = false;
    bettingSettled = false;
    computerTurnRunning = false;
  }

  /// Starts a hand by dealing round-robin and posting affordable antes.
  void _deal() {
    final shuffledDeck = standardFiftyTwoCardDeck()..shuffle();
    final hands = {
      for (var player = 1; player <= widget.playerCount; player++)
        player: <PlayingCard>[],
    };
    var cardIndex = 0;
    for (var round = 0; round < 5; round++) {
      for (var player = 1; player <= widget.playerCount; player++) {
        hands[player]!.add(shuffledDeck[cardIndex++]);
      }
    }
    setState(() {
      _resetBettingRound();
      deck = shuffledDeck;
      playerHands
        ..clear()
        ..addAll(hands);
      nextCardIndex = cardIndex;
      selectedCardIndexes.clear();
      drawComplete = false;
      for (var player = 1; player <= widget.playerCount; player++) {
        final ante = math.min(widget.anteAmount, playerBalances[player] ?? 0);
        playerBalances[player] = (playerBalances[player] ?? 0) - ante;
        playerWagers[player] = ante;
        playerBets[player] = 0;
      }
    });
  }

  void _shuffle() {
    FocusScope.of(context).unfocus();
    setState(() {
      _resetPlayerBalances();
      playerHands.clear();
      selectedCardIndexes.clear();
      deck = const [];
      nextCardIndex = 0;
      drawComplete = false;
    });
  }

  void _toggleCard(int index) {
    if (drawComplete || !_drawAvailable) {
      return;
    }
    setState(() {
      if (!selectedCardIndexes.remove(index) &&
          selectedCardIndexes.length < widget.maxCardsToDraw) {
        selectedCardIndexes.add(index);
      }
    });
  }

  /// Validates and dispatches an action in the pre-draw betting round.
  ///
  /// Once the initial turn is complete, only the next queued raise responder
  /// may call or fold.
  Future<void> _selectAction(int player, String action) async {
    if (drawComplete ||
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
        final callAmount = math.max(0, _highestBet - _playerBet(player));
        await _showWagerDialog(
          player,
          action,
          minimumAmount: _highestBet + 1,
          callAmount: callAmount,
        );
      case 'Call':
        final callAmount = math.max(0, _highestBet - _playerBet(player));
        if (callAmount == 0) {
          return;
        }
        if (callAmount > _playerBalance(player)) {
          await _showInsufficientFundsDialog(player, callAmount);
          return;
        }
        _commitWager(player, callAmount, action);
      case 'Check':
        if (_highestBet != _playerBet(player)) {
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
    }
  }

  Future<void> _showInsufficientFundsDialog(int player, int callAmount) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Not enough funds to call'),
        content: Text(
          'Player $player needs \\$callAmount to call, but has '
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
  }

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
      builder: (dialogContext) => AlertDialog(
        title: Text('$action - Player $player'),
        content: Form(
          key: formKey,
          child: TextFormField(
            key: ValueKey('draw-player-$player-${action.toLowerCase()}-amount'),
            autofocus: true,
            decoration: InputDecoration(
              labelText: action == 'Raise' ? 'Total amount to add' : 'Amount',
              prefixText: r'$',
              helperText: action == 'Raise' && callAmount > 0
                  ? 'Includes \$$callAmount to call'
                  : 'Available: \$$balance',
              border: const OutlineInputBorder(),
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
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: ValueKey('draw-player-$player-${action.toLowerCase()}-submit'),
            onPressed: () {
              if (!formKey.currentState!.validate()) {
                return;
              }
              _commitWager(player, int.parse(amountText), action);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  double? _teachModeRecommendation(int player) {
    if (!widget.teachMode || player != 1 || playerHands[player]?.length != 5) {
      return null;
    }
    final callAmount = math.max(0, _highestBet - _playerBet(player));
    final cost = math.max(1, callAmount).toDouble();
    final pot =
        playerWagers.values.fold(0, (total, wager) => total + wager) + cost;
    return calculatePokerBet(
      p: estimateWinningOdds(
        evaluatePokerHand(playerHands[player]!),
        _activePlayers.length - 1,
      ),
      cost: cost,
      pot: pot,
      maxBet: _playerBalance(player).toDouble(),
    );
  }

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
                  _playerBet(candidate) < _highestBet,
            ),
          );
      } else if (action == 'Call') {
        _completeRaiseResponse(player);
      }
    });
    _continueAfterUserAction(player);
  }

  /// Advances betting manually or runs queued computer turns after user input.
  void _continueAfterUserAction(int player) {
    if (drawComplete) {
      return;
    }
    if (!widget.automateComputerPlayers) {
      bettingRoundStarted = true;
      _finishBettingIfSettled();
      return;
    }
    if (player != 1) {
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

  /// Drains computer decisions until betting settles or the user must respond.
  void _runComputerTurns() {
    if (computerTurnRunning || !mounted) {
      return;
    }
    computerTurnRunning = true;
    while (mounted && !drawComplete) {
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

  void _performComputerDecision(int player) {
    final decision = chooseComputerDecision(
      balance: _playerBalance(player),
      currentBet: _playerBet(player),
      highestBet: _highestBet,
      pot: playerWagers.values.fold(0, (total, wager) => total + wager),
      winningOdds: estimateWinningOdds(
        evaluatePokerHand(playerHands[player]!),
        _activePlayers.length - 1,
      ),
    );
    _applyComputerDecision(player, decision);
  }

  void _performComputerResponse(int player) {
    final callAmount = _highestBet - _playerBet(player);
    final decision = chooseComputerResponse(
      balance: _playerBalance(player),
      callAmount: callAmount,
      pot: playerWagers.values.fold(0, (total, wager) => total + wager),
      winningOdds: estimateWinningOdds(
        evaluatePokerHand(playerHands[player]!),
        _activePlayers.length - 1,
      ),
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
        setState(() {
          foldedPlayers.add(player);
          playerActions[player] = 'Fold';
          _completeRaiseResponse(player);
        });
    }
  }

  /// Enables the draw when all first actions and raise responses are complete.
  ///
  /// If the user folded, computers draw and settle automatically because no
  /// user selection is needed.
  void _finishBettingIfSettled() {
    if (!bettingRoundStarted ||
        !_firstBettingTurnComplete ||
        pendingComputerPlayers.isNotEmpty ||
        _activeRaiseResponder != null ||
        !_activePlayers.every((player) => _playerBet(player) == _highestBet)) {
      return;
    }
    setState(() => bettingSettled = true);
    if (foldedPlayers.contains(1)) {
      _completeDraw();
    }
  }

  void _completeRaiseResponse(int player) {
    if (_activeRaiseResponder == player) {
      pendingRaiseResponders.removeAt(0);
    }
  }

  Iterable<int> _playersAfter(int player) sync* {
    for (var offset = 1; offset < widget.playerCount; offset++) {
      yield (player - 1 + offset) % widget.playerCount + 1;
    }
  }

  int _playerBalance(int player) => playerBalances[player] ?? 0;

  int _playerWager(int player) => playerWagers[player] ?? 0;

  int _playerBet(int player) => playerBets[player] ?? 0;

  int get _highestBet => playerBets.values.fold(0, math.max);

  bool get _firstBettingTurnComplete =>
      playerHands.isNotEmpty &&
      playerHands.keys.every(playerActions.containsKey);

  int? get _activeRaiseResponder =>
      _firstBettingTurnComplete ? pendingRaiseResponders.firstOrNull : null;

  List<int> get _activePlayers => playerHands.keys
      .where((player) => !foldedPlayers.contains(player))
      .toList();

  bool get _drawAvailable => !bettingRoundStarted || bettingSettled;

  /// Replaces the user's selected cards, then completes all computer draws.
  void _drawSelected() {
    if (selectedCardIndexes.isEmpty || drawComplete || !_drawAvailable) {
      return;
    }
    final replacementHand = [...playerHands[1]!];
    for (final index in selectedCardIndexes.toList()..sort()) {
      replacementHand[index] = deck[nextCardIndex++];
    }
    playerHands[1] = replacementHand;
    _completeDraw();
  }

  void _standPat() {
    if (playerHands[1]?.length != 5 || drawComplete || !_drawAvailable) {
      return;
    }
    _completeDraw();
  }

  /// Applies computer discards, evaluates all active hands, and awards the pot.
  ///
  /// Tied winners split the pot and receive remainder chips in player order.
  void _completeDraw() {
    for (var player = 2; player <= widget.playerCount; player++) {
      if (foldedPlayers.contains(player)) {
        continue;
      }
      final hand = [...playerHands[player]!];
      final discardIndexes = _computerDiscardIndexes(hand);
      for (final index in discardIndexes) {
        hand[index] = deck[nextCardIndex++];
      }
      playerHands[player] = hand;
    }
    final evaluatedHands = {
      for (final player in _activePlayers)
        player: evaluatePokerHand(playerHands[player]!),
    };
    final winningHand = evaluatedHands.values.reduce(
      (best, hand) => hand.compareTo(best) > 0 ? hand : best,
    );
    final winners = evaluatedHands.entries
        .where((entry) => entry.value == winningHand)
        .map((entry) => entry.key)
        .toList();
    final pot = playerWagers.values.fold(0, (total, wager) => total + wager);
    final share = pot ~/ winners.length;
    var remainder = pot % winners.length;
    for (final winner in winners) {
      final extraChip = remainder > 0 ? 1 : 0;
      playerBalances[winner] = _playerBalance(winner) + share + extraChip;
      remainder -= extraChip;
    }
    setState(() {
      selectedCardIndexes.clear();
      playerWagers.clear();
      playerBets.clear();
      pendingRaiseResponders.clear();
      payoutMessage = winners.length == 1
          ? 'Player ${winners.single} wins \$$pot'
          : 'Players ${winners.join(' & ')} split \$$pot';
      drawComplete = true;
    });
  }

  /// Chooses unmatched cards to discard while retaining at least one high card.
  ///
  /// This simple strategy always preserves pairs or better and respects the
  /// configured maximum number of replacement cards.
  List<int> _computerDiscardIndexes(List<PlayingCard> hand) {
    final valueCounts = <CardValue, int>{};
    for (final card in hand) {
      valueCounts.update(card.value, (count) => count + 1, ifAbsent: () => 1);
    }
    final unmatchedIndexes = <int>[
      for (var index = 0; index < hand.length; index++)
        if (valueCounts[hand[index].value] == 1) index,
    ];
    if (unmatchedIndexes.length == 5) {
      unmatchedIndexes.removeLast();
    }
    return unmatchedIndexes.take(widget.maxCardsToDraw).toList();
  }

  @override
  Widget build(BuildContext context) {
    final evaluatedHands = {
      for (final entry in playerHands.entries)
        if (!foldedPlayers.contains(entry.key))
          entry.key: evaluatePokerHand(entry.value),
    };
    final winningHand = !drawComplete
        ? null
        : evaluatedHands.values.reduce(
            (best, hand) => hand.compareTo(best) > 0 ? hand : best,
          );
    final winners = !drawComplete
        ? const <int>[]
        : evaluatedHands.entries
              .where((entry) => entry.value == winningHand)
              .map((entry) => entry.key)
              .toList();
    final hasHand = playerHands.isNotEmpty;
    return ColoredBox(
      key: const ValueKey('draw-page'),
      color: const Color(0xFF075B40),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    key: const ValueKey('draw-deal-button'),
                    onPressed: !hasHand || drawComplete ? _deal : null,
                    style: GameDeckButtonStyles.deal(),
                    child: Text(!hasHand ? 'Deal' : 'New Hand'),
                  ),
                  if (hasHand)
                    OutlinedButton(
                      key: const ValueKey('draw-shuffle-button'),
                      onPressed: _shuffle,
                      style: GameDeckButtonStyles.shuffle(),
                      child: const Text('Shuffle'),
                    ),
                  if (hasHand && !drawComplete) ...[
                    FilledButton.icon(
                      key: const ValueKey('draw-selected-button'),
                      onPressed: selectedCardIndexes.isEmpty || !_drawAvailable
                          ? null
                          : _drawSelected,
                      icon: const Icon(Icons.sync),
                      label: Text('Draw ${selectedCardIndexes.length}'),
                    ),
                    OutlinedButton(
                      key: const ValueKey('stand-pat-button'),
                      onPressed: _drawAvailable ? _standPat : null,
                      child: const Text('Stand Pat'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              Text(
                drawComplete
                    ? winners.length == 1
                          ? 'Player ${winners.single} wins'
                          : 'Players ${winners.join(' & ')} tie'
                    : !hasHand
                    ? 'FIVE CARD DRAW'
                    : !_drawAvailable
                    ? 'Complete betting before drawing'
                    : 'Select up to ${widget.maxCardsToDraw} cards',
                key: const ValueKey('draw-status'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 72,
                child: TableWagers(
                  playerCount: widget.playerCount,
                  wagers: playerWagers,
                  activeResponder: _activeRaiseResponder,
                  callAmount: _activeRaiseResponder == null
                      ? 0
                      : _highestBet - _playerBet(_activeRaiseResponder!),
                  payoutMessage: payoutMessage,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final layout = GameLayoutSpec.resolve(
                      constraints.maxWidth,
                      widget.playerCount,
                      height: constraints.maxHeight,
                    );
                    final spotWidth = layout.itemWidth(constraints.maxWidth);
                    return GameLayoutMarker(
                      layoutClass: layout.layoutClass,
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
                                  key: ValueKey('draw-player-$player'),
                                  width: spotWidth,
                                  child: _DrawPlayerHand(
                                    playerNumber: player,
                                    hand: playerHands[player] ?? const [],
                                    cardBack: widget.cardBack,
                                    patternIndex: widget.patternIndex,
                                    reveal:
                                        player == 1 ||
                                        (drawComplete &&
                                            !foldedPlayers.contains(player)),
                                    selectedCardIndexes: player == 1
                                        ? selectedCardIndexes
                                        : const {},
                                    selectionEnabled:
                                        player == 1 && !drawComplete,
                                    result:
                                        drawComplete &&
                                            !foldedPlayers.contains(player)
                                        ? evaluatedHands[player]
                                        : null,
                                    winner:
                                        drawComplete &&
                                        evaluatedHands[player] == winningHand,
                                    onCardTapped: _toggleCard,
                                    balance: _playerBalance(player),
                                    selectedAction: playerActions[player],
                                    folded: foldedPlayers.contains(player),
                                    actionsEnabled:
                                        (player == 1 ||
                                            !widget.automateComputerPlayers) &&
                                        !drawComplete &&
                                        !foldedPlayers.contains(player) &&
                                        (!_firstBettingTurnComplete
                                            ? !playerActions.containsKey(player)
                                            : _activeRaiseResponder == player),
                                    canBet: _highestBet == 0,
                                    canRaise:
                                        _highestBet > 0 &&
                                        _playerBalance(player) >
                                            _highestBet - _playerBet(player),
                                    canCall: _highestBet > _playerBet(player),
                                    canCheck: _highestBet == _playerBet(player),
                                    recommendedBet: _teachModeRecommendation(
                                      player,
                                    ),
                                    onActionSelected: (action) =>
                                        _selectAction(player, action),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawPlayerHand extends StatelessWidget {
  const _DrawPlayerHand({
    required this.playerNumber,
    required this.hand,
    required this.cardBack,
    required this.patternIndex,
    required this.reveal,
    required this.selectedCardIndexes,
    required this.selectionEnabled,
    required this.result,
    required this.winner,
    required this.onCardTapped,
    required this.balance,
    required this.selectedAction,
    required this.folded,
    required this.actionsEnabled,
    required this.canBet,
    required this.canRaise,
    required this.canCall,
    required this.canCheck,
    required this.recommendedBet,
    required this.onActionSelected,
  });

  final int playerNumber;
  final List<PlayingCard> hand;
  final CardBackDesign cardBack;
  final int patternIndex;
  final bool reveal;
  final Set<int> selectedCardIndexes;
  final bool selectionEnabled;
  final PokerHand? result;
  final bool winner;
  final ValueChanged<int> onCardTapped;
  final int balance;
  final String? selectedAction;
  final bool folded;
  final bool actionsEnabled;
  final bool canBet;
  final bool canRaise;
  final bool canCall;
  final bool canCheck;
  final double? recommendedBet;
  final ValueChanged<String> onActionSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          playerNumber == 1
              ? 'PLAYER 1 - YOU'
              : 'PLAYER $playerNumber - COMPUTER',
          maxLines: 1,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 92,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < hand.length; index++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _SelectableDrawCard(
                      playerNumber: playerNumber,
                      index: index,
                      card: hand[index],
                      cardBack: cardBack,
                      patternIndex: patternIndex,
                      reveal: reveal,
                      selected: selectedCardIndexes.contains(index),
                      enabled: selectionEnabled,
                      onTap: () => onCardTapped(index),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 18,
          child: Text(
            result == null
                ? reveal
                      ? 'READY TO DRAW'
                      : 'FACE DOWN'
                : '${result!.label}${winner ? ' - WINNER' : ''}',
            key: ValueKey('draw-player-$playerNumber-result'),
            style: TextStyle(
              color: winner ? Colors.amberAccent : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        ChipStacks(playerNumber: playerNumber, amount: balance),
        _DrawPlayerActions(
          playerNumber: playerNumber,
          enabled: actionsEnabled,
          canBet: canBet,
          canRaise: canRaise,
          canCall: canCall,
          canCheck: canCheck,
          recommendedBet: recommendedBet,
          selectedAction: selectedAction,
          onSelected: onActionSelected,
        ),
      ],
    );
  }
}

class _DrawPlayerActions extends StatelessWidget {
  const _DrawPlayerActions({
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
      keyPrefix: 'draw-player-$playerNumber',
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

class _SelectableDrawCard extends StatelessWidget {
  const _SelectableDrawCard({
    required this.playerNumber,
    required this.index,
    required this.card,
    required this.cardBack,
    required this.patternIndex,
    required this.reveal,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final int playerNumber;
  final int index;
  final PlayingCard card;
  final CardBackDesign cardBack;
  final int patternIndex;
  final bool reveal;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: enabled,
      selected: selected,
      label: 'Player $playerNumber draw card ${index + 1}',
      child: GestureDetector(
        key: ValueKey(
          playerNumber == 1
              ? 'draw-card-$index'
              : 'draw-player-$playerNumber-card-$index',
        ),
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.translationValues(0, selected ? -14 : 0, 0),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? Colors.amberAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? Colors.amberAccent : Colors.white54,
              width: 2,
            ),
          ),
          child: SizedBox(
            width: 58,
            height: 82,
            child: reveal
                ? PlayingCardFace(card: card)
                : CustomPaint(
                    painter: CardBackPainter(
                      color: cardBack.color,
                      accent: cardBack.accent,
                      patternIndex: patternIndex,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
