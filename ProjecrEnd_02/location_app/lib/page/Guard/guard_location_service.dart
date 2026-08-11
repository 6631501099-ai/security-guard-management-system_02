import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import 'guard_constants.dart';
import '../../date_key.dart';

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
///   - `schedules`: guardUid, guardName, date (YYYY-MM-DD), label,
///     startTime, endTime, note — written by the admin's schedule screen,
///     read here per (guardUid, date).
///   - `tasks`: guardUid, guardName, title, timeRange, date, done —
///     written by the admin's task-assignment screen, completed here.
///   - `incidents`: guardUid, guardName, type, description, photoUrl,
///     lat, lng, status ('new'|'reviewed') — written here, read by admin.
///   - `notifications`: targetUid ('all' for broadcast) or a specific
///     guard uid, title, subtitle, category, timestamp — written by
///     admin actions (accept SOS, assign task/shift) and read here.
///   - `users/{uid}/activity`: iconKey, title, subtitle, timestamp — a
///     short personal log read by the guard's own dashboard.
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

  /// Reads whether this guard is currently marked as working, so a screen
  /// that gets recreated (e.g. after switching bottom-nav tabs) can
  /// restore the right UI state instead of always assuming "not working".
  Future<bool> fetchWorkingStatus(String uid) async {
    try {
      final doc = await _firestore.collection('locations').doc(uid).get();
      return doc.data()?['working'] == true;
    } catch (_) {
      return false;
    }
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

  /// Records when the current shift began, so `CheckInOutScreen` can
  /// restore the correct "ระยะเวลา" (worked duration) if the screen gets
  /// recreated mid-shift (e.g. the guard switches bottom-nav tabs and
  /// comes back) instead of losing track of the real start time.
  Future<void> markShiftStarted(String uid) async {
    await _firestore.collection('locations').doc(uid).set(
      {'shiftStart': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Future<DateTime?> fetchShiftStart(String uid) async {
    try {
      final doc = await _firestore.collection('locations').doc(uid).get();
      final ts = doc.data()?['shiftStart'];
      if (ts is Timestamp) return ts.toDate();
    } catch (_) {
      // fall through to null
    }
    return null;
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
  // list; admin sets it to 'accepted' when handled (and, via
  // GuardActions.acceptSos on the admin side, pushes a notification back
  // here so the guard's Alerts screen shows the response).
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
    await logActivity(
      uid: uid,
      iconKey: 'sos',
      title: 'ส่งสัญญาณ SOS',
      subtitle: message,
    );
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
    await logActivity(
      uid: uid,
      iconKey: 'sos',
      title: 'ยกเลิกสัญญาณ SOS',
      subtitle: 'ยกเลิกโดยเจ้าหน้าที่เอง',
    );
  }

  // ---------------------------------------------------------------------
  // ACTIVITY FEED — a short, denormalized log of what a guard did, read
  // by the guard's own dashboard ("กิจกรรมล่าสุด"). Every write here is
  // best-effort: failures are swallowed so a logging hiccup never blocks
  // the real action (check-in, task done, SOS, incident...) that
  // triggered it.
  // ---------------------------------------------------------------------

  Future<void> logActivity({
    required String uid,
    required String iconKey,
    required String title,
    required String subtitle,
  }) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('activity')
          .add({
        'iconKey': iconKey,
        'title': title,
        'subtitle': subtitle,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // best-effort only, see doc comment above
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchRecentActivity(
    String uid, {
    int limit = 6,
  }) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('activity')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  // ---------------------------------------------------------------------
  // SCHEDULE — shifts the admin assigns to a guard, keyed by day so the
  // guard's calendar strip can query one date at a time.
  // NOTE: this query (equality on guardUid + equality on date) needs a
  // Firestore composite index; Firestore will log a direct link to
  // create it the first time this runs against real data.
  // ---------------------------------------------------------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> watchScheduleForDay(
    String uid,
    DateTime day,
  ) {
    return _firestore
        .collection('schedules')
        .where('guardUid', isEqualTo: uid)
        .where('date', isEqualTo: dateKey(day))
        .snapshots();
  }

  // ---------------------------------------------------------------------
  // TASKS — duties the admin assigns to a guard.
  // NOTE: also needs a composite index (guardUid equality + createdAt
  // order).
  // ---------------------------------------------------------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMyTasks(String uid) {
    return _firestore
        .collection('tasks')
        .where('guardUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> completeTask({
    required String taskId,
    required String uid,
    required String taskTitle,
  }) async {
    await _firestore.collection('tasks').doc(taskId).set(
      {'done': true, 'completedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    await logActivity(
      uid: uid,
      iconKey: 'task',
      title: 'ดำเนินการเสร็จสิ้น',
      subtitle: taskTitle,
    );
  }

  // ---------------------------------------------------------------------
  // INCIDENT REPORTS — written here by the guard, read by the admin's
  // incident inbox.
  // ---------------------------------------------------------------------

  Future<String> submitIncident({
    required String uid,
    required String guardName,
    required String type,
    required String description,
    String? photoUrl,
    double? lat,
    double? lng,
  }) async {
    final doc = await _firestore.collection('incidents').add({
      'guardUid': uid,
      'guardName': guardName,
      'type': type,
      'description': description,
      'photoUrl': photoUrl,
      'lat': lat,
      'lng': lng,
      'status': 'new',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await logActivity(
      uid: uid,
      iconKey: 'incident',
      title: 'ส่งรายงานเหตุการณ์',
      subtitle: type,
    );
    return doc.id;
  }

  // ---------------------------------------------------------------------
  // ALERTS / NOTIFICATIONS — things targeted at this guard specifically
  // (targetUid == uid) plus broadcasts to everyone (targetUid == 'all'),
  // read by the guard's Alerts screen.
  // NOTE: `targetUid whereIn [...] + orderBy(timestamp)` also needs a
  // composite index.
  // ---------------------------------------------------------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMyAlerts(String uid) {
    return _firestore
        .collection('notifications')
        .where('targetUid', whereIn: [uid, 'all'])
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }
}
