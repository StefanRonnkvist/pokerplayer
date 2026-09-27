import 'package:flutter_test/flutter_test.dart';
import 'package:playing_cards/playing_cards.dart';
import 'package:playpoker/features/five_card/models/poker_hand.dart';

void main() {
  PlayingCard card(Suit suit, CardValue value) => standardFiftyTwoCardDeck()
      .firstWhere((card) => card.suit == suit && card.value == value);

  test('evaluates every hand category', () {
    final hands = <String, List<PlayingCard>>{
      'Straight Flush': [
        card(Suit.hearts, CardValue.nine),
        card(Suit.hearts, CardValue.ten),
        card(Suit.hearts, CardValue.jack),
        card(Suit.hearts, CardValue.queen),
        card(Suit.hearts, CardValue.king),
      ],
      'Four of a Kind': [
        card(Suit.hearts, CardValue.ace),
        card(Suit.diamonds, CardValue.ace),
        card(Suit.clubs, CardValue.ace),
        card(Suit.spades, CardValue.ace),
        card(Suit.hearts, CardValue.two),
      ],
      'Full House': [
        card(Suit.hearts, CardValue.king),
        card(Suit.diamonds, CardValue.king),
        card(Suit.clubs, CardValue.king),
        card(Suit.hearts, CardValue.two),
        card(Suit.spades, CardValue.two),
      ],
      'Flush': [
        card(Suit.clubs, CardValue.two),
        card(Suit.clubs, CardValue.five),
        card(Suit.clubs, CardValue.eight),
        card(Suit.clubs, CardValue.jack),
        card(Suit.clubs, CardValue.ace),
      ],
      'Straight': [
        card(Suit.hearts, CardValue.ace),
        card(Suit.clubs, CardValue.two),
        card(Suit.diamonds, CardValue.three),
        card(Suit.spades, CardValue.four),
        card(Suit.hearts, CardValue.five),
      ],
      'Three of a Kind': [
        card(Suit.hearts, CardValue.queen),
        card(Suit.diamonds, CardValue.queen),
        card(Suit.clubs, CardValue.queen),
        card(Suit.spades, CardValue.four),
        card(Suit.hearts, CardValue.nine),
      ],
      'Two Pair': [
        card(Suit.hearts, CardValue.jack),
        card(Suit.diamonds, CardValue.jack),
        card(Suit.clubs, CardValue.four),
        card(Suit.spades, CardValue.four),
        card(Suit.hearts, CardValue.nine),
      ],
      'One Pair': [
        card(Suit.hearts, CardValue.ten),
        card(Suit.diamonds, CardValue.ten),
        card(Suit.clubs, CardValue.three),
        card(Suit.spades, CardValue.six),
        card(Suit.hearts, CardValue.king),
      ],
      'High Card': [
        card(Suit.hearts, CardValue.two),
        card(Suit.diamonds, CardValue.five),
        card(Suit.clubs, CardValue.eight),
        card(Suit.spades, CardValue.jack),
        card(Suit.hearts, CardValue.ace),
      ],
    };

    expect(
      hands.values.map(evaluatePokerHand).map((hand) => hand.label),
      hands.keys,
    );
  });

  test('compares wheel straight below a six-high straight', () {
    final wheel = evaluatePokerHand([
      card(Suit.hearts, CardValue.ace),
      card(Suit.clubs, CardValue.two),
      card(Suit.diamonds, CardValue.three),
      card(Suit.spades, CardValue.four),
      card(Suit.hearts, CardValue.five),
    ]);
    final sixHigh = evaluatePokerHand([
      card(Suit.hearts, CardValue.two),
      card(Suit.clubs, CardValue.three),
      card(Suit.diamonds, CardValue.four),
      card(Suit.spades, CardValue.five),
      card(Suit.hearts, CardValue.six),
    ]);

    expect(wheel.compareTo(sixHigh), lessThan(0));
  });

  test('rejects an incomplete hand', () {
    expect(
      () => evaluatePokerHand([card(Suit.hearts, CardValue.ace)]),
      throwsArgumentError,
    );
  });

  test('selects the best five-card hand from seven cards', () {
    final hand = evaluateBestPokerHand([
      card(Suit.hearts, CardValue.nine),
      card(Suit.hearts, CardValue.ten),
      card(Suit.hearts, CardValue.jack),
      card(Suit.hearts, CardValue.queen),
      card(Suit.hearts, CardValue.king),
      card(Suit.spades, CardValue.ace),
      card(Suit.clubs, CardValue.ace),
    ]);

    expect(hand.label, 'Straight Flush');
  });
}
