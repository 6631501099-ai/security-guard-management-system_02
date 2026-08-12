import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'auth_check.dart';

/// First screen shown on launch — matches the "Splash Screen" mockup:
/// maroon radial gradient, scattered gold particle dots, the MFU crest
/// (assets/icon02.png) inside a double gold ring, "Security Guard" /
/// "Management System" title, tagline, and a "POWERED BY MFU" footer
/// above a thin divider. Auto-continues into the existing auth flow
/// (AuthCheck decides login vs guard vs admin exactly like before —
/// nothing about that logic changes, this screen only sits in front of it).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthCheck()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 1.0,
                colors: [Color(0xFF8A1414), Color(0xFF4A0000)],
                stops: [0.0, 1.0],
              ),
            ),
          ),
          // Scattered gold particle dots (matches the faint dots in the
          // mockup, not the big blurred glow circles the old version had).
          const Positioned(left: 42, top: 260, child: _Particle(size: 4)),
          const Positioned(right: 60, top: 460, child: _Particle(size: 5)),
          const Positioned(right: 80, top: 590, child: _Particle(size: 6)),
          const Positioned(left: 70, bottom: 260, child: _Particle(size: 4)),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 5),
                _buildCrest(),
                const SizedBox(height: 24),
                const Text(
                  "Security Guard",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                ),
                const Text(
                  "Management System",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Secure • Manage • Protect",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(flex: 6),
                Container(
                  width: 90,
                  height: 1,
                  color: Colors.white.withOpacity(0.25),
                ),
                const SizedBox(height: 14),
                Text(
                  "POWERED BY MFU",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 11,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrest() {
    const outerSize = 128.0;
    const innerSize = 108.0;
    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer thin solid gold ring.
          Container(
            width: outerSize,
            height: outerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFD4AF37).withOpacity(0.55),
                width: 1,
              ),
            ),
          ),
          // Inner dashed gold ring.
          CustomPaint(
            size: const Size(innerSize + 10, innerSize + 10),
            painter: _DashedCirclePainter(
              color: const Color(0xFFD4AF37).withOpacity(0.8),
            ),
          ),
          // Dark maroon fill behind the crest.
          Container(
            width: innerSize,
            height: innerSize,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x33000000),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Image.asset(
              'assets/icon02.png',
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

class _Particle extends StatelessWidget {
  final double size;
  const _Particle({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFD4AF37).withOpacity(0.8),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withOpacity(0.5),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  const _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final radius = size.width / 2;
    final center = Offset(size.width / 2, size.height / 2);
    const dashCount = 40;
    const gapFraction = 0.5; // half dash, half gap
    for (int i = 0; i < dashCount; i++) {
      final startAngle = (i / dashCount) * 2 * math.pi;
      final sweep = (2 * math.pi / dashCount) * (1 - gapFraction);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) => false;
}