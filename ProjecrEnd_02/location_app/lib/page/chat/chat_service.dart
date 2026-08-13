import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'chat_models.dart';

/// Firestore-backed 1:1 chat between any two `users/{uid}` accounts
/// (guard <-> admin, guard <-> guard, etc). See chat_models.dart for the
/// exact document shape. Deliberately self-contained so it doesn't touch
/// any of the existing services/screens.
class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get myUid => FirebaseAuth.instance.currentUser?.uid;

  /// Deterministic chat id for a pair of uids, independent of order.
  String chatIdFor(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// All chat threads the current user is part of, newest first.
  Stream<List<ChatThread>> watchMyThreads() {
  final uid = myUid;
  if (uid == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('chats')
      .where('members', arrayContains: uid) // 👈 เปลี่ยน/เพิ่มให้ค้นหาจาก members ด้วย
      .snapshots()
      .map((snap) {
        final list = snap.docs.map((d) => ChatThread.fromDoc(d, uid)).toList();
        list.sort((a, b) {
          final at = a.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bt = b.lastMessageTime ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bt.compareTo(at);
        });
        return list;
      });
}

  /// People the current user can start a chat with: everyone in `users`
  /// except themselves (guards can message admins/other guards and
  /// vice-versa — the mockups show both roles using the same chat UI).
  Stream<List<ChatUser>> watchContacts() {
    final uid = myUid;
    if (uid == null) return const Stream.empty();
    return _db.collection('users').snapshots().map(
          (snap) => snap.docs
              .where((d) => d.id != uid)
              .map(ChatUser.fromDoc)
              .toList(),
        );
  }

  /// Makes sure a chat document exists for (me, other) and returns its id.
  Future<String> openOrCreateChat(ChatUser other) async {
    final uid = myUid;
    if (uid == null) throw StateError('ไม่ได้เข้าสู่ระบบ');
    final id = chatIdFor(uid, other.uid);
    final ref = _db.collection('chats').doc(id);
    final doc = await ref.get();

    if (!doc.exists) {
      String myName = 'ผู้ใช้งาน';
      String? myPhoto;
      final myDoc = await _db.collection('users').doc(uid).get();
      final myData = myDoc.data();
      if (myData != null) {
        myName = (myData['name'] as String?) ?? myName;
        myPhoto = myData['photoUrl'] as String?;
      }

      await ref.set({
        'participants': [uid, other.uid],
        'participantNames': {uid: myName, other.uid: other.name},
        'participantPhotos': {uid: myPhoto, other.uid: other.photoUrl},
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': null,
        'unread_$uid': 0,
        'unread_${other.uid}': 0,
      });
    }
    return id;
  }

  /// Messages in a chat, oldest first (ready to feed a bottom-anchored list).
  Stream<List<ChatMessage>> watchMessages(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map((snap) => snap.docs.map(ChatMessage.fromDoc).toList());
  }

  Future<void> sendMessage({
    required String chatId,
    required String otherUid,
    required String text,
  }) async {
    final uid = myUid;
    if (uid == null || text.trim().isEmpty) return;
    final chatRef = _db.collection('chats').doc(chatId);

    await chatRef.collection('messages').add({
      'senderId': uid,
      'text': text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });

    await chatRef.set({
      'lastMessage': text.trim(),
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': uid,
      'unread_$otherUid': FieldValue.increment(1),
      'unread_$uid': 0,
    }, SetOptions(merge: true));
  }

  /// Uploads [imageFile] to Storage under `chat_images/{chatId}/...` and
  /// writes an image message (optionally with a short [caption]). Mirrors
  /// the upload pattern already used for incident-report photos and
  /// profile photos elsewhere in the app.
  Future<void> sendImageMessage({
    required String chatId,
    required String otherUid,
    required File imageFile,
    String caption = '',
  }) async {
    final uid = myUid;
    if (uid == null) return;

    final ref = FirebaseStorage.instance
        .ref()
        .child('chat_images')
        .child(chatId)
        .child('${DateTime.now().millisecondsSinceEpoch}_$uid.jpg');
    await ref.putFile(imageFile);
    final imageUrl = await ref.getDownloadURL();

    final chatRef = _db.collection('chats').doc(chatId);

    await chatRef.collection('messages').add({
      'senderId': uid,
      'text': caption.trim(),
      'imageUrl': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await chatRef.set({
      // Image-only messages still need a non-empty preview string so the
      // thread list in ChatListScreen shows something meaningful instead
      // of a blank line.
      'lastMessage': caption.trim().isNotEmpty ? caption.trim() : '[รูปภาพ]',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': uid,
      'unread_$otherUid': FieldValue.increment(1),
      'unread_$uid': 0,
    }, SetOptions(merge: true));
  }

  /// Call when opening a thread so the badge clears for the current user.
  Future<void> markRead(String chatId) async {
    final uid = myUid;
    if (uid == null) return;
    await _db.collection('chats').doc(chatId).set({
      'unread_$uid': 0,
    }, SetOptions(merge: true));
  }
}
