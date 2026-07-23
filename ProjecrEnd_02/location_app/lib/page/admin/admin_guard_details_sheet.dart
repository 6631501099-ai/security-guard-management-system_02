import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'admin_theme.dart';
import 'admin_guard_actions.dart';
import 'admin_action_button.dart';
import 'admin_status_pill.dart';

/// Bottom sheet with full detail for a single guard, plus Locate / Call
/// actions. Extracted from _AdminDashboardState._showGuardDetails.
void showGuardDetailsSheet(
  BuildContext context, {
  required Map<String, dynamic> guard,
  required void Function(LatLng location, String? label) onLocate,
}) {
  final outOfScope = guard['outOfScope'] == true;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 60,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: outOfScope
                      ? AppColors.accentRed
                      : AppColors.success,
                  child: const Icon(Icons.security, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    guard['name'] ?? "Guard Details",
                    style: AppText.sectionTitle,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              "Email: ${guard['email'] ?? '—'}",
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              "Latitude: ${guard['lat'] ?? '—'}",
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              "Longitude: ${guard['lng'] ?? '—'}",
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            StatusPill(
              label: outOfScope ? "Out of scope" : "On route",
              color: outOfScope ? AppColors.accentRed : AppColors.success,
              icon: outOfScope ? Icons.error_outline : Icons.check_circle,
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionButton(
                  icon: Icons.map,
                  label: "Locate",
                  color: AppColors.primaryDark,
                  width: 150,
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    GuardActions.focusOnMap(
                      context,
                      lat: guard['lat'],
                      lng: guard['lng'],
                      label: guard['name'] ?? "Guard",
                      onLocationResolved: onLocate,
                    );
                  },
                ),
                ActionButton(
                  icon: Icons.call,
                  label: "Call Guard",
                  color: AppColors.info,
                  width: 150,
                  onPressed: () => GuardActions.callGuard(context, guard),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
