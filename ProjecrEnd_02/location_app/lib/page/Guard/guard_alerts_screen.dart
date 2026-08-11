import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'guard_nav_helper.dart';
import 'guard_theme.dart';
import 'guard_header.dart';
import 'guard_bottom_nav.dart';
import 'guard_location_service.dart';

/// 'emergency' shows up under the "แจ้ง" tab (things needing your
/// attention) alongside 'notice'; 'system' shows up under "อื่นๆ"
/// (informational/completed).
enum AlertCategory { emergency, notice, system }

AlertCategory _categoryFromString(String? raw) {
  switch (raw) {
    case 'emergency':
      return AlertCategory.emergency;
    case 'system':
      return AlertCategory.system;
    default:
      return AlertCategory.notice;
  }
}

/// Live feed of alerts targeted at this guard, read from the
/// `notifications` collection. Entries are written by admin actions —
/// accepting an SOS (admin_guard_actions.dart's acceptSos), assigning a
/// task or shift (admin_tasks_screen.dart / admin_schedule_screen.dart) —
/// so this screen reflects real events instead of sample data.
class GuardAlertsScreen extends StatefulWidget {
  const GuardAlertsScreen({super.key});

  @override
  State<GuardAlertsScreen> createState() => _GuardAlertsScreenState();
}

class _GuardAlertsScreenState extends State<GuardAlertsScreen>
    with SingleTickerProviderStateMixin {
  final GuardLocationService _locationService = GuardLocationService();
  final User? _user = FirebaseAuth.instance.currentUser;
  int _navIndex = 2;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
              title: "การแจ้งเตือนและเหตุฉุกเฉิน",
              showBack: true,
            ),
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: GuardTheme.primaryRed,
                unselectedLabelColor: GuardTheme.textGrey,
                indicatorColor: GuardTheme.primaryRed,
                tabs: const [
                  Tab(text: "ทั้งหมด"),
                  Tab(text: "แจ้ง"),
                  Tab(text: "อื่นๆ"),
                ],
              ),
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
                      stream: _locationService.watchMyAlerts(_user.uid),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              "โหลดการแจ้งเตือนไม่สำเร็จ: ${snapshot.error}",
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
                        return TabBarView(
                          controller: _tabController,
                          children: [
                            _buildList(docs),
                            _buildList(docs
                                .where((d) =>
                                    _categoryFromString(
                                        d.data()['category']) !=
                                    AlertCategory.system)
                                .toList()),
                            _buildList(docs
                                .where((d) =>
                                    _categoryFromString(
                                        d.data()['category']) ==
                                    AlertCategory.system)
                                .toList()),
                          ],
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

  Widget _buildList(List<QueryDocumentSnapshot<Map<String, dynamic>>> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          "ไม่มีการแจ้งเตือนในหมวดนี้",
          style: TextStyle(color: GuardTheme.textGrey),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, i) => _alertTile(items[i].data()),
    );
  }

  Widget _alertTile(Map<String, dynamic> data) {
    final category = _categoryFromString(data['category']);
    final (icon, color) = switch (category) {
      AlertCategory.emergency => (
          Icons.warning_amber_rounded,
          GuardTheme.primaryRed
        ),
      AlertCategory.notice => (
          Icons.notifications_active_outlined,
          GuardTheme.orange
        ),
      AlertCategory.system => (Icons.check_circle_outline, GuardTheme.green),
    };
    final ts = data['timestamp'] as Timestamp?;
    final timeLabel = ts == null ? '' : _relativeTime(ts.toDate());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: GuardTheme.cardDecoration(radius: 16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['title'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(data['subtitle'] ?? '',
                    style: const TextStyle(
                        fontSize: 12, color: GuardTheme.textGrey)),
              ],
            ),
          ),
          Text(timeLabel,
              style: const TextStyle(fontSize: 11, color: GuardTheme.textGrey)),
        ],
      ),
    );
  }

  String _relativeTime(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return "เมื่อสักครู่";
    if (diff.inMinutes < 60) return "${diff.inMinutes} นาทีที่แล้ว";
    if (diff.inHours < 24) return "${diff.inHours} ชม.ที่แล้ว";
    return "${diff.inDays} วันที่แล้ว";
  }
}
