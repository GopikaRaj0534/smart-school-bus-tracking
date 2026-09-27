import 'package:flutter/material.dart';

import 'package:routesafe/screens/admin/admin_analytics_screen.dart';
import 'package:routesafe/screens/admin/admin_history_screen.dart';
import 'package:routesafe/screens/admin/manage_buses_screen.dart';
import 'package:routesafe/screens/admin/manage_drivers_screen.dart';
import 'package:routesafe/screens/admin/manage_parents_screen.dart';
import 'package:routesafe/screens/admin/manage_routes_screen.dart';
import 'package:routesafe/screens/admin/manage_school_settings_screen.dart';
import 'package:routesafe/screens/admin/parent_child_assignment_screen.dart';
import 'package:routesafe/screens/admin/pending_driver_requests_screen.dart';
import 'package:routesafe/screens/admin/pending_parent_requests_screen.dart';
import 'package:routesafe/screens/auth/login_screen.dart';
import 'package:routesafe/services/api_service.dart';
import 'package:routesafe/utils/app_colors.dart';
import 'package:routesafe/utils/session_manager.dart';
import 'package:routesafe/widgets/stat_card.dart';
import 'package:routesafe/widgets/routesafe_logo.dart';

class AdminDashboard extends StatefulWidget {
  final String userName;

