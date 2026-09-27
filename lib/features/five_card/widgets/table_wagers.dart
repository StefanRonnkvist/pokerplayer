import 'package:flutter/material.dart';

import 'chip_stacks.dart';

/// Shows each player's committed chips and the current betting status.
class TableWagers extends StatelessWidget {
  const TableWagers({
    required this.playerCount,
    required this.wagers,
    required this.activeResponder,
    required this.callAmount,
    required this.payoutMessage,
    super.key,
  });

  final int playerCount;
  final Map<int, int> wagers;
  final int? activeResponder;
  final int callAmount;
  final String? payoutMessage;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chips on the game table',
      child: Column(
        key: const ValueKey('table-wagers'),
        children: [
          if (activeResponder != null)
            Text(
              'Player $activeResponder: Call \$$callAmount or Fold',
              key: const ValueKey('raise-response-prompt'),
              style: const TextStyle(
                color: Colors.amberAccent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          if (activeResponder == null && payoutMessage != null)
            Text(
              payoutMessage!,
              key: const ValueKey('payout-message'),
              style: const TextStyle(
                color: Colors.amberAccent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var player = 1; player <= playerCount; player++)
                  _AnimatedTableWager(
                    playerNumber: player,
                    amount: wagers[player] ?? 0,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Animates each wager change as chips moving onto the table.
class _AnimatedTableWager extends StatelessWidget {
  const _AnimatedTableWager({required this.playerNumber, required this.amount});

  static const _duration = Duration(milliseconds: 450);

  final int playerNumber;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: ValueKey('player-$playerNumber-animated-table-wager'),
      width: 64,
      child: AnimatedSwitcher(
        duration: _duration,
        reverseDuration: _duration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            key: ValueKey('player-$playerNumber-chip-movement-${child.key}'),
            position: Tween<Offset>(
              begin: const Offset(0, 1.4),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: FadeTransition(
              opacity: curvedAnimation,
              child: ScaleTransition(
                scale: Tween<double>(
                  begin: 0.72,
                  end: 1,
                ).animate(curvedAnimation),
                child: child,
              ),
            ),
          );
        },
        child: amount == 0
            ? SizedBox(
                key: ValueKey('player-$playerNumber-empty-table-wager'),
                height: 51,
              )
            : Column(
                key: ValueKey('player-$playerNumber-table-wager-$amount'),
                children: [
                  Text(
                    'P$playerNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  ChipStacks(
                    playerNumber: playerNumber,
                    amount: amount,
                    location: 'table',
                  ),
                ],
              ),
      ),
    );
  }
}
