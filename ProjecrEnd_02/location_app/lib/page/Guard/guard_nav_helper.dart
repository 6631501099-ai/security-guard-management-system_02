import 'package:flutter/material.dart';
import 'package:location_app/page/chat/chat_list_screen.dart';
import 'guard_dashboard_screen.dart';
import 'guard_tasks_screen.dart';
import 'sos_emergency_screen.dart';
import 'manager_profile_screen.dart';

/// Central place that decides which screen each bottom-nav tab points to,
/// so every screen's GuardBottomNav can share one navigation behaviour.
///
/// Index mapping (must match GuardBottomNav's labels list exactly):
///   0 = หน้าหลัก (Home)   1 = ภารกิจ (Tasks)   2 = SOS (center button)
///   3 = แชท (Chat)        4 = โปรไฟล์ (Profile)
void navigateToTab(BuildContext context, int index) {
  late final Widget target;
  switch (index) {
    case 0:
      target = const GuardDashboardScreen();
      break;
    case 1:
      target = const GuardTasksScreen();
      break;
    case 2:
      // Was pointing at GuardAlertsScreen — a leftover from before the
      // bottom nav was redesigned to put "SOS" (not "แจ้งเตือน") as the
      // raised center button. That made the SOS button silently open the
      // Alerts screen instead of actually sending an SOS.
      target = const SosEmergencyScreen();
      break;
    case 3:
      target = const ChatListScreen();
      break;
    case 4:
      target = const ManagerProfileScreen();
      break;
    default:
      target = const GuardDashboardScreen();
  }
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (_) => target),
  );
}
