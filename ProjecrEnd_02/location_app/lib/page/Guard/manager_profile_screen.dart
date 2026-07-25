import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
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

  bool _isEditing = false;
  bool _saving = false;
  late final TextEditingController _nameController = TextEditingController(text: _name);
  late final TextEditingController _phoneController = TextEditingController(text: _phone);

  final ImagePicker _picker = ImagePicker();
  File? _localPhoto;
  String? _photoUrl;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
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
        _photoUrl = (data['photoUrl'] as String?) ?? _photoUrl;
        _nameController.text = _name;
        _phoneController.text = _phone;
      });
    } catch (_) {
      // Keep whatever defaults we already have.
    }
  }

  Future<void> _pickProfilePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text("ถ่ายรูปใหม่"),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text("เลือกจากคลังภาพ"),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 800,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "เปิดกล้อง/คลังภาพไม่ได้: $e\n"
            "ตรวจสอบสิทธิ์กล้อง/คลังภาพของแอปในตั้งค่าเครื่อง",
          ),
        ),
      );
      return;
    }

    if (picked == null) {
      // User backed out of the camera/gallery picker — nothing to do,
      // but let them know so it's clear the tap was registered.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("ไม่ได้เลือกรูปภาพ")),
        );
      }
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณาเข้าสู่ระบบก่อนตั้งค่ารูปโปรไฟล์")),
      );
      return;
    }

    setState(() {
      _localPhoto = File(picked!.path);
      _uploadingPhoto = true;
    });

    try {
      final ref =
          FirebaseStorage.instance.ref().child('profile_photos').child('${user.uid}.jpg');
      await ref.putFile(_localPhoto!);
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'photoUrl': url},
        SetOptions(merge: true),
      );

      if (!mounted) return;
      setState(() {
        _photoUrl = url;
        _uploadingPhoto = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: GuardTheme.green,
          content: Text("อัปเดตรูปโปรไฟล์แล้ว"),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("อัปโหลดรูปไม่สำเร็จ: $e")),
      );
    }
  }

  void _toggleEditing() {
    setState(() {
      if (_isEditing) {
        // Leaving edit mode without saving — reset any unsaved changes.
        _nameController.text = _name;
        _phoneController.text = _phone;
      }
      _isEditing = !_isEditing;
    });
  }

  Future<void> _saveProfile() async {
    final newName = _nameController.text.trim();
    final newPhone = _phoneController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("กรุณากรอกชื่อ")),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          {'name': newName, 'phone': newPhone},
          SetOptions(merge: true),
        );
      }
      if (!mounted) return;
      setState(() {
        _name = newName;
        _phone = newPhone;
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: GuardTheme.green,
          content: Text("บันทึกข้อมูลเรียบร้อยแล้ว"),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("บันทึกไม่สำเร็จ: $e")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    if (_email == "-" || _email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("ไม่พบอีเมลสำหรับส่งลิงก์เปลี่ยนรหัสผ่าน")),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: _email);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ส่งลิงก์เปลี่ยนรหัสผ่านไปที่ $_email แล้ว")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ส่งลิงก์ไม่สำเร็จ: $e")),
      );
    }
  }

  void _showSecurityDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("ตั้งค่าความปลอดภัย"),
        content: Text(
          "ระบบจะส่งลิงก์สำหรับตั้งรหัสผ่านใหม่ไปที่ $_email",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("ยกเลิก"),
          ),
          FilledButton(
            onPressed: _sendPasswordReset,
            child: const Text("ส่งลิงก์เปลี่ยนรหัสผ่าน"),
          ),
        ],
      ),
    );
  }

  void _showNotificationSettings() {
    bool emergencyAlerts = true;
    bool scheduleAlerts = true;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("ตั้งค่าการแจ้งเตือน"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("แจ้งเตือนเหตุฉุกเฉิน"),
                value: emergencyAlerts,
                activeColor: GuardTheme.primaryRed,
                onChanged: (v) => setDialogState(() => emergencyAlerts = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("แจ้งเตือนตารางงาน"),
                value: scheduleAlerts,
                activeColor: GuardTheme.primaryRed,
                onChanged: (v) => setDialogState(() => scheduleAlerts = v),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    backgroundColor: GuardTheme.green,
                    content: Text("บันทึกการตั้งค่าการแจ้งเตือนแล้ว"),
                  ),
                );
              },
              child: const Text("บันทึก"),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("ศูนย์ช่วยเหลือ"),
        content: const Text(
          "หากพบปัญหาการใช้งานหรือต้องการความช่วยเหลือด่วน กรุณาติดต่อศูนย์ควบคุมของคุณผ่านหน้า SOS หรือโทรสายด่วนที่แอดมินให้ไว้",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("ปิด"),
          ),
        ],
      ),
    );
  }

  void _showPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("ข้อกำหนดและนโยบายความเป็นส่วนตัว"),
        content: const SingleChildScrollView(
          child: Text(
            "ข้อมูลตำแหน่งและกิจกรรมของคุณจะถูกใช้เพื่อการบริหารจัดการเวรงานและความปลอดภัยเท่านั้น "
            "กรุณาติดต่อผู้ดูแลระบบของหน่วยงานหากต้องการทราบรายละเอียดฉบับเต็ม",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("ปิด"),
          ),
        ],
      ),
    );
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
                        onPressed: _toggleEditing,
                        icon: Icon(_isEditing ? Icons.close : Icons.edit,
                            color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _uploadingPhoto ? null : _pickProfilePhoto,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white,
                          backgroundImage: _localPhoto != null
                              ? FileImage(_localPhoto!)
                              : (_photoUrl != null
                                  ? NetworkImage(_photoUrl!) as ImageProvider
                                  : null),
                          child: (_localPhoto == null && _photoUrl == null)
                              ? const Icon(Icons.person,
                                  size: 46, color: GuardTheme.primaryRed)
                              : null,
                        ),
                        if (_uploadingPhoto)
                          Positioned.fill(
                            child: CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.black45,
                              child: const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: GuardTheme.primaryRed,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(_name, style: GuardTheme.screenTitle),
                  const SizedBox(height: 4),
                  const Text(
                    "เจ้าหน้าที่รักษาความปลอดภัย",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: _uploadingPhoto ? null : _pickProfilePhoto,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.camera_alt_outlined, size: 16),
                    label: Text(
                      _uploadingPhoto ? "กำลังอัปโหลด..." : "เปลี่ยนรูปโปรไฟล์",
                      style: const TextStyle(
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                    ),
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
                    if (_isEditing) _buildEditForm(),
                    _menuSection("บัญชีของฉัน", [
                      _menuItem(Icons.person_outline, "ตั้งค่าบัญชี",
                          onTap: _toggleEditing),
                      _menuItem(Icons.shield_outlined, "ตั้งค่าความปลอดภัย",
                          onTap: _showSecurityDialog),
                      _menuItem(Icons.notifications_none, "ตั้งค่าการแจ้งเตือน",
                          onTap: _showNotificationSettings),
                    ]),
                    const SizedBox(height: 18),
                    _menuSection("สนับสนุน", [
                      _menuItem(Icons.help_outline, "ศูนย์ช่วยเหลือ",
                          onTap: _showHelpDialog),
                      _menuItem(Icons.privacy_tip_outlined,
                          "ข้อกำหนดและนโยบายความเป็นส่วนตัว",
                          onTap: _showPolicyDialog),
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

  Widget _buildEditForm() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: GuardTheme.cardDecoration(radius: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("แก้ไขข้อมูลส่วนตัว",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 14),
            const Text("ชื่อ-นามสกุล",
                style: TextStyle(fontSize: 12, color: GuardTheme.textGrey)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                filled: true,
                fillColor: GuardTheme.scaffoldBg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text("เบอร์โทรศัพท์",
                style: TextStyle(fontSize: 12, color: GuardTheme.textGrey)),
            const SizedBox(height: 6),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                filled: true,
                fillColor: GuardTheme.scaffoldBg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : _toggleEditing,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: GuardTheme.textGrey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("ยกเลิก"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _saveProfile,
                    style: FilledButton.styleFrom(
                      backgroundColor: GuardTheme.primaryRed,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text("บันทึก"),
                  ),
                ),
              ],
            ),
          ],
        ),
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

  Widget _menuItem(IconData icon, String label, {required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: GuardTheme.primaryRed),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: const Icon(Icons.chevron_right, color: GuardTheme.textGrey),
      onTap: onTap,
    );
  }
}
