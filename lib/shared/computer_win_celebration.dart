import 'dart:math' as math;

/// Tracks each computer player's consecutive outright wins and celebrates
/// streaks of two or more hands.
String? recordComputerHandWinners(
  Map<int, int> consecutiveWins,
  Iterable<int> winners, {
  required bool computersEnabled,
  required int playerCount,
}) {
  const phrases = [
    'Pure skill.',
    'Calculated.',
    'Totally planned.',
    'Read you.',
    'Never a doubt.',
    'Just that good.',
    'Easy game.',
    'Textbook play.',
    'Too easy.',
    'Saw that coming.',
  ];

  if (!computersEnabled) {
    consecutiveWins.clear();
    return null;
  }

  final winnerSet = winners.toSet();
  for (var player = 1; player <= playerCount; player++) {
    if (winnerSet.length == 1 && winnerSet.single == player && player > 1) {
      consecutiveWins[player] = (consecutiveWins[player] ?? 0) + 1;
    } else {
      consecutiveWins.remove(player);
    }
  }

  if (winnerSet.length != 1) {
    return null;
  }
  final winner = winnerSet.single;
  if (winner == 1 || consecutiveWins[winner] != 2) {
    return null;
  }

  final phrase = phrases[math.Random().nextInt(phrases.length)];
  return '🤖 Player $winner: $phrase';
}
