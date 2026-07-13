import 'package:flutter/material.dart';
import 'guard_nav_helper.dart';
import 'guard_theme.dart';
import 'guard_header.dart';
import 'guard_bottom_nav.dart';

class AlertEntry {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String time;

  const AlertEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.time,
  });
}

class GuardAlertsScreen extends StatefulWidget {
  const GuardAlertsScreen({super.key});

  @override
  State<GuardAlertsScreen> createState() => _GuardAlertsScreenState();
}

class _GuardAlertsScreenState extends State<GuardAlertsScreen>
    with SingleTickerProviderStateMixin {
  int _navIndex = 2;
  late final TabController _tabController;

  final List<AlertEntry> _all = const [
    AlertEntry(
      title: "แจ้งเตือนฉุกเฉิน - จุด S1",
      subtitle: "ส่งสัญญาณ SOS แล้ว",
      icon: Icons.warning_amber_rounded,
      color: GuardTheme.primaryRed,
      time: "2 นาทีที่แล้ว",
    ),
    AlertEntry(
      title: "จำเป็นการเปลี่ยนเวร",
      subtitle: "เวรของคุณเปลี่ยนเป็น 15 น.",
      icon: Icons.swap_horiz,
      color: Colors.blueAccent,
      time: "35 นาทีที่แล้ว",
    ),
    AlertEntry(
      title: "เพื่อการทำงาน",
      subtitle: "ระบบแจ้งเตือนก่อนเข้ากะ",
      icon: Icons.notifications_active_outlined,
      color: GuardTheme.orange,
      time: "1 ชม.ที่แล้ว",
    ),
    AlertEntry(
      title: "ดูแลระบบความปลอดภัย",
      subtitle: "เรียบร้อยแล้ว",
      icon: Icons.check_circle_outline,
      color: GuardTheme.green,
      time: "เมื่อวาน",
    ),
  ];

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
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _all.length,
                itemBuilder: (context, i) => _alertTile(_all[i]),
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

  Widget _alertTile(AlertEntry alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: GuardTheme.cardDecoration(radius: 16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: alert.color.withOpacity(0.12),
            child: Icon(alert.icon, color: alert.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(alert.subtitle,
                    style: const TextStyle(fontSize: 12, color: GuardTheme.textGrey)),
              ],
            ),
          ),
          Text(alert.time,
              style: const TextStyle(fontSize: 11, color: GuardTheme.textGrey)),
        ],
      ),
    );
  }
}
