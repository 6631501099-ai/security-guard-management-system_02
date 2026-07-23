import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Fullscreen map view, opened from the Live Tracking section.
class AdminFullMapScreen extends StatelessWidget {
  final Set<Marker> markers;

  const AdminFullMapScreen({super.key, required this.markers});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text("Live Fullscreen Map"),
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(20.044, 99.894),
          zoom: 15,
        ),
        markers: markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: true,
        zoomGesturesEnabled: true,
        scrollGesturesEnabled: true,
        rotateGesturesEnabled: true,
        tiltGesturesEnabled: true,
        compassEnabled: true,
        mapToolbarEnabled: true,
      ),
    );
  }
}
