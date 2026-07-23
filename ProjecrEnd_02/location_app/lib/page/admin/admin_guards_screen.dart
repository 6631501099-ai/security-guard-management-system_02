import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'admin_guard_details_sheet.dart';
import 'admin_theme.dart';
import 'admin_section_placeholder.dart';
import 'admin_status_pill.dart';

/// Roster of currently-active guards (updated within the last minute),
/// searchable by email, each opening a detail sheet with Locate/Call.
class GuardsSection extends StatelessWidget {
  final String search;
  final ValueChanged<String> onSearchChanged;
  final void Function(LatLng location, String? label) onLocate;

  const GuardsSection({
    super.key,
    required this.search,
    required this.onSearchChanged,
    required this.onLocate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Guard roster', style: AppText.sectionTitle),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: TextField(
            onChanged: onSearchChanged,
            decoration: searchFieldDecoration('Search guard email'),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('locations')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SectionPlaceholder.loading();

              final docs = snapshot.data!.docs;
              final guards = <Map<String, dynamic>>[];
              for (final doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final lastUpdate = data['lastUpdate'];
                if (lastUpdate == null) continue;
                final diff = DateTime.now()
                    .difference((lastUpdate as Timestamp).toDate())
                    .inSeconds;
                if (diff > 60) continue;
                final email = (data['email'] ?? '').toString().toLowerCase();
                if (!email.contains(search.toLowerCase())) continue;
                guards.add({...data, 'diff': diff});
              }

              if (guards.isEmpty) {
                return const SectionPlaceholder(
                  icon: Icons.person_off,
                  title: 'No active guards found',
                  subtitle: 'Guards appear here once they check in.',
                );
              }

              return ListView.separated(
                itemCount: guards.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final guard = guards[index];
                  final outOfScope = guard['outOfScope'] == true;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: cardDecoration(radius: AppRadius.lg),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: outOfScope
                              ? AppColors.accentRed
                              : AppColors.success,
                          child: const Icon(
                            Icons.security,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                guard['name'] ?? 'Guard',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                guard['email'] ?? '',
                                style: AppText.body,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Lat: ${guard['lat']} • Lng: ${guard['lng']}',
                                style: AppText.body,
                              ),
                              const SizedBox(height: 6),
                              StatusPill(
                                label: outOfScope ? 'Out of scope' : 'On route',
                                color: outOfScope
                                    ? AppColors.accentRed
                                    : AppColors.success,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryDark,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.md,
                              ),
                            ),
                          ),
                          onPressed: () => showGuardDetailsSheet(
                            context,
                            guard: guard,
                            onLocate: onLocate,
                          ),
                          icon: const Icon(Icons.location_on),
                          label: const Text('View'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
