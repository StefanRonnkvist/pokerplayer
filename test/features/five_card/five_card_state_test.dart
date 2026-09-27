import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:playpoker/features/five_card/five_card_state.dart';

void main() {
  test('round-trips complete game state', () {
    final state = FiveCardState(
      deckCardIndexes: List.generate(52, (index) => index),
      playerCardIndexes: const {
        1: [0, 1, 2, 3, 4],
        2: [5, 6, 7, 8, 9],
      },
      nextCardIndex: 10,
      handsRevealed: false,
      revealedPlayerNumbers: const {1},
      playerCount: 2,
      playerBalances: const {1: 88, 2: 98},
      playerWagers: const {1: 12, 2: 2},
      playerBets: const {1: 10, 2: 0},
      playerActions: const {1: 'Bet', 2: 'Fold'},
      foldedPlayers: const {2},
      pendingRaiseResponders: const [1],
      payoutMessage: 'In progress',
      bettingRoundStarted: true,
    );

    final restored = FiveCardState.decode(state.encode());

    expect(restored.deckCardIndexes, state.deckCardIndexes);
    expect(restored.playerCardIndexes, state.playerCardIndexes);
    expect(restored.revealedPlayerNumbers, state.revealedPlayerNumbers);
    expect(restored.playerBalances, state.playerBalances);
    expect(restored.playerWagers, state.playerWagers);
    expect(restored.playerBets, state.playerBets);
    expect(restored.playerActions, state.playerActions);
    expect(restored.foldedPlayers, state.foldedPlayers);
    expect(restored.pendingRaiseResponders, state.pendingRaiseResponders);
    expect(restored.bettingRoundStarted, isTrue);
  });

  test('migrates a version 1 state with empty betting data', () {
    final legacyState = jsonEncode({
      'version': 1,
      'deckCardIndexes': List.generate(52, (index) => index),
      'playerCardIndexes': {
        '1': [0, 1, 2, 3, 4],
      },
      'nextCardIndex': 5,
      'handsRevealed': false,
      'revealedPlayerNumbers': <int>[],
    });

    final restored = FiveCardState.decode(legacyState);

    expect(restored.playerBalances, isEmpty);
    expect(restored.playerWagers, isEmpty);
    expect(restored.playerActions, isEmpty);
    expect(restored.playerCount, isNull);
  });

  test('rejects a voluntary bet larger than its table contribution', () {
    final invalidState = jsonEncode({
      'version': 2,
      'deckCardIndexes': List.generate(52, (index) => index),
      'playerCardIndexes': {
        '1': [0, 1, 2, 3, 4],
        '2': [5, 6, 7, 8, 9],
      },
      'nextCardIndex': 10,
      'handsRevealed': false,
      'revealedPlayerNumbers': <int>[],
      'playerCount': 2,
      'playerBalances': {'1': 90, '2': 100},
      'playerWagers': {'1': 5, '2': 0},
      'playerBets': {'1': 10, '2': 0},
      'playerActions': {'1': 'Bet'},
      'foldedPlayers': <int>[],
      'pendingRaiseResponders': <int>[],
      'pendingComputerPlayers': <int>[],
      'payoutMessage': null,
      'potAwarded': false,
      'bettingRoundStarted': true,
    });

    expect(() => FiveCardState.decode(invalidState), throwsFormatException);
  });
}
