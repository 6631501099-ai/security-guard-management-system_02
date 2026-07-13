import 'package:flutter/material.dart';
import 'guard_nav_helper.dart';
import 'guard_theme.dart';
import 'guard_header.dart';
import 'guard_bottom_nav.dart';

class IncidentReportScreen extends StatefulWidget {
  const IncidentReportScreen({super.key});

  @override
  State<IncidentReportScreen> createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  int _navIndex = 2;
  String? _incidentType;
  final TextEditingController _descController = TextEditingController();

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
    super.dispose();
  }

  void _submit() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: GuardTheme.green,
        content: Text("ส่งรายงานเรียบร้อยแล้ว"),
      ),
    );
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
                        _attachTile(Icons.add_a_photo_outlined),
                        const SizedBox(width: 12),
                        _attachTile(Icons.videocam_outlined),
                        const SizedBox(width: 12),
                        _attachTile(Icons.mic_none_outlined),
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
                        onPressed: _submit,
                        icon: const Icon(Icons.send),
                        label: const Text(
                          "ส่งรายงาน",
                          style: TextStyle(
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

  Widget _attachTile(IconData icon) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Icon(icon, color: GuardTheme.textGrey),
    );
  }
}
