import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_theme.dart';

/// Dropdown for picking a guard to assign a shift/task to. Reads from the
/// `users` collection (the guard roster's source of truth) rather than
/// `locations`, so admins can assign work to a guard even if they're
/// currently offline / haven't opened the app yet today.
///
/// NOTE: this lists every doc in `users`. If the app later distinguishes
/// admin vs. guard accounts with a `role` field, add
/// `.where('role', isEqualTo: 'guard')` to the query below.
class GuardPickerField extends StatelessWidget {
  final String? selectedUid;
  final ValueChanged<String> onSelectedUid;
  final ValueChanged<String>? onSelectedName;

  const GuardPickerField({
    super.key,
    required this.selectedUid,
    required this.onSelectedUid,
    this.onSelectedName,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const LinearProgressIndicator();
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Text(
            "ยังไม่มีเจ้าหน้าที่ในระบบ",
            style: AppText.body,
          );
        }
        final validSelected =
            docs.any((d) => d.id == selectedUid) ? selectedUid : null;

        return DropdownButtonFormField<String>(
          value: validSelected,
          decoration: InputDecoration(
            labelText: "เลือกเจ้าหน้าที่",
            filled: true,
            fillColor: AppColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          items: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['name'] ?? doc.id).toString();
            return DropdownMenuItem(value: doc.id, child: Text(name));
          }).toList(),
          onChanged: (uid) {
            if (uid == null) return;
            onSelectedUid(uid);
            final match = docs.where((d) => d.id == uid);
            if (match.isNotEmpty && onSelectedName != null) {
              final data = match.first.data() as Map<String, dynamic>;
              onSelectedName!((data['name'] ?? uid).toString());
            }
          },
        );
      },
    );
  }
}
