import 'package:flutter/material.dart';
import '../Guard/guard_theme.dart';

/// Small reusable "pushed" mobile page: red rounded header with a back
/// button + title, white scrollable body underneath. Used to host the
/// existing desktop-built admin sections (Schedule, Tasks, Incidents,
/// Logs, ...) inside the new mobile navigation without rewriting their
/// Firestore logic — only the frame around them changes.
class AdminSectionPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const AdminSectionPage({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GuardTheme.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(8, 10, 20, 22),
              decoration: const BoxDecoration(
                color: GuardTheme.primaryRed,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(title, style: GuardTheme.screenTitle),
                  ),
                  Icon(icon, color: Colors.white),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
