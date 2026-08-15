import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin/admin_home_screen.dart';
import 'login_page.dart';
import 'Guard/guard_dashboard_screen.dart';

////////////////////////////////////////////////////////////
/// AUTH CHECK
////////////////////////////////////////////////////////////

class RoleGuard {
  static bool isAdminRole(dynamic roleValue) {
    final normalized = (roleValue ?? 'guard').toString().trim().toLowerCase();
    return normalized == 'admin' ||
        normalized == 'super_admin' ||
        normalized == 'manager';
  }

  static Future<String> getCurrentRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'guard';

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data() ?? const <String, dynamic>{};
    return (data['role'] ?? 'guard').toString().trim().toLowerCase();
  }

  static Future<void> redirectToRoleHome(BuildContext context) async {
    final role = await getCurrentRole();
    final target = isAdminRole(role)
        ? const AdminHomeScreen()
        : const GuardDashboardScreen();

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => target),
      (route) => false,
    );
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const RoleCheck();
        }

        return const LoginPage();
      },
    );
  }
}

////////////////////////////////////////////////////////////
/// ROLE CHECK
////////////////////////////////////////////////////////////

class RoleCheck extends StatelessWidget {
  const RoleCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const LoginPage();
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!.data() ?? const <String, dynamic>{};
        final role = data['role'] ?? 'guard';

        if (RoleGuard.isAdminRole(role)) {
          return const AdminHomeScreen();
        }

        final guardName = (data['name'] as String?) ?? 'เจ้าหน้าที่';
        return GuardDashboardScreen(guardName: guardName);
      },
    );
  }
}