  const AdminDashboard({
    super.key,
    required this.userName,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int? totalBuses;
  int? totalDrivers;
  int? totalParents;
  int? totalStudents;
  int? activeTrips;
  int? pendingRequestsCount;
  int? pendingDriverRequestsCount;

  bool loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  // ============================================================
  // LOAD DASHBOARD STATISTICS
  // ============================================================

  Future<void> _loadStats() async {
    if (mounted) {
      setState(() {
        loadingStats = true;
      });
    }

    try {
      final res = await ApiService.getAdminDashboardMetrics();
      if (res['success'] == true) {
        if (!mounted) return;
        final metrics = res['metrics'] is Map ? Map<String, dynamic>.from(res['metrics']) : res;
        setState(() {
          totalBuses = (metrics['total_buses'] ?? res['total_buses']) as int? ?? 0;
          totalDrivers = (metrics['total_drivers'] ?? res['total_drivers']) as int? ?? 0;
          totalParents = (metrics['total_parents'] ?? res['total_parents']) as int? ?? 0;
          totalStudents = (metrics['total_students'] ?? res['total_students']) as int? ?? 0;
          activeTrips = (metrics['active_trips'] ?? res['active_trips']) as int? ?? 0;
          pendingRequestsCount = (metrics['pending_parents'] ?? res['pending_parents']) as int? ?? 0;
          pendingDriverRequestsCount = (metrics['pending_drivers'] ?? res['pending_drivers']) as int? ?? 0;
          loadingStats = false;
        });
        return;
      }
    } catch (_) {}

    // Fallback if unified metrics endpoint fails
    int busCount = 0;
    int driverCount = 0;
    int parentCount = 0;
    int pendingCount = 0;
    int pendingDriverCount = 0;

    try {
      final busesResult = await ApiService.getBuses();
      final buses = busesResult['buses'] as List<dynamic>?;
      if (buses != null) busCount = buses.length;
    } catch (_) {}

    try {
      final driversResult = await ApiService.getDriversCount();
      final drivers = driversResult['count'] as int?;
      if (drivers != null) driverCount = drivers;
    } catch (_) {}

    try {
      final parentsResult = await ApiService.getParentsCount();
      final parents = parentsResult['count'] as int?;
      if (parents != null) parentCount = parents;
    } catch (_) {}

    try {
      final pendingResult = await ApiService.getPendingParentCount();
      final pending = pendingResult['count'] as int?;
      if (pending != null) pendingCount = pending;
    } catch (_) {}

    try {
      final pendingDriverRes = await ApiService.getPendingDriverCount();
      final pDriver = pendingDriverRes['count'] as int?;
      if (pDriver != null) pendingDriverCount = pDriver;
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      totalBuses = busCount;
      totalDrivers = driverCount;
      totalParents = parentCount;
      pendingRequestsCount = pendingCount;
      pendingDriverRequestsCount = pendingDriverCount;
      loadingStats = false;
    });
  }

  Future<void> _openPendingRequests() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PendingParentRequestsScreen(),
      ),
    );
    _loadStats();
  }

  Future<void> _openPendingDriverRequests() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PendingDriverRequestsScreen(),
      ),
    );
    _loadStats();
  }

  Future<void> _openChildAssignment() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ParentChildAssignmentScreen(),
      ),
    );
    _loadStats();
  }

  Future<void> _openManageBuses() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ManageBusesScreen(),
      ),
    );
    _loadStats();
  }

  Future<void> _openManageDrivers() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ManageDriversScreen(),
      ),
    );
    _loadStats();
  }

  Future<void> _openManageParents() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ManageParentsScreen(),
      ),
    );
    _loadStats();
  }

  Future<void> _openManageRoutes() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ManageRoutesScreen(),
      ),
    );
    _loadStats();
  }

  Future<void> _openAdminHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminHistoryScreen(),
      ),
    );
    _loadStats();
  }

  Future<void> _openAdminAnalytics() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminAnalyticsScreen(),
      ),
    );
    _loadStats();
  }

  Future<void> _openSchoolSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ManageSchoolSettingsScreen(),
      ),
    );
    _loadStats();
  }

  Future<void> _logout(BuildContext context) async {
    await SessionManager.clearSession();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  Future<void> _showEmergencyAlertsDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text("Emergency Alerts"),
          ],
        ),
        content: FutureBuilder<Map<String, dynamic>>(
          future: ApiService.getAdminEmergencies(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || snapshot.data?['success'] != true) {
              return Text(
                snapshot.error?.toString().replaceFirst('Exception: ', '') ??
                    snapshot.data?['message']?.toString() ??
                    "Unable to load emergency reports.",
              );
            }

            final list = snapshot.data!['emergencies'] as List? ?? [];
            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text("No emergency alerts reported."),
              );
            }

            return SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final item = list[index] as Map<String, dynamic>;
                  final driverName = item['driver_name']?.toString() ?? 'Driver';
                  final driverPhone = item['driver_phone']?.toString() ?? '';
                  final message = item['message']?.toString() ?? '';
                  final time = item['created_at']?.toString() ?? '';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: AppColors.dangerLight.withOpacityCompat(0.3),
                    child: ListTile(
                      title: Text(
                        driverName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Phone: $driverPhone"),
                          const SizedBox(height: 4),
                          Text("Alert: $message",
                              style: const TextStyle(
                                  color: AppColors.danger,
                                  fontWeight: FontWeight.bold)),
                          Text("Time: $time",
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingTotal = (pendingRequestsCount ?? 0) + (pendingDriverRequestsCount ?? 0);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Row(
          children: [
            RouteSafeLogo(
              fontSize: 19,
              isDarkBackground: true,
              showIcon: false,
            ),
            SizedBox(width: 8),
            Text(
              'Admin Dashboard',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh Data',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStats,
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryDark,
                    AppColors.primary,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const RouteSafeLogo(
                    isDarkBackground: true,
                    fontSize: 22,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.userName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                  ),
                  const Text(
                    'Fleet Administrator',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.hourglass_top_rounded, color: AppColors.warning),
              title: Row(
                children: [
                  const Text('Pending Parents'),
                  if ((pendingRequestsCount ?? 0) > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${pendingRequestsCount ?? 0}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              onTap: () {
                Navigator.pop(context);
                _openPendingRequests();
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.warning),
              title: Row(
                children: [
                  const Text('Pending Drivers'),
                  if ((pendingDriverRequestsCount ?? 0) > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${pendingDriverRequestsCount ?? 0}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              onTap: () {
                Navigator.pop(context);
                _openPendingDriverRequests();
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
              title: const Text('Driver Emergency Alerts'),
              onTap: () {
                Navigator.pop(context);
                _showEmergencyAlertsDialog();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.directions_bus_rounded, color: AppColors.primary),
              title: const Text('Manage Buses'),
              onTap: () {
                Navigator.pop(context);
                _openManageBuses();
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_alt_rounded, color: AppColors.primary),
              title: const Text('Manage Drivers'),
              onTap: () {
                Navigator.pop(context);
                _openManageDrivers();
              },
            ),
            ListTile(
              leading: const Icon(Icons.family_restroom_rounded, color: AppColors.primary),
              title: const Text('Manage Parents'),
              onTap: () {
                Navigator.pop(context);
                _openManageParents();
              },
            ),
            ListTile(
              leading: const Icon(Icons.route_rounded, color: AppColors.primary),
              title: const Text('Manage Routes & Stops'),
              onTap: () {
                Navigator.pop(context);
                _openManageRoutes();
              },
            ),
            ListTile(
              leading: const Icon(Icons.school_rounded, color: AppColors.primary),
              title: const Text('School Settings'),
              onTap: () {
                Navigator.pop(context);
                _openSchoolSettings();
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment_ind_rounded, color: AppColors.primary),
              title: const Text('Link Parent & Child'),
              onTap: () {
                Navigator.pop(context);
                _openChildAssignment();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.history_rounded, color: AppColors.primary),
              title: const Text('Audit History & Logs'),
              onTap: () {
                Navigator.pop(context);
                _openAdminHistory();
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart_rounded, color: AppColors.primary),
              title: const Text('Analytics & Reports'),
              onTap: () {
                Navigator.pop(context);
                _openAdminAnalytics();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
              title: const Text('Logout'),
              onTap: () => _logout(context),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(
            18,
            18,
            18,
            18 + MediaQuery.of(context).padding.bottom + 40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Welcome Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacityCompat(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white24,
                          child: Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome, ${widget.userName}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'RouteSafe Fleet Control Center',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (pendingTotal > 0) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacityCompat(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.warning.withOpacityCompat(0.5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_active_rounded, color: AppColors.warning, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$pendingTotal pending approval request(s) require action',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Overview Section Title
              const Text(
                'Fleet Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Live snapshot of school transport network',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),

              // Metric Stat Cards Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.15,
                children: [
                  StatCard(
                    icon: Icons.directions_bus_rounded,
                    title: 'Total Buses',
                    value: loadingStats ? '…' : '${totalBuses ?? 0}',
                    color: AppColors.primary,
                    backgroundColor: AppColors.primaryLight,
                  ),
                  StatCard(
                    icon: Icons.person_rounded,
                    title: 'Drivers',
                    value: loadingStats ? '…' : '${totalDrivers ?? 0}',
                    color: AppColors.skyBlue,
                    backgroundColor: AppColors.primaryLight,
                  ),
                  StatCard(
                    icon: Icons.people_rounded,
                    title: 'Parents',
                    value: loadingStats ? '…' : '${totalParents ?? 0}',
                    color: AppColors.success,
                    backgroundColor: AppColors.successLight,
                  ),
                  StatCard(
                    icon: Icons.face_rounded,
                    title: 'Students',
                    value: loadingStats ? '…' : '${totalStudents ?? 0}',
                    color: AppColors.skyBlue,
                    backgroundColor: AppColors.primaryLight,
                  ),
                  StatCard(
                    icon: Icons.alt_route_rounded,
                    title: 'Active Trips',
                    value: loadingStats ? '…' : '${activeTrips ?? 0}',
                    color: AppColors.primary,
                    backgroundColor: AppColors.primaryLight,
                  ),
                  InkWell(
                    onTap: _openPendingDriverRequests,
                    child: StatCard(
                      icon: Icons.person_add_alt_1_rounded,
                      title: 'Pending Drivers',
                      value: loadingStats ? '…' : '${pendingDriverRequestsCount ?? 0}',
                      color: AppColors.warning,
                      backgroundColor: AppColors.warningLight,
                    ),
                  ),
                  InkWell(
                    onTap: _openPendingRequests,
                    child: StatCard(
                      icon: Icons.hourglass_top_rounded,
                      title: 'Pending Parents',
                      value: loadingStats ? '…' : '${pendingRequestsCount ?? 0}',
                      color: AppColors.warning,
                      backgroundColor: AppColors.warningLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Interactive Analytics Preview Action Banner
              InkWell(
                onTap: _openAdminAnalytics,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryLight,
                        Colors.blue.shade50,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.primary.withOpacityCompat(0.3), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Interactive Fleet Analytics & Charts',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'View student boarding pie chart, trip completion rates & fleet utilization',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.primary, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 26),

              // Quick Actions Section Title
              const Text(
                'Quick Actions & Management',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              InfoTile(
                icon: Icons.person_add_alt_1_rounded,
                title: 'Pending Driver Approvals',
                subtitle: (pendingDriverRequestsCount ?? 0) > 0
                    ? '$pendingDriverRequestsCount driver request(s) awaiting approval'
                    : 'Review driver registration requests',
                color: AppColors.warning,
                backgroundColor: AppColors.warningLight,
                onTap: _openPendingDriverRequests,
              ),
              InfoTile(
                icon: Icons.hourglass_top_rounded,
                title: 'Pending Parent Approvals',
                subtitle: (pendingRequestsCount ?? 0) > 0
                    ? '$pendingRequestsCount parent request(s) awaiting approval'
                    : 'Review parent registration requests',
                color: AppColors.warning,
                backgroundColor: AppColors.warningLight,
                onTap: _openPendingRequests,
              ),
              InfoTile(
                icon: Icons.school_rounded,
                title: 'School Settings',
                subtitle: 'Manage fixed school location, coordinates & destination point',
                color: AppColors.primary,
                backgroundColor: AppColors.primaryLight,
                onTap: _openSchoolSettings,
              ),
              InfoTile(
                icon: Icons.route_rounded,
                title: 'Manage Routes & Pickup Stops',
                subtitle: 'Add, edit, or remove routes and GPS pickup points',
                color: AppColors.skyBlue,
                backgroundColor: AppColors.primaryLight,
                onTap: _openManageRoutes,
              ),
              InfoTile(
                icon: Icons.assignment_ind_rounded,
                title: 'Link Parent & Student / Assign Bus',
                subtitle: 'Link parents to children and assign bus & pickup stop',
                color: AppColors.primary,
                backgroundColor: AppColors.primaryLight,
                onTap: _openChildAssignment,
              ),
              InfoTile(
                icon: Icons.directions_bus_rounded,
                title: 'Manage Buses',
                subtitle: 'Add, edit, or remove buses and driver assignments',
                color: AppColors.primary,
                backgroundColor: AppColors.primaryLight,
                onTap: _openManageBuses,
              ),
              InfoTile(
                icon: Icons.people_rounded,
                title: 'Manage Drivers',
                subtitle: 'Manage active drivers & licenses',
                color: AppColors.skyBlue,
                backgroundColor: AppColors.primaryLight,
                onTap: _openManageDrivers,
              ),
              InfoTile(
                icon: Icons.family_restroom_rounded,
                title: 'Manage Parents',
                subtitle: 'View and manage parent accounts & linked children',
                color: AppColors.success,
                backgroundColor: AppColors.successLight,
                onTap: _openManageParents,
              ),
              InfoTile(
                icon: Icons.history_rounded,
                title: 'Audit History & Tracking Logs',
                subtitle: 'View trip logs, boarding history & assignment changes',
                color: AppColors.primary,
                backgroundColor: AppColors.primaryLight,
                onTap: _openAdminHistory,
              ),
              InfoTile(
                icon: Icons.bar_chart_rounded,
                title: 'Analytics & Fleet Metrics',
                subtitle: 'View trip completion rate, student boarding & bus usage',
                color: AppColors.success,
                backgroundColor: AppColors.successLight,
                onTap: _openAdminAnalytics,
              ),
            ],
          ),
        ),
      ),
    );
  }
}