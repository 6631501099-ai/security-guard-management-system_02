import 'package:flutter/material.dart';
import '../chat/chat_list_screen.dart';
import '../Guard/manager_profile_screen.dart';
import 'admin_home_screen.dart';
import 'admin_guard_list_screen.dart';
import 'admin_alerts_screen.dart';

/// Central place that decides which screen each Admin bottom-nav tab
/// points to, so every Admin mobile screen's GuardBottomNav can share one
/// navigation behaviour. Index mapping matches the Guard nav exactly:
/// 0 = Home, 1 = Guards, 2 = Alerts (raised, red), 3 = Chat, 4 = Profile.
void navigateToAdminTab(BuildContext context, int index) {
  late final Widget target;
  switch (index) {
    case 0:
      target = const AdminHomeScreen();
      break;
    case 1:
      target = const AdminGuardListScreen();
      break;
    case 2:
      target = const AdminAlertsScreen();
      break;
    case 3:
      target = const ChatListScreen();
      break;
    case 4:
default:
  target = const ManagerProfileScreen(onNavTap: navigateToAdminTab);
  break;
  }
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (_) => target),
  );
}
