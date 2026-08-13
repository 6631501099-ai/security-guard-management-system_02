import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Guard/guard_theme.dart';
import '../Guard/guard_bottom_nav.dart';
import '../Guard/guard_stat_card.dart';
import '../Guard/guard_location_service.dart';
import 'admin_full_map_screen.dart';
import 'admin_nav_helper.dart';
import 'admin_section_page.dart';
import 'admin_schedule_screen.dart';
import 'admin_tasks_screen.dart';
import 'admin_incidents_screen.dart';
import 'admin_logs_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final GuardLocationService _locationService = GuardLocationService();
  String _displayName = "ผู้ดูแลระบบ";

  @override
  void initState() {
    super.initState();
    _loadRealName();
  }

  Future<void> _loadRealName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final name = await _locationService.fetchUserName(user.uid);
    if (mounted && name != "เจ้าหน้าที่") setState(() => _displayName = name);
  }

  void _openFullMap() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('locations').get();
    final markers = <Marker>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final lastUpdate = data['lastUpdate'];
      if (lastUpdate == null) continue;
      final diff = DateTime.now()
          .difference((lastUpdate as Timestamp).toDate())
          .inSeconds;
      if (diff > 60) continue;
      final lat = data['lat'];
      final lng = data['lng'];
      if (lat == null || lng == null) continue;
      markers.add(
        Marker(
          markerId: MarkerId(doc.id),
          position: LatLng((lat as num).toDouble(), (lng as num).toDouble()),
          infoWindow: InfoWindow(title: data['name'] ?? data['email'] ?? ''),
        ),
      );
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AdminFullMapScreen(markers: markers)),
    );
  }

  void _openSection(String title, IconData icon, Widget child) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminSectionPage(title: title, icon: icon, child: child),
      ),
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
            // 1. ส่วน Header สีแดง + กล่อง 3 อัน ซ้อนคาบเกี่ยวกัน (Stack)
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                // แถบสีแดงอยู่ด้านบนสุดและเพิ่มความยาวลงมา
                _buildHeader(),

                // กล่อง 3 อันถูกขยับมาวางเหลื่อมทับขอบล่างของแถบสีแดง
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: -55, // ดึงกล่องลงมาทับขอบล่างของแถบสีแดง
                  child: _buildStatRow(),
                ),
              ],
            ),
            
            // ระยะเว้นเผื่อความสูงของ StatRow ที่ล้นลงมาด้านล่าง
            const SizedBox(height: 65),

            // 2. ส่วนเนื้อหาที่ Scroll ได้
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("เมนูช่วยเหลือ", style: GuardTheme.sectionTitle),
                    const SizedBox(height: 12),
                    _buildActionGrid(),
                    const SizedBox(height: 24),
                    const Text("การแจ้งเตือนล่าสุด", style: GuardTheme.sectionTitle),
                    const SizedBox(height: 12),
                    _buildRecentAlerts(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      
      // 3. ส่วน Bottom Navigation Bar
      bottomNavigationBar: GuardBottomNav(
        currentIndex: 0,
        labels: const ["หน้าหลัก", "เจ้าหน้าที่", "แจ้งเตือน", "แชท", "โปรไฟล์"],
        onTap: (i) {
          if (i == 0) return;
          navigateToAdminTab(context, i);
        },
      ),
    );
  }

  // แถบสีแดงด้านบนสุด
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      // เพิ่ม Padding ด้านล่าง (60) เพื่อเพิ่มความยาวลงมา ให้รองรับกล่องสถิติที่จะซ้อนทับ
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 60), 
      decoration: const BoxDecoration(
        color: GuardTheme.primaryRed,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_displayName, style: GuardTheme.screenTitle),
                const SizedBox(height: 4),
                const Text(
                  "ผู้ดูแลระบบ • Head of Operations",
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const Stack(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: GuardTheme.primaryRed),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: _OnlineDot(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // กล่อง 3 อัน ( Stat Cards )
  Widget _buildStatRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('locations').snapshots(),
      builder: (context, locSnap) {
        int onlineCount = 0;
        int outOfScopeCount = 0;
        if (locSnap.hasData) {
          for (final doc in locSnap.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final lastUpdate = data['lastUpdate'];
            if (lastUpdate == null) continue;
            final diff = DateTime.now()
                .difference((lastUpdate as Timestamp).toDate())
                .inSeconds;
            if (diff <= 60) {
              onlineCount++;
              if (data['outOfScope'] == true) outOfScopeCount++;
            }
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('sos')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, sosSnap) {
            final pending = sosSnap.data?.docs.length ?? 0;
            return Row(
              children: [
                Expanded(
                  child: GuardStatCard(
                    icon: Icons.verified_user,
                    title: "ปฏิบัติหน้าที่",
                    value: "$onlineCount",
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GuardStatCard(
                    icon: Icons.warning_amber_rounded,
                    title: "นอกพื้นที่",
                    value: "$outOfScopeCount",
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GuardStatCard(
                    icon: Icons.report_problem,
                    title: "SOS ค้างอยู่",
                    value: "$pending",
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildActionGrid() {
    final actions = <_ActionData>[
      _ActionData(Icons.groups_rounded, "ตรวจเช็คเจ้าหน้าที่",
          () => navigateToAdminTab(context, 1)),
      _ActionData(Icons.warning_amber_rounded, "แจ้งเตือนความปลอดภัย",
          () => navigateToAdminTab(context, 2)),
      _ActionData(Icons.map_rounded, "แผนที่ตำแหน่งเรียลไทม์", _openFullMap),
      _ActionData(
        Icons.calendar_month_rounded,
        "ตารางเวรยาม",
        () => _openSection("ตารางเวรยาม", Icons.calendar_month_rounded,
            const AdminScheduleSection()),
      ),
      _ActionData(
        Icons.assignment_turned_in_rounded,
        "มอบหมายงานใหม่",
        () => _openSection("มอบหมายงานใหม่", Icons.assignment_turned_in_rounded,
            const AdminTasksSection()),
      ),
      _ActionData(
        Icons.fact_check_rounded,
        "คลังรายงานเหตุการณ์",
        () => _openSection("คลังรายงานเหตุการณ์", Icons.fact_check_rounded,
            const AdminIncidentsSection()),
      ),
      _ActionData(
        Icons.history_rounded,
        "ประวัติการทำงาน",
        () => _openSection(
            "ประวัติการทำงาน", Icons.history_rounded, const LogsSection()),
      ),
    ];

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.95,
      children: actions.map((a) => _actionTile(a)).toList(),
    );
  }

  // 7 กล่องสีแดงเลือดหมู + ไอคอนสีทอง
  Widget _actionTile(_ActionData a) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: a.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF800000), // สีแดงเลือดหมู (Maroon)
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(a.icon, color: const Color(0xFFFFD700), size: 22), // ไอคอนสีทอง (Gold)
            const SizedBox(height: 8),
            Text(
              a.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10, 
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAlerts() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sos')
          .orderBy('timestamp', descending: true)
          .limit(4)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: GuardTheme.cardDecoration(radius: 16),
            child: const Text(
              "ยังไม่มีการแจ้งเตือน",
              style: TextStyle(color: GuardTheme.textGrey),
            ),
          );
        }
        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = (data['status'] ?? 'pending').toString();
            final isPending = status == 'pending';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: GuardTheme.cardDecoration(radius: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: isPending ? GuardTheme.primaryRed : GuardTheme.green,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (data['name'] ?? data['email'] ?? 'เจ้าหน้าที่')
                              .toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          (data['message'] ?? '').toString().isEmpty
                              ? (isPending ? 'รอตรวจสอบ' : 'รับเรื่องแล้ว')
                              : data['message'].toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: GuardTheme.textGrey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right,
                        color: GuardTheme.textGrey),
                    onPressed: () => navigateToAdminTab(context, 2),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ActionData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  _ActionData(this.icon, this.label, this.onTap);
}

class _OnlineDot extends StatelessWidget {
  const _OnlineDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: GuardTheme.green,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}