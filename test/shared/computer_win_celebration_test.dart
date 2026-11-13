import 'package:flutter_test/flutter_test.dart';
import 'package:playpoker/shared/computer_win_celebration.dart';

void main() {
  test(
    'celebrates computer outright wins starting with the second in a row',
    () {
      final streaks = <int, int>{};

      expect(
        recordComputerHandWinners(
          streaks,
          [2],
          computersEnabled: true,
          playerCount: 3,
        ),
        isNull,
      );
      final celebration = recordComputerHandWinners(
        streaks,
        [2],
        computersEnabled: true,
        playerCount: 3,
      );

      expect(streaks[2], 2);
      expect(
        celebration,
        matches(
          RegExp(
            r'^🤖 Player 2: (Pure skill\.|Calculated\.|Totally planned\.|Read you\.|Never a doubt\.|Just that good\.|Easy game\.|Textbook play\.|Too easy\.|Saw that coming\.)$',
          ),
        ),
      );
    },
  );

  test('a user win or a tie breaks the computer streak', () {
    final streaks = <int, int>{};
    recordComputerHandWinners(
      streaks,
      [2],
      computersEnabled: true,
      playerCount: 3,
    );
    recordComputerHandWinners(
      streaks,
      [1],
      computersEnabled: true,
      playerCount: 3,
    );

    expect(streaks, isEmpty);
    expect(
      recordComputerHandWinners(
        streaks,
        [2, 3],
        computersEnabled: true,
        playerCount: 3,
      ),
      isNull,
    );
    expect(streaks, isEmpty);
  });
}
