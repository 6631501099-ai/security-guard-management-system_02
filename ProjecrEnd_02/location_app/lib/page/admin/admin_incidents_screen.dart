import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_theme.dart';
import 'admin_section_placeholder.dart';
import 'admin_status_pill.dart';

/// Admin-side incident report inbox — reads what guards submit from
/// `incident_report_screen.dart` (collection `incidents`).
class AdminIncidentsSection extends StatefulWidget {
  const AdminIncidentsSection({super.key});

  @override
  State<AdminIncidentsSection> createState() => _AdminIncidentsSectionState();
}

enum _IncidentFilter { newOnly, reviewed, all }

class _AdminIncidentsSectionState extends State<AdminIncidentsSection> {
  _IncidentFilter _filter = _IncidentFilter.newOnly;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('รายงานเหตุการณ์', style: AppText.sectionTitle),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _filterChip('ใหม่', _IncidentFilter.newOnly),
            _filterChip('ตรวจแล้ว', _IncidentFilter.reviewed),
            _filterChip('ทั้งหมด', _IncidentFilter.all),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('incidents')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SectionPlaceholder(
                  icon: Icons.cloud_off,
                  title: 'โหลดรายงานไม่สำเร็จ',
                  subtitle: '${snapshot.error}',
                );
              }
              if (!snapshot.hasData) return const SectionPlaceholder.loading();

              final docs = snapshot.data!.docs.where((doc) {
                final status =
                    (doc.data() as Map<String, dynamic>)['status'] ?? 'new';
                if (_filter == _IncidentFilter.newOnly) return status == 'new';
                if (_filter == _IncidentFilter.reviewed) {
                  return status == 'reviewed';
                }
                return true;
              }).toList();

              if (docs.isEmpty) {
                return const SectionPlaceholder(
                  icon: Icons.fact_check_outlined,
                  title: 'ไม่มีรายงานในหมวดนี้',
                );
              }

              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  final reviewed = data['status'] == 'reviewed';
                  final photoUrl = (data['photoUrl'] ?? '').toString();
                  return InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    onTap: () => _showDetail(context, doc.id, data),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: cardDecoration(radius: AppRadius.lg),
                      child: Row(
                        children: [
                          if (photoUrl.isNotEmpty)
                            ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm),
                              child: Image.network(
                                photoUrl,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.broken_image),
                              ),
                            )
                          else
                            const CircleAvatar(
                              backgroundColor: AppColors.warning,
                              child:
                                  Icon(Icons.report_problem, color: Colors.white),
                            ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['type'] ?? 'เหตุการณ์',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(data['guardName'] ?? '',
                                    style: AppText.body),
                                Text(
                                  data['description'] ?? '',
                                  style: AppText.body,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          StatusPill(
                            label: reviewed ? 'ตรวจแล้ว' : 'ใหม่',
                            color: reviewed
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ],
                      ),
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

  Widget _filterChip(String label, _IncidentFilter value) {
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

  void _showDetail(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) {
    final photoUrl = (data['photoUrl'] ?? '').toString();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['type'] ?? 'เหตุการณ์', style: AppText.sectionTitle),
              const SizedBox(height: 8),
              Text("เจ้าหน้าที่: ${data['guardName'] ?? '-'}"),
              const SizedBox(height: 6),
              Text("รายละเอียด: ${data['description'] ?? '-'}"),
              if (data['lat'] != null && data['lng'] != null) ...[
                const SizedBox(height: 6),
                Text("ตำแหน่ง: ${data['lat']}, ${data['lng']}"),
              ],
              const SizedBox(height: 14),
              if (photoUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Image.network(
                    photoUrl,
                    errorBuilder: (_, _, _) =>
                        const Text("ไม่สามารถโหลดรูปภาพได้"),
                  ),
                ),
              const SizedBox(height: 18),
              if (data['status'] != 'reviewed')
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('incidents')
                          .doc(docId)
                          .update({
                        'status': 'reviewed',
                        'reviewedAt': FieldValue.serverTimestamp(),
                      });
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text("ทำเครื่องหมายว่าตรวจแล้ว"),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
