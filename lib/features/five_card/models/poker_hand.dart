import 'package:playing_cards/playing_cards.dart';

/// Evaluates every five-card combination and returns the strongest poker hand.
///
/// This supports community-card variants as well as five-card games. At least
/// five cards are required; ties between equivalent combinations do not affect
/// the returned hand value.
PokerHand evaluateBestPokerHand(List<PlayingCard> cards) {
  if (cards.length < 5) {
    throw ArgumentError.value(
      cards.length,
      'cards.length',
      'Must be at least 5',
    );
  }
  if (cards.length == 5) {
    return evaluatePokerHand(cards);
  }

  PokerHand? bestHand;
  // Enumerate combinations directly so evaluating seven cards does not require
  // allocating a complete list of all 21 candidate hands first.
  for (var first = 0; first < cards.length - 4; first++) {
    for (var second = first + 1; second < cards.length - 3; second++) {
      for (var third = second + 1; third < cards.length - 2; third++) {
        for (var fourth = third + 1; fourth < cards.length - 1; fourth++) {
          for (var fifth = fourth + 1; fifth < cards.length; fifth++) {
            final hand = evaluatePokerHand([
              cards[first],
              cards[second],
              cards[third],
              cards[fourth],
              cards[fifth],
            ]);
            if (bestHand == null || hand.compareTo(bestHand) > 0) {
              bestHand = hand;
            }
          }
        }
      }
    }
  }
  return bestHand!;
}

/// Classifies exactly five cards and builds the rank-specific tie breakers.
///
/// Categories increase with hand strength. Tie breakers are ordered from most
/// to least significant so [PokerHand.compareTo] can compare them in sequence.
/// An ace is normally high, except in an A-2-3-4-5 straight where the high card
/// is recorded as five.
PokerHand evaluatePokerHand(List<PlayingCard> cards) {
  if (cards.length != 5) {
    throw ArgumentError.value(cards.length, 'cards.length', 'Must be 5');
  }

  final ranks = cards.map((card) => _pokerRank(card.value)).toList();
  final counts = <int, int>{};
  for (final rank in ranks) {
    counts.update(rank, (count) => count + 1, ifAbsent: () => 1);
  }

  final groups = counts.entries.toList()
    ..sort((left, right) {
      final countComparison = right.value.compareTo(left.value);
      return countComparison != 0
          ? countComparison
          : right.key.compareTo(left.key);
    });
  final descendingRanks = [...ranks]..sort((left, right) => right - left);
  final uniqueRanks = counts.keys.toList()..sort();
  final isFlush = cards.map((card) => card.suit).toSet().length == 1;
  final straightHigh = uniqueRanks.length != 5
      ? null
      : uniqueRanks.last - uniqueRanks.first == 4
      ? uniqueRanks.last
      : uniqueRanks.toString() == '[2, 3, 4, 5, 14]'
      ? 5
      : null;

  if (isFlush && straightHigh != null) {
    return PokerHand(8, [straightHigh], 'Straight Flush');
  }
  if (groups.first.value == 4) {
    return PokerHand(7, [groups.first.key, groups.last.key], 'Four of a Kind');
  }
  if (groups.first.value == 3 && groups[1].value == 2) {
    return PokerHand(6, [groups.first.key, groups[1].key], 'Full House');
  }
  if (isFlush) {
    return PokerHand(5, descendingRanks, 'Flush');
  }
  if (straightHigh != null) {
    return PokerHand(4, [straightHigh], 'Straight');
  }
  if (groups.first.value == 3) {
    return PokerHand(3, [
      groups.first.key,
      ...groups.skip(1).map((group) => group.key),
    ], 'Three of a Kind');
  }
  if (groups.first.value == 2 && groups[1].value == 2) {
    return PokerHand(2, [
      groups.first.key,
      groups[1].key,
      groups.last.key,
    ], 'Two Pair');
  }
  if (groups.first.value == 2) {
    return PokerHand(1, [
      groups.first.key,
      ...groups.skip(1).map((group) => group.key),
    ], 'One Pair');
  }
  return PokerHand(0, descendingRanks, 'High Card');
}

int _pokerRank(CardValue value) => switch (value) {
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
  CardValue.joker_1 || CardValue.joker_2 => throw StateError(
    'Jokers are not valid in five-card poker.',
  ),
};

/// A comparable poker-hand value containing its category and ordered kickers.
class PokerHand implements Comparable<PokerHand> {
  const PokerHand(this.category, this.tieBreakers, this.label);

  /// Numeric hand strength from `0` (high card) to `8` (straight flush).
  final int category;

  /// Rank values compared in order when two hands share a [category].
  final List<int> tieBreakers;

  /// Human-readable category name shown in the game UI.
  final String label;

  /// Returns a positive value when this hand outranks [other].
  @override
  int compareTo(PokerHand other) {
    final categoryComparison = category.compareTo(other.category);
    if (categoryComparison != 0) {
      return categoryComparison;
    }
    for (var index = 0; index < tieBreakers.length; index++) {
      final comparison = tieBreakers[index].compareTo(other.tieBreakers[index]);
      if (comparison != 0) {
        return comparison;
      }
    }
    return 0;
  }

  @override
  bool operator ==(Object other) => other is PokerHand && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(category, Object.hashAll(tieBreakers));
}
