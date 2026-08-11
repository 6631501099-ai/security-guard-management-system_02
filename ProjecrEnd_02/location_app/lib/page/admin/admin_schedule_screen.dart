import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_theme.dart';
import 'admin_section_placeholder.dart';
import 'admin_guard_picker.dart';
import '../../date_key.dart';

/// Admin-side shift/schedule manager: pick a guard, pick a day, add or
/// remove shifts. Writes to the same `schedules` collection that
/// `guard_schedule_screen.dart` reads from, keyed by (guardUid, date).
class AdminScheduleSection extends StatefulWidget {
  const AdminScheduleSection({super.key});

  @override
  State<AdminScheduleSection> createState() => _AdminScheduleSectionState();
}

class _AdminScheduleSectionState extends State<AdminScheduleSection> {
  String? _guardUid;
  String? _guardName;
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('จัดการตารางงาน', style: AppText.sectionTitle),
        const SizedBox(height: 12),
        GuardPickerField(
          selectedUid: _guardUid,
          onSelectedUid: (uid) => setState(() => _guardUid = uid),
          onSelectedName: (name) => _guardName = name,
        ),
        const SizedBox(height: 12),
        _dayPicker(),
        const SizedBox(height: 16),
        Expanded(
          child: _guardUid == null
              ? const SectionPlaceholder(
                  icon: Icons.badge_outlined,
                  title: 'เลือกเจ้าหน้าที่เพื่อดูและจัดตารางงาน',
                )
              : _scheduleList(),
        ),
      ],
    );
  }

  Widget _dayPicker() {
    return Row(
      children: [
        IconButton(
          onPressed: () => setState(
            () => _selectedDay = _selectedDay.subtract(const Duration(days: 1)),
          ),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Center(
            child: Text(
              "${_selectedDay.day}/${_selectedDay.month}/${_selectedDay.year + 543}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        IconButton(
          onPressed: () => setState(
            () => _selectedDay = _selectedDay.add(const Duration(days: 1)),
          ),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _scheduleList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schedules')
          .where('guardUid', isEqualTo: _guardUid)
          .where('date', isEqualTo: dateKey(_selectedDay))
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SectionPlaceholder(
            icon: Icons.cloud_off,
            title: 'โหลดตารางงานไม่สำเร็จ',
            subtitle: '${snapshot.error}',
          );
        }
        if (!snapshot.hasData) return const SectionPlaceholder.loading();

        final docs = List.of(snapshot.data!.docs)
          ..sort((a, b) {
            final at = (a.data() as Map<String, dynamic>)['startTime'] ?? '';
            final bt = (b.data() as Map<String, dynamic>)['startTime'] ?? '';
            return at.toString().compareTo(bt.toString());
          });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: _addShift,
                icon: const Icon(Icons.add),
                label: const Text("เพิ่มกะงาน"),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: docs.isEmpty
                  ? const SectionPlaceholder(
                      icon: Icons.event_busy,
                      title: 'ยังไม่มีกะงานสำหรับวันนี้',
                    )
                  : ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final doc = docs[i];
                        final data = doc.data() as Map<String, dynamic>;
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: cardDecoration(radius: AppRadius.lg),
                          child: Row(
                            children: [
                              const Icon(Icons.schedule,
                                  color: AppColors.primaryDark),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['label'] ?? 'กะงาน',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      "${data['startTime'] ?? '-'} - ${data['endTime'] ?? '-'} น.",
                                      style: AppText.body,
                                    ),
                                    if ((data['note'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                      Text('${data['note']}',
                                          style: AppText.body),
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
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addShift() async {
    final labelController = TextEditingController();
    final startController = TextEditingController();
    final endController = TextEditingController();
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("เพิ่มกะงาน"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelController,
                decoration:
                    const InputDecoration(labelText: "ชื่อกะ (เช่น กะ S1)"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: startController,
                decoration:
                    const InputDecoration(labelText: "เวลาเริ่ม (เช่น 08:00)"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: endController,
                decoration: const InputDecoration(
                    labelText: "เวลาสิ้นสุด (เช่น 16:00)"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                decoration:
                    const InputDecoration(labelText: "หมายเหตุ (ไม่บังคับ)"),
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
            child: const Text("บันทึก"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (_guardUid == null || labelController.text.trim().isEmpty) return;

    final firestore = FirebaseFirestore.instance;
    await firestore.collection('schedules').add({
      'guardUid': _guardUid,
      'guardName': _guardName ?? '',
      'date': dateKey(_selectedDay),
      'label': labelController.text.trim(),
      'startTime': startController.text.trim(),
      'endTime': endController.text.trim(),
      'note': noteController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await firestore.collection('notifications').add({
      'targetUid': _guardUid,
      'title': 'ตารางเวรมีการอัปเดต',
      'subtitle':
          '${labelController.text.trim()} วันที่ ${_selectedDay.day}/${_selectedDay.month}',
      'category': 'notice',
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.success,
          content: Text("เพิ่มกะงานแล้ว"),
        ),
      );
    }
  }
}
