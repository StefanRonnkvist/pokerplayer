import 'package:flutter_test/flutter_test.dart';
import 'package:playpoker/features/five_card/models/poker_hand.dart';
import 'package:playpoker/features/five_card/strategy/computer_strategy.dart';

void main() {
  test('scales a recommended bet above break-even probability', () {
    final bet = calculatePokerBet(p: 0.62, cost: 10, pot: 40, maxBet: 100);

    expect(bet, closeTo(49.33, 0.01));
  });

  test('returns no bet at or below the probability threshold', () {
    expect(calculatePokerBet(p: 0.25, cost: 10, pot: 40, maxBet: 100), 0);
  });

  test('rejects a pot that does not include the betting cost', () {
    expect(
      () => calculatePokerBet(p: 0.5, cost: 10, pot: 5, maxBet: 100),
      throwsArgumentError,
    );
  });

  test('folds a weak hand when opening the betting', () {
    final decision = chooseComputerDecision(
      balance: 1000,
      currentBet: 0,
      highestBet: 0,
      pot: 10,
      winningOdds: 0.2,
    );

    expect(decision.action, ComputerAction.fold);
    expect(decision.amount, 0);
  });

  test('calls when winning odds cover the pot odds', () {
    final decision = chooseComputerDecision(
      balance: 1000,
      currentBet: 0,
      highestBet: 100,
      pot: 400,
      winningOdds: 0.4,
    );

    expect(decision.action, ComputerAction.call);
    expect(decision.amount, 100);
  });

  test('raises a strong hand without exceeding the bank', () {
    final decision = chooseComputerDecision(
      balance: 120,
      currentBet: 0,
      highestBet: 100,
      pot: 400,
      winningOdds: 0.9,
    );

    expect(decision.action, ComputerAction.raise);
    expect(decision.amount, 112);
  });

  test('uses the betting equation for computer raise responses', () {
    final call = chooseComputerResponse(
      balance: 100,
      callAmount: 10,
      pot: 40,
      winningOdds: 0.3,
    );
    final fold = chooseComputerResponse(
      balance: 100,
      callAmount: 10,
      pot: 40,
      winningOdds: 0.2,
    );

    expect(call.action, ComputerAction.call);
    expect(call.amount, 10);
    expect(fold.action, ComputerAction.fold);
  });

  test('winning odds decrease as the opponent count grows', () {
    const hand = PokerHand(4, [10], 'Straight');

    expect(
      estimateWinningOdds(hand, 3),
      lessThan(estimateWinningOdds(hand, 1)),
    );
  });
}
