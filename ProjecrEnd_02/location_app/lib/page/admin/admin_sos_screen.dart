import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'admin_sos_details_sheet.dart';
import 'admin_theme.dart';
import 'admin_guard_actions.dart';
import 'admin_action_button.dart';
import 'admin_section_placeholder.dart';
import 'admin_status_pill.dart';

/// Pending SOS alerts, each reviewable/locatable/acceptable in one tap.
/// Also filterable to show accepted alerts or the full history.
class SosSection extends StatefulWidget {
  final void Function(LatLng location, String? label) onLocate;

  const SosSection({super.key, required this.onLocate});

  @override
  State<SosSection> createState() => _SosSectionState();
}

enum _SosFilter { pending, accepted, all }

class _SosSectionState extends State<SosSection> {
  _SosFilter _filter = _SosFilter.pending;

  bool _matches(Map<String, dynamic> data) {
    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    switch (_filter) {
      case _SosFilter.pending:
        return status == 'pending';
      case _SosFilter.accepted:
        return status == 'accepted';
      case _SosFilter.all:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('SOS Alerts', style: AppText.sectionTitle),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _filterChip('Pending', _SosFilter.pending),
            _filterChip('Accepted', _SosFilter.accepted),
            _filterChip('All', _SosFilter.all),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
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
              final filteredDocs = docs.where((doc) {
                return _matches(doc.data() as Map<String, dynamic>);
              }).toList();

              if (filteredDocs.isEmpty) {
                return SectionPlaceholder(
                  icon: _filter == _SosFilter.pending
                      ? Icons.verified
                      : Icons.inbox_outlined,
                  iconColor: _filter == _SosFilter.pending
                      ? AppColors.success
                      : null,
                  title: _filter == _SosFilter.pending
                      ? 'No pending SOS alerts.'
                      : 'No alerts match this filter.',
                  subtitle:
                      _filter == _SosFilter.pending ? 'All clear.' : null,
                );
              }

              return ListView.separated(
                itemCount: filteredDocs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final accepted = data['status'] == 'accepted';
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: cardDecoration(radius: AppRadius.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              accepted ? Icons.check_circle : Icons.warning,
                              color: accepted
                                  ? AppColors.success
                                  : AppColors.accentRed,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                data['name'] ?? 'Unknown guard',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            StatusPill(
                              label: (data['status'] ?? 'pending')
                                  .toString(),
                              color: accepted
                                  ? AppColors.success
                                  : AppColors.accentRed,
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
                                    onLocate: widget.onLocate,
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
                                onLocationResolved: widget.onLocate,
                              ),
                            ),
                            if (!accepted)
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
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, _SosFilter value) {
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
