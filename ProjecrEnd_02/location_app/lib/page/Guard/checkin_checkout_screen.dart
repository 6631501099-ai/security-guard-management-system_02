import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'guard_constants.dart';
import 'guard_location_service.dart';
import 'guard_nav_helper.dart';
import 'guard_theme.dart';
import 'guard_bottom_nav.dart';

const _thaiWeekdays = [
  "วันจันทร์", "วันอังคาร", "วันพุธ", "วันพฤหัสบดี",
  "วันศุกร์", "วันเสาร์", "วันอาทิตย์",
];
const _thaiMonthsShort = [
  "ม.ค.", "ก.พ.", "มี.ค.", "เม.ย.", "พ.ค.", "มิ.ย.",
  "ก.ค.", "ส.ค.", "ก.ย.", "ต.ค.", "พ.ย.", "ธ.ค.",
];

String _formatThaiDate(DateTime d) {
  final weekday = _thaiWeekdays[d.weekday - 1];
  final month = _thaiMonthsShort[d.month - 1];
  final buddhistYear = d.year + 543;
  return "$weekday, ${d.day} $month $buddhistYear";
}

String _two(int n) => n.toString().padLeft(2, '0');
String _formatTime(DateTime d) => "${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}";
String _formatClock(DateTime d) => "${_two(d.hour)}:${_two(d.minute)} น.";

/// Check In/Out screen — restores the real GPS/Firebase logic from the
/// original guard_page.dart (permission, live position stream, checkpoint
/// logging, working-status toggle) inside the new mockup-matching UI.
///
/// IMPORTANT: `_positionStream`/`_heartbeatTimer` live on this widget's
/// State, so they stop the moment this screen is disposed — which
/// happens whenever the guard navigates away (back button OR switching
/// bottom-nav tabs, since `navigateToTab` uses `pushReplacement`). To
/// avoid silently losing live tracking for the rest of the shift, this
/// screen re-reads the guard's real `working`/`shiftStart` state from
/// Firestore on `initState` and re-attaches tracking if a shift is
/// already in progress, instead of always assuming "not working".
class CheckInOutScreen extends StatefulWidget {
  const CheckInOutScreen({super.key});

  @override
  State<CheckInOutScreen> createState() => _CheckInOutScreenState();
}

class _CheckInOutScreenState extends State<CheckInOutScreen> {
  final GuardLocationService _locationService = GuardLocationService();
  final User? _user = FirebaseAuth.instance.currentUser;

  int _navIndex = 0;
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  StreamSubscription<Position>? _positionStream;
  Timer? _heartbeatTimer;
  GoogleMapController? _mapController;

