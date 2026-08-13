import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../Guard/guard_theme.dart';
import '../Guard/guard_bottom_nav.dart';
import '../Admin/admin_nav_helper.dart';
import 'chat_detail_screen.dart';
import 'chat_models.dart';
import 'chat_service.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _service = ChatService();
  final TextEditingController _search = TextEditingController();
  String _query = '';
  
  // 0 = ทั้งหมด, 1 = ยังไม่ได้อ่าน, 2 = กลุ่ม
  int _selectedFilter = 0; 

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _openThread(String chatId, String otherUid, String otherName, String? otherPhoto) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          chatId: chatId,
          otherUid: otherUid,
          otherName: otherName,
          otherPhoto: otherPhoto,
        ),
      ),
    );
  }

  Future<void> _startChatWith(ChatUser user) async {
    final chatId = await _service.openOrCreateChat(user);
    if (!mounted) return;
    _openThread(chatId, user.uid, user.name, user.photoUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GuardTheme.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeaderBar(),
            _buildSearchBar(),
            _buildFilterChips(),
            const SizedBox(height: 8),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      
      bottomNavigationBar: GuardBottomNav(
        currentIndex: 3,
        labels: const ["หน้าหลัก", "เจ้าหน้าที่", "แจ้งเตือน", "แชท", "โปรไฟล์"],
        onTap: (i) {
          if (i == 3) return;
          navigateToAdminTab(context, i);
        },
      ),
    );
  }

  Widget _buildHeaderBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'กล่องข้อความ',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          IconButton(
            onPressed: _createGroupChat,
            icon: const Icon(Icons.group_add_rounded, color: Color(0xFF800000), size: 26),
            tooltip: 'สร้างแชทกลุ่ม',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        decoration: GuardTheme.cardDecoration(radius: 14),
        child: TextField(
          controller: _search,
          onChanged: (v) => setState(() => _query = v.trim()),
          decoration: const InputDecoration(
            hintText: 'หาเจ้าหน้าที่ด้วยชื่อหรือID',
            hintStyle: TextStyle(color: GuardTheme.textGrey, fontSize: 13),
            prefixIcon: Icon(Icons.search, color: GuardTheme.textGrey, size: 20),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _filterChip(
            index: 0,
            label: 'ทั้งหมด',
            bgColor: const Color(0xFF6B7280),
            textColor: Colors.white,
          ),
          const SizedBox(width: 10),
          _filterChip(
            index: 1,
            label: 'ยังไม่ได้อ่าน',
            bgColor: const Color(0xFF800000),
            textColor: Colors.white,
          ),
          const SizedBox(width: 10),
          _filterChip(
            index: 2,
            label: 'กลุ่ม',
            bgColor: const Color(0xFFD4AF37),
            textColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required int index,
    required String label,
    required Color bgColor,
    required Color textColor,
  }) {
    return InkWell(
      onTap: () => setState(() => _selectedFilter = index),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: bgColor.withOpacity(0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final uid = _service.myUid;
    if (uid == null) {
      return const Center(
        child: Text('กรุณาเข้าสู่ระบบ', style: TextStyle(color: GuardTheme.textGrey)),
      );
    }

    return StreamBuilder<List<ChatThread>>(
      stream: _service.watchMyThreads(),
      builder: (context, threadSnap) {
        final threads = threadSnap.data ?? const <ChatThread>[];
        final threadOtherUids = threads.map((t) => t.otherUid(uid)).toSet();

        return StreamBuilder<List<ChatUser>>(
          stream: _service.watchContacts(),
          builder: (context, contactSnap) {
            final contacts = contactSnap.data ?? const <ChatUser>[];

            final filteredThreads = threads.where((t) {
              final titleName = t.isGroup
                  ? (t.name.isNotEmpty ? t.name : 'แชทกลุ่ม')
                  : t.otherName(uid);

              if (_query.isNotEmpty &&
                  !titleName.toLowerCase().contains(_query.toLowerCase())) {
                return false;
              }
              if (_selectedFilter == 1) return t.unreadForMe > 0;
              if (_selectedFilter == 2) return t.isGroup;
              return true;
            }).toList();

            final newContacts = contacts.where((c) {
              if (_selectedFilter == 1 || _selectedFilter == 2) return false;
              if (threadOtherUids.contains(c.uid)) return false;
              if (_query.isEmpty) return true;
              return c.name.toLowerCase().contains(_query.toLowerCase());
            }).toList();

            if (threadSnap.connectionState == ConnectionState.waiting &&
                contactSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (filteredThreads.isEmpty && newContacts.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'ไม่พบรายการสนทนา',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: GuardTheme.textGrey),
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                ...filteredThreads.map((t) => _threadTile(t, uid)),
                if (newContacts.isNotEmpty) ...[
                  //const Padding(
                  // padding: EdgeInsets.fromLTRB(6, 16, 6, 8),
                  //  child: Text('เริ่มแชทใหม่', style: GuardTheme.sectionTitle),
                  //),
                  ...newContacts.map(_contactTile),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _threadTile(ChatThread t, String uid) {
    final name = t.isGroup ? (t.name.isNotEmpty ? t.name : 'แชทกลุ่ม') : t.otherName(uid);
    final photo = t.isGroup ? null : t.otherPhoto(uid);
    final unread = t.unreadForMe;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: GuardTheme.cardDecoration(radius: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: _avatar(name, photo, isGroup: t.isGroup),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          t.lastMessage.isEmpty ? 'เริ่มการสนทนา' : t.lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: GuardTheme.textGrey, fontSize: 13),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _timeLabel(t.lastMessageTime),
                  style: const TextStyle(color: GuardTheme.textGrey, fontSize: 11),
                ),
              ],
            ),
            if (unread > 0) ...[
              const SizedBox(width: 8),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF800000),
                  shape: BoxShape.circle,
                ),
              ),
            ],
            if (t.isGroup) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                onPressed: () => _confirmDeleteGroup(t.id, name),
              ),
            ],
          ],
        ),
        onTap: () => _openThread(t.id, t.isGroup ? '' : t.otherUid(uid), name, photo),
        onLongPress: t.isGroup ? () => _confirmDeleteGroup(t.id, name) : null,
      ),
    );
  }

  Widget _contactTile(ChatUser user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: GuardTheme.cardDecoration(radius: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: _avatar(user.name, user.photoUrl),
        title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          user.role == 'admin' ? 'ผู้ดูแลระบบ' : 'เจ้าหน้าที่รักษาความปลอดภัย',
          style: const TextStyle(color: GuardTheme.textGrey, fontSize: 12),
        ),
        trailing: const Icon(Icons.chat_bubble_outline, color: GuardTheme.primaryRed, size: 20),
        onTap: () => _startChatWith(user),
      ),
    );
  }

  Widget _avatar(String name, String? photoUrl, {bool isGroup = false}) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: GuardTheme.primaryRed.withOpacity(0.12),
      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
      child: photoUrl == null
          ? (isGroup
              ? const Icon(Icons.group, color: GuardTheme.primaryRed)
              : Text(
                  name.isNotEmpty ? name.substring(0, 1) : '?',
                  style: const TextStyle(
                    color: GuardTheme.primaryRed,
                    fontWeight: FontWeight.bold,
                  ),
                ))
          : null,
    );
  }

  String _timeLabel(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}';
  }

  // ฟังก์ชันลบแชทกลุ่ม
  Future<void> _confirmDeleteGroup(String chatId, String groupName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("ยืนยันการลบกลุ่ม"),
        content: Text("คุณต้องการลบกลุ่ม '$groupName' ใช่หรือไม่? ข้อความทั้งหมดจะถูกลบ"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("ยกเลิก"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF800000)),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text("ลบกลุ่ม", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance.collection('chats').doc(chatId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF800000),
            content: Text("ลบกลุ่ม '$groupName' เรียบร้อยแล้ว"),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("เกิดข้อผิดพลาดในการลบกลุ่ม: $e")),
        );
      }
    }
  }

  // ฟังก์ชันสร้างกลุ่มใหม่
  Future<void> _createGroupChat() async {
    final groupNameController = TextEditingController();
    final Set<String> selectedMemberUids = {};

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("ตั้งแชทกลุ่มใหม่"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: groupNameController,
                    decoration: const InputDecoration(
                      labelText: "ชื่อกลุ่มแชท",
                      hintText: "เช่น ลาดตระเวน S1",
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("เลือกสมาชิกเข้าร่วมกลุ่ม:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  
                  StreamBuilder<List<ChatUser>>(
                    stream: _service.watchContacts(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final contacts = snapshot.data ?? [];
                      return Column(
                        children: contacts.map((user) {
                          final isSelected = selectedMemberUids.contains(user.uid);
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: isSelected,
                            title: Text(user.name, style: const TextStyle(fontSize: 14)),
                            onChanged: (val) {
                              setDialogState(() {
                                if (val == true) {
                                  selectedMemberUids.add(user.uid);
                                } else {
                                  selectedMemberUids.remove(user.uid);
                                }
                              });
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text("ยกเลิก"),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF800000)),
                onPressed: () async {
                  final groupName = groupNameController.text.trim();
                  if (groupName.isEmpty || selectedMemberUids.isEmpty) return;

                  Navigator.of(dialogContext).pop();

                  final myUid = _service.myUid;
                  if (myUid == null) return;

                  await FirebaseFirestore.instance.collection('chats').add({
                    'type': 'group',
                    'isGroup': true,
                    'name': groupName,
                    'members': [...selectedMemberUids, myUid],
                    'participants': [...selectedMemberUids, myUid],
                    'createdBy': myUid,
                    'lastMessage': 'สร้างกลุ่มแล้ว',
                    'lastMessageTime': FieldValue.serverTimestamp(),
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("สร้างกลุ่ม '$groupName' เรียบร้อยแล้ว")),
                    );
                  }
                },
                child: const Text("สร้างกลุ่ม"),
              ),
            ],
          );
        },
      ),
    );
  }
}