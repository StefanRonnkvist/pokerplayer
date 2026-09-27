import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Visualizes a player's money as stacks of available chip denominations.
class ChipStacks extends StatelessWidget {
  const ChipStacks({
    required this.playerNumber,
    required this.amount,
    this.location = 'bank',
    super.key,
  });

  static const _denominations = [
    (value: 100000, asset: 'assets/pokerchip_100k.png'),
    (value: 50000, asset: 'assets/pokerchip_50k.png'),
    (value: 20000, asset: 'assets/pokerchip_20k.png'),
    (value: 10000, asset: 'assets/pokerchip_10k.png'),
    (value: 5000, asset: 'assets/pokerchip_5k.png'),
    (value: 1000, asset: 'assets/pokerchip_1k.png'),
    (value: 500, asset: 'assets/pokerchip_500.png'),
    (value: 100, asset: 'assets/pokerchip_100.png'),
    (value: 50, asset: 'assets/pokerchip_50.png'),
    (value: 20, asset: 'assets/pokerchip_20.png'),
    (value: 10, asset: 'assets/pokerchip_10.png'),
    (value: 5, asset: 'assets/pokerchip_5.png'),
    (value: 1, asset: 'assets/pokerchip_1.png'),
  ];

  final int playerNumber;
  final int amount;
  final String location;

  @override
  Widget build(BuildContext context) {
    var remainder = amount;
    // Avoid representing the whole bank with one oversized chip. Limiting the
    // largest denomination to one tenth of the amount produces visible stacks.
    final maximumChipValue = math.max(1, amount ~/ 10);
    final stacks = <({int value, String asset, int count})>[];
    for (final denomination in _denominations) {
      if (denomination.value > maximumChipValue) {
        continue;
      }
      final count = remainder ~/ denomination.value;
      if (count > 0) {
        stacks.add((
          value: denomination.value,
          asset: denomination.asset,
          count: count,
        ));
        remainder %= denomination.value;
      }
    }

    return Semantics(
      label: location == 'bank'
          ? 'Player $playerNumber chip bank, $amount dollars'
          : 'Player $playerNumber table wager, $amount dollars',
      child: SizedBox(
        key: ValueKey(
          location == 'bank'
              ? 'player-$playerNumber-chip-bank'
              : 'player-$playerNumber-table-wager',
        ),
        height: 40,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final stack in stacks)
                _ChipStack(
                  playerNumber: playerNumber,
                  location: location,
                  value: stack.value,
                  asset: stack.asset,
                  count: stack.count,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipStack extends StatelessWidget {
  const _ChipStack({
    required this.playerNumber,
    required this.location,
    required this.value,
    required this.asset,
    required this.count,
  });

  final int playerNumber;
  final String location;
  final int value;
  final String asset;
  final int count;

  @override
  Widget build(BuildContext context) {
    final visibleCount = math.min(count, 8);

    return Semantics(
      label: '$count chips worth $value dollars each',
      child: SizedBox(
        key: ValueKey(
          location == 'bank'
              ? 'player-$playerNumber-chip-$value'
              : 'player-$playerNumber-table-chip-$value',
        ),
        width: 35,
        height: 40,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            for (var index = visibleCount - 1; index >= 0; index--)
              Positioned(
                bottom: index * 2,
                child: Image.asset(
                  asset,
                  key: ValueKey(
                    location == 'bank'
                        ? 'player-$playerNumber-chip-$value-image-$index'
                        : 'player-$playerNumber-table-chip-$value-image-$index',
                  ),
                  width: 25,
                  height: 25,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            if (count > 1)
              Positioned(
                right: 0,
                top: 0,
                child: Text(
                  'x$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 7,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
