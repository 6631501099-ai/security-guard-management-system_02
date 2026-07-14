import 'package:flutter/material.dart';

/// A small stat display card used on the guard dashboard.
class GuardStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final double minWidth;

  const GuardStatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    this.minWidth = 150,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: minWidth,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.red, size: 28),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