  bool _isWorking = false;
  bool _inScope = true;
  bool _busy = false;
  bool _restoring = true;
  Position? _currentPosition;
  String _name = "";
  DateTime? _shiftStart;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _loadProfile();
    _primeLocation();
    _restoreShiftState();
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _positionStream?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (_user == null) return;
    final name = await _locationService.fetchUserName(_user.uid);
    if (mounted) setState(() => _name = name);
  }

  /// Gets an initial fix so the map/zone status has something to show
  /// even before the guard starts a shift.
  Future<void> _primeLocation() async {
    final result = await _locationService.requestPermission();
    if (!mounted) return;
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange,
          content: Text(result.errorMessage ?? "ไม่สามารถเข้าถึงตำแหน่งได้"),
        ),
      );
      return;
    }
    setState(() {
      _currentPosition = result.position;
      _inScope = _locationService.distanceToCenter(result.position!) <=
          GuardConstants.scopeRadiusMeters;
    });
  }

  /// Checks whether this guard is already mid-shift (per Firestore) and,
  /// if so, restores `_isWorking`/`_shiftStart` and re-attaches the
  /// position stream + heartbeat instead of showing "เข้างาน" as if
  /// nothing were happening.
  Future<void> _restoreShiftState() async {
    if (_user == null) {
      if (mounted) setState(() => _restoring = false);
      return;
    }
    final working = await _locationService.fetchWorkingStatus(_user.uid);
    if (!working) {
      if (mounted) setState(() => _restoring = false);
      return;
    }
    final shiftStart = await _locationService.fetchShiftStart(_user.uid);
    if (!mounted) return;
    _attachTracking();
    setState(() {
      _isWorking = true;
      _shiftStart = shiftStart ?? DateTime.now();
      _restoring = false;
    });
  }

  Future<void> _toggleShift() async {
    if (_user == null || _busy) return;
    setState(() => _busy = true);

    try {
      if (_isWorking) {
        await _endShift();
      } else {
        await _startShift();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Shared by both a fresh check-in and `_restoreShiftState` resuming an
  /// already-active shift: attaches the live position stream and the
  /// heartbeat timer that keep `locations/{uid}` fresh for the admin
  /// dashboard.
  void _attachTracking() {
    _positionStream?.cancel();
    _positionStream = _locationService.watchPosition(
      onUpdate: (pos, insideScope) async {
        if (!mounted || _user == null) return;
        final wasInScope = _inScope;
        setState(() {
          _currentPosition = pos;
          _inScope = insideScope;
        });
        if (!insideScope && wasInScope) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.orange,
              content: Text("คุณอยู่นอกพื้นที่ที่กำหนด กรุณากลับเข้าสู่เขตงาน"),
              duration: Duration(seconds: 4),
            ),
          );
        }
        await _locationService.updateLiveLocation(
          uid: _user.uid,
          name: _name,
          email: _user.email,
          position: pos,
          inScope: insideScope,
        );
      },
    );

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_currentPosition == null || _user == null) return;
      await _locationService.updateLiveLocation(
        uid: _user.uid,
        name: _name,
        email: _user.email,
        position: _currentPosition!,
        inScope: _inScope,
      );
    });
  }

  Future<void> _startShift() async {
    final result = await _locationService.requestPermission();
    if (!mounted) return;

    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange,
          content: Text(result.errorMessage ?? "ไม่พบตำแหน่ง GPS"),
        ),
      );
      return;
    }

    final position = result.position!;
    final inScope = _locationService.distanceToCenter(position) <=
        GuardConstants.scopeRadiusMeters;

    await _locationService.setWorkingStatus(_user!.uid, working: true);
    await _locationService.markShiftStarted(_user.uid);
    await _locationService.logCheckpoint(
      uid: _user.uid,
      name: _name,
      email: _user.email,
      position: position,
      inScope: inScope,
    );
    await _locationService.updateLiveLocation(
      uid: _user.uid,
      name: _name,
      email: _user.email,
      position: position,
      inScope: inScope,
    );

    _attachTracking();

    if (!mounted) return;
    setState(() {
      _isWorking = true;
      _currentPosition = position;
      _inScope = inScope;
      _shiftStart = DateTime.now();
    });

    await _locationService.logActivity(
      uid: _user.uid,
      iconKey: 'checkin',
      title: 'เข้างาน',
      subtitle: 'Duty commenced',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: GuardTheme.green,
        content: Text("เข้างานสำเร็จ"),
      ),
    );
  }

  Future<void> _endShift() async {
    await _positionStream?.cancel();
    _positionStream = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;

    if (_currentPosition != null) {
      await _locationService.logCheckpoint(
        uid: _user!.uid,
        name: _name,
        email: _user.email,
        position: _currentPosition!,
        inScope: _inScope,
      );
    }

    await _locationService.markInactive(_user!.uid);
    await _locationService.setWorkingStatus(_user.uid, working: false);
    await _locationService.logActivity(
      uid: _user.uid,
      iconKey: 'checkout',
      title: 'ออกงาน',
      subtitle: 'Duty ended',
    );

    if (!mounted) return;
    setState(() {
      _isWorking = false;
      _shiftStart = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: GuardTheme.primaryRed,
        content: Text("ออกงานแล้ว"),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _formatThaiDate(_now);
    final timeLabel = _formatTime(_now);
    final workedDuration = _shiftStart == null
        ? "0 น."
        : _now.difference(_shiftStart!).toString().split('.').first;

    return Scaffold(
      backgroundColor: GuardTheme.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
              decoration: const BoxDecoration(
                color: GuardTheme.primaryRed,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Text("การเข้างาน", style: GuardTheme.screenTitle),
                            Text(dateLabel,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    timeLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: SizedBox(
                        height: 180,
                        child: _currentPosition == null
                            ? Container(
                                color: const Color(0xFFE6EAE6),
                                alignment: Alignment.center,
                                child: const Text(
                                  "กำลังค้นหาตำแหน่ง GPS...",
                                  style: TextStyle(color: GuardTheme.textGrey),
                                ),
                              )
                            : GoogleMap(
                                onMapCreated: (c) => _mapController = c,
                                initialCameraPosition: CameraPosition(
                                  target: LatLng(_currentPosition!.latitude,
                                      _currentPosition!.longitude),
                                  zoom: 16,
                                ),
                                markers: {
                                  Marker(
                                    markerId: const MarkerId("me"),
                                    position: LatLng(_currentPosition!.latitude,
                                        _currentPosition!.longitude),
                                  ),
                                },
                                circles: {
                                  Circle(
                                    circleId: const CircleId("zone"),
                                    center: GuardConstants.scopeCenter,
                                    radius: GuardConstants.scopeRadiusMeters,
                                    fillColor: GuardTheme.primaryRed
                                        .withOpacity(0.12),
                                    strokeColor: GuardTheme.primaryRed,
                                    strokeWidth: 2,
                                  ),
                                },
                                myLocationEnabled: false,
                                zoomControlsEnabled: false,
                                mapToolbarEnabled: false,
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        _inScope ? "Within Zone" : "Outside Zone",
                        style: TextStyle(
                          color: _inScope ? GuardTheme.green : GuardTheme.primaryRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: GestureDetector(
                        onTap: (_busy || _restoring) ? null : _toggleShift,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isWorking
                                ? Colors.grey.shade300
                                : GuardTheme.primaryRed.withOpacity(0.12),
                            border: Border.all(
                              color: GuardTheme.primaryRed,
                              width: 3,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: (_busy || _restoring)
                              ? const CircularProgressIndicator(
                                  color: GuardTheme.primaryRed)
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _isWorking
                                          ? Icons.logout
                                          : Icons.fingerprint,
                                      size: 40,
                                      color: GuardTheme.primaryRed,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _isWorking ? "ออกงาน" : "เข้างาน",
                                      style: const TextStyle(
                                        color: GuardTheme.primaryRed,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        "แตะเพื่อยืนยันการเข้างาน",
                        style: TextStyle(fontSize: 12, color: GuardTheme.textGrey),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: GuardTheme.cardDecoration(radius: 18),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _summaryStat("เวลาเข้า",
                              _shiftStart == null ? "-" : _formatClock(_shiftStart!)),
                          _summaryStat("ระยะเวลา", workedDuration),
                          _summaryStat(
                              "สถานะ", _isWorking ? "กำลังปฏิบัติงาน" : "ยังไม่เข้างาน"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text("ประวัติการเข้างาน", style: GuardTheme.sectionTitle),
                    const SizedBox(height: 12),
                    if (_user == null)
                      const Text("กรุณาเข้าสู่ระบบ",
                          style: TextStyle(color: GuardTheme.textGrey))
                    else
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream:
                            _locationService.watchCheckpointHistory(_user.uid),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final docs = snapshot.data!.docs;
                          if (docs.isEmpty) {
                            return const Text("ยังไม่มีประวัติการเข้างาน",
                                style: TextStyle(color: GuardTheme.textGrey));
                          }
                          return Column(
                            children: docs.map((doc) {
                              final data = doc.data();
                              final ts = data['timestamp'] as Timestamp?;
                              final inScope = data['inScope'] as bool? ?? true;
                              final timeLabel = ts == null
                                  ? "-"
                                  : _formatClock(ts.toDate());
                              return _historyTile(inScope, timeLabel);
                            }).toList(),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: GuardBottomNav(
        currentIndex: _navIndex,
        onTap: (i) {
          if (i == _navIndex) return;
          navigateToTab(context, i);
        },
      ),
    );
  }

  Widget _summaryStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: GuardTheme.textGrey)),
      ],
    );
  }

  Widget _historyTile(bool inScope, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: GuardTheme.cardDecoration(radius: 16),
      child: Row(
        children: [
          Icon(
            inScope ? Icons.check_circle_outline : Icons.error_outline,
            color: inScope ? GuardTheme.green : GuardTheme.primaryRed,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(inScope ? "บันทึกตำแหน่ง (ในพื้นที่)" : "บันทึกตำแหน่ง (นอกพื้นที่)",
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Text(time, style: const TextStyle(fontSize: 12, color: GuardTheme.textGrey)),
        ],
      ),
    );
  }
}
