import 'package:flutter/material.dart';
import 'guard_nav_helper.dart';
import 'guard_theme.dart';
import 'guard_header.dart';
import 'guard_bottom_nav.dart';

class TaskEntry {
  final String title;
  final String timeRange;
  final bool done;

  const TaskEntry({required this.title, required this.timeRange, this.done = false});
}

class GuardTasksScreen extends StatefulWidget {
  final int remainingTasks;
  final double progress;
  final List<TaskEntry> tasks;

  const GuardTasksScreen({
    super.key,
    this.remainingTasks = 4,
    this.progress = 0.35,
    this.tasks = const [
      TaskEntry(title: "ตรวจตราอาคาร C", timeRange: "13.30 - 14.00 น."),
      TaskEntry(title: "พักกลางวัน", timeRange: "11.00 - 12.00 น."),
      TaskEntry(title: "ตรวจสอบผู้เยี่ยมชมออกกิจ", timeRange: "11.30 - 12.00 น."),
      TaskEntry(title: "ตรวจสอบบทพากย", timeRange: "13.30 - 14.00 น.", done: true),
    ],
  });

  @override
  State<GuardTasksScreen> createState() => _GuardTasksScreenState();
}

class _GuardTasksScreenState extends State<GuardTasksScreen> {
  int _navIndex = 1;
  late List<bool> _doneFlags;

  @override
  void initState() {
    super.initState();
    _doneFlags = widget.tasks.map((t) => t.done).toList();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _doneFlags.where((d) => !d).length;

    return Scaffold(
      backgroundColor: GuardTheme.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const GuardHeader(
              title: "หน้าที่วันนี้",
              subtitle: "งานที่ต้องดำเนินการวันนี้",
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: GuardTheme.cardDecoration(radius: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                    GuardTheme.primaryRed.withOpacity(0.1),
                                child: Text(
                                  "$remaining",
                                  style: const TextStyle(
                                    color: GuardTheme.primaryRed,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text("หน้าที่เหลือวันนี้",
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value:
                                  1 - (remaining / widget.tasks.length),
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade200,
                              color: GuardTheme.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text("คำสั่งดำเนินการ", style: GuardTheme.sectionTitle),
                    const SizedBox(height: 12),
                    ...List.generate(
                      widget.tasks.length,
                      (i) => _taskTile(i, widget.tasks[i]),
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

  Widget _taskTile(int index, TaskEntry task) {
    final done = _doneFlags[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: GuardTheme.cardDecoration(radius: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 14, color: GuardTheme.textGrey),
                    const SizedBox(width: 4),
                    Text(task.timeRange,
                        style: const TextStyle(
                            fontSize: 12, color: GuardTheme.textGrey)),
                  ],
                ),
              ],
            ),
          ),
          if (done)
            const Icon(Icons.check_circle, color: GuardTheme.green)
          else
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: GuardTheme.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => setState(() => _doneFlags[index] = true),
              child: const Text("เริ่มดำเนินการ", style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
