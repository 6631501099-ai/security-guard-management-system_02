import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_theme.dart';
import 'admin_quick_action_chip.dart';
import 'admin_stat_card.dart';

/// Dashboard landing section: live counters + shortcuts into other sections.
class OverviewSection extends StatelessWidget {
  final ValueChanged<String> onNavigate;

  const OverviewSection({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Admin Dashboard', style: AppText.pageTitle),
          const SizedBox(height: 10),
          const Text(
            'Keep the team moving with a compact control center for guards, '
            'patrol status, and incoming emergencies.',
            style: AppText.body,
          ),
          const SizedBox(height: 20),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('locations')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();

              int onlineCount = 0;
              int outOfScopeCount = 0;
              for (final doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final lastUpdate = data['lastUpdate'];
                if (lastUpdate == null) continue;
                final diff = DateTime.now()
                    .difference((lastUpdate as Timestamp).toDate())
                    .inSeconds;
                if (diff <= 60) {
                  onlineCount++;
                  if (data['outOfScope'] == true) outOfScopeCount++;
                }
              }

              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  StatCard(
                    icon: Icons.people,
                    title: 'Guards Online',
                    value: '$onlineCount',
                    color: AppColors.success,
                  ),
                  StatCard(
                    icon: Icons.warning_amber,
                    title: 'Out of scope',
                    value: '$outOfScopeCount',
                    color: AppColors.accentRed,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sos')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              final pending = snapshot.data!.docs.length;
              return StatCard(
                icon: Icons.report_problem,
                title: 'Pending SOS',
                value: '$pending',
                color: AppColors.warning,
                minWidth: 220,
              );
            },
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Quick actions', style: AppText.sectionTitle),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    QuickActionChip(
                      icon: Icons.map,
                      label: 'Open tracking',
                      onTap: () => onNavigate('tracking'),
                    ),
                    QuickActionChip(
                      icon: Icons.warning,
                      label: 'Review SOS',
                      onTap: () => onNavigate('sos'),
                    ),
                    QuickActionChip(
                      icon: Icons.people,
                      label: 'Guard roster',
                      onTap: () => onNavigate('guards'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
