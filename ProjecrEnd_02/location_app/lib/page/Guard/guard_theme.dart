import 'package:flutter/material.dart';

/// Shared design tokens used across every Guard screen so the
/// converted UI stays visually consistent with the Figma mockups.
class GuardTheme {
  GuardTheme._();

  static const Color primaryRed = Color(0xFF800000);
  static const Color darkRed = Color(0xFF4A0000);
  static const Color scaffoldBg = Color(0xFFF8F9FA);
  static const Color profileBg = Color(0xFFFAFAF9);
  static const Color cardBg = Colors.white;
  static const Color green = Color(0xFF2E7D32);
  static const Color orange = Color(0xFFD4AF37);
  static const Color textGrey = Color(0xFF6B7280);

  static BoxShadow get softShadow => BoxShadow(
    color: Colors.black.withOpacity(0.06),
    blurRadius: 16,
    offset: const Offset(0, 6),
  );

  static BoxDecoration cardDecoration({double radius = 20}) => BoxDecoration(
    color: cardBg,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [softShadow],
  );

  static const TextStyle screenTitle = TextStyle(
    color: Colors.white,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
  );

  /// Scale factor (<= 1.0) for fixed-size elements (big circles, floating
  /// buttons, etc.) so they shrink proportionally on narrow phones instead
  /// of overflowing, while normal/large phones are left untouched.
  ///
  /// Usage: `size * GuardTheme.responsiveScale(context)`
  static double responsiveScale(BuildContext context, {double baseWidth = 360}) {
    final width = MediaQuery.of(context).size.width;
    if (width >= baseWidth) return 1.0;
    return (width / baseWidth).clamp(0.78, 1.0);
  }
}
