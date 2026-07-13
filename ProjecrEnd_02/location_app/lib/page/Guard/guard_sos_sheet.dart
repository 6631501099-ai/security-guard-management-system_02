import 'package:flutter/material.dart';
import 'guard_theme.dart';

/// Shows the SOS composer bottom sheet. [onSend] is called when the guard
/// taps send; the caller is responsible for actually dispatching the SOS
/// (e.g. via GuardLocationService.sendSOS) and closing the sheet if desired.
Future<void> showGuardSosSheet({
  required BuildContext context,
  required TextEditingController controller,
  required Future<void> Function() onSend,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: GuardTheme.primaryRed),
                const SizedBox(width: 8),
                const Text(
                  "แจ้งเหตุฉุกเฉิน",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "ระบุรายละเอียดสั้นๆ (ถ้ามี) ระบบจะส่งตำแหน่งปัจจุบันของคุณไปยังแอดมินทันที",
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "เจ้าหน้าที่ต้องการความช่วยเหลือด่วน",
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: GuardTheme.primaryRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await onSend();
                },
                icon: const Icon(Icons.send),
                label: const Text(
                  "ส่ง SOS ทันที",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}
