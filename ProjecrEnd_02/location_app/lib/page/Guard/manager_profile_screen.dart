import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'guard_nav_helper.dart';
import 'guard_theme.dart';
import 'guard_bottom_nav.dart';
import '../auth_check.dart';

class ManagerProfileScreen extends StatefulWidget {
  final String? name;
  final String? email;
  final String? phone;
  final String badgeId;
  final VoidCallback? onLogout;

  const ManagerProfileScreen({
    super.key,
    this.name,
    this.email,
    this.phone,
    this.badgeId = "-",
    this.onLogout,
  });

  @override
  State<ManagerProfileScreen> createState() => _ManagerProfileScreenState();
}

class _ManagerProfileScreenState extends State<ManagerProfileScreen> {
  int _navIndex = 3;

  late String _name = widget.name ?? "เจ้าหน้าที่";
  late String _email = widget.email ?? FirebaseAuth.instance.currentUser?.email ?? "-";
  late String _phone = widget.phone ?? "-";
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (!mounted || data == null) return;
      setState(() {
        _name = widget.name ?? (data['name'] as String?) ?? _name;
        _phone = widget.phone ?? (data['phone'] as String?) ?? _phone;
      });
    } catch (_) {
      // Keep whatever defaults we already have.
    }
  }

  Future<void> _confirmLogout() async {
    if (widget.onLogout != null) {
      widget.onLogout!();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("ออกจากระบบ"),
        content: const Text("คุณต้องการออกจากระบบใช่หรือไม่?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("ยกเลิก"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("ออกจากระบบ",
                style: TextStyle(color: GuardTheme.primaryRed)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loggingOut = true);
    try {
      await FirebaseAuth.instance.signOut();
    } finally {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthCheck()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GuardTheme.profileBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              decoration: const BoxDecoration(
                color: GuardTheme.primaryRed,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const Expanded(
                        child: Text(
                          "ข้อมูลส่วนตัว",
                          textAlign: TextAlign.center,
                          style: GuardTheme.screenTitle,
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.edit, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 46, color: GuardTheme.primaryRed),
                  ),
                  const SizedBox(height: 12),
                  Text(_name, style: GuardTheme.screenTitle),
                  const SizedBox(height: 4),
                  const Text(
                    "เจ้าหน้าที่รักษาความปลอดภัย",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: GuardTheme.cardDecoration(radius: 18),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _contactItem(Icons.email_outlined, _email),
                            _divider(),
                            _contactItem(Icons.call_outlined, _phone),
                            _divider(),
                            _contactItem(Icons.badge_outlined, widget.badgeId),
                          ],
                        ),
                      ),
                    ),
                    _menuSection("บัญชีของฉัน", [
                      _menuItem(Icons.person_outline, "ตั้งค่าบัญชี"),
                      _menuItem(Icons.shield_outlined, "ตั้งค่าความปลอดภัย"),
                      _menuItem(Icons.notifications_none, "ตั้งค่าการแจ้งเตือน"),
                    ]),
                    const SizedBox(height: 18),
                    _menuSection("สนับสนุน", [
                      _menuItem(Icons.help_outline, "ศูนย์ช่วยเหลือ"),
                      _menuItem(Icons.privacy_tip_outlined,
                          "ข้อกำหนดและนโยบายความเป็นส่วนตัว"),
                    ]),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: GuardTheme.primaryRed,
                          side: const BorderSide(color: GuardTheme.primaryRed),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _loggingOut ? null : _confirmLogout,
                        icon: _loggingOut
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.logout),
                        label: Text(_loggingOut ? "กำลังออกจากระบบ..." : "ออกจากระบบ"),
                      ),
                    ),
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

  Widget _contactItem(IconData icon, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: GuardTheme.primaryRed, size: 20),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: GuardTheme.textGrey),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 34, color: Colors.grey.shade200);

  Widget _menuSection(String title, List<Widget> items) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold, color: GuardTheme.textGrey)),
          ),
          Container(
            decoration: GuardTheme.cardDecoration(radius: 16),
            child: Column(children: items),
          ),
        ],
      ),
    );
  }

  Widget _menuItem(IconData icon, String label) {
    return ListTile(
      leading: Icon(icon, color: GuardTheme.primaryRed),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: const Icon(Icons.chevron_right, color: GuardTheme.textGrey),
      onTap: () {},
    );
  }
}
