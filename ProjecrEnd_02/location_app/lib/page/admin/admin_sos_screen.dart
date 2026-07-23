import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'admin_sos_details_sheet.dart';
import 'admin_theme.dart';
import 'admin_guard_actions.dart';
import 'admin_action_button.dart';
import 'admin_section_placeholder.dart';

/// Pending SOS alerts, each reviewable/locatable/acceptable in one tap.
class SosSection extends StatelessWidget {
  final void Function(LatLng location, String? label) onLocate;

  const SosSection({super.key, required this.onLocate});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sos')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SectionPlaceholder(
            icon: Icons.cloud_off,
            title: 'Unable to load SOS alerts right now.',
            subtitle: 'Check your connection and try again.',
          );
        }
        if (!snapshot.hasData) return const SectionPlaceholder.loading();

        final docs = snapshot.data!.docs;
        final pendingDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data['status'] ?? 'pending').toString().toLowerCase() ==
              'pending';
        }).toList();

        if (pendingDocs.isEmpty) {
          return const SectionPlaceholder(
            icon: Icons.verified,
            iconColor: AppColors.success,
            title: 'No pending SOS alerts.',
            subtitle: 'All clear.',
          );
        }

        return ListView.separated(
          itemCount: pendingDocs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = pendingDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: cardDecoration(radius: AppRadius.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning, color: AppColors.accentRed),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data['name'] ?? 'Unknown guard',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data['message'] ?? 'Emergency reported',
                    style: AppText.body,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionButton(
                        icon: Icons.visibility,
                        label: 'Review',
                        color: AppColors.primaryDark,
                        onPressed: () =>
                            showSosDetailsSheet(
                              context,
                              sos: data,
                              docId: doc.id,
                              onLocate: onLocate,
                            ),
                      ),
                      ActionButton(
                        icon: Icons.location_on,
                        label: 'Locate',
                        color: AppColors.info,
                        onPressed: () => GuardActions.focusOnMap(
                          context,
                          lat: data['lat'],
                          lng: data['lng'],
                          label: data['name'] ?? 'SOS guard',
                          onLocationResolved: onLocate,
                        ),
                      ),
                      ActionButton(
                        icon: Icons.check,
                        label: 'Accept',
                        color: AppColors.success,
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection('sos')
                              .doc(doc.id)
                              .update({'status': 'accepted'});
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
