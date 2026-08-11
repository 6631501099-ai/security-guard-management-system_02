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
    final scale = GuardTheme.responsiveScale(context);
    final fabSize = 58 * scale;

    // How much space the phone's own on-screen back/home/recents buttons
    // (or the gesture bar) take up at the bottom. Since main.dart enables
    // edge-to-edge rendering, the app now draws all the way behind that
    // area instead of Android reserving a solid strip for it — so without
    // this, our own nav bar's tap targets/icons end up hidden underneath
    // the phone's system buttons. Padding by exactly that inset pushes
    // our content up above it everywhere this widget is used.
    final systemNavInset = MediaQuery.of(context).padding.bottom;

    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(bottom: systemNavInset),
      child: SizedBox(
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
              top: -22 * scale,
              child: GestureDetector(
                onTap: () => onTap(2),
                child: Container(
                  width: fabSize,
                  height: fabSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: GuardTheme.primaryRed,
                    border: Border.all(color: Colors.white, width: 4 * scale),
                    boxShadow: [
                      BoxShadow(
                        color: GuardTheme.primaryRed.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(Icons.warning_rounded,
                      color: Colors.white, size: 24 * scale),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
