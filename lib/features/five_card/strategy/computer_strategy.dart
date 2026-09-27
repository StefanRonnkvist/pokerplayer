import 'dart:math' as math;

import '../models/poker_hand.dart';

/// Betting actions that the automated player can choose.
enum ComputerAction { bet, call, raise, fold }

/// An automated player's selected [action] and total amount to commit.
class ComputerDecision {
  const ComputerDecision(this.action, [this.amount = 0]);

  final ComputerAction action;
  final int amount;
}

/// Calculates a bet from the probability that a five-card hand is best.
///
/// [cost] is the amount required to call, or the base betting unit. [pot]
/// includes that cost. [p0] defaults to the break-even probability, and
/// [maxBet] is the available bankroll or table limit.
double calculatePokerBet({
  required double p,
  required double cost,
  required double pot,
  double? p0,
  required double maxBet,
}) {
  if (p < 0 || p > 1) {
    throw ArgumentError.value(p, 'p', 'Must be between 0 and 1');
  }
  if (cost <= 0 || pot < cost) {
    throw ArgumentError('pot must include a positive cost');
  }
  if (maxBet < 0) {
    throw ArgumentError.value(maxBet, 'maxBet', 'Must not be negative');
  }

  final breakEven = cost / pot;
  final threshold = p0 ?? breakEven;
  if (threshold < 0 || threshold > 1) {
    throw ArgumentError.value(p0, 'p0', 'Must be between 0 and 1');
  }
  if (p <= threshold || threshold == 1) {
    return 0;
  }

  final scaled = (p - threshold) / (1 - threshold);
  return (scaled * maxBet).clamp(0, maxBet).toDouble();
}

/// Estimates the chance that [hand] beats every active opponent.
///
/// Each category is assigned an approximate single-opponent percentile. Raising
/// that percentile to the opponent count models the need to beat every player;
/// this is intentionally a lightweight heuristic rather than a card simulation.
double estimateWinningOdds(PokerHand hand, int activeOpponentCount) {
  const percentileByCategory = [
    0.25,
    0.62,
    0.88,
    0.955,
    0.98,
    0.996,
    0.9985,
    0.99975,
    0.99998,
  ];
  return math
      .pow(
        percentileByCategory[hand.category],
        math.max(1, activeOpponentCount),
      )
      .toDouble();
}

/// Chooses an automated player's first action for the current betting cycle.
///
/// When no call is due, a sufficiently strong hand opens with a bet. Otherwise
/// the player folds, calls, or raises according to the commitment recommended
/// by [calculatePokerBet]. Decision amounts are additional chips to commit.
ComputerDecision chooseComputerDecision({
  required int balance,
  required int currentBet,
  required int highestBet,
  required int pot,
  required double winningOdds,
}) {
  final callAmount = math.max(0, highestBet - currentBet);

  if (callAmount == 0) {
    final recommendedBet = calculatePokerBet(
      p: winningOdds,
      cost: 1,
      pot: math.max(1, pot + 1).toDouble(),
      p0: 0.28,
      maxBet: balance.toDouble(),
    );
    if (recommendedBet == 0) {
      return const ComputerDecision(ComputerAction.fold);
    }
    final amount = math.min(balance, math.max(1, recommendedBet.round()));
    return ComputerDecision(ComputerAction.bet, amount);
  }
  if (callAmount > balance) {
    return const ComputerDecision(ComputerAction.fold);
  }
  final recommendedCommitment = calculatePokerBet(
    p: winningOdds,
    cost: callAmount.toDouble(),
    pot: (pot + callAmount).toDouble(),
    maxBet: balance.toDouble(),
  );
  if (recommendedCommitment == 0) {
    return const ComputerDecision(ComputerAction.fold);
  }
  if (balance > callAmount) {
    final recommendedRaise = calculatePokerBet(
      p: winningOdds,
      cost: callAmount.toDouble(),
      pot: (pot + callAmount).toDouble(),
      p0: 0.75,
      maxBet: (balance - callAmount).toDouble(),
    );
    if (recommendedRaise > 0) {
      final amount = math
          .min(balance, callAmount + math.max(1, recommendedRaise.round()))
          .toInt();
      return ComputerDecision(ComputerAction.raise, amount);
    }
  }
  return ComputerDecision(ComputerAction.call, callAmount);
}

/// Chooses whether an automated player calls a raise or folds.
///
/// Raise responses never re-raise. Invalid or unaffordable calls fold
/// immediately; affordable calls still require positive expected commitment.
ComputerDecision chooseComputerResponse({
  required int balance,
  required int callAmount,
  required int pot,
  required double winningOdds,
}) {
  if (callAmount <= 0 || callAmount > balance) {
    return const ComputerDecision(ComputerAction.fold);
  }
  final recommendedCommitment = calculatePokerBet(
    p: winningOdds,
    cost: callAmount.toDouble(),
    pot: (pot + callAmount).toDouble(),
    maxBet: balance.toDouble(),
  );
  if (recommendedCommitment > 0) {
    return ComputerDecision(ComputerAction.call, callAmount);
  }
  return const ComputerDecision(ComputerAction.fold);
}
