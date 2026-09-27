import 'package:flutter/material.dart';
import 'package:playing_cards/playing_cards.dart';

import '../../shared/cards/card_back.dart';

class CardBackSelector extends StatelessWidget {
  const CardBackSelector({
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Choose a card back',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'Selected: ${cardBackDesigns[selectedIndex].name}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 18,
            runSpacing: 22,
            children: [
              for (var index = 0; index < cardBackDesigns.length; index++)
                _CardBackChoice(
                  name: cardBackDesigns[index].name,
                  color: cardBackDesigns[index].color,
                  accent: cardBackDesigns[index].accent,
                  patternIndex: index,
                  isSelected: selectedIndex == index,
                  onSelected: () => onSelected(index),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardBackChoice extends StatelessWidget {
  const _CardBackChoice({
    required this.name,
    required this.color,
    required this.accent,
    required this.patternIndex,
    required this.isSelected,
    required this.onSelected,
  });

  final String name;
  final Color color;
  final Color accent;
  final int patternIndex;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    const width = 132.0;
    const height = width / playingCardAspectRatio;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$name card back',
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: width + 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: width,
                height: height,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? accent : Colors.white70,
                    width: isSelected ? 4 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: isSelected ? 12 : 6,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: CustomPaint(
                    painter: CardBackPainter(
                      color: color,
                      accent: accent,
                      patternIndex: patternIndex,
                    ),
                    child: isSelected
                        ? Align(
                            alignment: Alignment.topRight,
                            child: Container(
                              margin: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Icon(Icons.check, color: color, size: 24),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
