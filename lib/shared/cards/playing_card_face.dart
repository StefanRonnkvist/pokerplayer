import 'package:material_ui/material_ui.dart';
import 'package:playing_cards/playing_cards.dart';

class PlayingCardFace extends StatelessWidget {
  const PlayingCardFace({required this.card, super.key});

  final PlayingCard card;

  @override
  Widget build(BuildContext context) {
    final rank = _rankLabel(card.value);
    final suit = _suitLabel(card.suit);
    final color = card.suit == Suit.hearts || card.suit == Suit.diamonds
        ? const Color(0xFFC62828)
        : const Color(0xFF151515);

    return Semantics(
      label: '$rank of ${card.suit.name}',
      child: Container(
        color: Colors.white,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cornerSize = constraints.maxWidth * 0.27;
            final centerSize = constraints.maxWidth * 0.48;
            final mark = _CardCornerMark(
              rank: rank,
              suit: suit,
              color: color,
              fontSize: cornerSize,
            );

            return Stack(
              children: [
                Positioned(left: 3, top: 3, child: mark),
                Center(
                  child: Text(
                    suit,
                    style: TextStyle(
                      color: color,
                      fontSize: centerSize,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                Positioned(
                  right: 3,
                  bottom: 3,
                  child: RotatedBox(quarterTurns: 2, child: mark),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CardCornerMark extends StatelessWidget {
  const _CardCornerMark({
    required this.rank,
    required this.suit,
    required this.color,
    required this.fontSize,
  });

  final String rank;
  final String suit;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          rank,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            height: 0.9,
            letterSpacing: 0,
          ),
        ),
        Text(
          suit,
          style: TextStyle(
            color: color,
            fontSize: fontSize * 0.82,
            height: 0.9,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

String _rankLabel(CardValue value) => switch (value) {
  CardValue.two => '2',
  CardValue.three => '3',
  CardValue.four => '4',
  CardValue.five => '5',
  CardValue.six => '6',
  CardValue.seven => '7',
  CardValue.eight => '8',
  CardValue.nine => '9',
  CardValue.ten => '10',
  CardValue.jack => 'J',
  CardValue.queen => 'Q',
  CardValue.king => 'K',
  CardValue.ace => 'A',
  CardValue.joker_1 || CardValue.joker_2 => 'Joker',
};

String _suitLabel(Suit suit) => switch (suit) {
  Suit.spades => '♠',
  Suit.hearts => '♥',
  Suit.diamonds => '♦',
  Suit.clubs => '♣',
  Suit.joker => '★',
};
