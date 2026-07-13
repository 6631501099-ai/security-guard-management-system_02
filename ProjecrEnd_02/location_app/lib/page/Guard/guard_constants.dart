import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Shared constants for the patrol/work zone.
/// Adjust [scopeCenter] and [scopeRadiusMeters] to match your actual site.
class GuardConstants {
  GuardConstants._();

  /// Center point of the allowed patrol/work zone.
  static const LatLng scopeCenter = LatLng(13.736717, 100.523186); // Bangkok, replace with your site's coordinates

  /// Radius (in meters) around [scopeCenter] considered "inside" the zone.
  static const double scopeRadiusMeters = 200;

  /// ⚠️ TODO: replace with your control room / admin's real phone number.
  static const String emergencyContactPhone = "0800000000";
}
