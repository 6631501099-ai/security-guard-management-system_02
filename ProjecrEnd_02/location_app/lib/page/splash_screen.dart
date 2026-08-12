import 'package:flutter/material.dart';

import 'auth_check.dart';

/// First screen shown on launch — matches the "Splash Screen" mockup:
/// maroon radial gradient, shield/guard icon, app name + tagline, then
/// auto-continues into the existing auth flow (AuthCheck decides
/// login vs guard vs admin exactly like before — nothing about that
/// logic changes, this screen only sits in front of it).
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
                center: Alignment.center,
                radius: 0.9,
                colors: [Color(0xFF800000), Color(0xFF4A0000)],
                stops: [0.0, 1.0],
              ),
            ),
          ),
          Positioned(
            top: -120,
            left: -80,
            child: _glow(const Color(0x22D4AF37)),
          ),
          Positioned(
            bottom: -100,
            right: -80,
            child: _glow(const Color(0x22D4AF37)),
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.12),
                      border: Border.all(
                        color: const Color(0xFFD4AF37),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.shield_moon_rounded,
                      color: Color(0xFFD4AF37),
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Security Guard\nManagement System",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Secure · Manage · Protect",
                    style: TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 48),
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation(Color(0xFFD4AF37)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(Color color) {
    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 120, spreadRadius: 30)],
      ),
    );
  }
}
