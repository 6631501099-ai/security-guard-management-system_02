import 'package:flutter/material.dart';
import 'guard_dashboard_screen.dart';
import 'guard_tasks_screen.dart';
import 'guard_alerts_screen.dart';
import 'manager_profile_screen.dart';

/// Central place that decides which screen each bottom-nav tab points to,
/// so every screen's GuardBottomNav can share one navigation behaviour.
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
      target = const GuardAlertsScreen();
      break;
    case 3:
    default:
      target = const ManagerProfileScreen();
      break;
  }
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (_) => target),
  );
}
