import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'admin_theme.dart';
import 'admin_full_map_screen.dart';

/// Live tracking section: search + map of all guards currently online,
/// with an optional "focused" marker highlighted (e.g. jumped to from an
/// SOS alert or the guard roster).
class TrackingSection extends StatelessWidget {
  final String search;
  final ValueChanged<String> onSearchChanged;
  final LatLng? focusedGuardLocation;
  final String? focusedGuardName;
  final void Function(GoogleMapController controller) onMapCreated;

  const TrackingSection({
    super.key,
    required this.search,
    required this.onSearchChanged,
    required this.focusedGuardLocation,
    required this.focusedGuardName,
    required this.onMapCreated,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Live tracking', style: AppText.sectionTitle),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 200,
              height: 44,
              child: TextField(
                onChanged: onSearchChanged,
                decoration: searchFieldDecoration('Search guards'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: cardDecoration(),
            child: Stack(
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('locations')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryRed,
                        ),
                      );
                    }
                    final docs = snapshot.data!.docs;
                    final markers = <Marker>{};
                    for (final doc in docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final lastUpdate = data['lastUpdate'];
                      if (lastUpdate == null) continue;
                      final diff = DateTime.now()
                          .difference((lastUpdate as Timestamp).toDate())
                          .inSeconds;
                      if (diff > 60) continue;
                      final email = (data['email'] ?? '')
                          .toString()
                          .toLowerCase();
                      if (!email.contains(search.toLowerCase())) continue;
                      markers.add(
                        Marker(
                          markerId: MarkerId(doc.id),
                          position: LatLng(data['lat'], data['lng']),
                          infoWindow: InfoWindow(
                            title: data['name'] ?? '',
                            snippet: data['outOfScope'] == true
                                ? 'OUT OF SCOPE'
                                : 'ONLINE',
                          ),
                        ),
                      );
                    }
                    if (focusedGuardLocation != null) {
                      markers.add(
                        Marker(
                          markerId: const MarkerId('focused_guard'),
                          position: focusedGuardLocation!,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueAzure,
                          ),
                          infoWindow: InfoWindow(
                            title: focusedGuardName ?? 'Focused guard',
                            snippet: 'Selected location',
                          ),
                        ),
                      );
                    }
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      child: GoogleMap(
                        onMapCreated: (controller) {
                          onMapCreated(controller);
                          if (focusedGuardLocation != null) {
                            controller.animateCamera(
                              CameraUpdate.newLatLngZoom(
                                focusedGuardLocation!,
                                16,
                              ),
                            );
                          }
                        },
                        initialCameraPosition: const CameraPosition(
                          target: LatLng(20.044, 99.894),
                          zoom: 14,
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
                  },
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'fullscreen_map_fab',
                    backgroundColor: Colors.white,
                    onPressed: () async {
                      final snapshot = await FirebaseFirestore.instance
                          .collection('locations')
                          .get();
                      final markers = <Marker>{};
                      for (final doc in snapshot.docs) {
                        final data = doc.data();
                        markers.add(
                          Marker(
                            markerId: MarkerId(doc.id),
                            position: LatLng(data['lat'], data['lng']),
                            infoWindow: InfoWindow(title: data['name']),
                          ),
                        );
                      }
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminFullMapScreen(markers: markers),
                        ),
                      );
                    },
                    child: const Icon(Icons.fullscreen, color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
