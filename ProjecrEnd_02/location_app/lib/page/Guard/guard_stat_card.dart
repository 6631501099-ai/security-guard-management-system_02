import 'package:flutter/material.dart';
import 'guard_theme.dart';

/// Small stat tile — icon, title, value — used in dashboard-style grids.
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
      constraints: BoxConstraints(minWidth: minWidth),
      padding: const EdgeInsets.all(14),
      decoration: GuardTheme.cardDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: GuardTheme.primaryRed, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 11, color: GuardTheme.textGrey),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
