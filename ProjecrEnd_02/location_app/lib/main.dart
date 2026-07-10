import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'firebase_options.dart';
import 'admin_dashboard.dart';
////////////////////////////////////////////////////////////
/// MAIN
////////////////////////////////////////////////////////////

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

////////////////////////////////////////////////////////////
/// APP
////////////////////////////////////////////////////////////

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Firebase.apps.isEmpty
          ? Firebase.initializeApp(
              options: DefaultFirebaseOptions.currentPlatform,
            )
          : Future.value(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: "Security Guard System",
          theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.red),
          home: const AuthCheck(),
        );
      },
    );
  }
}

////////////////////////////////////////////////////////////
/// AUTH CHECK
////////////////////////////////////////////////////////////

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const RoleCheck();
        }

        return const LoginPage();
      },
    );
  }
}

////////////////////////////////////////////////////////////
/// ROLE CHECK
////////////////////////////////////////////////////////////

class RoleCheck extends StatelessWidget {
  const RoleCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const LoginPage();
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;

        final role = data?['role'] ?? 'guard';

        if (role == "admin") {
          return const AdminDashboard();
        }

        return const GuardPage();
      },
    );
  }
}

////////////////////////////////////////////////////////////
/// LOGIN PAGE
////////////////////////////////////////////////////////////

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();

  bool loading = false;

  Future<void> login() async {
    try {
      setState(() => loading = true);

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text.trim(),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Login ไม่สำเร็จ")));
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          ////////////////////////////////////////////////////////////
          /// BACKGROUND
          ////////////////////////////////////////////////////////////
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  "https://images.unsplash.com/photo-1519501025264-65ba15a82390",
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),

          Container(color: Colors.black.withOpacity(0.6)),

          ////////////////////////////////////////////////////////////
          /// CONTENT
          ////////////////////////////////////////////////////////////
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.security, size: 80, color: Colors.red),

                      const SizedBox(height: 20),

                      const Text(
                        "Security Guard System",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 30),

                      TextField(
                        controller: email,
                        decoration: InputDecoration(
                          hintText: "Email",
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      TextField(
                        controller: password,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: "Password",
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: loading ? null : login,
                          child: loading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  "LOGIN",
                                  style: TextStyle(fontSize: 18),
                                ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterPage(),
                            ),
                          );
                        },
                        child: const Text("Create Account"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// REGISTER PAGE
////////////////////////////////////////////////////////////

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();

  Future<void> register() async {
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email.text.trim(),
            password: password.text.trim(),
          );

      await FirebaseFirestore.instance
          .collection("users")
          .doc(credential.user!.uid)
          .set({
            "name": name.text.trim(),
            "email": email.text.trim(),
            "role": "guard",
            "status": "offline",
          });

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("สมัครสมาชิกไม่สำเร็จ")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: "ชื่อ"),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: "Email"),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Password"),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: register,
                child: const Text("REGISTER"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// ADMIN PAGE
////////////////////////////////////////////////////////////

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        title: const Text("ADMIN DASHBOARD"),
        actions: [
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("locations")
            .where("isActive", isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          Set<Marker> markers = {};

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;

            markers.add(
              Marker(
                markerId: MarkerId(doc.id),
                position: LatLng(data['lat'], data['lng']),
                infoWindow: InfoWindow(
                  title: data['name'] ?? "",
                  snippet: data['email'] ?? "",
                ),
              ),
            );
          }

          return Stack(
            children: [
              ////////////////////////////////////////////////////////////
              /// MAP
              ////////////////////////////////////////////////////////////
              GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: LatLng(13.736717, 100.523186),
                  zoom: 6,
                ),
                markers: markers,
              ),

              ////////////////////////////////////////////////////////////
              /// ONLINE GUARDS
              ////////////////////////////////////////////////////////////
              Positioned(
                top: 20,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "ONLINE GUARDS : ${docs.length}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// GUARD PAGE
////////////////////////////////////////////////////////////

class GuardPage extends StatefulWidget {
  const GuardPage({super.key});

  @override
  State<GuardPage> createState() => _GuardPageState();
}

class _GuardPageState extends State<GuardPage> {
  StreamSubscription<Position>? stream;

  bool isWorking = false;
  bool inScope = true;
  bool hasOutOfScopeAlert = false;
  bool isLoggingCheckpoint = false;

  Position? currentPosition;

  User? user;

  String name = "";
  String lastCheckIn = "No checkpoint logged yet";
  int checkInCount = 0;

  final LatLng scopeCenter = const LatLng(13.736717, 100.523186);
  final double scopeRadiusMeters = 1000;

  GoogleMapController? guardMapController;

  final TextEditingController sosController = TextEditingController();

  @override
  void initState() {
    super.initState();

    user = FirebaseAuth.instance.currentUser;

    loadProfile();

    requestPermission();
  }

  ////////////////////////////////////////////////////////////
  /// LOAD PROFILE
  ////////////////////////////////////////////////////////////

  Future<void> loadProfile() async {
    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .get();

    final data = doc.data();

    if (data != null) {
      setState(() {
        name = data['name'] ?? "";
      });
    }
  }

  ////////////////////////////////////////////////////////////
  /// PERMISSION
  ////////////////////////////////////////////////////////////

  Future<bool> requestPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text("GPS is off. Please enable location services."),
          ),
        );
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.orange,
            content: Text(
              "Location permission is required to track the guard.",
            ),
          ),
        );
        return false;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return false;
      setState(() {
        currentPosition = position;
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text("Unable to get GPS location yet. Please try again."),
        ),
      );
      return false;
    }
  }

  ////////////////////////////////////////////////////////////
  /// SCOPE CHECK
  ////////////////////////////////////////////////////////////

  bool checkInScope(Position position) {
    final distance = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      scopeCenter.latitude,
      scopeCenter.longitude,
    );

    return distance <= scopeRadiusMeters;
  }

  String formatDistance(double meters) {
    if (meters >= 1000) {
      return "${(meters / 1000).toStringAsFixed(1)} km";
    }
    return "${meters.round()} m";
  }

  Future<void> recordCheckpoint() async {
    if (currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.orange,
          content: Text("ไม่พบตำแหน่ง GPS กรุณาลองใหม่อีกครั้ง"),
        ),
      );
      return;
    }

    setState(() {
      isLoggingCheckpoint = true;
    });

    try {
      final now = DateTime.now().toLocal();

      await FirebaseFirestore.instance.collection("patrol_logs").add({
        "uid": user!.uid,
        "name": name,
        "email": user!.email ?? "",
        "lat": currentPosition!.latitude,
        "lng": currentPosition!.longitude,
        "status": inScope ? "on_route" : "out_of_scope",
        "timestamp": FieldValue.serverTimestamp(),
      });

      setState(() {
        checkInCount += 1;
        lastCheckIn = now.toString().split('.').first;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text("Checkpoint logged successfully"),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange,
          content: Text("เกิดข้อผิดพลาดในการบันทึก : $e"),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoggingCheckpoint = false;
        });
      }
    }
  }

  ////////////////////////////////////////////////////////////
  /// START WORK
  ////////////////////////////////////////////////////////////

  void startWork() async {
    final locationReady = await requestPermission();
    if (!locationReady) {
      setState(() {
        isWorking = false;
      });
      return;
    }

    setState(() {
      isWorking = true;
    });

    await FirebaseFirestore.instance.collection("users").doc(user!.uid).update({
      "status": "working",
    });

    stream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((position) async {
          final insideScope = checkInScope(position);
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
                content: Text(
                  "คุณอยู่นอกพื้นที่ที่กำหนด กรุณากลับเข้าสู่เขตงาน",
                ),
                duration: Duration(seconds: 4),
              ),
            );
          } else if (insideScope) {
            hasOutOfScopeAlert = false;
          }

          await FirebaseFirestore.instance
              .collection("locations")
              .doc(user!.uid)
              .set({
                "name": name,
                "email": user!.email,

                "lat": position.latitude,
                "lng": position.longitude,

                //////////////////////////////////////////////////////
                /// ONLINE STATUS
                //////////////////////////////////////////////////////
                "isActive": true,
                "outOfScope": !insideScope,

                //////////////////////////////////////////////////////
                /// LAST UPDATE
                //////////////////////////////////////////////////////
                "lastUpdate": FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
        });
  }

  ////////////////////////////////////////////////////////////
  /// STOP WORK
  ////////////////////////////////////////////////////////////

  void stopWork() async {
    await stream?.cancel();

    await FirebaseFirestore.instance
        .collection("locations")
        .doc(user!.uid)
        .update({"isActive": false});

    await FirebaseFirestore.instance.collection("users").doc(user!.uid).update({
      "status": "offline",
    });

    setState(() {
      isWorking = false;
    });
  }

  ////////////////////////////////////////////////////////////
  /// SOS
  ////////////////////////////////////////////////////////////

  Future<void> sendSOS() async {
    try {
      ////////////////////////////////////////////////////////////
      /// CHECK LOCATION
      ////////////////////////////////////////////////////////////

      if (currentPosition == null) {
        final locationReady = await requestPermission();
        if (!locationReady || currentPosition == null) {
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

      ////////////////////////////////////////////////////////////
      /// SEND SOS
      ////////////////////////////////////////////////////////////

      await FirebaseFirestore.instance.collection("sos").add({
        "uid": user!.uid,
        "name": name,
        "email": user!.email ?? "",
        "lat": currentPosition!.latitude,
        "lng": currentPosition!.longitude,
        "status": "pending",
        "message": message,
        "imageUrl": "",
        "timestamp": FieldValue.serverTimestamp(),
      });

      sosController.clear();

      ////////////////////////////////////////////////////////////
      /// SUCCESS
      ////////////////////////////////////////////////////////////

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text("ส่ง SOS ไปยังแอดมินแล้ว"),
        ),
      );
    } catch (e) {
      ////////////////////////////////////////////////////////////
      /// ERROR
      ////////////////////////////////////////////////////////////

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.orange,
          content: Text("เกิดข้อผิดพลาด : $e"),
        ),
      );
    }
  }

  void _showSosSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        bool isSending = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
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
                  const SizedBox(height: 16),
                  const Text(
                    "Emergency Report",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Describe the situation and send an SOS to the admin.",
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: sosController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: "Enter details about the incident...",
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      icon: const Icon(Icons.send),
                      label: Text(isSending ? "Sending..." : "Send SOS"),
                      onPressed: isSending
                          ? null
                          : () async {
                              setState(() {
                                isSending = true;
                              });
                              await sendSOS();
                              setState(() {
                                isSending = false;
                              });
                              Navigator.pop(context);
                            },
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  ////////////////////////////////////////////////////////////
  /// DISPOSE
  ////////////////////////////////////////////////////////////

  @override
  void dispose() {
    stream?.cancel();
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
        : Geolocator.distanceBetween(
            currentPosition!.latitude,
            currentPosition!.longitude,
            scopeCenter.latitude,
            scopeCenter.longitude,
          );

    final locationStatus = currentPosition == null
        ? "Waiting for GPS..."
        : "${formatDistance(distanceToCenter)} from center";

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
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
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
              Container(
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
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
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
              ),

              const SizedBox(height: 22),

              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildStatCard(
                    icon: Icons.map,
                    title: "Patrol Zone",
                    value: "${formatDistance(scopeRadiusMeters)} radius",
                  ),
                  _buildStatCard(
                    icon: Icons.location_on,
                    title: "Distance",
                    value: locationStatus,
                  ),
                  _buildStatCard(
                    icon: Icons.check_circle,
                    title: "Checkpoints",
                    value: "$checkInCount logged",
                  ),
                  _buildStatCard(
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
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 260,
                  child: currentPosition == null
                      ? Container(
                          color: Colors.white,
                          child: Center(
                            child: Text(
                              "Waiting for GPS signal...",
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        )
                      : GoogleMap(
                          onMapCreated: (controller) {
                            guardMapController = controller;
                          },
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
                              infoWindow: const InfoWindow(
                                title: "Your Location",
                              ),
                            ),
                          },
                          circles: {
                            Circle(
                              circleId: const CircleId("scope_zone"),
                              center: scopeCenter,
                              radius: scopeRadiusMeters,
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
              ),

              const SizedBox(height: 24),

              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Quick Actions",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: isWorking
                                    ? Colors.grey
                                    : Colors.green,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              icon: Icon(
                                isWorking ? Icons.stop : Icons.play_arrow,
                              ),
                              label: Text(
                                isWorking ? "End Shift" : "Start Shift",
                                style: const TextStyle(fontSize: 16),
                              ),
                              onPressed: isWorking ? stopWork : startWork,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.blueGrey.shade900,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              icon: const Icon(Icons.flag),
                              label: Text(
                                isLoggingCheckpoint ? "Logging..." : "Check-in",
                                style: const TextStyle(fontSize: 16),
                              ),
                              onPressed: isLoggingCheckpoint
                                  ? null
                                  : recordCheckpoint,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: _showSosSheet,
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
              ),

              const SizedBox(height: 22),

              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.black54),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Tap Emergency Report to describe the incident, attach location details, and notify the admin with one modern flow.",
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              if (currentPosition != null)
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.location_on, color: Colors.red),
                    title: const Text("Current Location"),
                    subtitle: Text(
                      "${currentPosition!.latitude.toStringAsFixed(6)}, ${currentPosition!.longitude.toStringAsFixed(6)}",
                    ),
                    trailing: Text(
                      zoneLabel,
                      style: TextStyle(
                        color: zoneColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    double minWidth = 150,
  }) {
    return Container(
      width: minWidth,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.red, size: 28),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
