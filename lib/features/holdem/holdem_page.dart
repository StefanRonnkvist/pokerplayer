import 'package:material_ui/material_ui.dart';

import '../../shared/cards/card_back.dart';
import '../stud/stud_page.dart';

class HoldemPage extends StatelessWidget {
  const HoldemPage({
    required this.cardBack,
    required this.patternIndex,
    this.playerCount = 5,
    this.initialBankAmount = 1000,
    this.anteAmount = 2,
    this.teachMode = false,
    this.automateComputerPlayers = true,
    super.key,
  });

  final CardBackDesign cardBack;
  final int patternIndex;
  final int playerCount;
  final int initialBankAmount;
  final int anteAmount;
  final bool teachMode;
  final bool automateComputerPlayers;

  @override
  Widget build(BuildContext context) {
    return StudPage(
      cardBack: cardBack,
      patternIndex: patternIndex,
      playerCount: playerCount,
      initialBankAmount: initialBankAmount,
      anteAmount: anteAmount,
      holdEm: true,
      teachMode: teachMode,
      automateComputerPlayers: automateComputerPlayers,
    );
  }
}
