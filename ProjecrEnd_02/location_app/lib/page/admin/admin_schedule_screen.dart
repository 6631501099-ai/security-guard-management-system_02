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

    // ตัวแปรสำหรับเก็บการทำซ้ำกะงาน
    bool repeatEnable = false;
    bool repeatEveryday = false;
    int repeatWeeks = 1; // สั่งซ้ำล่วงหน้ากี่สัปดาห์ (ค่าเริ่มต้น 1 สัปดาห์)
    
    // เก็บรายการวันที่ต้องการทำซ้ำ (1 = จันทร์, 7 = อาทิตย์ ตาม DateTime.weekday)
    final Set<int> selectedDays = {_selectedDay.weekday};

    final daysMap = {
      1: 'จ.',
      2: 'อ.',
      3: 'พ.',
      4: 'พฤ.',
      5: 'ศ.',
      6: 'ส.',
      7: 'อา.',
    };

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("เพิ่มกะงาน"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 16),
                  
                  // --- ส่วนฟังก์ชันสั่งซ้ำ ---
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("ตั้งค่าสั่งซ้ำ (Repeat)",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    value: repeatEnable,
                    onChanged: (val) {
                      setDialogState(() {
                        repeatEnable = val;
                      });
                    },
                  ),

                  if (repeatEnable) ...[
                    // ตัวเลือกสั่งซ้ำทุกวัน
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("สั่งซ้ำทุกวัน", style: TextStyle(fontSize: 13)),
                      value: repeatEveryday,
                      onChanged: (val) {
                        setDialogState(() {
                          repeatEveryday = val ?? false;
                          if (repeatEveryday) {
                            selectedDays.addAll([1, 2, 3, 4, 5, 6, 7]);
                          } else {
                            selectedDays.clear();
                            selectedDays.add(_selectedDay.weekday);
                          }
                        });
                      },
                    ),

                    // ตัวเลือกติ๊กวันในสัปดาห์ (จ. - อา.)
                    if (!repeatEveryday) ...[
                      const Text("เลือกวันที่ต้องการซ้ำในสัปดาห์:",
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: daysMap.entries.map((entry) {
                          final isSelected = selectedDays.contains(entry.key);
                          return FilterChip(
                            label: Text(entry.value, style: const TextStyle(fontSize: 12)),
                            selected: isSelected,
                            selectedColor: AppColors.primaryDark.withOpacity(0.2),
                            onSelected: (bool selected) {
                              setDialogState(() {
                                if (selected) {
                                  selectedDays.add(entry.key);
                                } else {
                                  if (selectedDays.length > 1) {
                                    selectedDays.remove(entry.key);
                                  }
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],

                    const SizedBox(height: 10),
                    // ระยะเวลาที่ต้องการสร้างกะงานล่วงหน้า
                    Row(
                      children: [
                        const Text("สร้างกะล่วงหน้า: ", style: TextStyle(fontSize: 12)),
                        DropdownButton<int>(
                          value: repeatWeeks,
                          isDense: true,
                          items: const [
                            DropdownMenuItem(value: 1, child: Text("1 สัปดาห์")),
                            DropdownMenuItem(value: 2, child: Text("2 สัปดาห์")),
                            DropdownMenuItem(value: 4, child: Text("1 เดือน (4 สัปดาห์)")),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => repeatWeeks = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(null),
                child: const Text("ยกเลิก"),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop({'confirmed': true}),
                child: const Text("บันทึก"),
              ),
            ],
          );
        },
      ),
    );

    if (result == null || result['confirmed'] != true) return;
    if (_guardUid == null || labelController.text.trim().isEmpty) return;

    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    // คำนวณวันที่ต้องสร้างกะทั้งหมด
    List<DateTime> targetDates = [];

    if (!repeatEnable) {
      targetDates.add(_selectedDay);
    } else {
      // หากเลือกสั่งซ้ำ ให้คำนวณตั้งแต่วันที่เลือก ยิงยาวไปตามจำนวนสัปดาห์
      final totalDaysToCalculate = repeatWeeks * 7;
      for (int i = 0; i < totalDaysToCalculate; i++) {
        final checkDate = _selectedDay.add(Duration(days: i));
        if (selectedDays.contains(checkDate.weekday)) {
          targetDates.add(checkDate);
        }
      }
    }

    // วนลูปสร้างเอกสารลง Firestore
    for (final date in targetDates) {
      final docRef = firestore.collection('schedules').doc();
      batch.set(docRef, {
        'guardUid': _guardUid,
        'guardName': _guardName ?? '',
        'date': dateKey(date),
        'label': labelController.text.trim(),
        'startTime': startController.text.trim(),
        'endTime': endController.text.trim(),
        'note': noteController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // ส่งการแจ้งเตือน
    final notiRef = firestore.collection('notifications').doc();
    batch.set(notiRef, {
      'targetUid': _guardUid,
      'title': 'ตารางเวรมีการอัปเดต',
      'subtitle': repeatEnable
          ? 'มีการเพิ่มกะงานใหม่ (${targetDates.length} วัน)'
          : '${labelController.text.trim()} วันที่ ${_selectedDay.day}/${_selectedDay.month}',
      'category': 'notice',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // ยืนยันการบันทึกข้อมูลทั้งหมดลง Firestore
    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(repeatEnable
              ? "เพิ่มกะงานสั่งซ้ำเรียบร้อยแล้ว (${targetDates.length} วัน)"
              : "เพิ่มกะงานแล้ว"),
        ),
      );
    }
  }
}
