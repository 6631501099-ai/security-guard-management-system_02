import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'guard_nav_helper.dart';
import 'guard_theme.dart';
import 'guard_header.dart';
import 'guard_bottom_nav.dart';
import 'guard_location_service.dart';

/// Guard-side schedule: month strip + shifts for the selected day, read
/// live from the `schedules` collection that admin's Schedule section
/// (admin_schedule_screen.dart) writes to.
class GuardScheduleScreen extends StatefulWidget {
  const GuardScheduleScreen({super.key});

  @override
  State<GuardScheduleScreen> createState() => _GuardScheduleScreenState();
}

class _GuardScheduleScreenState extends State<GuardScheduleScreen> {
  final GuardLocationService _locationService = GuardLocationService();
  final User? _user = FirebaseAuth.instance.currentUser;

  int _navIndex = 1;
  late DateTime _selected;
  late DateTime _currentMonth;

  static const _thaiMonthsShort = [
    "ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.",
    "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค.",
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = DateTime(now.year, now.month, now.day);
    _currentMonth = DateTime(now.year, now.month);
  }

  String get _monthLabel {
    final buddhistYear = _currentMonth.year + 543;
    return "${_thaiMonthsShort[_currentMonth.month - 1]} $buddhistYear";
  }

  List<int> get _daysInMonth {
    final lastDay =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    return List.generate(lastDay, (i) => i + 1);
  }

  void _goToPreviousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _goToNextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GuardTheme.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const GuardHeader(
              title: "ตารางงาน",
              subtitle: "ตารางเวรของเจ้าหน้าที่",
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: _goToPreviousMonth,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text(_monthLabel,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        IconButton(
                          onPressed: _goToNextMonth,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 74,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _daysInMonth.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, i) {
                          final day = _daysInMonth[i];
                          final date = DateTime(
                              _currentMonth.year, _currentMonth.month, day);
                          final selected = date.year == _selected.year &&
                              date.month == _selected.month &&
                              date.day == _selected.day;
                          return GestureDetector(
                            onTap: () => setState(() => _selected = date),
                            child: Container(
                              width: 46,
                              decoration: BoxDecoration(
                                color: selected
                                    ? GuardTheme.primaryRed
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow:
                                    selected ? [] : [GuardTheme.softShadow],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "$day",
                                style: TextStyle(
                                  color:
                                      selected ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text("ตารางงานของเจ้าหน้าที่วันที่ ${_selected.day}",
                        style: GuardTheme.sectionTitle),
                    const SizedBox(height: 12),
                    if (_user == null)
                      const Text(
                        "กรุณาเข้าสู่ระบบ",
                        style: TextStyle(color: GuardTheme.textGrey),
                      )
                    else
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _locationService.watchScheduleForDay(
                          _user.uid,
                          _selected,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Text(
                              "โหลดตารางงานไม่สำเร็จ: ${snapshot.error}",
                              style: const TextStyle(color: GuardTheme.textGrey),
                            );
                          }
                          if (!snapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                  child: CircularProgressIndicator()),
                            );
                          }
                          final docs = snapshot.data!.docs;
                          if (docs.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                "ไม่มีกะงานสำหรับวันนี้",
                                style: TextStyle(color: GuardTheme.textGrey),
                              ),
                            );
                          }
                          return Column(
                            children: docs.map((doc) {
                              final data = doc.data();
                              return _shiftTile(
                                label: data['label'] ?? 'กะงาน',
                                timeRange:
                                    "${data['startTime'] ?? '-'} - ${data['endTime'] ?? '-'} น.",
                              );
                            }).toList(),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: GuardBottomNav(
        currentIndex: _navIndex,
        onTap: (i) {
          if (i == _navIndex) return;
          navigateToTab(context, i);
        },
      ),
    );
  }

  Widget _shiftTile({required String label, required String timeRange}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: GuardTheme.cardDecoration(radius: 16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: GuardTheme.primaryRed.withOpacity(0.1),
            child: const Icon(Icons.wb_sunny_outlined,
                color: GuardTheme.primaryRed, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(timeRange,
                    style: const TextStyle(
                        fontSize: 12, color: GuardTheme.textGrey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
