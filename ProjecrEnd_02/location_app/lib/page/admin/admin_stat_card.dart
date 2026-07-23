import 'package:flutter/material.dart';
import 'admin_theme.dart';

/// Small metric card ("Guards Online: 4") used on the Overview section.
class StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final double minWidth;

  const StatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.minWidth = 170,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: minWidth,
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.cardLabel),
                const SizedBox(height: 6),
                Text(value, style: AppText.cardValue.copyWith(color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
