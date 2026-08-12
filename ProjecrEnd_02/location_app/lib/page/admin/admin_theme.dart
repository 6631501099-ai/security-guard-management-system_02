import 'package:flutter/material.dart';

/// Centralized color palette for the Guard Panel admin dashboard.
/// Keeping every color here means the whole app re-themes from one place.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFFF5F7FB);
  static const Color surface = Colors.white;

  static const Color primaryDark = Color(0xFF4A0000);
  static const Color primaryRed = Color(0xFF800000);
  static const Color accentRed = Color(0xFFE53935);

  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFD4AF37);
  static const Color info = Color(0xFF37474F);

  static const Color textPrimary = Color(0xFF1B1B1F);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color divider = Color(0xFFE9EBF0);

  static const LinearGradient sidebarGradient = LinearGradient(
    colors: [primaryRed, primaryDark],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

/// Shared corner radii so every card/sheet/button feels consistent.
class AppRadius {
  AppRadius._();
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
}

/// Shared elevation/shadow presets.
class AppShadows {
  AppShadows._();
  static List<BoxShadow> card = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 14,
      offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
}

/// The standard "white rounded card" decoration used all over the dashboard.
BoxDecoration cardDecoration({double radius = AppRadius.xl, Color? color}) {
  return BoxDecoration(
    color: color ?? AppColors.surface,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: AppShadows.card,
  );
}

/// Reusable text styles.
class AppText {
  AppText._();

  static const TextStyle pageTitle = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static const TextStyle cardValue = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle cardLabel = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
    fontWeight: FontWeight.w500,
  );
}

/// A standard input decoration for search fields used across sections.
InputDecoration searchFieldDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textSecondary),
    prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(vertical: 0),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.divider),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.4),
    ),
  );
}
