import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../admin_dashboard.dart';
import 'login_page.dart';
import 'Guard/guard_dashboard_screen.dart';

////////////////////////////////////////////////////////////
/// AUTH CHECK
////////////////////////////////////////////////////////////

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

    return FutureBuilder<DocumentSnapshot>(
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

        final data = snapshot.data!.data() as Map<String, dynamic>?;

        final role = data?['role'] ?? 'guard';

        if (role == "admin") {
          return const AdminDashboard();
        }

        final guardName = data?['name'] as String? ?? "เจ้าหน้าที่";

        return GuardDashboardScreen(guardName: guardName);
      },
    );
  }
}
