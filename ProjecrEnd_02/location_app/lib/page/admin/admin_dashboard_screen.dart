import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'admin_theme.dart';
import 'admin_sidebar_nav_item.dart';
import 'admin_guards_screen.dart';
import 'admin_logs_screen.dart';
import 'admin_overview_screen.dart';
import 'admin_sos_screen.dart';
import 'admin_tracking_screen.dart';
import 'admin_schedule_screen.dart';
import 'admin_tasks_screen.dart';
import 'admin_incidents_screen.dart';

/// Admin control center: sidebar navigation + Overview / Live Tracking /
/// SOS Alerts / Guards / Schedule / Tasks / Incidents / Logs sections.
/// This file only owns layout and shared state (search text, active
/// section, sidebar width, focused-guard map target) — each section's
/// content lives in its own file under screens/sections/.
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String _search = "";
  String _selectedSection = "overview";
  bool _isSidebarExpanded = false;
  LatLng? _focusedGuardLocation;
  String? _focusedGuardName;
  GoogleMapController? _mapController;

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  void _goToSection(String section) {
    setState(() => _selectedSection = section);
  }

  /// Passed down to sections/sheets so they can jump to a guard's location
  /// on the Live Tracking map without needing to know about sidebar state.
  void _focusGuard(LatLng location, String? label) {
    setState(() {
      _selectedSection = "tracking";
      _focusedGuardLocation = location;
      _focusedGuardName = label;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(location, 16));
    });
  }

  @override
  Widget build(BuildContext context) {
    final sidebarWidth = _isSidebarExpanded ? 240.0 : 84.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(_sectionTitle(), style: AppText.sectionTitle),
        leading: IconButton(
          tooltip: _isSidebarExpanded ? 'Collapse menu' : 'Expand menu',
          icon: Icon(
            _isSidebarExpanded ? Icons.close_fullscreen : Icons.menu_open,
          ),
          onPressed: () {
            setState(() => _isSidebarExpanded = !_isSidebarExpanded);
          },
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            width: sidebarWidth,
            decoration: const BoxDecoration(gradient: AppColors.sidebarGradient),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.security,
                    color: AppColors.accentRed,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 12),
                if (_isSidebarExpanded)
                  const Text(
                    "MFU SECURITY",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  )
                else
                  const SizedBox(height: 18),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SidebarNavItem(
                          icon: Icons.dashboard,
                          title: "Overview",
                          active: _selectedSection == "overview",
                          expanded: _isSidebarExpanded,
                          onTap: () => _goToSection("overview"),
                        ),
                        SidebarNavItem(
                          icon: Icons.map,
                          title: "Live Tracking",
                          active: _selectedSection == "tracking",
                          expanded: _isSidebarExpanded,
                          onTap: () => _goToSection("tracking"),
                        ),
                        SidebarNavItem(
                          icon: Icons.warning,
                          title: "SOS Alerts",
                          active: _selectedSection == "sos",
                          expanded: _isSidebarExpanded,
                          onTap: () => _goToSection("sos"),
                        ),
                        SidebarNavItem(
                          icon: Icons.people,
                          title: "Guards",
                          active: _selectedSection == "guards",
                          expanded: _isSidebarExpanded,
                          onTap: () => _goToSection("guards"),
                        ),
                        SidebarNavItem(
                          icon: Icons.calendar_month,
                          title: "ตารางงาน",
                          active: _selectedSection == "schedule",
                          expanded: _isSidebarExpanded,
                          onTap: () => _goToSection("schedule"),
                        ),
                        SidebarNavItem(
                          icon: Icons.assignment_turned_in,
                          title: "มอบหมายงาน",
                          active: _selectedSection == "tasks",
                          expanded: _isSidebarExpanded,
                          onTap: () => _goToSection("tasks"),
                        ),
                        SidebarNavItem(
                          icon: Icons.fact_check,
                          title: "รายงานเหตุการณ์",
                          active: _selectedSection == "incidents",
                          expanded: _isSidebarExpanded,
                          onTap: () => _goToSection("incidents"),
                        ),
                        SidebarNavItem(
                          icon: Icons.history,
                          title: "Logs",
                          active: _selectedSection == "logs",
                          expanded: _isSidebarExpanded,
                          onTap: () => _goToSection("logs"),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _isSidebarExpanded
                      ? SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.accentRed,
                              minimumSize: const Size.fromHeight(44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                            ),
                            onPressed: _logout,
                            icon: const Icon(Icons.logout),
                            label: const Text("Logout"),
                          ),
                        )
                      : IconButton.filledTonal(
                          onPressed: _logout,
                          tooltip: 'Logout',
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(
                              Colors.white,
                            ),
                          ),
                          icon: const Icon(
                            Icons.logout,
                            color: AppColors.accentRed,
                          ),
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

  String _sectionTitle() {
    switch (_selectedSection) {
      case 'tracking':
        return 'Live Tracking';
      case 'sos':
        return 'SOS Alerts';
      case 'guards':
        return 'Guards';
      case 'schedule':
        return 'ตารางงาน';
      case 'tasks':
        return 'มอบหมายงาน';
      case 'incidents':
        return 'รายงานเหตุการณ์';
      case 'logs':
        return 'Recent Logs';
      default:
        return 'Admin Dashboard';
    }
  }

  Widget _buildSectionContent() {
    switch (_selectedSection) {
      case 'tracking':
        return TrackingSection(
          search: _search,
          onSearchChanged: (v) => setState(() => _search = v),
          focusedGuardLocation: _focusedGuardLocation,
          focusedGuardName: _focusedGuardName,
          onMapCreated: (controller) => _mapController = controller,
        );
      case 'sos':
        return SosSection(onLocate: _focusGuard);
      case 'guards':
        return GuardsSection(
          search: _search,
          onSearchChanged: (v) => setState(() => _search = v),
          onLocate: _focusGuard,
        );
      case 'schedule':
        return const AdminScheduleSection();
      case 'tasks':
        return const AdminTasksSection();
      case 'incidents':
        return const AdminIncidentsSection();
      case 'logs':
        return const LogsSection();
      default:
        return OverviewSection(onNavigate: _goToSection);
    }
  }
}
