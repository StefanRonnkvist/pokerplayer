import 'package:flutter/material.dart';

/// Applies the shared felt background and high-contrast table theme.
class CardTableSurface extends StatelessWidget {
  const CardTableSurface({
    required this.child,
    this.color = const Color(0xFF185C3A),
    super.key,
  });

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tableTheme = Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme
          .apply(bodyColor: Colors.white, displayColor: Colors.white),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white70),
        ),
      ),
    );

    return ColoredBox(
      color: color,
      child: CustomPaint(
        painter: const FeltTexturePainter(),
        child: Theme(data: tableTheme, child: child),
      ),
    );
  }
}

/// Draws crossing translucent fibers to create a lightweight felt texture.
class FeltTexturePainter extends CustomPainter {
  const FeltTexturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final lightFiber = Paint()
      ..color = Colors.white.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    final darkFiber = Paint()
      ..color = Colors.black.withValues(alpha: 0.035)
      ..strokeWidth = 1;

    for (var offset = 0.0; offset < size.width + size.height; offset += 8) {
      canvas.drawLine(
        Offset(offset, 0),
        Offset(offset - size.height, size.height),
        lightFiber,
      );
      canvas.drawLine(
        Offset(offset - size.height, 0),
        Offset(offset, size.height),
        darkFiber,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
