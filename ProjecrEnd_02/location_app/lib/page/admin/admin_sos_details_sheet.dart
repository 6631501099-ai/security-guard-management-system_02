import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'admin_theme.dart';
import 'admin_guard_actions.dart';
import 'admin_action_button.dart';

/// Bottom sheet with full detail for a single SOS alert, plus Map / Call /
/// Accept actions. Extracted from _AdminDashboardState._showSosDetails.
void showSosDetailsSheet(
  BuildContext context, {
  required Map<String, dynamic> sos,
  required String docId,
  required void Function(LatLng location, String? label) onLocate,
}) {
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
                const Icon(Icons.warning_rounded, color: AppColors.accentRed),
                const SizedBox(width: 8),
                const Text("SOS Alert Details", style: AppText.sectionTitle),
              ],
            ),
            const SizedBox(height: 14),
            _DetailRow(label: "Name", value: "${sos['name'] ?? '—'}"),
            _DetailRow(label: "Email", value: "${sos['email'] ?? '—'}"),
            _DetailRow(
              label: "Location",
              value: "${sos['lat'] ?? '—'}, ${sos['lng'] ?? '—'}",
            ),
            _DetailRow(
              label: "Status",
              value: "${sos['status'] ?? 'pending'}",
              emphasize: true,
            ),
            _DetailRow(label: "Message", value: "${sos['message'] ?? ''}"),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionButton(
                  icon: Icons.map,
                  label: "Map",
                  color: AppColors.primaryDark,
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    GuardActions.focusOnMap(
                      context,
                      lat: sos['lat'],
                      lng: sos['lng'],
                      label: sos['name'] ?? "SOS guard",
                      onLocationResolved: onLocate,
                    );
                  },
                ),
                ActionButton(
                  icon: Icons.call,
                  label: "Call",
                  color: AppColors.info,
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    GuardActions.callGuard(context, sos);
                  },
                ),
                ActionButton(
                  icon: Icons.check,
                  label: "Accept",
                  color: AppColors.success,
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection("sos")
                        .doc(docId)
                        .update({"status": "accepted"});
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _DetailRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
          children: [
            TextSpan(
              text: "$label: ",
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontWeight: emphasize ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
