import 'package:material_ui/material_ui.dart';

abstract final class GameDeckButtonStyles {
  static ButtonStyle deal() => OutlinedButton.styleFrom(
    foregroundColor: const Color(0xFF211A05),
    backgroundColor: const Color(0xFFD8B75B),
    disabledForegroundColor: Colors.white54,
    disabledBackgroundColor: Colors.white12,
    side: const BorderSide(color: Color(0xFFFFE39A)),
  );

  static ButtonStyle shuffle() => OutlinedButton.styleFrom(
    foregroundColor: Colors.white,
    backgroundColor: const Color(0xFF8F1D24),
    side: const BorderSide(color: Color(0xFFE69A9F)),
  );
}