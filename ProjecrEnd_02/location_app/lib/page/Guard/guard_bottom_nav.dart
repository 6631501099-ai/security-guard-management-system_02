import 'package:flutter/material.dart';
import 'guard_theme.dart';

/// Bottom navigation bar shared by every Guard screen.
/// Index mapping: 0 = Home, 1 = Tasks/List, 2 = Alerts (raised, red), 3 = Profile.
class GuardBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<String> labels;

  const GuardBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.labels = const ["หน้าหลัก", "งาน", "แจ้งเตือน", "โปรไฟล์"],
  });

  @override
  Widget build(BuildContext context) {
    final icons = [Icons.home_rounded, Icons.list_alt_rounded, null, Icons.person_rounded];

    return SizedBox(
      height: 78,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Row(
              children: List.generate(4, (i) {
                if (i == 2) {
                  return const Expanded(child: SizedBox());
                }
                final selected = currentIndex == i;
                return Expanded(
                  child: InkWell(
                    onTap: () => onTap(i),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icons[i],
                            color: selected
                                ? GuardTheme.primaryRed
                                : Colors.grey.shade400,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: 11,
                              color: selected
                                  ? GuardTheme.primaryRed
                                  : Colors.grey.shade400,
                              fontWeight:
                                  selected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Positioned(
            top: -22,
            child: GestureDetector(
              onTap: () => onTap(2),
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: GuardTheme.primaryRed,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: GuardTheme.primaryRed.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.warning_rounded, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
