import 'package:material_ui/material_ui.dart';

/// Named colors used to paint one selectable card-back design.
typedef CardBackDesign = ({String name, Color color, Color accent});

const cardBackDesigns = <CardBackDesign>[
  (
    name: 'Crimson Lattice',
    color: Color(0xFF9E1B32),
    accent: Color(0xFFFFE7B3),
  ),
  (name: 'Midnight Star', color: Color(0xFF173B57), accent: Color(0xFFD5EDF5)),
  (name: 'Emerald Crown', color: Color(0xFF176B52), accent: Color(0xFFFFD166)),
  (name: 'Black Diamond', color: Color(0xFF252525), accent: Color(0xFFE8E8E8)),
  (name: 'Royal Sun', color: Color(0xFFB24C17), accent: Color(0xFFFFE0A3)),
  (
    name: 'Violet Constellation',
    color: Color(0xFF5B356B),
    accent: Color(0xFFFFE8FF),
  ),
  (name: 'Ocean Chevron', color: Color(0xFF087E8B), accent: Color(0xFFFFD166)),
  (name: 'Burgundy Orbit', color: Color(0xFF6D213C), accent: Color(0xFFF4D35E)),
  (name: 'Silver Mosaic', color: Color(0xFF4A5568), accent: Color(0xFFE2E8F0)),
  (name: 'Teal Current', color: Color(0xFF0B6E69), accent: Color(0xFFFFF1C1)),
];

/// Paints a bordered card back using one of the indexed procedural patterns.
class CardBackPainter extends CustomPainter {
  const CardBackPainter({
    required this.color,
    required this.accent,
    required this.patternIndex,
  });

  final Color color;
  final Color accent;
  final int patternIndex;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color);

    final linePaint = Paint()
      ..color = accent.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final boldPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final center = Offset(size.width / 2, size.height / 2);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(5, 5, size.width - 10, size.height - 10),
        const Radius.circular(3),
      ),
      boldPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(10, 10, size.width - 20, size.height - 20),
        const Radius.circular(2),
      ),
      linePaint,
    );

    // Pattern geometry scales from the canvas dimensions, allowing the same
    // painter to render selection previews and full-size playing cards.
    switch (patternIndex) {
      case 0:
        for (var offset = -size.height; offset < size.width; offset += 14) {
          canvas.drawLine(
            Offset(offset, 0),
            Offset(offset + size.height, size.height),
            linePaint,
          );
          canvas.drawLine(
            Offset(offset + size.height, 0),
            Offset(offset, size.height),
            linePaint,
          );
        }
      case 1:
        for (var radius = 16.0; radius < size.width; radius += 14) {
          canvas.drawCircle(center, radius, linePaint);
        }
        canvas.drawCircle(center, 9, Paint()..color = accent);
      case 2:
        for (var y = 22.0; y < size.height; y += 28) {
          for (var x = 18.0; x < size.width; x += 28) {
            canvas.drawRect(
              Rect.fromCenter(center: Offset(x, y), width: 12, height: 12),
              linePaint,
            );
          }
        }
      case 3:
        for (var radius = 18.0; radius < size.height / 1.5; radius += 18) {
          canvas.drawRect(
            Rect.fromCenter(center: center, width: radius, height: radius),
            linePaint,
          );
        }
      case 4:
        for (var angle = 0.0; angle < 6.28; angle += 0.52) {
          canvas.save();
          canvas.translate(center.dx, center.dy);
          canvas.rotate(angle);
          canvas.drawLine(Offset.zero, Offset(0, size.height / 2), linePaint);
          canvas.restore();
        }
        canvas.drawCircle(center, 20, boldPaint);
      case 5:
        for (var y = 22.0; y < size.height; y += 24) {
          for (var x = 18.0; x < size.width; x += 24) {
            final offsetX = (y ~/ 24).isEven ? 0.0 : 12.0;
            canvas.drawCircle(Offset(x + offsetX, y), 3, linePaint);
          }
        }
        canvas.drawCircle(center, 24, boldPaint);
      case 6:
        for (var y = 20.0; y < size.height; y += 22) {
          for (var x = 12.0; x < size.width; x += 28) {
            final chevron = Path()
              ..moveTo(x, y)
              ..lineTo(x + 8, y + 8)
              ..lineTo(x + 16, y);
            canvas.drawPath(chevron, linePaint);
          }
        }
      case 7:
        for (var inset = 16.0; inset < size.width / 2; inset += 12) {
          canvas.drawOval(
            Rect.fromLTRB(
              inset,
              inset * 1.5,
              size.width - inset,
              size.height - inset * 1.5,
            ),
            linePaint,
          );
        }
        canvas.drawCircle(center, 8, Paint()..color = accent);
      case 8:
        for (var y = 18.0; y < size.height; y += 20) {
          for (var x = 16.0; x < size.width; x += 20) {
            if (((x + y) ~/ 20).isEven) {
              canvas.drawCircle(Offset(x, y), 6, linePaint);
            } else {
              canvas.drawRect(
                Rect.fromCenter(center: Offset(x, y), width: 10, height: 10),
                linePaint,
              );
            }
          }
        }
      case 9:
        for (var y = 18.0; y < size.height; y += 18) {
          final wave = Path()..moveTo(8, y);
          for (var x = 8.0; x < size.width; x += 24) {
            wave.quadraticBezierTo(x + 6, y - 8, x + 12, y);
            wave.quadraticBezierTo(x + 18, y + 8, x + 24, y);
          }
          canvas.drawPath(wave, linePaint);
        }
    }
  }

  @override
  bool shouldRepaint(CardBackPainter oldDelegate) =>
      color != oldDelegate.color ||
      accent != oldDelegate.accent ||
      patternIndex != oldDelegate.patternIndex;
}
