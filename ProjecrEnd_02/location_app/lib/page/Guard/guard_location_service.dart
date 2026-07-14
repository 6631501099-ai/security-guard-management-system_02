import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import 'guard_constants.dart';

/// Result of a permission/location request attempt.
class LocationRequestResult {
  final bool success;
  final String? errorMessage;
  final Position? position;

  const LocationRequestResult({
    required this.success,
    this.errorMessage,
    this.position,
  });
}

/// Handles all Firestore + Geolocator interactions for the guard flow,
/// keeping the UI layer free of data/service logic.
class GuardLocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Requests location permission and returns the current position.
  Future<LocationRequestResult> requestPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationRequestResult(
          success: false,
          errorMessage: "GPS is off. Please enable location services.",
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const LocationRequestResult(
          success: false,
          errorMessage: "Location permission is required to track the guard.",
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return LocationRequestResult(success: true, position: position);
    } catch (e) {
      return const LocationRequestResult(
        success: false,
        errorMessage: "Unable to get GPS location yet. Please try again.",
      );
    }
  }

  /// Whether the given position falls inside the patrol geofence.
  bool isInScope(Position position) {
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      GuardConstants.scopeCenter.latitude,
      GuardConstants.scopeCenter.longitude,
    );
    return distance <= GuardConstants.scopeRadiusMeters;
  }

  double distanceToCenter(Position position) {
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      GuardConstants.scopeCenter.latitude,
      GuardConstants.scopeCenter.longitude,
    );
  }

  /// Starts a continuous position stream used while the guard is on duty.
  StreamSubscription<Position> watchPosition({
    required void Function(Position position, bool inScope) onUpdate,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) => onUpdate(position, isInScope(position)));
  }

  Future<void> setWorkingStatus(String uid, {required bool working}) {
    return _firestore.collection("users").doc(uid).update({
      "status": working ? "working" : "offline",
    });
  }

  Future<void> updateLiveLocation({
    required String uid,
    required String name,
    required String? email,
    required Position position,
    required bool inScope,
  }) {
    return _firestore.collection("locations").doc(uid).set({
      "name": name,
      "email": email,
      "lat": position.latitude,
      "lng": position.longitude,
      "isActive": true,
      "outOfScope": !inScope,
      "lastUpdate": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markInactive(String uid) {
    return _firestore.collection("locations").doc(uid).update({
      "isActive": false,
    });
  }

  Future<void> logCheckpoint({
    required String uid,
    required String name,
    required String? email,
    required Position position,
    required bool inScope,
  }) {
    return _firestore.collection("patrol_logs").add({
      "uid": uid,
      "name": name,
      "email": email ?? "",
      "lat": position.latitude,
      "lng": position.longitude,
      "status": inScope ? "on_route" : "out_of_scope",
      "timestamp": FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendSOS({
    required String uid,
    required String name,
    required String? email,
    required Position position,
    required String message,
  }) {
    return _firestore.collection("sos").add({
      "uid": uid,
      "name": name,
      "email": email ?? "",
      "lat": position.latitude,
      "lng": position.longitude,
      "status": "pending",
      "message": message,
      "imageUrl": "",
      "timestamp": FieldValue.serverTimestamp(),
    });
  }

  Future<String> fetchUserName(String uid) async {
    final doc = await _firestore.collection("users").doc(uid).get();
    return doc.data()?['name'] ?? "";
  }
}
