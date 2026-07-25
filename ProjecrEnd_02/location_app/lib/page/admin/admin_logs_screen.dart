import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_theme.dart';
import 'admin_section_placeholder.dart';

/// Read-only feed of recent SOS activity/status changes, filterable by
/// status and searchable by guard name.
class LogsSection extends StatefulWidget {
  const LogsSection({super.key});

  @override
  State<LogsSection> createState() => _LogsSectionState();
}

enum _LogFilter { all, pending, accepted }

class _LogsSectionState extends State<LogsSection> {
  _LogFilter _filter = _LogFilter.all;
  String _search = '';

  bool _matches(Map<String, dynamic> data) {
    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    final matchesFilter = switch (_filter) {
      _LogFilter.all => true,
      _LogFilter.pending => status == 'pending',
      _LogFilter.accepted => status == 'accepted',
    };
    if (!matchesFilter) return false;
    if (_search.isEmpty) return true;
    final name = (data['name'] ?? '').toString().toLowerCase();
    return name.contains(_search.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent logs', style: AppText.sectionTitle),
        const SizedBox(height: 8),
        const Text(
          'Latest patrol events, SOS activity, and current guard status.',
          style: AppText.body,
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 44,
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: searchFieldDecoration('Search by guard name'),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _filterChip('All', _LogFilter.all),
            _filterChip('Pending', _LogFilter.pending),
            _filterChip('Accepted', _LogFilter.accepted),
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
              if (!snapshot.hasData) return const SectionPlaceholder.loading();

              final items = snapshot.data!.docs.where((doc) {
                return _matches(doc.data() as Map<String, dynamic>);
              }).toList();

              if (items.isEmpty) {
                return const SectionPlaceholder(
                  icon: Icons.history,
                  title: 'No activity yet',
                );
              }

              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final data = item.data() as Map<String, dynamic>;
                  final accepted = data['status'] == 'accepted';
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: cardDecoration(radius: AppRadius.lg),
                    child: Row(
                      children: [
                        Icon(
                          accepted ? Icons.check_circle : Icons.warning,
                          color: accepted
                              ? AppColors.success
                              : AppColors.accentRed,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['name'] ?? 'Guard',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                data['message'] ?? 'No message',
                                style: AppText.body,
                              ),
                              Text(
                                'Status: ${data['status'] ?? 'pending'}',
                                style: AppText.body,
                              ),
                            ],
                          ),
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

  Widget _filterChip(String label, _LogFilter value) {
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
