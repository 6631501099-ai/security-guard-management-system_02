import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'admin_guard_details_sheet.dart';
import 'admin_theme.dart';
import 'admin_section_placeholder.dart';
import 'admin_status_pill.dart';

/// Roster of currently-active guards (updated within the last minute),
/// searchable by email and filterable by scope status, each opening a
/// detail sheet with Locate/Call/Edit/Remove.
class GuardsSection extends StatefulWidget {
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
  State<GuardsSection> createState() => _GuardsSectionState();
}

enum _GuardFilter { all, inScope, outOfScope }

class _GuardsSectionState extends State<GuardsSection> {
  _GuardFilter _filter = _GuardFilter.all;

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
            onChanged: widget.onSearchChanged,
            decoration: searchFieldDecoration('Search guard email'),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _filterChip('All', _GuardFilter.all),
            _filterChip('In scope', _GuardFilter.inScope),
            _filterChip('Out of scope', _GuardFilter.outOfScope),
          ],
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
                if (!email.contains(widget.search.toLowerCase())) continue;

                final outOfScope = data['outOfScope'] == true;
                if (_filter == _GuardFilter.inScope && outOfScope) continue;
                if (_filter == _GuardFilter.outOfScope && !outOfScope) {
                  continue;
                }

                guards.add({...data, 'id': doc.id, 'diff': diff});
              }

              if (guards.isEmpty) {
                return SectionPlaceholder(
                  icon: Icons.person_off,
                  title: 'No active guards found',
                  subtitle: _filter == _GuardFilter.all
                      ? 'Guards appear here once they check in.'
                      : 'No guards match this filter right now.',
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
                            docId: guard['id'] as String,
                            onLocate: widget.onLocate,
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

  Widget _filterChip(String label, _GuardFilter value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      showCheckmark: false,
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.accentRed.withValues(alpha: 0.12),
      labelStyle: TextStyle(
        color: selected ? AppColors.accentRed : AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: selected ? AppColors.accentRed : AppColors.divider,
        ),
      ),
    );
  }
}
