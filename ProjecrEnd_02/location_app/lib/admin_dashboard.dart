// 🔥 IMPORT
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

////////////////////////////////////////////////////////////
/// ADMIN DASHBOARD
////////////////////////////////////////////////////////////

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  ////////////////////////////////////////////////////////////
  /// VARIABLES
  ////////////////////////////////////////////////////////////

  String search = "";
  String selectedSection = "overview";
  bool isSidebarExpanded = false;
  LatLng? focusedGuardLocation;
  String? focusedGuardName;

  GoogleMapController? mapController;

  ////////////////////////////////////////////////////////////
  /// LOGOUT
  ////////////////////////////////////////////////////////////

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }

  ////////////////////////////////////////////////////////////
  /// HELPERS
  ////////////////////////////////////////////////////////////

  void _focusGuardOnMap(
    BuildContext context,
    dynamic lat,
    dynamic lng, {
    String? label,
  }) {
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text("No location available for this guard."),
        ),
      );
      return;
    }

    try {
      final parsedLat = double.parse(lat.toString());
      final parsedLng = double.parse(lng.toString());

      setState(() {
        selectedSection = "tracking";
        focusedGuardLocation = LatLng(parsedLat, parsedLng);
        focusedGuardName = label;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(parsedLat, parsedLng), 16),
        );
      });
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text("The saved location is not valid."),
        ),
      );
    }
  }

  Future<void> _callGuard(
    BuildContext context,
    Map<String, dynamic> guard,
  ) async {
    final phone = (guard['phone'] ?? guard['phoneNumber'] ?? '')
        .toString()
        .trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text("No phone number is available for this guard."),
        ),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text("Unable to open the phone dialer."),
        ),
      );
    }
  }

  void _showSosDetails(
    BuildContext context,
    Map<String, dynamic> latest,
    String docId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 60,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                "SOS Alert Details",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                "Name: ${latest['name']}",
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                "Email: ${latest['email']}",
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                "Location: ${latest['lat']}, ${latest['lng']}",
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                "Status: ${latest['status']}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Message: ${latest['message'] ?? ''}",
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 120,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _focusGuardOnMap(
                          context,
                          latest['lat'],
                          latest['lng'],
                          label: latest['name'] ?? "SOS guard",
                        );
                      },
                      icon: const Icon(Icons.map),
                      label: const Text("Map"),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _callGuard(context, latest);
                      },
                      icon: const Icon(Icons.call),
                      label: const Text("Call"),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection("sos")
                            .doc(docId)
                            .update({"status": "accepted"});
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text("Accept"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showGuardDetails(BuildContext context, Map<String, dynamic> guard) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final outOfScope = guard['outOfScope'] == true;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 60,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                guard['name'] ?? "Guard Details",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Email: ${guard['email'] ?? ''}",
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                "Latitude: ${guard['lat']}",
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                "Longitude: ${guard['lng']}",
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                outOfScope ? "Status: Out of scope" : "Status: On route",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: outOfScope ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 150,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _focusGuardOnMap(
                          context,
                          guard['lat'],
                          guard['lng'],
                          label: guard['name'] ?? "Guard",
                        );
                      },
                      icon: const Icon(Icons.map),
                      label: const Text("Locate"),
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => _callGuard(context, guard),
                      icon: const Icon(Icons.call),
                      label: const Text("Call Guard"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  ////////////////////////////////////////////////////////////
  /// BUILD
  ////////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    final sidebarWidth = isSidebarExpanded ? 240.0 : 84.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: Text(_sectionTitle()),
        leading: IconButton(
          icon: Icon(
            isSidebarExpanded ? Icons.close_fullscreen : Icons.menu_open,
          ),
          onPressed: () {
            setState(() {
              isSidebarExpanded = !isSidebarExpanded;
            });
          },
        ),
        actions: [
          IconButton(onPressed: logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: sidebarWidth,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF8E0E00), Color(0xFF1F1C18)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.security, color: Colors.red, size: 34),
                ),
                const SizedBox(height: 12),
                if (isSidebarExpanded)
                  const Text(
                    "MFU SECURITY",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else
                  const SizedBox(height: 18),
                const SizedBox(height: 24),
                _buildNavItem(Icons.dashboard, "Overview", "overview"),
                _buildNavItem(Icons.map, "Live Tracking", "tracking"),
                _buildNavItem(Icons.warning, "SOS Alerts", "sos"),
                _buildNavItem(Icons.people, "Guards", "guards"),
                _buildNavItem(Icons.history, "Logs", "logs"),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: isSidebarExpanded
                      ? SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red,
                              minimumSize: const Size.fromHeight(44),
                            ),
                            onPressed: logout,
                            icon: const Icon(Icons.logout),
                            label: const Text("Logout"),
                          ),
                        )
                      : IconButton.filledTonal(
                          onPressed: logout,
                          tooltip: 'Logout',
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(
                              Colors.white,
                            ),
                          ),
                          icon: const Icon(Icons.logout, color: Colors.red),
                        ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _buildSectionContent(),
            ),
          ),
        ],
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// MENU
  ////////////////////////////////////////////////////////////

  Widget _buildNavItem(IconData icon, String title, String section) {
    final active = selectedSection == section;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Material(
        color: active ? Colors.white24 : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              selectedSection = section;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 22),
                if (isSidebarExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _sectionTitle() {
    switch (selectedSection) {
      case 'tracking':
        return 'Live Tracking';
      case 'sos':
        return 'SOS Alerts';
      case 'guards':
        return 'Guards';
      case 'logs':
        return 'Recent Logs';
      default:
        return 'Admin Dashboard';
    }
  }

  Widget _buildSectionContent() {
    switch (selectedSection) {
      case 'tracking':
        return _buildTrackingSection();
      case 'sos':
        return _buildSosSection();
      case 'guards':
        return _buildGuardsSection();
      case 'logs':
        return _buildLogsSection();
      default:
        return _buildOverviewSection();
    }
  }

  Widget _buildOverviewSection() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Dashboard',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            'Keep the team moving with a compact control center for guards, patrol status, and incoming emergencies.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
          ),
          const SizedBox(height: 18),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('locations')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox();
              }
              int onlineCount = 0;
              int outOfScopeCount = 0;
              for (final doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final lastUpdate = data['lastUpdate'];
                if (lastUpdate == null) continue;
                final diff = DateTime.now()
                    .difference((lastUpdate as Timestamp).toDate())
                    .inSeconds;
                if (diff <= 60) {
                  onlineCount++;
                  if (data['outOfScope'] == true) {
                    outOfScopeCount++;
                  }
                }
              }
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildInfoCard(
                    icon: Icons.people,
                    title: 'Guards Online',
                    value: '$onlineCount',
                    color: Colors.green,
                  ),
                  _buildInfoCard(
                    icon: Icons.warning_amber,
                    title: 'Out of scope',
                    value: '$outOfScopeCount',
                    color: Colors.red,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sos')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox();
              }
              final pending = snapshot.data!.docs.length;
              return _buildInfoCard(
                icon: Icons.report_problem,
                title: 'Pending SOS',
                value: '$pending',
                color: Colors.orange,
                minWidth: 220,
              );
            },
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick actions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildQuickAction(
                      Icons.map,
                      'Open tracking',
                      () => setState(() => selectedSection = 'tracking'),
                    ),
                    _buildQuickAction(
                      Icons.warning,
                      'Review SOS',
                      () => setState(() => selectedSection = 'sos'),
                    ),
                    _buildQuickAction(
                      Icons.people,
                      'Guard roster',
                      () => setState(() => selectedSection = 'guards'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingSection() {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Live tracking',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              width: 180,
              child: TextField(
                onChanged: (value) => setState(() => search = value),
                decoration: InputDecoration(
                  hintText: 'Search guards',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('locations')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
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
                      borderRadius: BorderRadius.circular(24),
                      child: GoogleMap(
                        onMapCreated: (controller) {
                          mapController = controller;
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
                      if (!mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullMapPage(markers: markers),
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

  Widget _buildSosSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sos')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Unable to load SOS alerts right now.'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        final pendingDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data['status'] ?? 'pending').toString().toLowerCase() ==
              'pending';
        }).toList();

        if (pendingDocs.isEmpty) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('No pending SOS alerts. All clear.'),
            ),
          );
        }
        return ListView.separated(
          itemCount: pendingDocs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = pendingDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data['name'] ?? 'Unknown guard',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(data['message'] ?? 'Emergency reported'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 120,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.black,
                          ),
                          onPressed: () =>
                              _showSosDetails(context, data, doc.id),
                          icon: const Icon(Icons.visibility),
                          label: const Text('Review'),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.blueGrey,
                          ),
                          onPressed: () => _focusGuardOnMap(
                            context,
                            data['lat'],
                            data['lng'],
                            label: data['name'] ?? 'SOS guard',
                          ),
                          icon: const Icon(Icons.location_on),
                          label: const Text('Locate'),
                        ),
                      ),
                      SizedBox(
                        width: 120,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          onPressed: () async {
                            await FirebaseFirestore.instance
                                .collection('sos')
                                .doc(doc.id)
                                .update({'status': 'accepted'});
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Accept'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGuardsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Guard roster',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        TextField(
          onChanged: (value) => setState(() => search = value),
          decoration: InputDecoration(
            hintText: 'Search guard email',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('locations')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              final guards = <Map<String, dynamic>>[];
              for (final doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final lastUpdate = data['lastUpdate'];
                if (lastUpdate == null) continue;
                final diff = DateTime.now()
                    .difference((lastUpdate as Timestamp).toDate())
                    .inSeconds;
                if (diff > 60) continue;
                final email = (data['email'] ?? '').toString().toLowerCase();
                if (!email.contains(search.toLowerCase())) continue;
                guards.add({...data, 'diff': diff});
              }
              if (guards.isEmpty) {
                return const Center(child: Text('No active guards found'));
              }
              return ListView.separated(
                itemCount: guards.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final guard = guards[index];
                  final outOfScope = guard['outOfScope'] == true;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: outOfScope
                              ? Colors.red
                              : Colors.green,
                          child: const Icon(
                            Icons.security,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                guard['name'] ?? 'Guard',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(guard['email'] ?? ''),
                              Text(
                                'Lat: ${guard['lat']} • Lng: ${guard['lng']}',
                              ),
                              Text(
                                outOfScope ? 'Out of scope' : 'On route',
                                style: TextStyle(
                                  color: outOfScope ? Colors.red : Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.black,
                          ),
                          onPressed: () => _showGuardDetails(context, guard),
                          icon: const Icon(Icons.location_on),
                          label: const Text('View'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLogsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent logs',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Latest patrol events, SOS activity, and current guard status.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sos')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snapshot.data!.docs;
              if (items.isEmpty) {
                return const Center(child: Text('No activity yet'));
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final data = item.data() as Map<String, dynamic>;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          data['status'] == 'accepted'
                              ? Icons.check_circle
                              : Icons.warning,
                          color: data['status'] == 'accepted'
                              ? Colors.green
                              : Colors.red,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['name'] ?? 'Guard',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(data['message'] ?? 'No message'),
                              Text(
                                'Status: ${data['status'] ?? 'pending'}',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.red),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    double minWidth = 160,
  }) {
    return Container(
      width: minWidth,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// FULL MAP PAGE
////////////////////////////////////////////////////////////

class FullMapPage extends StatelessWidget {
  final Set<Marker> markers;

  const FullMapPage({super.key, required this.markers});

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
