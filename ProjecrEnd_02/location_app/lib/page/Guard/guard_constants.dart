import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Constants defining the guard patrol scope/geofence.
class GuardConstants {
  GuardConstants._();

  static const LatLng scopeCenter = LatLng(13.736717, 100.523186);
  static const double scopeRadiusMeters = 1000;
}
