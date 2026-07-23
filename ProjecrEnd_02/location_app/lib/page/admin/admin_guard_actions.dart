import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_theme.dart';

/// Guard-related side effects (locating on the map, placing a call) that
/// used to live as private methods on _AdminDashboardState. Pulling them out
/// means the guard list, the SOS list, and both bottom sheets can all call
/// the exact same logic instead of duplicating it.
class GuardActions {
  GuardActions._();

  /// Parses [lat]/[lng] (which may arrive as num or String from Firestore)
  /// and, if valid, calls [onLocationResolved]. Shows a warning snackbar on
  /// missing or malformed coordinates instead of throwing.
  static void focusOnMap(
    BuildContext context, {
    required dynamic lat,
    required dynamic lng,
    String? label,
    required void Function(LatLng location, String? label) onLocationResolved,
  }) {
    if (lat == null || lng == null) {
      _showWarning(context, "No location available for this guard.");
      return;
    }

    try {
      final parsedLat = double.parse(lat.toString());
      final parsedLng = double.parse(lng.toString());
      onLocationResolved(LatLng(parsedLat, parsedLng), label);
    } catch (_) {
      _showWarning(context, "The saved location is not valid.");
    }
  }

  /// Opens the phone dialer for a guard/SOS record's phone number, if any.
  static Future<void> callGuard(
    BuildContext context,
    Map<String, dynamic> guard,
  ) async {
    final phone = (guard['phone'] ?? guard['phoneNumber'] ?? '')
        .toString()
        .trim();
    if (phone.isEmpty) {
      _showWarning(context, "No phone number is available for this guard.");
      return;
    }

    final uri = Uri(scheme: 'tel', path: phone);
    final launched = await launchUrl(uri);
    if (!launched) {
      if (!context.mounted) return;
      _showWarning(context, "Unable to open the phone dialer.");
    }
  }

  static void _showWarning(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        content: Text(message),
      ),
    );
  }
}
