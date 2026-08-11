import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'guard_nav_helper.dart';
import 'guard_theme.dart';
import 'guard_header.dart';
import 'guard_bottom_nav.dart';
import 'guard_location_service.dart';

/// Guard-side "หน้าที่วันนี้" list, read live from the `tasks` collection
/// that admin's Task Assignment section (admin_tasks_screen.dart) writes
/// to. Tapping "เริ่มดำเนินการ" marks the task done in Firestore.
class GuardTasksScreen extends StatefulWidget {
  const GuardTasksScreen({super.key});

  @override
  State<GuardTasksScreen> createState() => _GuardTasksScreenState();
}

class _GuardTasksScreenState extends State<GuardTasksScreen> {
  final GuardLocationService _locationService = GuardLocationService();
  final User? _user = FirebaseAuth.instance.currentUser;
  int _navIndex = 1;
  final Set<String> _completing = {};

  Future<void> _complete(String taskId, String title) async {
    if (_user == null || _completing.contains(taskId)) return;
    setState(() => _completing.add(taskId));
    try {
      await _locationService.completeTask(
        taskId: taskId,
        uid: _user.uid,
        taskTitle: title,
      );
    } finally {
      if (mounted) setState(() => _completing.remove(taskId));
    }
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
              title: "หน้าที่วันนี้",
              subtitle: "งานที่ต้องดำเนินการวันนี้",
            ),
            Expanded(
              child: _user == null
                  ? const Center(
                      child: Text(
                        "กรุณาเข้าสู่ระบบ",
                        style: TextStyle(color: GuardTheme.textGrey),
                      ),
                    )
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _locationService.watchMyTasks(_user.uid),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              "โหลดรายการงานไม่สำเร็จ: ${snapshot.error}",
                              style:
                                  const TextStyle(color: GuardTheme.textGrey),
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final docs = snapshot.data!.docs;
                        final remaining =
                            docs.where((d) => d.data()['done'] != true).length;
                        final progress =
                            docs.isEmpty ? 0.0 : 1 - (remaining / docs.length);

                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration:
                                    GuardTheme.cardDecoration(radius: 20),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: GuardTheme
                                              .primaryRed
                                              .withOpacity(0.1),
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
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        value: progress.clamp(0.0, 1.0),
                                        minHeight: 8,
                                        backgroundColor: Colors.grey.shade200,
                                        color: GuardTheme.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 22),
                              const Text("คำสั่งดำเนินการ",
                                  style: GuardTheme.sectionTitle),
                              const SizedBox(height: 12),
                              if (docs.isEmpty)
                                const Padding(
                                  padding:
                                      EdgeInsets.symmetric(vertical: 16),
                                  child: Text(
                                    "วันนี้ยังไม่มีงานที่ได้รับมอบหมาย",
                                    style:
                                        TextStyle(color: GuardTheme.textGrey),
                                  ),
                                )
                              else
                                ...docs.map((doc) => _taskTile(doc)),
                            ],
                          ),
                        );
                      },
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

  Widget _taskTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final done = data['done'] == true;
    final busy = _completing.contains(doc.id);
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
                Text(data['title'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 14, color: GuardTheme.textGrey),
                    const SizedBox(width: 4),
                    Text(data['timeRange'] ?? '',
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
              onPressed:
                  busy ? null : () => _complete(doc.id, data['title'] ?? ''),
              child: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text("เริ่มดำเนินการ", style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
