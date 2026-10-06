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

class StudPage extends StatefulWidget {
  const StudPage({
    required this.cardBack,
    required this.patternIndex,
    this.playerCount = 5,
    this.initialBankAmount = 1000,
    this.anteAmount = 2,
    this.cardCount = 5,
    this.holdEm = false,
    this.teachMode = false,
    this.automateComputerPlayers = true,
    super.key,
  }) : assert(playerCount >= 2 && playerCount <= 5),
       assert(initialBankAmount > 0),
       assert(anteAmount > 0 && anteAmount <= initialBankAmount),
       assert(cardCount == 5 || cardCount == 7);

  final CardBackDesign cardBack;
  final int patternIndex;
  final int playerCount;
  final int initialBankAmount;
  final int anteAmount;
  final int cardCount;
  final bool holdEm;
  final bool teachMode;
  final bool automateComputerPlayers;

  @override
  State<StudPage> createState() => _StudPageState();
}

class _StudPageState extends State<StudPage> {
  final playerHands = <int, List<PlayingCard>>{};
  final playerBalances = <int, int>{};
  final playerWagers = <int, int>{};
  final streetBets = <int, int>{};
  final playerActions = <int, String>{};
  final foldedPlayers = <int>{};
  final pendingRaiseResponders = <int>[];
  final pendingComputerPlayers = <int>[];
  final revealedUserCards = <int>{};
  final communityCards = <PlayingCard>[];
  List<PlayingCard> deck = const [];
  int nextCardIndex = 0;
  int street = 0;
  bool streetSettled = true;
  bool computerTurnRunning = false;
  bool showdown = false;
  String? payoutMessage;

  @override
  void initState() {
    super.initState();
    _resetBalances();
  }

