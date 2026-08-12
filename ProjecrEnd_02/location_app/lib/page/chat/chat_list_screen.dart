import 'package:flutter/material.dart';

import '../Guard/guard_theme.dart';
import 'chat_detail_screen.dart';
import 'chat_models.dart';
import 'chat_service.dart';

/// "แชท" — list of conversations + people you can start a new chat with.
/// Matches the chat mockup: red rounded header, search field, avatar rows
/// with last-message preview and an unread badge.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _service = ChatService();
  final TextEditingController _search = TextEditingController();
  String _query = '';

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
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 22),
      decoration: const BoxDecoration(
        color: GuardTheme.primaryRed,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const Text('แชท', style: GuardTheme.screenTitle),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Container(
        decoration: GuardTheme.cardDecoration(radius: 14),
        child: TextField(
          controller: _search,
          onChanged: (v) => setState(() => _query = v.trim()),
          decoration: const InputDecoration(
            hintText: 'ค้นหาชื่อผู้ติดต่อ',
            hintStyle: TextStyle(color: GuardTheme.textGrey, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: GuardTheme.textGrey),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
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
              if (_query.isEmpty) return true;
              return t.otherName(uid).toLowerCase().contains(_query.toLowerCase());
            }).toList();

            final newContacts = contacts.where((c) {
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
                    'ยังไม่มีการสนทนา — เริ่มแชทกับเพื่อนร่วมงานได้เลย',
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
                  const Padding(
                    padding: EdgeInsets.fromLTRB(6, 16, 6, 8),
                    child: Text('เริ่มแชทใหม่', style: GuardTheme.sectionTitle),
                  ),
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
    final name = t.otherName(uid);
    final photo = t.otherPhoto(uid);
    final unread = t.unreadForMe;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: GuardTheme.cardDecoration(radius: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: _avatar(name, photo),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          t.lastMessage.isEmpty ? 'เริ่มการสนทนา' : t.lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: GuardTheme.textGrey, fontSize: 13),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(_timeLabel(t.lastMessageTime),
                style: const TextStyle(color: GuardTheme.textGrey, fontSize: 11)),
            const SizedBox(height: 6),
            if (unread > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: GuardTheme.primaryRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$unread',
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
          ],
        ),
        onTap: () => _openThread(t.id, t.otherUid(uid), name, photo),
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

  Widget _avatar(String name, String? photoUrl) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: GuardTheme.primaryRed.withOpacity(0.12),
      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
      child: photoUrl == null
          ? Text(
              name.isNotEmpty ? name.substring(0, 1) : '?',
              style: const TextStyle(
                color: GuardTheme.primaryRed,
                fontWeight: FontWeight.bold,
              ),
            )
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
}
