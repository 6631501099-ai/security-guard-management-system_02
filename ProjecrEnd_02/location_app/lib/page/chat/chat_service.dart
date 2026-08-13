import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'chat_models.dart';

class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get myUid => FirebaseAuth.instance.currentUser?.uid;

  String chatIdFor(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Stream<List<ChatThread>> watchMyThreads() {
    final uid = myUid;
    if (uid == null) return Stream.value([]);

    return _db
        .collection('chats')
        .where('participants', arrayContains: uid)
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
        'members': [uid, other.uid],
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

    final updateData = <String, dynamic>{
      'lastMessage': text.trim(),
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': uid,
      'unread_$uid': 0,
    };

    if (otherUid.isNotEmpty) {
      updateData['unread_$otherUid'] = FieldValue.increment(1);
    }

    await chatRef.set(updateData, SetOptions(merge: true));
  }

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

    final updateData = <String, dynamic>{
      'lastMessage': caption.trim().isNotEmpty ? caption.trim() : '[รูปภาพ]',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': uid,
      'unread_$uid': 0,
    };

    if (otherUid.isNotEmpty) {
      updateData['unread_$otherUid'] = FieldValue.increment(1);
    }

    await chatRef.set(updateData, SetOptions(merge: true));
  }

  Future<void> markRead(String chatId) async {
    final uid = myUid;
    if (uid == null) return;
    await _db.collection('chats').doc(chatId).set({
      'unread_$uid': 0,
    }, SetOptions(merge: true));
  }
}