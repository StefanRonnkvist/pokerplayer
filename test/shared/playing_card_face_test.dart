import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playing_cards/playing_cards.dart';
import 'package:playpoker/shared/cards/playing_card_face.dart';

void main() {
  testWidgets('shows the card rank and suit at compact table size', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 58,
            height: 82,
            child: PlayingCardFace(
              card: PlayingCard(Suit.hearts, CardValue.ace),
            ),
          ),
        ),
      ),
    );

    expect(find.text('A'), findsNWidgets(2));
    expect(find.text('♥'), findsNWidgets(3));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'A of hearts',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
