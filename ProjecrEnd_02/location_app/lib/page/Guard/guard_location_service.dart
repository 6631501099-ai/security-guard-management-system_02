import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import 'guard_constants.dart';

/// Result of a location-permission request.
class GuardPermissionResult {
  final bool success;
  final String? errorMessage;
  final Position? position;

  const GuardPermissionResult({
    required this.success,
    this.errorMessage,
    this.position,
  });
}

/// Handles everything location/Firebase-related for the Guard flow.
///
/// IMPORTANT: the collection/field names here are deliberately matched to
/// what `admin_dashboard.dart` actually reads, so writes from this service
/// show up on the admin side:
///   - `locations/{uid}`: name, email, lat, lng, outOfScope, lastUpdate
///   - `sos`: uid, name, email, lat, lng, message, status, timestamp
///     (status starts as 'pending'; admin sets it to 'accepted')
class GuardLocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------
  // PROFILE
  // ---------------------------------------------------------------------

  /// Reads the guard's display name from their Firestore user doc.
  Future<String> fetchUserName(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data();
      return (data?['name'] as String?) ?? "เจ้าหน้าที่";
    } catch (_) {
      return "เจ้าหน้าที่";
    }
  }

  // ---------------------------------------------------------------------
  // PERMISSION / CURRENT POSITION
  // ---------------------------------------------------------------------

  Future<GuardPermissionResult> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return const GuardPermissionResult(
        success: false,
        errorMessage: "กรุณาเปิดใช้งาน GPS ของอุปกรณ์ก่อนใช้งาน",
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return const GuardPermissionResult(
          success: false,
          errorMessage: "ไม่ได้รับอนุญาตให้เข้าถึงตำแหน่ง GPS",
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return const GuardPermissionResult(
        success: false,
        errorMessage:
            "การเข้าถึงตำแหน่งถูกปฏิเสธถาวร กรุณาเปิดสิทธิ์ในตั้งค่าแอป",
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return GuardPermissionResult(success: true, position: position);
    } catch (e) {
      return GuardPermissionResult(
        success: false,
        errorMessage: "ไม่สามารถอ่านตำแหน่ง GPS ได้: $e",
      );
    }
  }

  // ---------------------------------------------------------------------
  // ZONE CHECK
  // ---------------------------------------------------------------------

  double distanceToCenter(Position position) {
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      GuardConstants.scopeCenter.latitude,
      GuardConstants.scopeCenter.longitude,
    );
  }

  bool _isInsideScope(Position position) {
    return distanceToCenter(position) <= GuardConstants.scopeRadiusMeters;
  }

  // ---------------------------------------------------------------------
  // LIVE POSITION STREAM
  // ---------------------------------------------------------------------

  StreamSubscription<Position> watchPosition({
    required void Function(Position position, bool insideScope) onUpdate,
  }) {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // meters between updates
    );
    return Geolocator.getPositionStream(locationSettings: settings)
        .listen((position) {
      onUpdate(position, _isInsideScope(position));
    });
  }

  // ---------------------------------------------------------------------
  // WORKING STATUS
  // ---------------------------------------------------------------------

  Future<void> setWorkingStatus(String uid, {required bool working}) async {
    await _firestore.collection('locations').doc(uid).set(
      {'working': working},
      SetOptions(merge: true),
    );
  }

  /// Called when the guard ends their shift. Admin treats a guard as
  /// "online" only if `lastUpdate` is within the last 60s, so once we
  /// stop writing updates they'll naturally drop off the online count —
  /// this just flips `working` immediately for anything that reads it.
  Future<void> markInactive(String uid) async {
    await _firestore.collection('locations').doc(uid).set(
      {'working': false},
      SetOptions(merge: true),
    );
  }

  // ---------------------------------------------------------------------
  // LIVE LOCATION — writes to `locations/{uid}`, exactly what the admin
  // dashboard's Overview / Live Tracking / Guards sections read.
  // ---------------------------------------------------------------------

  Future<void> updateLiveLocation({
    required String uid,
    required String name,
    String? email,
    required Position position,
    required bool inScope,
  }) async {
    await _firestore.collection('locations').doc(uid).set({
      'name': name,
      'email': email,
      'lat': position.latitude,
      'lng': position.longitude,
      'outOfScope': !inScope, // admin's field is the inverse of "inScope"
      'lastUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------
  // CHECKPOINT HISTORY (Firestore) — used by the guard's own check-in
  // history list. Admin dashboard doesn't read this collection.
  // ---------------------------------------------------------------------

  Future<void> logCheckpoint({
    required String uid,
    required String name,
    String? email,
    required Position position,
    required bool inScope,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('checkpoints')
        .add({
      'name': name,
      'email': email,
      'lat': position.latitude,
      'lng': position.longitude,
      'inScope': inScope,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Streams the guard's most recent checkpoints, newest first.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchCheckpointHistory(
    String uid, {
    int limit = 20,
  }) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('checkpoints')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  // ---------------------------------------------------------------------
  // SOS — writes to `sos`, exactly what admin's SOS Alerts / Recent Logs
  // sections read. status starts 'pending' so it shows in admin's pending
  // list; admin sets it to 'accepted' when handled.
  // ---------------------------------------------------------------------

  Future<String> sendSOS({
    required String uid,
    required String name,
    String? email,
    required Position position,
    required String message,
  }) async {
    final doc = await _firestore.collection('sos').add({
      'uid': uid,
      'name': name,
      'email': email,
      'lat': position.latitude,
      'lng': position.longitude,
      'message': message,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Cancels an SOS the guard sent by mistake / resolved themselves.
  /// Admin's pending list filters on status == 'pending', so this removes
  /// it from that view immediately.
  Future<void> cancelSOS(String uid, {String? alertId}) async {
    if (alertId != null) {
      await _firestore.collection('sos').doc(alertId).set(
        {'status': 'cancelled'},
        SetOptions(merge: true),
      );
    }
  }
}
