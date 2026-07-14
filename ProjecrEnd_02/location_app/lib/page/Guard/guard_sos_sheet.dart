import 'package:flutter/material.dart';

/// Shows the bottom sheet used to compose and send an emergency SOS report.
/// [onSend] should perform the actual submission (e.g. write to Firestore).
Future<void> showGuardSosSheet({
  required BuildContext context,
  required TextEditingController controller,
  required Future<void> Function() onSend,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      bool isSending = false;

      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 60,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Emergency Report",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Describe the situation and send an SOS to the admin.",
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: "Enter details about the incident...",
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    icon: const Icon(Icons.send),
                    label: Text(isSending ? "Sending..." : "Send SOS"),
                    onPressed: isSending
                        ? null
                        : () async {
                            setState(() => isSending = true);
                            await onSend();
                            setState(() => isSending = false);
                            if (context.mounted) Navigator.pop(context);
                          },
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      );
    },
  );
}
