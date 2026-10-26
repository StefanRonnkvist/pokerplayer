import 'package:flutter/material.dart';

import '../shared/card_table_surface.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF185C3A),
      body: CustomPaint(
        painter: FeltTexturePainter(),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 176,
                height: 176,
                child: Image(
                  image: AssetImage('assets/play_store_512.png'),
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Play Poker',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 28),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: Color(0xFFD8B75B),
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