  @override
  void didUpdateWidget(StudPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playerCount != oldWidget.playerCount ||
        widget.initialBankAmount != oldWidget.initialBankAmount ||
        widget.anteAmount != oldWidget.anteAmount ||
        widget.cardCount != oldWidget.cardCount ||
        widget.holdEm != oldWidget.holdEm) {
      setState(_resetBalances);
    }
  }

  void _resetBalances() {
    playerBalances
      ..clear()
      ..addEntries(
        List.generate(
          widget.playerCount,
          (index) => MapEntry(index + 1, widget.initialBankAmount),
        ),
      );
    _resetHand();
  }

  void _resetHand() {
    playerHands.clear();
    playerWagers.clear();
    streetBets.clear();
    playerActions.clear();
    foldedPlayers.clear();
    pendingRaiseResponders.clear();
    pendingComputerPlayers.clear();
    revealedUserCards.clear();
    communityCards.clear();
    deck = const [];
    nextCardIndex = 0;
    street = 0;
    streetSettled = true;
    computerTurnRunning = false;
    showdown = false;
    payoutMessage = null;
  }

  void _shuffle() {
    FocusScope.of(context).unfocus();
    setState(_resetBalances);
  }

  /// Deals the next street and opens a fresh street-specific betting round.
  ///
  /// Hold'em deals two private cards, then a 3-1-1 community board. Stud deals
  /// one card per active player on every street.
  void _dealNextStreet() {
    if (!streetSettled || showdown || street >= _lastStreet) {
      return;
    }
    if (street == 0) {
      deck = standardFiftyTwoCardDeck()..shuffle();
      playerHands.addEntries(
        List.generate(
          widget.playerCount,
          (index) => MapEntry(index + 1, <PlayingCard>[]),
        ),
      );
      for (var player = 1; player <= widget.playerCount; player++) {
        final ante = math.min(widget.anteAmount, _playerBalance(player));
        playerBalances[player] = _playerBalance(player) - ante;
        playerWagers[player] = ante;
      }
    }

    setState(() {
      if (widget.holdEm) {
        if (street == 0) {
          for (var card = 0; card < 2; card++) {
            for (var player = 1; player <= widget.playerCount; player++) {
              playerHands[player]!.add(deck[nextCardIndex++]);
            }
          }
        } else {
          final cardsToDeal = street == 1 ? 3 : 1;
          for (var card = 0; card < cardsToDeal; card++) {
            communityCards.add(deck[nextCardIndex++]);
          }
        }
      } else {
        for (var player = 1; player <= widget.playerCount; player++) {
          if (!foldedPlayers.contains(player)) {
            playerHands[player]!.add(deck[nextCardIndex++]);
          }
        }
      }
      street++;
      streetBets
        ..clear()
        ..addEntries(_activePlayers.map((player) => MapEntry(player, 0)));
      playerActions.clear();
      pendingRaiseResponders.clear();
      pendingComputerPlayers.clear();
      streetSettled = false;
    });
  }

  /// Validates and dispatches a betting action for the current street.
  ///
  /// After every active player has acted, only the queued responder to the most
  /// recent raise may act, and that response is limited to call or fold.
  Future<void> _selectAction(int player, String action) async {
    if (streetSettled ||
        showdown ||
        foldedPlayers.contains(player) ||
        (!_firstTurnComplete && playerActions.containsKey(player)) ||
        (_firstTurnComplete && _activeRaiseResponder == null) ||
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
          minimumAmount: callAmount + 1,
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
        _continueAfterAction(player);
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
      playerBalances[player] = _playerBalance(player) +
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
            key: ValueKey('stud-player-$player-${action.toLowerCase()}-amount'),
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
            key: ValueKey('stud-player-$player-${action.toLowerCase()}-submit'),
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
    if (!widget.teachMode ||
        player != 1 ||
        (playerHands[player]?.isEmpty ?? true)) {
      return null;
    }
    final callAmount = math.max(0, _highestBet - _playerBet(player));
    final cost = math.max(1, callAmount).toDouble();
    final pot =
        playerWagers.values.fold(0, (total, wager) => total + wager) + cost;
    return calculatePokerBet(
      p: _estimatedOdds(player),
      cost: cost,
      pot: pot,
      maxBet: _playerBalance(player).toDouble(),
    );
  }

  void _commitWager(int player, int amount, String action) {
    setState(() {
      playerBalances[player] = _playerBalance(player) - amount;
      playerWagers[player] = _playerWager(player) + amount;
      streetBets[player] = _playerBet(player) + amount;
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
    _continueAfterAction(player);
  }

  /// Advances settlement directly or runs computer turns after user input.
  void _continueAfterAction(int player) {
    if (!widget.automateComputerPlayers) {
      _finishStreetIfSettled();
      return;
    }
    if (player != 1 || showdown) {
      return;
    }
    if (pendingComputerPlayers.isEmpty && !_firstTurnComplete) {
      pendingComputerPlayers.addAll(
        List.generate(widget.playerCount - 1, (index) => index + 2),
      );
    }
    _runComputerTurns();
  }

  /// Processes computer decisions until the street settles or awaits the user.
  ///
  /// A sole remaining player wins immediately, while raise responders are
  /// processed before players that have not taken their first turn.
  void _runComputerTurns() {
    if (computerTurnRunning || !mounted) {
      return;
    }
    computerTurnRunning = true;
    while (mounted && !showdown) {
      if (_activePlayers.length == 1) {
        _awardPot();
        break;
      }
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
    _finishStreetIfSettled();
  }

  void _performComputerDecision(int player) {
    final decision = chooseComputerDecision(
      balance: _playerBalance(player),
      currentBet: _playerBet(player),
      highestBet: _highestBet,
      pot: playerWagers.values.fold(0, (total, wager) => total + wager),
      winningOdds: _estimatedOdds(player),
    );
    _applyComputerDecision(player, decision);
  }

  void _performComputerResponse(int player) {
    final callAmount = _highestBet - _playerBet(player);
    final decision = chooseComputerResponse(
      balance: _playerBalance(player),
      callAmount: callAmount,
      pot: playerWagers.values.fold(0, (total, wager) => total + wager),
      winningOdds: _estimatedOdds(player),
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

  /// Estimates strength from a complete hand or currently exposed high card.
  double _estimatedOdds(int player) {
    final cards = [
      ...playerHands[player]!,
      if (widget.holdEm) ...communityCards,
    ];
    if (cards.length >= 5) {
      return estimateWinningOdds(
        evaluateBestPokerHand(cards),
        _activePlayers.length - 1,
      );
    }
    final exposedCards = widget.holdEm
        ? cards
        : cards.indexed
              .where((entry) => _isFaceUp(entry.$1))
              .map((entry) => entry.$2)
              .toList();
    if (exposedCards.isEmpty) {
      return 0.5;
    }
    final highCard = exposedCards
        .map((card) => _rank(card.value))
        .reduce(math.max);
    return (0.34 + highCard / 35).clamp(0.3, 0.74);
  }

  /// Closes a street once all active bets match and no actions remain queued.
  ///
  /// The final street enters showdown. If the user has folded, later streets
  /// are scheduled automatically so the remaining computer players can finish.
  void _finishStreetIfSettled() {
    if (!_firstTurnComplete ||
        pendingComputerPlayers.isNotEmpty ||
        _activeRaiseResponder != null ||
        !_activePlayers.every((player) => _playerBet(player) == _highestBet)) {
      return;
    }
    setState(() => streetSettled = true);
    if (_activePlayers.length == 1 || street == _lastStreet) {
      _awardPot();
      return;
    }
    if (widget.automateComputerPlayers && foldedPlayers.contains(1)) {
      _scheduleComputerOnlyStreet();
    }
  }

  void _scheduleComputerOnlyStreet() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          showdown ||
          !streetSettled ||
          !foldedPlayers.contains(1)) {
        return;
      }
      _dealNextStreet();
      pendingComputerPlayers.addAll(_activePlayers);
      _runComputerTurns();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  /// Awards the pot to the last active player or the strongest showdown hand.
  ///
  /// Ties split evenly, with remainder chips assigned in winner-list order.
  void _awardPot() {
    if (showdown || _activePlayers.isEmpty) {
      return;
    }
    final winners = _activePlayers.length == 1
        ? [_activePlayers.single]
        : _winningPlayers();
    final pot = playerWagers.values.fold(0, (total, wager) => total + wager);
    final share = pot ~/ winners.length;
    var remainder = pot % winners.length;
    for (final winner in winners) {
      final extraChip = remainder > 0 ? 1 : 0;
      playerBalances[winner] = _playerBalance(winner) + share + extraChip;
      remainder -= extraChip;
    }
    setState(() {
      playerWagers.clear();
      streetBets.clear();
      pendingRaiseResponders.clear();
      payoutMessage = winners.length == 1
          ? 'Player ${winners.single} wins \$$pot'
          : 'Players ${winners.join(' & ')} split \$$pot';
      showdown = true;
    });
  }

  List<int> _winningPlayers() {
    final evaluatedHands = {
      for (final player in _activePlayers)
        player: evaluateBestPokerHand([
          ...playerHands[player]!,
          if (widget.holdEm) ...communityCards,
        ]),
    };
    final winningHand = evaluatedHands.values.reduce(
      (best, hand) => hand.compareTo(best) > 0 ? hand : best,
    );
    return evaluatedHands.entries
        .where((entry) => entry.value == winningHand)
        .map((entry) => entry.key)
        .toList();
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

  /// Returns whether a stud card is publicly visible before showdown.
  bool _isFaceUp(int cardIndex) =>
      cardIndex > 0 && cardIndex < widget.cardCount - 1;

  /// Reveals one of the user's down cards when it is tapped.
  void _revealUserCard(int cardIndex) {
    if ((cardIndex == 0 || cardIndex == widget.cardCount - 1) &&
        !revealedUserCards.contains(cardIndex)) {
      setState(() => revealedUserCards.add(cardIndex));
    }
  }

  int _rank(CardValue value) => switch (value) {
    CardValue.two => 2,
    CardValue.three => 3,
    CardValue.four => 4,
    CardValue.five => 5,
    CardValue.six => 6,
    CardValue.seven => 7,
    CardValue.eight => 8,
    CardValue.nine => 9,
    CardValue.ten => 10,
    CardValue.jack => 11,
    CardValue.queen => 12,
    CardValue.king => 13,
    CardValue.ace => 14,
    CardValue.joker_1 || CardValue.joker_2 => 0,
  };

  int _playerBalance(int player) => playerBalances[player] ?? 0;
  int _playerWager(int player) => playerWagers[player] ?? 0;
  int _playerBet(int player) => streetBets[player] ?? 0;
  int get _lastStreet => widget.holdEm ? 4 : widget.cardCount;
  int get _highestBet => streetBets.values.fold(0, math.max);
  List<int> get _activePlayers => playerHands.keys
      .where((player) => !foldedPlayers.contains(player))
      .toList();
  bool get _firstTurnComplete =>
      _activePlayers.isNotEmpty &&
      _activePlayers.every(playerActions.containsKey);
  int? get _activeRaiseResponder =>
      _firstTurnComplete ? pendingRaiseResponders.firstOrNull : null;

  @override
  Widget build(BuildContext context) {
    final evaluatedHands = !showdown || street < _lastStreet
        ? const <int, PokerHand>{}
        : {
            for (final player in _activePlayers)
              player: evaluateBestPokerHand([
                ...playerHands[player]!,
                if (widget.holdEm) ...communityCards,
              ]),
          };
    final winningHand = evaluatedHands.isEmpty
        ? null
        : evaluatedHands.values.reduce(
            (best, hand) => hand.compareTo(best) > 0 ? hand : best,
          );
    final hasHand = street > 0;

    return ColoredBox(
      key: ValueKey(widget.holdEm ? 'holdem-page' : 'stud-page'),
      color: const Color(0xFF075B40),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 6,
                children: [
                  OutlinedButton(
                    key: ValueKey(
                      widget.holdEm ? 'holdem-deal-button' : 'stud-deal-button',
                    ),
                    onPressed: showdown
                        ? () => setState(_resetHand)
                        : streetSettled
                        ? _dealNextStreet
                        : null,
                    style: GameDeckButtonStyles.deal(),
                    child: Text(showdown ? 'New Hand' : _dealButtonLabel),
                  ),
                  if (hasHand)
                    OutlinedButton(
                      key: ValueKey(
                        widget.holdEm
                            ? 'holdem-shuffle-button'
                            : 'stud-shuffle-button',
                      ),
                      onPressed: _shuffle,
                      style: GameDeckButtonStyles.shuffle(),
                      child: const Text('Shuffle'),
                    ),
                  if (hasHand && !showdown) ...[
                    Text(
                      streetSettled
                          ? 'Betting complete'
                          : widget.holdEm
                          ? _holdEmRoundLabel
                          : 'Betting round $street',
                      key: ValueKey(
                        widget.holdEm ? 'holdem-status' : 'stud-status',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
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
              const SizedBox(height: 6),
              if (widget.holdEm) ...[
                _HoldEmCommunityCards(cards: communityCards),
                const SizedBox(height: 6),
              ],
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
                                  key: ValueKey('stud-player-$player'),
                                  width: spotWidth,
                                  child: _StudPlayerSpot(
                                    playerNumber: player,
                                    cards: playerHands[player] ?? const [],
                                    cardBack: widget.cardBack,
                                    patternIndex: widget.patternIndex,
                                    showdown: showdown,
                                    folded: foldedPlayers.contains(player),
                                    cardCount: widget.holdEm
                                        ? 2
                                        : widget.cardCount,
                                    holdEm: widget.holdEm,
                                    revealedCardIndexes: player == 1
                                        ? revealedUserCards
                                        : const {},
                                    balance: _playerBalance(player),
                                    selectedAction: playerActions[player],
                                    result: evaluatedHands[player],
                                    winner:
                                        evaluatedHands[player] == winningHand,
                                    actionsEnabled:
                                        hasHand &&
                                        !streetSettled &&
                                        !foldedPlayers.contains(player) &&
                                        (player == 1 ||
                                            !widget.automateComputerPlayers) &&
                                        (!_firstTurnComplete
                                            ? !playerActions.containsKey(player)
                                            : _activeRaiseResponder == player),
                                    canBet: _highestBet == 0,
                                    canRaise:
                                        _highestBet > 0 &&
                                        _playerBalance(player) >
                                            _highestBet - _playerBet(player),
                                    canCall:
                                        _highestBet > _playerBet(player) &&
                                        _playerBalance(player) >=
                                            _highestBet - _playerBet(player),
                                    canCheck: _highestBet == _playerBet(player),
                                    recommendedBet: _teachModeRecommendation(
                                      player,
                                    ),
                                    onActionSelected: (action) =>
                                        _selectAction(player, action),
                                    onCardTapped: player == 1
                                        ? widget.holdEm
                                              ? null
                                              : _revealUserCard
                                        : null,
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

  String get _dealButtonLabel {
    if (!widget.holdEm) {
      return street == 0 ? 'Deal First Card' : 'Deal Card ${street + 1}';
    }
    return switch (street) {
      0 => 'Deal Hole Cards',
      1 => 'Deal Flop',
      2 => 'Deal Turn',
      _ => 'Deal River',
    };
  }

  String get _holdEmRoundLabel => switch (street) {
    1 => 'Pre-flop betting',
    2 => 'Flop betting',
    3 => 'Turn betting',
    _ => 'River betting',
  };
}

class _StudPlayerSpot extends StatelessWidget {
  const _StudPlayerSpot({
    required this.playerNumber,
    required this.cards,
    required this.cardBack,
    required this.patternIndex,
    required this.showdown,
    required this.folded,
    required this.cardCount,
    required this.holdEm,
    required this.revealedCardIndexes,
    required this.balance,
    required this.selectedAction,
    required this.result,
    required this.winner,
    required this.actionsEnabled,
    required this.canBet,
    required this.canRaise,
    required this.canCall,
    required this.canCheck,
    required this.recommendedBet,
    required this.onActionSelected,
    required this.onCardTapped,
  });

  final int playerNumber;
  final List<PlayingCard> cards;
  final CardBackDesign cardBack;
  final int patternIndex;
  final bool showdown;
  final bool folded;
  final int cardCount;
  final bool holdEm;
  final Set<int> revealedCardIndexes;
  final int balance;
  final String? selectedAction;
  final PokerHand? result;
  final bool winner;
  final bool actionsEnabled;
  final bool canBet;
  final bool canRaise;
  final bool canCall;
  final bool canCheck;
  final double? recommendedBet;
  final ValueChanged<String> onActionSelected;
  final ValueChanged<int>? onCardTapped;

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
        const SizedBox(height: 4),
        _StudFannedCards(
          playerNumber: playerNumber,
          cards: cards,
          cardBack: cardBack,
          patternIndex: patternIndex,
          showdown: showdown,
          folded: folded,
          cardCount: cardCount,
          faceUp: holdEm && playerNumber == 1,
          revealedCardIndexes: revealedCardIndexes,
          onCardTapped: onCardTapped,
        ),
        SizedBox(
          height: 17,
          child: Text(
            folded
                ? 'FOLDED'
                : result == null
                ? '${cards.length} OF $cardCount CARDS'
                : '${result!.label}${winner ? ' - WINNER' : ''}',
            key: ValueKey('stud-player-$playerNumber-result'),
            style: TextStyle(
              color: winner ? Colors.amberAccent : Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        ChipStacks(playerNumber: playerNumber, amount: balance),
        _StudActions(
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

class _StudFannedCards extends StatelessWidget {
  const _StudFannedCards({
    required this.playerNumber,
    required this.cards,
    required this.cardBack,
    required this.patternIndex,
    required this.showdown,
    required this.folded,
    required this.cardCount,
    required this.faceUp,
    required this.revealedCardIndexes,
    required this.onCardTapped,
  });

  static const _width = 154.0;
  static const _height = 92.0;
  static const _cardWidth = 58.0;
  static const _cardHeight = 82.0;

  final int playerNumber;
  final List<PlayingCard> cards;
  final CardBackDesign cardBack;
  final int patternIndex;
  final bool showdown;
  final bool folded;
  final int cardCount;
  final bool faceUp;
  final Set<int> revealedCardIndexes;
  final ValueChanged<int>? onCardTapped;

  @override
  Widget build(BuildContext context) {
    final offset = cards.length == 1
        ? 0.0
        : math.min(24.0, (_width - _cardWidth) / (cards.length - 1));
    final handWidth = _cardWidth + offset * (cards.length - 1);
    final start = (_width - handWidth) / 2;
    final center = (cards.length - 1) / 2;

    return SizedBox(
      key: ValueKey('stud-player-$playerNumber-card-fan'),
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
                child: GestureDetector(
                  onTap: (index == 0 || index == cardCount - 1) && !showdown
                      ? () => onCardTapped?.call(index)
                      : null,
                  child: Container(
                    key: ValueKey('stud-player-$playerNumber-card-$index'),
                    width: _cardWidth,
                    height: _cardHeight,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white54),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child:
                          faceUp ||
                              (index > 0 && index < cardCount - 1) ||
                              revealedCardIndexes.contains(index) ||
                              (showdown && !folded)
                          ? PlayingCardFace(card: cards[index])
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
              ),
            ),
        ],
      ),
    );
  }
}

class _HoldEmCommunityCards extends StatelessWidget {
  const _HoldEmCommunityCards({required this.cards});

  final List<PlayingCard> cards;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('holdem-community-cards'),
      height: 70,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < 5; index++)
            Container(
              key: ValueKey('holdem-community-card-$index'),
              width: 48,
              height: 68,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white54),
                borderRadius: BorderRadius.circular(5),
              ),
              child: index < cards.length
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: PlayingCardFace(card: cards[index]),
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

class _StudActions extends StatelessWidget {
  const _StudActions({
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
      keyPrefix: 'stud-player-$playerNumber',
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
