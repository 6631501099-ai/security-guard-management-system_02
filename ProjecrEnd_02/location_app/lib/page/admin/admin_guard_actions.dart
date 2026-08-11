import 'package:cloud_firestore/cloud_firestore.dart';
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

  // ---------------------------------------------------------------------
  // SOS ACCEPT — marks the alert accepted AND writes a notification back
  // to the guard who sent it, so their Alerts screen shows a real
  // response instead of just going quiet. `sos` is the SOS doc's data
  // (must include the `uid` field written by GuardLocationService.sendSOS).
  // ---------------------------------------------------------------------

  static Future<void> acceptSos(
    String docId,
    Map<String, dynamic> sos,
  ) async {
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('sos').doc(docId).update({
      'status': 'accepted',
    });

    final targetUid = sos['uid']?.toString();
    if (targetUid != null && targetUid.isNotEmpty) {
      await firestore.collection('notifications').add({
        'targetUid': targetUid,
        'title': 'SOS ได้รับการตอบรับแล้ว',
        'subtitle': 'แอดมินรับทราบการแจ้งเหตุฉุกเฉินของคุณแล้ว กำลังส่งความช่วยเหลือ',
        'category': 'emergency',
        'relatedId': docId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  // ---------------------------------------------------------------------
  // EDIT — writes to both `users/{uid}` (what the guard app itself reads
  // for its own profile) and `locations/{uid}` (so the roster/live-tracking
  // labels update immediately, without waiting for the guard to reconnect).
  // ---------------------------------------------------------------------

  static Future<void> updateGuardProfile({
    required String uid,
    required String name,
    required String phone,
  }) async {
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('users').doc(uid).set(
      {'name': name, 'phone': phone},
      SetOptions(merge: true),
    );
    await firestore.collection('locations').doc(uid).set(
      {'name': name},
      SetOptions(merge: true),
    );
  }

  /// Opens a simple name/phone edit dialog for [uid] and saves on confirm.
  static Future<void> showEditDialog(
    BuildContext context, {
    required String uid,
    required String currentName,
    required String currentPhone,
  }) async {
    final nameController = TextEditingController(text: currentName);
    final phoneController = TextEditingController(text: currentPhone);
    bool saving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setDialogState) => AlertDialog(
          title: const Text("Edit guard"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "Phone"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text("Cancel"),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      final phone = phoneController.text.trim();
                      if (name.isEmpty) {
                        _showWarning(context, "Name can't be empty.");
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        await updateGuardProfile(
                          uid: uid,
                          name: name,
                          phone: phone,
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: AppColors.success,
                              content: Text("Guard profile updated."),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (context.mounted) {
                          _showWarning(context, "Update failed: $e");
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // DELETE — removes the guard from the active roster/live tracking and
  // clears their stored profile. This does NOT delete their Firebase Auth
  // account or block them from logging back in: deleting an auth account
  // requires the Firebase Admin SDK (e.g. a Cloud Function) and can't be
  // done safely from a client app. To fully deactivate someone, also
  // disable their account from the Firebase Console (Authentication tab).
  // ---------------------------------------------------------------------

  static Future<void> deleteGuard(String uid) async {
    final firestore = FirebaseFirestore.instance;
    await firestore.collection('locations').doc(uid).delete();
    await firestore.collection('users').doc(uid).delete();
  }

  /// Shows a confirmation dialog before the destructive delete; returns
  /// true only if the admin explicitly confirmed.
  static Future<bool> confirmDelete(
    BuildContext context, {
    required String guardName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Remove this guard?"),
        content: Text(
          'Remove "$guardName" from the roster and live tracking?\n\n'
          "Their login will still work afterwards — to fully deactivate "
          "the account, do that separately from the Firebase Console.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentRed,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text("Remove"),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}
