import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_theme.dart';
import 'admin_section_placeholder.dart';
import 'admin_guard_picker.dart';
import '../../date_key.dart';

/// Admin-side task assignment: pick a guard, give them a duty for today.
/// Writes to `tasks`, which `guard_tasks_screen.dart` reads for that
/// guard's "หน้าที่วันนี้" list, and marks done from the guard side.
class AdminTasksSection extends StatefulWidget {
  const AdminTasksSection({super.key});

  @override
  State<AdminTasksSection> createState() => _AdminTasksSectionState();
}

enum _TaskFilter { all, pending, done }

class _AdminTasksSectionState extends State<AdminTasksSection> {
  _TaskFilter _filter = _TaskFilter.pending;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('มอบหมายงาน', style: AppText.sectionTitle),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              onPressed: () => _assignTask(context),
              icon: const Icon(Icons.add_task),
              label: const Text("มอบหมายงาน"),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _filterChip('ทั้งหมด', _TaskFilter.all),
            _filterChip('ยังไม่เสร็จ', _TaskFilter.pending),
            _filterChip('เสร็จแล้ว', _TaskFilter.done),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tasks')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SectionPlaceholder(
                  icon: Icons.cloud_off,
                  title: 'โหลดรายการงานไม่สำเร็จ',
                  subtitle: '${snapshot.error}',
                );
              }
              if (!snapshot.hasData) return const SectionPlaceholder.loading();

              final docs = snapshot.data!.docs.where((doc) {
                final done =
                    (doc.data() as Map<String, dynamic>)['done'] == true;
                if (_filter == _TaskFilter.pending) return !done;
                if (_filter == _TaskFilter.done) return done;
                return true;
              }).toList();

              if (docs.isEmpty) {
                return const SectionPlaceholder(
                  icon: Icons.checklist,
                  title: 'ไม่มีงานในหมวดนี้',
                );
              }

              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  final done = data['done'] == true;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: cardDecoration(radius: AppRadius.lg),
                    child: Row(
                      children: [
                        Icon(
                          done ? Icons.check_circle : Icons.pending_actions,
                          color: done ? AppColors.success : AppColors.warning,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['title'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(data['guardName'] ?? '',
                                  style: AppText.body),
                              Text(
                                "${data['timeRange'] ?? ''} • ${data['date'] ?? ''}",
                                style: AppText.body,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => doc.reference.delete(),
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.accentRed),
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

  Widget _filterChip(String label, _TaskFilter value) {
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

  Future<void> _assignTask(BuildContext context) async {
    String? guardUid;
    String? guardName;
    final titleController = TextEditingController();
    final timeController = TextEditingController();
    final date = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setDialogState) => AlertDialog(
          title: const Text("มอบหมายงานใหม่"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GuardPickerField(
                  selectedUid: guardUid,
                  onSelectedUid: (uid) =>
                      setDialogState(() => guardUid = uid),
                  onSelectedName: (name) => guardName = name,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: "ชื่องาน"),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: timeController,
                  decoration: const InputDecoration(
                      labelText: "ช่วงเวลา (เช่น 13:30 - 14:00 น.)"),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text("ยกเลิก"),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text("มอบหมาย"),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    if (guardUid == null || titleController.text.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("กรุณาเลือกเจ้าหน้าที่และระบุชื่องาน")),
        );
      }
      return;
    }

    final firestore = FirebaseFirestore.instance;
    await firestore.collection('tasks').add({
      'guardUid': guardUid,
      'guardName': guardName ?? '',
      'title': titleController.text.trim(),
      'timeRange': timeController.text.trim(),
      'date': dateKey(date),
      'done': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await firestore.collection('notifications').add({
      'targetUid': guardUid,
      'title': 'มีงานใหม่ได้รับมอบหมาย',
      'subtitle': titleController.text.trim(),
      'category': 'notice',
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.success,
          content: Text("มอบหมายงานแล้ว"),
        ),
      );
    }
  }
}
