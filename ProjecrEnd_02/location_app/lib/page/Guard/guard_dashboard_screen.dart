import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'guard_location_service.dart';
import 'guard_nav_helper.dart';
import 'guard_theme.dart';
import 'guard_bottom_nav.dart';
import 'guard_sos_sheet.dart';
import 'checkin_checkout_screen.dart';
import 'guard_schedule_screen.dart';
import 'incident_report_screen.dart';
import 'sos_emergency_screen.dart';

class GuardDashboardScreen extends StatefulWidget {
  final String guardName;

  const GuardDashboardScreen({super.key, this.guardName = "เจ้าหน้าที่"});

  @override
  State<GuardDashboardScreen> createState() => _GuardDashboardScreenState();
}

class _GuardDashboardScreenState extends State<GuardDashboardScreen> {
  final GuardLocationService _locationService = GuardLocationService();
  int _navIndex = 0;
  late String _displayName = widget.guardName;
  final TextEditingController _sosController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadRealName();
  }

  @override
  void dispose() {
    _sosController.dispose();
    super.dispose();
  }

  Future<void> _loadRealName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final name = await _locationService.fetchUserName(user.uid);
    if (mounted) setState(() => _displayName = name);
  }

  void _openSosComposer() {
    showGuardSosSheet(
      context: context,
      controller: _sosController,
      onSend: () async {
        final message = _sosController.text.trim();
        _sosController.clear();
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SosEmergencyScreen(
              initialMessage: message.isEmpty ? null : message,
            ),
          ),
        );
      },
    );
  }

  final List<_ActivityItem> _activities = const [
    _ActivityItem(
      icon: Icons.verified_user,
      iconColor: GuardTheme.green,
      title: "ตรวจสอบจุด",
      subtitle: "Verified security point at S1 Building",
      time: "08:45 น.",
    ),
    _ActivityItem(
      icon: Icons.gps_fixed,
      iconColor: GuardTheme.orange,
      title: "ตรวจสอบตำแหน่ง",
      subtitle: "Status confirmed with Control Center",
      time: "08:12 น.",
    ),
    _ActivityItem(
      icon: Icons.login,
      iconColor: GuardTheme.primaryRed,
      title: "เข้างาน",
      subtitle: "Duty commenced at Main gate",
      time: "07:00 น.",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GuardTheme.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildActionGrid(context),
                    const SizedBox(height: 24),
                    const Text("กิจกรรมล่าสุด", style: GuardTheme.sectionTitle),
                    const SizedBox(height: 12),
                    ..._activities.map(_buildActivityTile),
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

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 26),
      decoration: const BoxDecoration(
        color: GuardTheme.primaryRed,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(_displayName, style: GuardTheme.screenTitle),
          ),
          Stack(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: GuardTheme.primaryRed),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: GuardTheme.green,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.3,
      children: [
        _actionCard(
          icon: Icons.access_time,
          label: "การเข้างาน",
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CheckInOutScreen()),
          ),
        ),
        _actionCard(
          icon: Icons.calendar_month,
          label: "ตารางงาน",
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const GuardScheduleScreen()),
          ),
        ),
        _actionCard(
          icon: Icons.description,
          label: "รายงาน",
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const IncidentReportScreen()),
          ),
        ),
        _actionCard(
          icon: Icons.warning_amber_rounded,
          label: "SOS",
          onTap: _openSosComposer,
          isAlert: true,
        ),
      ],
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isAlert = false,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isAlert ? GuardTheme.primaryRed : GuardTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [GuardTheme.softShadow],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: isAlert ? Colors.white : GuardTheme.primaryRed),
            const Spacer(),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isAlert ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTile(_ActivityItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: GuardTheme.cardDecoration(radius: 16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: item.iconColor.withOpacity(0.12),
            child: Icon(item.icon, color: item.iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: GuardTheme.textGrey),
                ),
              ],
            ),
          ),
          Text(item.time,
              style: const TextStyle(fontSize: 12, color: GuardTheme.textGrey)),
        ],
      ),
    );
  }
}

class _ActivityItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;

  const _ActivityItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
  });
}
