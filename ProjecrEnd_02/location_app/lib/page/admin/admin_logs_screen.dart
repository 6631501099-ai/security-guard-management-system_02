import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_theme.dart';
import 'admin_section_placeholder.dart';

/// Read-only feed of recent SOS activity/status changes.
class LogsSection extends StatelessWidget {
  const LogsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent logs', style: AppText.sectionTitle),
        const SizedBox(height: 8),
        const Text(
          'Latest patrol events, SOS activity, and current guard status.',
          style: AppText.body,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sos')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SectionPlaceholder.loading();

              final items = snapshot.data!.docs;
              if (items.isEmpty) {
                return const SectionPlaceholder(
                  icon: Icons.history,
                  title: 'No activity yet',
                );
              }

              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final data = item.data() as Map<String, dynamic>;
                  final accepted = data['status'] == 'accepted';
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: cardDecoration(radius: AppRadius.lg),
                    child: Row(
                      children: [
                        Icon(
                          accepted ? Icons.check_circle : Icons.warning,
                          color: accepted
                              ? AppColors.success
                              : AppColors.accentRed,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['name'] ?? 'Guard',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                data['message'] ?? 'No message',
                                style: AppText.body,
                              ),
                              Text(
                                'Status: ${data['status'] ?? 'pending'}',
                                style: AppText.body,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
