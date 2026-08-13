import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Guard/guard_theme.dart';
import '../Guard/guard_bottom_nav.dart';
import 'admin_guards_screen.dart';
import 'admin_full_map_screen.dart';
import 'admin_nav_helper.dart';

/// "รายชื่อเจ้าหน้าที่" — mobile-styled shell (red rounded header + white
/// body + shared bottom nav) wrapped around the existing [GuardsSection],
/// so the roster data/search/filter/detail-sheet logic stays exactly as
/// built for the desktop dashboard — only the frame changes to match the
/// Guard app's look.
class AdminGuardListScreen extends StatefulWidget {
  const AdminGuardListScreen({super.key});

  @override
  State<AdminGuardListScreen> createState() => _AdminGuardListScreenState();
}

class _AdminGuardListScreenState extends State<AdminGuardListScreen> {
  String _search = "";

  void _locate(LatLng location, String? label) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminFullMapScreen(
          markers: {
            Marker(
              markerId: MarkerId(label ?? 'guard'),
              position: location,
              infoWindow: InfoWindow(title: label ?? 'เจ้าหน้าที่'),
            ),
          },
        ),
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
            _buildHeader(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: GuardsSection(
                  search: _search,
                  onSearchChanged: (v) => setState(() => _search = v),
                  onLocate: _locate,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: GuardBottomNav(
        currentIndex: 1,
        labels: const ["หน้าหลัก", "เจ้าหน้าที่", "แจ้งเตือน", "แชท", "โปรไฟล์"],
        onTap: (i) {
          if (i == 1) return;
          navigateToAdminTab(context, i);
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
      decoration: const BoxDecoration(
        color: GuardTheme.primaryRed,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Text('ตรวจเช็คเจ้าหน้าที่', style: GuardTheme.screenTitle),
          ),
          Icon(Icons.groups_rounded, color: Colors.white),
        ],
      ),
    );
  }
}
