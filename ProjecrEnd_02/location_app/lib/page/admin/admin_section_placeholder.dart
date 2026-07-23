import 'package:flutter/material.dart';
import 'admin_theme.dart';

/// Friendly placeholder for empty lists, load errors, and loading states,
/// so every section (SOS, Guards, Logs...) looks consistent instead of a
/// bare Text or spinner floating in the middle of the screen.
class SectionPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;

  const SectionPlaceholder({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
  });

  const SectionPlaceholder.loading({super.key})
    : icon = Icons.hourglass_top,
      title = 'Loading…',
      subtitle = null,
      iconColor = null;

  @override
  Widget build(BuildContext context) {
    if (title == 'Loading…') {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryRed),
      );
    }
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
        decoration: cardDecoration(radius: AppRadius.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: iconColor ?? AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: AppText.body,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
