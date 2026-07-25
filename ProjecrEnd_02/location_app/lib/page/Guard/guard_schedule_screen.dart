import 'package:flutter/material.dart';
import 'guard_nav_helper.dart';
import 'guard_theme.dart';
import 'guard_header.dart';
import 'guard_bottom_nav.dart';

class ShiftEntry {
  final String label;
  final String timeRange;
  final IconData icon;

  const ShiftEntry({required this.label, required this.timeRange, required this.icon});
}

class GuardScheduleScreen extends StatefulWidget {
  final String monthLabel;
  final List<int> visibleDays;
  final int selectedDay;
  final List<ShiftEntry> shifts;

  const GuardScheduleScreen({
    super.key,
    this.monthLabel = "พ.ค. 2569",
    this.visibleDays = const [13, 14, 15, 16, 17, 18, 19],
    this.selectedDay = 15,
    this.shifts = const [
      ShiftEntry(label: "กะ S1", timeRange: "08:00 น. - 16:00 น.", icon: Icons.wb_sunny_outlined),
      ShiftEntry(label: "พักกลางวัน", timeRange: "11:00 น. - 12:00 น.", icon: Icons.restaurant_outlined),
      ShiftEntry(label: "กะ S1", timeRange: "12:00 น. - 16:00 น.", icon: Icons.wb_sunny_outlined),
    ],
  });

  @override
  State<GuardScheduleScreen> createState() => _GuardScheduleScreenState();
}

class _GuardScheduleScreenState extends State<GuardScheduleScreen> {
  int _navIndex = 1;
  late int _selected;
  late DateTime _currentMonth;

  static const _thaiMonthsShort = [
    "ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.",
    "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค.",
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedDay;
    // The default sample data represents "พ.ค. 2569" (May, Buddhist year
    // 2569) = May 2026 in the Gregorian calendar used internally.
    _currentMonth = DateTime(2026, 5);
  }

  String get _monthLabel {
    final buddhistYear = _currentMonth.year + 543;
    return "${_thaiMonthsShort[_currentMonth.month - 1]} $buddhistYear";
  }

  List<int> get _daysInMonth {
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    return List.generate(lastDay, (i) => i + 1);
  }

  void _goToPreviousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _selected = _selected.clamp(1, _daysInMonth.length);
    });
  }

  void _goToNextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      _selected = _selected.clamp(1, _daysInMonth.length);
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
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, i) {
                          final day = _daysInMonth[i];
                          final selected = day == _selected;
                          return GestureDetector(
                            onTap: () => setState(() => _selected = day),
                            child: Container(
                              width: 46,
                              decoration: BoxDecoration(
                                color: selected
                                    ? GuardTheme.primaryRed
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: selected ? [] : [GuardTheme.softShadow],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                "$day",
                                style: TextStyle(
                                  color: selected ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text("ตารางงานของเจ้าหน้าที่วันที่ $_selected",
                        style: GuardTheme.sectionTitle),
                    const SizedBox(height: 12),
                    ...widget.shifts.map(_shiftTile),
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

  Widget _shiftTile(ShiftEntry shift) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: GuardTheme.cardDecoration(radius: 16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: GuardTheme.primaryRed.withOpacity(0.1),
            child: Icon(shift.icon, color: GuardTheme.primaryRed, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shift.label,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(shift.timeRange,
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
