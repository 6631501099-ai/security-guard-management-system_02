import 'package:cloud_firestore/cloud_firestore.dart';

/// One entry in the "people you can chat with" list — backed by a
/// `users/{uid}` document (see GuardLocationService's doc comment for the
/// full schema this app already uses).
class ChatUser {
  final String uid;
  final String name;
  final String? photoUrl;
  final String role; // 'guard' | 'admin'

  const ChatUser({
    required this.uid,
    required this.name,
    required this.role,
    this.photoUrl,
  });

  factory ChatUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return ChatUser(
      uid: doc.id,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? data['name'] as String
          : 'ผู้ใช้งาน',
      role: (data['role'] as String?) ?? 'guard',
      photoUrl: data['photoUrl'] as String?,
    );
  }
}

/// One row in the `chats` collection: a 1:1 conversation between two
/// `users/{uid}` accounts OR a group chat.
class ChatThread {
  final String id;
  final bool isGroup;
  final String name; // 👈 เพิ่มประกาศ field name ตรงนี้
  final List<String> participants;
  final Map<String, String> participantNames;
  final Map<String, String?> participantPhotos;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final String? lastSenderId;
  final int unreadForMe;

  const ChatThread({
    required this.id,
    this.isGroup = false,
    this.name = '', // 👈 แก้ไข syntax constructor ตรงนี้
    required this.participants,
    required this.participantNames,
    required this.participantPhotos,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastSenderId,
    required this.unreadForMe,
  });

  factory ChatThread.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String myUid,
  ) {
    final data = doc.data() ?? const {};
    final ts = data['lastMessageTime'] as Timestamp?;
    
    // ดึงสมาชิกไม่ว่าจะเก็บในฟิลด์ members (แชทกลุ่ม) หรือ participants (แชทเดี่ยว)
    final membersList = List<String>.from(data['members'] ?? data['participants'] ?? const []);

    return ChatThread(
      id: doc.id,
      isGroup: data['isGroup'] == true || data['type'] == 'group',
      name: (data['name'] as String?) ?? '', // 👈 อ่านค่าชื่อกลุ่มจาก Firestore
      participants: membersList,
      participantNames: Map<String, String>.from(
        data['participantNames'] ?? const {},
      ),
      participantPhotos: Map<String, String?>.from(
        data['participantPhotos'] ?? const {},
      ),
      lastMessage: (data['lastMessage'] as String?) ?? '',
      lastMessageTime: ts?.toDate(),
      lastSenderId: data['lastSenderId'] as String?,
      unreadForMe: (data['unread_$myUid'] as num?)?.toInt() ?? 0,
    );
  }

  /// The other participant's uid in this 1:1 chat.
  String otherUid(String myUid) =>
      participants.firstWhere((u) => u != myUid, orElse: () => myUid);

  String otherName(String myUid) =>
      participantNames[otherUid(myUid)] ?? 'ผู้ใช้งาน';

  String? otherPhoto(String myUid) => participantPhotos[otherUid(myUid)];
}

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime? timestamp;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
  });

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final ts = data['timestamp'] as Timestamp?;
    return ChatMessage(
      id: doc.id,
      senderId: (data['senderId'] as String?) ?? '',
      text: (data['text'] as String?) ?? '',
      timestamp: ts?.toDate(),
    );
  }
}