import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Guard/guard_theme.dart';
import '../Guard/guard_bottom_nav.dart';
import 'admin_sos_screen.dart';
import 'admin_full_map_screen.dart';
import 'admin_nav_helper.dart';

/// "แจ้งเตือนความปลอดภัย" — mobile-styled shell (red rounded header + white
/// body + shared bottom nav) wrapped around the existing [SosSection], so
/// every pending/accepted SOS alert, the locate/accept actions, and the
/// detail sheet keep working exactly as already built for the desktop
/// dashboard — only the frame changes to match the Guard app's look.
/// Reached from the raised, red center icon of [GuardBottomNav], the same
/// spot the Guard app uses for its own SOS action.
class AdminAlertsScreen extends StatelessWidget {
  const AdminAlertsScreen({super.key});

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
                child: SosSection(
                  onLocate: (LatLng location, String? label) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AdminFullMapScreen(
                          markers: {
                            Marker(
                              markerId: MarkerId(label ?? 'sos'),
                              position: location,
                              infoWindow: InfoWindow(title: label ?? 'SOS'),
                            ),
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: GuardBottomNav(
        currentIndex: 2,
        labels: const ["หน้าหลัก", "เจ้าหน้าที่", "แจ้งเตือน", "แชท", "โปรไฟล์"],
        onTap: (i) {
          if (i == 2) return;
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
            child: Text('แจ้งเตือนความปลอดภัย', style: GuardTheme.screenTitle),
          ),
          Icon(Icons.warning_amber_rounded, color: Colors.white),
        ],
      ),
    );
  }
}
