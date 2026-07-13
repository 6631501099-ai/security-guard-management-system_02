import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import 'guard_constants.dart';
import 'guard_location_service.dart';
import 'guard_nav_helper.dart';
import 'guard_theme.dart';
import 'guard_bottom_nav.dart';

/// SOS screen — actually sends the guard's live position + message to
/// GuardLocationService.sendSOS on open, tracks real elapsed time, and
/// lets the guard call/SMS the control room or cancel the alert.
class SosEmergencyScreen extends StatefulWidget {
  final String? initialMessage;

  const SosEmergencyScreen({super.key, this.initialMessage});

  @override
  State<SosEmergencyScreen> createState() => _SosEmergencyScreenState();
}

class _SosEmergencyScreenState extends State<SosEmergencyScreen>
    with SingleTickerProviderStateMixin {
  final GuardLocationService _locationService = GuardLocationService();
  final User? _user = FirebaseAuth.instance.currentUser;

  int _navIndex = 2;
  late final AnimationController _pulseController;
  Timer? _elapsedTimer;
  double _secondsElapsed = 0;

  bool _sending = true;
  bool _sent = false;
  bool _cancelled = false;
  String? _errorMessage;
  String? _alertId;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat(reverse: true);
    _sendAlert();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _elapsedTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendAlert() async {
    if (_user == null) {
      setState(() {
        _sending = false;
        _errorMessage = "กรุณาเข้าสู่ระบบก่อนส่ง SOS";
      });
      return;
    }

    final permission = await _locationService.requestPermission();
    if (!mounted) return;

    if (!permission.success || permission.position == null) {
      setState(() {
        _sending = false;
        _errorMessage = permission.errorMessage ?? "ไม่พบตำแหน่ง GPS";
      });
      return;
    }

    final position = permission.position!;
    final name = await _locationService.fetchUserName(_user.uid);

    try {
      final alertId = await _locationService.sendSOS(
        uid: _user.uid,
        name: name,
        email: _user.email,
        position: position,
        message: widget.initialMessage?.trim().isNotEmpty == true
            ? widget.initialMessage!.trim()
            : "เจ้าหน้าที่ต้องการความช่วยเหลือด่วน",
      );

      if (!mounted) return;
      setState(() {
        _sending = false;
        _sent = true;
        _alertId = alertId;
        _lat = position.latitude;
        _lng = position.longitude;
      });

      _elapsedTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (mounted) setState(() => _secondsElapsed += 0.1);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _errorMessage = "ส่ง SOS ไม่สำเร็จ: $e";
      });
    }
  }

  Future<void> _cancelAlert() async {
    if (_user != null && _sent) {
      await _locationService.cancelSOS(_user.uid, alertId: _alertId);
    }
    _elapsedTimer?.cancel();
    if (!mounted) return;
    setState(() => _cancelled = true);
    Navigator.of(context).maybePop();
  }

  Future<void> _call() async {
    final uri = Uri(scheme: 'tel', path: GuardConstants.emergencyContactPhone);
    if (!await launchUrl(uri)) {
      _showSnack("ไม่สามารถโทรออกได้");
    }
  }

  Future<void> _message() async {
    final uri = Uri(scheme: 'sms', path: GuardConstants.emergencyContactPhone);
    if (!await launchUrl(uri)) {
      _showSnack("ไม่สามารถเปิดหน้าส่งข้อความได้");
    }
  }

  Future<void> _shareLocation() async {
    if (_lat == null || _lng == null) return;
    final uri = Uri.parse(
        "https://www.google.com/maps/search/?api=1&query=$_lat,$_lng");
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnack("ไม่สามารถเปิดแผนที่ได้");
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.orange, content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GuardTheme.darkRed,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      "แจ้งเตือนฉุกเฉิน",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "ฉุกเฉิน",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 28),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1 + (_pulseController.value * 0.08);
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.08),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: GuardTheme.primaryRed,
                  ),
                  alignment: Alignment.center,
                  child: _sending
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "SOS",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_sent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${_secondsElapsed.toStringAsFixed(1)}s",
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              _sending
                  ? "กำลังส่งตำแหน่งของคุณไปยังแอดมิน..."
                  : _errorMessage != null
                      ? _errorMessage!
                      : "ส่งสัญญาณแล้ว กำลังรอการตอบรับ...",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _errorMessage != null
                    ? Colors.orangeAccent
                    : Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  setState(() {
                    _sending = true;
                    _errorMessage = null;
                  });
                  _sendAlert();
                },
                child: const Text("ลองส่งอีกครั้ง",
                    style: TextStyle(color: Colors.white)),
              ),
            ],
            const Spacer(),
            if (_sent)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.white70),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "GPS ${_lat?.toStringAsFixed(6)}, ${_lng?.toStringAsFixed(6)}",
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _quickAction(Icons.call, "โทรด่วน", _call),
                _quickAction(Icons.message, "ส่งข้อความ", _message),
                _quickAction(
                    Icons.share_location,
                    "แชร์ตำแหน่ง",
                    _lat == null ? null : _shareLocation),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _cancelAlert,
              child: const Text(
                "ยกเลิกการแจ้งเตือน",
                style: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
      bottomNavigationBar: GuardBottomNav(
        currentIndex: _navIndex,
        onTap: (i) {
          if (i == _navIndex) return;
          navigateToTab(context, i);
        },
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, VoidCallback? onTap) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(onTap == null ? 0.05 : 0.12),
            ),
            child: Icon(icon,
                color: onTap == null ? Colors.white30 : Colors.white),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}
