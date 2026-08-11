import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'guard_nav_helper.dart';
import 'guard_theme.dart';
import 'guard_header.dart';
import 'guard_bottom_nav.dart';
import 'guard_location_service.dart';

class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({super.key});

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  final GuardLocationService _locationService = GuardLocationService();
  int _navIndex = 2;
  String? _incidentType;
  final TextEditingController _descController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _photoFile;
  File? _videoFile;
  bool _isRecordingNote = false;
  Duration _noteDuration = Duration.zero;
  Timer? _noteTimer;
  bool _submitting = false;

  final List<String> _incidentTypes = const [
    "บุคคลต้องสงสัย",
    "ทรัพย์สินเสียหาย",
    "อัคคีภัย",
    "การบุกรุก",
    "อื่นๆ",
  ];

  @override
  void dispose() {
    _descController.dispose();
    _noteTimer?.cancel();
    super.dispose();
  }

  Future<ImageSource?> _chooseSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text("ถ่ายภาพ/วิดีโอใหม่"),
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
  }

  Future<void> _pickPhoto() async {
    final source = await _chooseSource();
    if (source == null) return;
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 80);
      if (file != null && mounted) {
        setState(() => _photoFile = File(file.path));
      }
    } catch (e) {
      if (mounted) _showSnack("ไม่สามารถแนบรูปภาพได้: $e");
    }
  }

  Future<void> _pickVideo() async {
    final source = await _chooseSource();
    if (source == null) return;
    try {
      final file = await _picker.pickVideo(source: source);
      if (file != null && mounted) {
        setState(() => _videoFile = File(file.path));
      }
    } catch (e) {
      if (mounted) _showSnack("ไม่สามารถแนบวิดีโอได้: $e");
    }
  }

  void _toggleVoiceNote() {
    if (_isRecordingNote) {
      _noteTimer?.cancel();
      setState(() => _isRecordingNote = false);
      _showSnack("บันทึกเสียงแล้ว (${_noteDuration.inSeconds} วินาที)");
    } else {
      setState(() {
        _isRecordingNote = true;
        _noteDuration = Duration.zero;
      });
      _noteTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _noteDuration += const Duration(seconds: 1));
      });
    }
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Uploads the attached photo (if any) to Storage, captures a best-effort
  /// GPS fix, and writes the report to Firestore's `incidents` collection
  /// so it shows up in the admin's "รายงานเหตุการณ์" inbox.
  ///
  /// NOTE: video attachments and voice notes are captured locally in this
  /// screen but not yet uploaded anywhere — only the photo and text
  /// description are persisted. Wire those up to Storage the same way as
  /// the photo below if/when you need them on the admin side too.
  Future<void> _submit() async {
    if (_incidentType == null) {
      _showSnack("กรุณาเลือกรูปแบบเหตุการณ์");
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack("กรุณาเข้าสู่ระบบก่อนส่งรายงาน");
      return;
    }

    setState(() => _submitting = true);
    try {
      String? photoUrl;
      if (_photoFile != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('incident_photos')
            .child('${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_photoFile!);
        photoUrl = await ref.getDownloadURL();
      }

      double? lat;
      double? lng;
      try {
        final pos = await Geolocator.getCurrentPosition();
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {
        // Location is a nice-to-have on the report — don't block
        // submission if GPS isn't available right now.
      }

      final guardName = await _locationService.fetchUserName(user.uid);
      await _locationService.submitIncident(
        uid: user.uid,
        guardName: guardName,
        type: _incidentType!,
        description: _descController.text.trim(),
        photoUrl: photoUrl,
        lat: lat,
        lng: lng,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: GuardTheme.green,
          content: Text("ส่งรายงานเรียบร้อยแล้ว"),
        ),
      );
      setState(() {
        _incidentType = null;
        _descController.clear();
        _photoFile = null;
        _videoFile = null;
        _isRecordingNote = false;
        _noteDuration = Duration.zero;
      });
    } catch (e) {
      if (mounted) _showSnack("ส่งรายงานไม่สำเร็จ: $e");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GuardTheme.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const GuardHeader(
              title: "รายงานเหตุการณ์",
              subtitle: "รหัสรายงาน: RPT-0-0000-01",
              showBack: true,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel("รูปแบบเหตุการณ์"),
                    DropdownButtonFormField<String>(
                      value: _incidentType,
                      hint: const Text("เลือกรูปแบบ"),
                      decoration: _inputDecoration(),
                      items: _incidentTypes
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) => setState(() => _incidentType = v),
                    ),
                    const SizedBox(height: 16),
                    _fieldLabel("ตำแหน่ง"),
                    TextField(
                      readOnly: true,
                      decoration: _inputDecoration(
                        hint: "อาคาร C2 ชั้น 2, ระเบียงฝั่ง E3",
                        prefixIcon: const Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _fieldLabel("รายละเอียดเหตุการณ์"),
                    TextField(
                      controller: _descController,
                      maxLines: 4,
                      decoration:
                          _inputDecoration(hint: "อธิบายเหตุการณ์ที่เกิดขึ้น..."),
                    ),
                    const SizedBox(height: 16),
                    _fieldLabel("หลักฐาน (รูปภาพ/วิดีโอ)"),
                    Row(
                      children: [
                        _attachTile(
                          icon: Icons.add_a_photo_outlined,
                          onTap: _pickPhoto,
                          active: _photoFile != null,
                          badge: _photoFile != null ? "1" : null,
                        ),
                        const SizedBox(width: 12),
                        _attachTile(
                          icon: Icons.videocam_outlined,
                          onTap: _pickVideo,
                          active: _videoFile != null,
                          badge: _videoFile != null ? "1" : null,
                        ),
                        const SizedBox(width: 12),
                        _attachTile(
                          icon: _isRecordingNote
                              ? Icons.stop_circle_outlined
                              : Icons.mic_none_outlined,
                          onTap: _toggleVoiceNote,
                          active: _isRecordingNote,
                          badge: _isRecordingNote
                              ? "${_noteDuration.inSeconds}s"
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: GuardTheme.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.send),
                        label: Text(
                          _submitting ? "กำลังส่งรายงาน..." : "ส่งรายงาน",
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
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

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      );

  InputDecoration _inputDecoration({String? hint, Widget? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }

  Widget _attachTile({
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
    String? badge,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: active ? GuardTheme.primaryRed.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? GuardTheme.primaryRed : Colors.grey.shade300,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon,
                color: active ? GuardTheme.primaryRed : GuardTheme.textGrey),
            if (badge != null)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: GuardTheme.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(fontSize: 9, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
