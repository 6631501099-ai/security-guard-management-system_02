import 'package:flutter/material.dart';
import 'guard_theme.dart';

/// Bottom navigation bar shared by every Guard screen.
/// Index mapping: 0 = Home, 1 = Tasks/List, 2 = Alerts (raised, red), 3 = Profile.
class GuardBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<String> labels;
  final bool hasNotification;

  const GuardBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.hasNotification = false,
    this.labels = const ["หน้าหลัก", "ภารกิจ", "SOS", "แชท", "โปรไฟล์"],
  });

  @override
  Widget build(BuildContext context) {
    final icons = [Icons.home_rounded, Icons.format_list_bulleted_rounded, null,Icons.chat_bubble_rounded, Icons.person_rounded];
    final scale = GuardTheme.responsiveScale(context);
    final fabSize = 76 * scale;

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
        height: 90,
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
              child: // เปลี่ยนจำนวนจาก 4 เป็น 5 ช่องรายการ
            Row(
              children: List.generate(5, (i) {
                if (i == 2) {
                  return const Expanded(child: SizedBox()); // เว้นช่องกลางไว้ให้ปุ่ม SOS
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
           // [ไฮไลท์] ซ้อน Stack เพื่อเพิ่มจุด Notification Badge สีส้มที่กระดิ่งแจ้งเตือน (Index 3)
             Stack(
               clipBehavior: Clip.none,
                 children: [
                   Icon(
                    icons[i],
                      size: 26,
                       color: selected
                        ? GuardTheme.primaryRed
                        : Colors.grey.shade400,
                         ),
         if (i == 3 && hasNotification)
            Positioned(
             right: -2,
             top: 0,
             child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFFE6A100),
                  shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
              const SizedBox(height: 4),
                Text(
                  labels[i],
                style: TextStyle(
                fontSize: 11,
                color: selected
                  ? GuardTheme.primaryRed
                  : Colors.grey.shade400,
                fontWeight: selected
                  ? FontWeight.bold
                  : FontWeight.normal,
                   ),
               ),
              const SizedBox(height: 3),
             //  เพิ่มจุดสีแดงใต้เมนูที่กำลังเลือกใช้งานอยู่
          if (selected)
             Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
              color: GuardTheme.primaryRed,
              shape: BoxShape.circle,
                  ),
              )
                else
              const SizedBox(height: 4),
               ],
             ),
           ),
          ),
         );
       }),
     ),
   ),
            // [ไฮไลท์] ปรับโทนสีและไอคอนปุ่ม SOS ตรงกลางให้เหมือนในภาพ
          Positioned(
            top: -24 * scale,
            child: GestureDetector(
              onTap: () => onTap(2),
              child: Container(
                width: fabSize,
                height: fabSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF7A0000), // [ไฮไลท์] สีแดงเข้มตามภาพ
                  border: Border.all(color: Colors.white, width: 4 * scale),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: const Color(0xFFE5B83A), // [ไฮไลท์] ไอคอนตกใจสีทอง/ส้ม
                    size: 42 * scale,
                  ),
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}
