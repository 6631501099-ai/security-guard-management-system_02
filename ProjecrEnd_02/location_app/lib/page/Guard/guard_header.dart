import 'package:flutter/material.dart';
import 'guard_theme.dart';

/// Red rounded header block: back/title row + optional subtitle,
/// with the guard's avatar and an online status dot on the right.
class GuardHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool showBack;
  final String? avatarAsset;

  const GuardHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.avatarAsset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
      decoration: const BoxDecoration(
        color: GuardTheme.primaryRed,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GuardTheme.screenTitle),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          Stack(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white,
                backgroundImage:
                    avatarAsset != null ? AssetImage(avatarAsset!) : null,
                child: avatarAsset == null
                    ? const Icon(Icons.person, color: GuardTheme.primaryRed)
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: GuardTheme.green,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
