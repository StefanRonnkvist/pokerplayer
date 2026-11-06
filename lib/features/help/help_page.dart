import 'package:flutter/material.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const _sections = [
    (
      icon: Icons.style_outlined,
      title: 'Card Backs',
      description:
          'Choose one of 10 card-back designs. Your selection is used by the '
          'poker games and remembered when you reopen the app.',
    ),
    (
      icon: Icons.casino_outlined,
      title: 'Five Card',
      description:
          'Select Deal to give every player five cards and post the ante. '
          'After the betting round settles, tap your cards to reveal your '
          'hand; computer hands reveal automatically. Select New Deal for '
          'another hand, or Shuffle to start with a fresh deck order. This '
          'game restores the current hand and bankrolls when you return.',
    ),
    (
      icon: Icons.swap_horiz,
      title: 'Draw',
      description:
          'Complete the betting round, then tap the cards you want to replace '
          'and select Draw Selected. You can select up to the replacement '
          'limit in Settings, or choose Stand Pat to keep all five cards. '
          'Computer players choose their own discards before showdown.',
    ),
    (
      icon: Icons.style_outlined,
      title: 'Stud',
      description:
          'Play five-card stud with betting after every card. The first and '
          'fifth cards are down; cards two through four are visible. Tap your '
          'first or fifth card to view it. The pot is awarded after the fifth '
          'betting round or when only one player remains.',
    ),
    (
      icon: Icons.filter_7_outlined,
      title: 'Stud7',
      description:
          'Play seven-card stud with betting after every card. The first and '
          'seventh cards are down and the five middle cards are visible. At '
          'showdown, each active player is ranked by the best five-card hand '
          'available from all seven cards.',
    ),
    (
      icon: Icons.table_restaurant_outlined,
      title: "Hold'em",
      description:
          "Play Texas Hold'em with two private hole cards per player and five "
          'shared community cards. Betting occurs pre-flop, after the '
          'three-card flop, after the turn, and after the river. The best '
          "five-card hand from each player's seven available cards wins. "
          'This table uses the configured ante rather than blinds.',
    ),
    (
      icon: Icons.emoji_events_outlined,
      title: 'Hand Rankings',
      description:
          'From strongest to weakest: Straight Flush, Four of a Kind, Full '
          'House, Flush, Straight, Three of a Kind, Two Pair, One Pair, and '
          'High Card. Hands in the same category use their card ranks as '
          'tie-breakers; equal hands split the pot.',
    ),
    (
      icon: Icons.settings_outlined,
      title: 'Settings and Betting',
      description:
          'Use Settings to choose 2-5 players, the starting bank, the ante, '
          'and the maximum Draw replacements (1-5). Defaults are five '
          'players, a 1,000-chip bank, a 2-chip ante, and five replacements. '
          'Player 1 is always you. Bet opens the wagering, Raise increases '
          'it, Call matches it, and Fold leaves the hand. Check passes '
          'without wagering when no call is required. Unavailable actions '
          'are disabled, and computer play continues if you fold.',
    ),
    (
      icon: Icons.school_outlined,
      title: 'Teach Mode',
      description:
          'Turn on Teach Mode in Settings to show Player 1 a recommended bet '
          'during betting turns. The estimate uses hand strength, opponents, '
          'the pot, call cost, and your available bank. It is guidance, not a '
          'guarantee of winning.',
    ),
    (
      icon: Icons.paid_outlined,
      title: 'Virtual Chips and Progress',
      description:
          'All banks, antes, bets, and pots use virtual chips only; there is '
          'no real-money wagering or prizes. A wager cannot exceed the '
          'available bank. Five Card progress and the selected card back are '
          'remembered between sessions; the other games start fresh.',
    ),
    (
      icon: Icons.info_outline,
      title: 'Information',
      description:
          'Use Contact to send a message to the developer. Open Inquiries to '
          'view submitted messages. These features require an internet '
          'connection.',
    ),
    (
      icon: Icons.help_outline,
      title: 'Help',
      description: 'Review the purpose and controls of every tab in the app.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colors.surface,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: _sections.length + 1,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Play Poker Help',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose a game tab and select Deal to start. Use the '
                    'highlighted betting actions when it is your turn. Open '
                    'Settings from the app bar to configure the table. Swipe '
                    'the tab bar horizontally when a tab is outside the '
                    'visible area; use the table zoom controls to resize the '
                    'game display.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          }

          final section = _sections[index - 1];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            leading: Icon(section.icon, color: colors.primary),
            title: Text(
              section.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(section.description),
            ),
          );
        },
      ),
    );
  }
}
