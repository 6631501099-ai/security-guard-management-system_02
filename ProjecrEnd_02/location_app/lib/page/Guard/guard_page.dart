import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'guard_constants.dart';
import 'guard_location_service.dart';
import 'guard_stat_card.dart';
import 'guard_sos_sheet.dart';

////////////////////////////////////////////////////////////
/// GUARD PAGE
////////////////////////////////////////////////////////////

class GuardPage extends StatefulWidget {
  const GuardPage({super.key});

  @override
  State<GuardPage> createState() => _GuardPageState();
}

class _GuardPageState extends State<GuardPage> {
  final GuardLocationService _locationService = GuardLocationService();

  StreamSubscription<Position>? _positionStream;

  bool isWorking = false;
  bool inScope = true;
  bool hasOutOfScopeAlert = false;
  bool isLoggingCheckpoint = false;

  Position? currentPosition;

  User? user;

  String name = "";
  String lastCheckIn = "No checkpoint logged yet";
  int checkInCount = 0;

  GoogleMapController? guardMapController;

  final TextEditingController sosController = TextEditingController();

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    _loadProfile();
    _requestPermission();
  }

  ////////////////////////////////////////////////////////////
  /// LOAD PROFILE
  ////////////////////////////////////////////////////////////

  Future<void> _loadProfile() async {
    final fetchedName = await _locationService.fetchUserName(user!.uid);
    if (!mounted) return;
    setState(() => name = fetchedName);
  }

  ////////////////////////////////////////////////////////////
  /// PERMISSION
  ////////////////////////////////////////////////////////////

  Future<bool> _requestPermission() async {
    final result = await _locationService.requestPermission();

    if (!mounted) return false;

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange,
          content: Text(result.errorMessage!),
        ),
      );
      return false;
    }

    setState(() => currentPosition = result.position);
    return true;
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return "${(meters / 1000).toStringAsFixed(1)} km";
    }
    return "${meters.round()} m";
  }

  ////////////////////////////////////////////////////////////
  /// CHECK-IN
  ////////////////////////////////////////////////////////////

  Future<void> _recordCheckpoint() async {
    if (currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text("ไม่พบตำแหน่ง GPS กรุณาลองใหม่อีกครั้ง"),
        ),
      );
      return;
    }

    setState(() => isLoggingCheckpoint = true);

    try {
      final now = DateTime.now().toLocal();

      await _locationService.logCheckpoint(
        uid: user!.uid,
        name: name,
        email: user!.email,
        position: currentPosition!,
        inScope: inScope,
      );

      setState(() {
        checkInCount += 1;
        lastCheckIn = now.toString().split('.').first;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text("Checkpoint logged successfully"),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange,
          content: Text("เกิดข้อผิดพลาดในการบันทึก : $e"),
        ),
      );
    } finally {
      if (mounted) setState(() => isLoggingCheckpoint = false);
    }
  }

  ////////////////////////////////////////////////////////////
  /// START WORK
  ////////////////////////////////////////////////////////////

  void _startWork() async {
    final locationReady = await _requestPermission();
    if (!locationReady) {
      setState(() => isWorking = false);
      return;
    }

    setState(() => isWorking = true);

    await _locationService.setWorkingStatus(user!.uid, working: true);

    _positionStream = _locationService.watchPosition(
      onUpdate: (position, insideScope) async {
        final wasInScope = inScope;

        if (!mounted) return;

        setState(() {
          currentPosition = position;
          inScope = insideScope;
        });

        if (!insideScope && wasInScope && !hasOutOfScopeAlert) {
          hasOutOfScopeAlert = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.orange,
              content:
                  Text("คุณอยู่นอกพื้นที่ที่กำหนด กรุณากลับเข้าสู่เขตงาน"),
              duration: Duration(seconds: 4),
            ),
          );
        } else if (insideScope) {
          hasOutOfScopeAlert = false;
        }

        await _locationService.updateLiveLocation(
          uid: user!.uid,
          name: name,
          email: user!.email,
          position: position,
          inScope: insideScope,
        );
      },
    );
  }

  ////////////////////////////////////////////////////////////
  /// STOP WORK
  ////////////////////////////////////////////////////////////

  void _stopWork() async {
    await _positionStream?.cancel();
    await _locationService.markInactive(user!.uid);
    await _locationService.setWorkingStatus(user!.uid, working: false);
    setState(() => isWorking = false);
  }

  ////////////////////////////////////////////////////////////
  /// SOS
  ////////////////////////////////////////////////////////////

  Future<void> _sendSOS() async {
    try {
      if (currentPosition == null) {
        final locationReady = await _requestPermission();
        if (!locationReady || currentPosition == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.orange,
              content: Text("ไม่พบตำแหน่ง GPS"),
            ),
          );
          return;
        }
      }

      final message = sosController.text.trim().isEmpty
          ? "เจ้าหน้าที่ต้องการความช่วยเหลือด่วน"
          : sosController.text.trim();

      await _locationService.sendSOS(
        uid: user!.uid,
        name: name,
        email: user!.email,
        position: currentPosition!,
        message: message,
      );

      sosController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text("ส่ง SOS ไปยังแอดมินแล้ว"),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange,
          content: Text("เกิดข้อผิดพลาด : $e"),
        ),
      );
    }
  }

  ////////////////////////////////////////////////////////////
  /// DISPOSE
  ////////////////////////////////////////////////////////////

  @override
  void dispose() {
    _positionStream?.cancel();
    sosController.dispose();
    super.dispose();
  }

  ////////////////////////////////////////////////////////////
  /// UI
  ////////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    final distanceToCenter = currentPosition == null
        ? 0.0
        : _locationService.distanceToCenter(currentPosition!);

    final locationStatus = currentPosition == null
        ? "Waiting for GPS..."
        : "${_formatDistance(distanceToCenter)} from center";

    final zoneLabel = inScope ? "Inside patrol zone" : "Outside patrol zone";
    final zoneColor = inScope ? Colors.green : Colors.red;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        title: const Text("GUARD PANEL"),
        actions: [
          IconButton(
            onPressed: () async => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(zoneLabel, zoneColor),
              const SizedBox(height: 22),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  GuardStatCard(
                    icon: Icons.map,
                    title: "Patrol Zone",
                    value:
                        "${_formatDistance(GuardConstants.scopeRadiusMeters)} radius",
                  ),
                  GuardStatCard(
                    icon: Icons.location_on,
                    title: "Distance",
                    value: locationStatus,
                  ),
                  GuardStatCard(
                    icon: Icons.check_circle,
                    title: "Checkpoints",
                    value: "$checkInCount logged",
                  ),
                  GuardStatCard(
                    icon: Icons.history,
                    title: "Last Check-in",
                    value: lastCheckIn,
                    minWidth: 170,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                "Live Patrol Map",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _buildMap(),
              const SizedBox(height: 24),
              _buildQuickActions(),
              const SizedBox(height: 22),
              _buildHintCard(),
              const SizedBox(height: 24),
              if (currentPosition != null)
                _buildLocationCard(zoneLabel, zoneColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String zoneLabel, Color zoneColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.red, Colors.black],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const CircleAvatar(
            radius: 48,
            backgroundColor: Colors.white,
            child: Icon(Icons.security, size: 52, color: Colors.red),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            user?.email ?? "",
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: isWorking ? Colors.green : Colors.white24,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              isWorking ? "On Duty" : "Offline",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            zoneLabel,
            style: TextStyle(
              color: zoneColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 260,
        child: currentPosition == null
            ? Container(
                color: Colors.white,
                child: Center(
                  child: Text(
                    "Waiting for GPS signal...",
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ),
              )
            : GoogleMap(
                onMapCreated: (controller) => guardMapController = controller,
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    currentPosition!.latitude,
                    currentPosition!.longitude,
                  ),
                  zoom: 16,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId("guard_position"),
                    position: LatLng(
                      currentPosition!.latitude,
                      currentPosition!.longitude,
                    ),
                    infoWindow: const InfoWindow(title: "Your Location"),
                  ),
                },
                circles: {
                  Circle(
                    circleId: const CircleId("scope_zone"),
                    center: GuardConstants.scopeCenter,
                    radius: GuardConstants.scopeRadiusMeters,
                    fillColor: Colors.red.withOpacity(0.12),
                    strokeColor: Colors.redAccent,
                    strokeWidth: 2,
                  ),
                },
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                myLocationEnabled: false,
              ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Quick Actions",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: isWorking ? Colors.grey : Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: Icon(isWorking ? Icons.stop : Icons.play_arrow),
                    label: Text(
                      isWorking ? "End Shift" : "Start Shift",
                      style: const TextStyle(fontSize: 16),
                    ),
                    onPressed: isWorking ? _stopWork : _startWork,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.blueGrey.shade900,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.flag),
                    label: Text(
                      isLoggingCheckpoint ? "Logging..." : "Check-in",
                      style: const TextStyle(fontSize: 16),
                    ),
                    onPressed: isLoggingCheckpoint ? null : _recordCheckpoint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => showGuardSosSheet(
                  context: context,
                  controller: sosController,
                  onSend: _sendSOS,
                ),
                icon: const Icon(Icons.warning),
                label: const Text(
                  "EMERGENCY REPORT",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHintCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.black54),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Tap Emergency Report to describe the incident, attach location details, and notify the admin with one modern flow.",
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(String zoneLabel, Color zoneColor) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ListTile(
        leading: const Icon(Icons.location_on, color: Colors.red),
        title: const Text("Current Location"),
        subtitle: Text(
          "${currentPosition!.latitude.toStringAsFixed(6)}, ${currentPosition!.longitude.toStringAsFixed(6)}",
        ),
        trailing: Text(
          zoneLabel,
          style: TextStyle(color: zoneColor, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
