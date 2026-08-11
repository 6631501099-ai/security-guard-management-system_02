import 'package:cloud_firestore/cloud_firestore.dart';
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

/// Maps the `iconKey` string stored on each activity-log entry to an
/// actual icon/color pair for display. Keep this in sync with the
/// `iconKey` values GuardLocationService.logActivity is called with
/// ('checkin', 'checkout', 'task', 'incident', 'sos', ...).
const Map<String, ({IconData icon, Color color})> _activityIcons = {
  'checkin': (icon: Icons.login, color: GuardTheme.primaryRed),
  'checkout': (icon: Icons.logout, color: GuardTheme.textGrey),
  'task': (icon: Icons.verified_user, color: GuardTheme.green),
  'incident': (icon: Icons.description, color: GuardTheme.orange),
  'sos': (icon: Icons.warning_amber_rounded, color: GuardTheme.primaryRed),
};

class _GuardDashboardScreenState extends State<GuardDashboardScreen> {
  final GuardLocationService _locationService = GuardLocationService();
  final User? _user = FirebaseAuth.instance.currentUser;
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
                    _buildActivitySection(),
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

  Widget _buildActivitySection() {
    if (_user == null) {
      return const Text("กรุณาเข้าสู่ระบบ", style: TextStyle(color: GuardTheme.textGrey));
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _locationService.watchRecentActivity(_user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            "โหลดกิจกรรมไม่สำเร็จ: ${snapshot.error}",
            style: const TextStyle(color: GuardTheme.textGrey),
          );
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              "ยังไม่มีกิจกรรมล่าสุด — เริ่มเข้างานหรือส่งรายงานเพื่อดูที่นี่",
              style: TextStyle(color: GuardTheme.textGrey),
            ),
          );
        }
        return Column(children: docs.map(_activityTile).toList());
      },
    );
  }

  Widget _activityTile(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final style = _activityIcons[data['iconKey']] ??
        (icon: Icons.notifications_none, color: GuardTheme.textGrey);
    final ts = data['timestamp'] as Timestamp?;
    final timeLabel = ts == null ? '' : _formatClock(ts.toDate());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: GuardTheme.cardDecoration(radius: 16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: style.color.withOpacity(0.12),
            child: Icon(style.icon, color: style.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['title'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  data['subtitle'] ?? '',
                  style: const TextStyle(
                      fontSize: 12, color: GuardTheme.textGrey),
                ),
              ],
            ),
          ),
          Text(timeLabel,
              style: const TextStyle(fontSize: 12, color: GuardTheme.textGrey)),
        ],
      ),
    );
  }

  String _formatClock(DateTime d) =>
      "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} น.";

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
    return LayoutBuilder(
      builder: (context, constraints) {
        const crossAxisCount = 2;
        const spacing = 14.0;
        const tileHeight = 108.0; // fixed, proportional card height
        final tileWidth = (constraints.maxWidth - spacing) / crossAxisCount;
        final aspectRatio = tileWidth / tileHeight;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: aspectRatio,
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
      },
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
}
